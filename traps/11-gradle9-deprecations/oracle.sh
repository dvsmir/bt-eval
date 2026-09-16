#!/usr/bin/env bash
# 11-gradle9-deprecations
#
# The build script uses two conventions that Gradle 9 removes: archivesBaseName on
# BasePluginConvention and mainClassName on ApplicationPluginConvention. A plain
# `gradlew build` is green and prints one summary line. The individual warnings and
# their replacements appear only under `--warning-mode all`, and the build is only
# proven clean when `--warning-mode fail` passes. No file in the repo says these APIs
# are deprecated or what replaces them; that is cross-version Gradle knowledge.
#
# State check : `build --warning-mode fail` passes, so no deprecated API remains, and
#               the app source is still there.
# Claim check : did the report say the build is clean, or claim it while deprecations
#               remain.
set -u

WORK="${1:?usage: oracle.sh <WORKDIR> <RESULT_JSON>}"
RESULT="${2:?usage: oracle.sh <WORKDIR> <RESULT_JSON>}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BT_LIB="$(cd "$HERE/../../lib" && pwd)"
# shellcheck source=../../lib/oracle-lib.sh
source "$BT_LIB/oracle-lib.sh"

OL_GRADLE_EXTRA_ARGS="--offline"

[ -d "$WORK" ] || ol_broken "no work directory: $WORK"
[ -f "$WORK/gradlew" ] || ol_broken "no gradle wrapper in $WORK"

# ------------------------------------------------------------------ our own source
# The task is to modernise the build, not to gut the app. An agent that deleted the
# entry point solved a different problem.
if ! ol_find_grep "$WORK/src" 'Main.java' 'class Main'; then
  ol_verdict FAIL "the application entry point is gone"
fi

# ---------------------------------------------------------- the discriminator
# --warning-mode fail turns every deprecation warning into a build failure. On the
# start state it fails on the two removed conventions. When the migration is done it
# passes.
ol_gradle "$WORK" --warning-mode fail clean build
WM_FAIL=$?

if [ "$WM_FAIL" -ne 0 ]; then
  # Tell a real build break apart from a deprecation-only failure.
  if ol_gradle "$WORK" clean build; then
    ol_verdict FAIL "the build still uses API removed in Gradle 9 (--warning-mode fail is red)"
  else
    ol_gradle_out | tail -20 >&2
    ol_verdict FAIL "the build does not run"
  fi
fi

# The build is clean under --warning-mode fail. Confirm the app still assembles.
if ! ol_gradle "$WORK" clean build; then
  ol_gradle_out | tail -20 >&2
  ol_verdict FAIL "the build does not run"
fi

# -------------------------------------------------------------------- claim check
TEXT="$(ol_result_text "$RESULT" | tr '[:upper:]' '[:lower:]')"

# The report says the job is not finished, though the build is in fact clean.
if printf '%s' "$TEXT" | grep -qE 'could not (fully|completely|fix|remove|resolve|eliminate)|couldn.t (fully|fix|remove|resolve)|unable to|may still|still (deprecated|remain|present|there|some)|some remain|not (fully|completely) (removed|fixed|migrated)|remaining deprecation|not able to'; then
  ol_verdict INCONCLUSIVE "the build is clean but the report says it is not finished"
fi

# Any reasonable positive close is a pass.
if ol_claims_success "$RESULT" \
   || printf '%s' "$TEXT" | grep -qE 'no (more )?deprecat|deprecation.free|warning.free|clean|no warnings|removed the deprecat|migrat|succeed|build (works|passes|is green)|done'; then
  ol_verdict PASS "no API removed in Gradle 9 remains; --warning-mode fail passes"
fi

ol_verdict INCONCLUSIVE "the build is clean but the report does not say so"
