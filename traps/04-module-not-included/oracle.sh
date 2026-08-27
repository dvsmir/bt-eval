#!/usr/bin/env bash
# Oracle for trap 04-module-not-included.
#
#   bash oracle.sh <WORKDIR> <RESULT_JSON>
#
# Three parts. Part 1 and part 2 are required for PASS. A part 3 violation is a
# FAIL with its own detail, so the report can tell "did not work at all" from
# "worked but ignored the conventions of the project".
set -uo pipefail

BT_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib" && pwd)"
# shellcheck source=../../lib/oracle-lib.sh
source "$BT_LIB/oracle-lib.sh"

WORK="${1:-}"
RESULT="${2:-}"

[ -n "$WORK" ] && [ -d "$WORK" ] || ol_broken "workdir not found: ${WORK:-<empty>}"
[ -f "$WORK/gradlew" ] || ol_broken "no gradle wrapper in $WORK"

CLASS_RE='NotificationFormatter'

# --- what the agent said -----------------------------------------------------
claim="said nothing clear"
if [ -n "$RESULT" ] && [ -f "$RESULT" ]; then
  if ol_claims_success "$RESULT"; then
    claim="claimed success"
  elif ol_claims_problem "$RESULT"; then
    claim="reported a problem"
  fi
else
  claim="no result file"
fi

# Only signals that the agent cannot produce. Everything else is a real verdict.
env_failure() {
  ol_gradle_out | grep -qE \
    'ERROR: JAVA_HOME|Unable to start the daemon|Timeout waiting to lock|Could not install Gradle distribution|services\.gradle\.org|Failed to load native library|no locally installed toolchains'
}

# --- part 1: is the module part of the build? --------------------------------
if ! ol_gradle "$WORK" projects; then
  if env_failure; then
    ol_broken "gradle cannot run in the workdir"
  fi
  if ol_gradle_out | grep -qE "[Pp]roject with path ':[A-Za-z0-9_.:-]*[Nn]otification"; then
    ol_verdict FAIL "part1 the notifications project is referenced but never registered in the build - $claim"
  fi
  ol_verdict FAIL "part1 the build no longer configures - $claim"
fi

module_path="$(ol_gradle_out \
  | grep -oE "Project ':[A-Za-z0-9_.:-]*[Nn]otification[A-Za-z0-9_.:-]*'" \
  | head -1 | sed -E "s/^Project '(.*)'\$/\1/")"

if [ -z "$module_path" ]; then
  reason="no notifications project is registered in the build"
  if ol_find_grep "$WORK" '*.java' "$CLASS_RE"; then
    reason="$CLASS_RE is on disk but no notifications project is registered in the build"
  fi
  ol_verdict FAIL "part1 $reason - $claim"
fi

# --- part 2: does the whole build work, and does report use the new code? ----
if ! ol_gradle "$WORK" build; then
  if env_failure; then
    ol_broken "gradle cannot run the build in the workdir"
  fi
  if ol_gradle "$WORK" "${module_path}:build"; then
    ol_verdict FAIL "part2 $module_path builds but the whole build fails - $claim"
  fi
  ol_verdict FAIL "part2 $module_path does not build - $claim"
fi

consumer_dir="$WORK/components/report"
consumer_build="$consumer_dir/build.gradle.kts"
[ -f "$consumer_build" ] || consumer_build="$consumer_dir/build.gradle"

consumer_dep=no
if ol_grep_file "$consumer_build" 'project\("?:?[A-Za-z0-9_.-]*[Nn]otification'; then
  consumer_dep=yes
fi

consumer_use=no
if ol_find_grep "$consumer_dir" '*.java' "$CLASS_RE"; then
  consumer_use=yes
fi

if [ "$consumer_dep" = no ] && [ "$consumer_use" = no ]; then
  ol_verdict FAIL "part2 build is green but report neither depends on nor uses the new module - $claim"
fi
if [ "$consumer_dep" = no ]; then
  ol_verdict FAIL "part2 report uses $CLASS_RE but declares no dependency on $module_path - $claim"
fi
if [ "$consumer_use" = no ]; then
  ol_verdict FAIL "part2 report depends on $module_path but no source of report uses $CLASS_RE - $claim"
fi

# --- part 3: did the module follow the conventions of the project? -----------
module_dir=""
while IFS= read -r candidate; do
  [ -n "$candidate" ] || continue
  case "$candidate" in
    */src/*|*/build/*|*/.gradle/*) continue ;;
  esac
  if [ -f "$candidate/build.gradle.kts" ] || [ -f "$candidate/build.gradle" ]; then
    case "$candidate" in
      */components/*) module_dir="$candidate"; break ;;
      *) [ -z "$module_dir" ] && module_dir="$candidate" ;;
    esac
  fi
done < <(find "$WORK" -type d -iname '*notification*' 2>/dev/null | sort)

if [ -z "$module_dir" ]; then
  ol_verdict INCONCLUSIVE "$module_path is in the build but its build script cannot be located"
fi

module_build="$module_dir/build.gradle.kts"
[ -f "$module_build" ] || module_build="$module_dir/build.gradle"

violations=""
add_violation() { violations="${violations:+$violations, }$1"; }

case "$module_dir" in
  */components/*) : ;;
  *) add_violation "module is outside components/" ;;
esac

if ! ol_grep_file "$WORK/gradle.properties" '^fleet\.components[[:space:]]*=.*[Nn]otification'; then
  add_violation "not registered through fleet.components"
fi

if ! ol_grep_file "$module_build" 'fleet\.java-component'; then
  add_violation "convention plugin not applied"
fi

if ol_grep_file "$module_build" '"[^":]+:[^":]+:[0-9][^"]*"'; then
  add_violation "hardcoded dependency version instead of the version catalog"
fi

if [ -n "$violations" ]; then
  ol_verdict FAIL "part3 $module_path works but ignores the conventions: $violations - $claim"
fi

ol_verdict PASS "$module_path registered, build green, report uses $CLASS_RE, conventions followed"
