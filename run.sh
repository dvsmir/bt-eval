#!/usr/bin/env bash
# Runner for the build-tool agent eval.
#
# For every trap and every repeat it does this:
#   1. It copies traps/<slug>/project into a fresh scratch directory.
#   2. It runs `claude -p` on traps/<slug>/TASK.md in that directory.
#   3. It calls traps/<slug>/oracle.sh to get a verdict.
#   4. It appends one row to the results CSV.
#
# Each run is isolated from every other run. See "per-run isolation" below.
#
# Usage:
#   ./run.sh                          all traps, 5 repeats, model sonnet
#   ./run.sh -t 01-test-task-mapping  one trap
#   ./run.sh -t 01-a,02-b -n 3        two traps, 3 repeats
#   ./run.sh --calibrate              measure the fixed harness overhead only
#   ./run.sh --naive                  remove the fair baseline CLAUDE.md
#   ./run.sh --skill                  install the trap's declared skill(s), then run
#   ./run.sh --dry-run                show the plan, run nothing
#   ./run.sh -s /tmp/other            put the scratch tree somewhere else
#
# Read README.md before you believe any number this produces.

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_JAVA_HOME="/c/Users/Dmitriy.Smirnov/.jdks/corretto-21.0.6"

# The agent under test must run OUTSIDE this repository. Claude Code collects every
# CLAUDE.md from the working directory upwards. A scratch directory inside the
# workspace gives the agent the workspace instructions, which is measured context
# pollution: a probe answered YES to a Next Move Theory question and paid about
# 1,500 extra tokens. Keep the scratch root on a neutral path.
DEFAULT_SCRATCH_ROOT="/tmp/bt-eval"

# The host's real Claude config. Each run gets a fresh copy seeded with only the
# keys auth needs, so no transcript, memory, history, plugin, or personal skill
# from a previous run or from the host reaches the agent. See "per-run isolation".
REAL_CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

TRAPS=""
REPEATS=5
MODEL="sonnet"
OUT=""
TIMEOUT_S=1200
NAIVE=0
CALIBRATE=0
SKILL=0
SCRATCH_ROOT="$DEFAULT_SCRATCH_ROOT"
DRYRUN=0

die() { printf 'run.sh: %s\n' "$1" >&2; exit 1; }

# ------------------------------------------------------ per-run isolation helpers
# Convert a path to the native (Windows) form the JVM and the Node CLI expect, and
# back to the POSIX form the shell writes with. No-ops off Windows.
nativepath() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi; }
unixpath()   { if command -v cygpath >/dev/null 2>&1; then cygpath -u "$1"; else printf '%s' "$1"; fi; }

# Junction (Windows) or symlink (elsewhere) $2 -> $1, only when the target exists
# and the link does not. Used to share the immutable Gradle download cache and the
# wrapper distribution into a per-run Gradle home, so isolation costs no re-download.
link_shared() {
  local tgt="$1" lnk="$2"
  [ -e "$tgt" ] || return 0
  [ -e "$lnk" ] && return 0
  if command -v cygpath >/dev/null 2>&1; then
    MSYS_NO_PATHCONV=1 cmd /c mklink /J "$(cygpath -w "$lnk")" "$(cygpath -w "$tgt")" >/dev/null 2>&1 || true
  else
    ln -s "$tgt" "$lnk" 2>/dev/null || true
  fi
}

# Seed a fresh Claude config dir with only what auth needs, then the agent runs
# with no prior transcript, memory, history, plugin, or the host's personal skills.
# $1 is the target dir, wiped and recreated.
seed_claude_home() {
  local dir="$1"
  rm -rf "$dir"; mkdir -p "$dir"
  [ -f "$REAL_CLAUDE_DIR/.credentials.json" ] && cp "$REAL_CLAUDE_DIR/.credentials.json" "$dir/.credentials.json" 2>/dev/null
  python "$HERE/lib/seed_claude_settings.py" "$REAL_CLAUDE_DIR/settings.json" "$dir/settings.json" 2>/dev/null || printf '{}' > "$dir/settings.json"
}

while [ $# -gt 0 ]; do
  case "$1" in
    -t) TRAPS="${TRAPS}${TRAPS:+,}$2"; shift 2 ;;
    -n) REPEATS="$2"; shift 2 ;;
    -m) MODEL="$2"; shift 2 ;;
    -o) OUT="$2"; shift 2 ;;
    -T) TIMEOUT_S="$2"; shift 2 ;;
    -s) SCRATCH_ROOT="$2"; shift 2 ;;
    --naive) NAIVE=1; shift ;;
    --skill) SKILL=1; shift ;;
    --calibrate) CALIBRATE=1; shift ;;
    --dry-run) DRYRUN=1; shift ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

command -v claude >/dev/null 2>&1 || die "the claude CLI is not on PATH"
command -v python >/dev/null 2>&1 || die "python is not on PATH"

STAMP="$(date +%Y%m%d-%H%M%S)"
RUNDIR="$HERE/results/$STAMP"
[ -n "$OUT" ] || OUT="$RUNDIR/results.csv"
mkdir -p "$RUNDIR"
SCRATCH="$SCRATCH_ROOT/$STAMP"
mkdir -p "$SCRATCH" || die "cannot create the scratch directory $SCRATCH"
# Test the hazard itself, not a path prefix. An earlier version compared the
# scratch path against the repository root. That let a scratch directory beside
# the repository inherit the workspace CLAUDE.md, and nothing complained.
probe="$(cd "$SCRATCH" && pwd -P)"
while [ -n "$probe" ]; do
  [ -f "$probe/CLAUDE.md" ] && die "the scratch root inherits $probe/CLAUDE.md; pick another with -s"
  parent="$(dirname "$probe")"
  [ "$parent" = "$probe" ] && break
  probe="$parent"
done

HAVE_TIMEOUT=0
command -v timeout >/dev/null 2>&1 && HAVE_TIMEOUT=1

# ---------------------------------------------------------------- calibration
# Every headless run pays a fixed token cost for the system prompt and the tool
# definitions, before it does any work on the task. Subtract this number, or a
# real saving on the task looks much smaller than it is.
calibrate() {
  local dir="$SCRATCH/_calibration"
  mkdir -p "$dir"
  printf 'Calibrating fixed harness overhead (model %s) ...\n' "$MODEL"
  seed_claude_home "$dir/claude-home"
  local chome; chome="$(nativepath "$dir/claude-home")"
  ( cd "$dir" && CLAUDE_CONFIG_DIR="$chome" claude -p "Reply with exactly: OK" \
      --output-format json --model "$MODEL" ) >"$dir/result.json" 2>"$dir/stderr.log"
  python "$HERE/lib/append_row.py" "$OUT" "$dir/result.json" \
    "_calibration" "0" "PASS" "fixed harness overhead" "$MODEL" "0" "$STAMP" "calibration"
  # Persist the calibration where a later trap run can find it. summarize.py walks
  # up from results/<stamp>/results.csv and reads results/calibration.csv, so one
  # calibration serves every run that follows, with no need to force -o onto one file.
  mkdir -p "$HERE/results"
  python "$HERE/lib/append_row.py" "$HERE/results/calibration.csv" "$dir/result.json" \
    "_calibration" "0" "PASS" "fixed harness overhead" "$MODEL" "0" "$STAMP" "calibration"
  local total
  total="$(python "$HERE/lib/jsonget.py" "$dir/result.json" usage.cache_creation_input_tokens 0)"
  printf 'Fixed overhead (cache_creation_input_tokens): %s\n' "$total"
  printf 'Recorded as trap "_calibration" in %s\n' "$HERE/results/calibration.csv"
}

if [ "$CALIBRATE" = "1" ]; then
  [ "$DRYRUN" = "1" ] && { echo "would calibrate with model $MODEL"; exit 0; }
  calibrate
  exit 0
fi

# ------------------------------------------------------------------ trap list
if [ -z "$TRAPS" ]; then
  TRAP_LIST=""
  for d in "$HERE"/traps/*/; do
    [ -f "$d/TASK.md" ] || continue
    TRAP_LIST="${TRAP_LIST}${TRAP_LIST:+ }$(basename "$d")"
  done
else
  TRAP_LIST="$(printf '%s' "$TRAPS" | tr ',' ' ')"
fi
[ -n "$TRAP_LIST" ] || die "no traps found; each trap needs traps/<slug>/TASK.md"

printf 'Run       : %s\n' "$STAMP"
printf 'Model     : %s\n' "$MODEL"
printf 'Repeats   : %s\n' "$REPEATS"
printf 'Traps     : %s\n' "$TRAP_LIST"
printf 'Baseline  : %s\n' "$([ "$NAIVE" = "1" ] && echo 'naive (no CLAUDE.md)' || echo 'fair (BASELINE_CLAUDE.md)')"
printf 'Skill     : %s\n' "$([ "$SKILL" = "1" ] && echo 'on (install declared skills)' || echo 'off')"
printf 'Isolation : fresh Claude config, Gradle home, and Maven purge per run\n'
printf 'Results   : %s\n\n' "$OUT"

if [ "$DRYRUN" = "1" ]; then
  for slug in $TRAP_LIST; do
    printf 'would run %s x%s\n' "$slug" "$REPEATS"
  done
  exit 0
fi

# --------------------------------------------------------------------- driver
for slug in $TRAP_LIST; do
  TRAP_DIR="$HERE/traps/$slug"
  [ -d "$TRAP_DIR" ] || { printf 'SKIP %s: no such trap\n' "$slug"; continue; }
  [ -f "$TRAP_DIR/TASK.md" ] || { printf 'SKIP %s: no TASK.md\n' "$slug"; continue; }
  [ -f "$TRAP_DIR/oracle.sh" ] || { printf 'SKIP %s: no oracle.sh\n' "$slug"; continue; }
  [ -d "$TRAP_DIR/project" ] || { printf 'SKIP %s: no project/\n' "$slug"; continue; }

  # A trap about JDK versions may pin its own JAVA_HOME.
  BT_JAVA_HOME="$DEFAULT_JAVA_HOME"
  # A trap about hidden build state may inject a Gradle home or Maven args from
  # env.sh. Clear them each trap so one trap's env.sh cannot leak into the next.
  unset GRADLE_USER_HOME MAVEN_ARGS
  # shellcheck disable=SC1091
  [ -f "$TRAP_DIR/env.sh" ] && . "$TRAP_DIR/env.sh"
  export BT_JAVA_HOME
  # A trap may pin its own Gradle home (09). Keep it across this trap's repeats, but
  # force the daemon off so no in-memory build state survives between them.
  TRAP_GH="${GRADLE_USER_HOME:-}"
  if [ -n "$TRAP_GH" ]; then
    _ghu="$(unixpath "$TRAP_GH")"; mkdir -p "$_ghu"
    grep -q '^org.gradle.daemon=false' "$_ghu/gradle.properties" 2>/dev/null \
      || printf 'org.gradle.daemon=false\n' >> "$_ghu/gradle.properties"
    unset _ghu
  fi

  i=1
  while [ "$i" -le "$REPEATS" ]; do
    WORKROOT="$RUNDIR/$slug/run$i"
    WORK="$SCRATCH/$slug/run$i/work"
    mkdir -p "$WORKROOT" "$(dirname "$WORK")"
    rm -rf "$WORK"
    cp -r "$TRAP_DIR/project" "$WORK"

    # The agent must never see the trap documentation. Only project/ is copied,
    # but strip any stray answer files just in case a trap author slipped.
    rm -f "$WORK/TRAP.md" "$WORK/EXPECTED.md" "$WORK/oracle.sh" 2>/dev/null

    # Strip any committed build output so the agent starts from source, not from a
    # previous build. Some trap projects carry a stale build/, .gradle/, or target/.
    find "$WORK" -type d \( -name build -o -name .gradle -o -name target \) -prune -exec rm -rf {} + 2>/dev/null

    if [ "$NAIVE" = "0" ] && [ -f "$HERE/template/BASELINE_CLAUDE.md" ]; then
      cp "$HERE/template/BASELINE_CLAUDE.md" "$WORK/CLAUDE.md"
    fi

    # A skill run installs the trap's declared skills into the session, and if the trap
    # ships mock fixtures it puts the mock CLI on PATH and serves them. The agent then
    # sees the skill and the tool as a user who had installed them would. skill.txt names
    # one shared skill per line. Comments and blank lines are ignored.
    CONDITION="baseline"
    SKILL_BIN=""
    MOCK_DIR=""
    if [ "$SKILL" = "1" ] && [ -f "$TRAP_DIR/skill.txt" ]; then
      while IFS= read -r sname || [ -n "$sname" ]; do
        case "$sname" in ''|'#'*) continue ;; esac
        if [ -d "$HERE/skills/$sname" ]; then
          mkdir -p "$WORK/.claude/skills"
          cp -r "$HERE/skills/$sname" "$WORK/.claude/skills/$sname"
          CONDITION="skill"
        else
          printf 'WARN %s: skill "%s" not found in skills/\n' "$slug" "$sname" >&2
        fi
      done < "$TRAP_DIR/skill.txt"
      # Serve the trap's mock fixtures through the shared CLI. Both sit outside the
      # agent's working tree, so the answer reaches the agent only through the tool.
      if [ "$CONDITION" = "skill" ] && [ -d "$TRAP_DIR/mock" ]; then
        SKILL_BIN="$SCRATCH/$slug/run$i/bin"
        MOCK_DIR="$SCRATCH/$slug/run$i/mock"
        mkdir -p "$SKILL_BIN" "$MOCK_DIR"
        cp "$HERE"/lib/mock/* "$SKILL_BIN"/ 2>/dev/null
        chmod +x "$SKILL_BIN"/bt-ide 2>/dev/null
        cp "$TRAP_DIR/mock/"* "$MOCK_DIR"/ 2>/dev/null
      fi
    fi

    # A trap may need extra flags on the claude command. Trap 07 denies the web
    # tools, because a question it asks is only meaningful when the agent cannot
    # look the answer up. One argument per line, blank lines and # comments ignored.
    TRAP_ARGS=()
    if [ -f "$TRAP_DIR/agent-args.txt" ]; then
      while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in ''|'#'*) continue ;; esac
        TRAP_ARGS+=("$line")
      done < "$TRAP_DIR/agent-args.txt"
    fi

    # ---- per-run isolation ---------------------------------------------------
    # No cache, memory, or daemon from a previous run may reach this one.
    # Claude: a fresh, auth-seeded config dir (no transcripts, memory, or plugins).
    seed_claude_home "$SCRATCH/$slug/run$i/claude-home"
    CLAUDE_HOME_NATIVE="$(nativepath "$SCRATCH/$slug/run$i/claude-home")"
    # Detect the build tool from what the agent will see.
    IS_MAVEN=0
    { [ -f "$WORK/pom.xml" ] || [ -f "$WORK/mvnw" ] || ls "$WORK"/*/pom.xml >/dev/null 2>&1; } && IS_MAVEN=1
    # Gradle: a fresh home with the daemon off and only the immutable download cache
    # and wrapper shared in, unless the trap pinned its own home above.
    if [ -n "$TRAP_GH" ]; then
      export GRADLE_USER_HOME="$TRAP_GH"
    elif [ "$IS_MAVEN" = "0" ]; then
      _gh="$SCRATCH/$slug/run$i/gradle-home"
      rm -rf "$_gh"; mkdir -p "$_gh/caches"
      printf 'org.gradle.daemon=false\n' > "$_gh/gradle.properties"
      link_shared "$HOME/.gradle/wrapper" "$_gh/wrapper"
      link_shared "$HOME/.gradle/caches/modules-2" "$_gh/caches/modules-2"
      export GRADLE_USER_HOME="$(nativepath "$_gh")"
      unset _gh
    else
      unset GRADLE_USER_HOME
    fi
    # Maven: keep the shared ~/.m2 download cache, but record its SNAPSHOT set now so
    # any module the agent installs can be removed after, before it masks the trap
    # for the next repeat.
    SNAP_BEFORE=""
    if [ "$IS_MAVEN" = "1" ] && [ -d "$HOME/.m2/repository" ]; then
      SNAP_BEFORE="$WORKROOT/.snap-before.list"
      find "$HOME/.m2/repository" -type d -name '*-SNAPSHOT' 2>/dev/null | sort > "$SNAP_BEFORE"
    fi

    printf '%-28s run %s/%s ... ' "$slug" "$i" "$REPEATS"
    START="$(date +%s)"
    if [ "$HAVE_TIMEOUT" = "1" ]; then
      ( cd "$WORK" && JAVA_HOME="$BT_JAVA_HOME" CLAUDE_CONFIG_DIR="$CLAUDE_HOME_NATIVE" PATH="${SKILL_BIN:+$SKILL_BIN:}$PATH" BT_MOCK_DIR="$MOCK_DIR" timeout "${TIMEOUT_S}s" \
          claude -p "$(cat "$TRAP_DIR/TASK.md")" \
            --output-format json --model "$MODEL" \
            --permission-mode bypassPermissions \
            ${TRAP_ARGS[@]+"${TRAP_ARGS[@]}"} ) \
        >"$WORKROOT/result.json" 2>"$WORKROOT/stderr.log"
    else
      ( cd "$WORK" && JAVA_HOME="$BT_JAVA_HOME" CLAUDE_CONFIG_DIR="$CLAUDE_HOME_NATIVE" PATH="${SKILL_BIN:+$SKILL_BIN:}$PATH" BT_MOCK_DIR="$MOCK_DIR" \
          claude -p "$(cat "$TRAP_DIR/TASK.md")" \
            --output-format json --model "$MODEL" \
            --permission-mode bypassPermissions \
            ${TRAP_ARGS[@]+"${TRAP_ARGS[@]}"} ) \
        >"$WORKROOT/result.json" 2>"$WORKROOT/stderr.log"
    fi
    END="$(date +%s)"
    WALL=$(( END - START ))

    # Remove any Maven module the agent installed into the shared ~/.m2, so the next
    # repeat faces the trap fresh. Only SNAPSHOTs that appeared during this run go.
    if [ "$IS_MAVEN" = "1" ] && [ -n "$SNAP_BEFORE" ]; then
      find "$HOME/.m2/repository" -type d -name '*-SNAPSHOT' 2>/dev/null | sort > "$WORKROOT/.snap-after.list"
      comm -13 "$SNAP_BEFORE" "$WORKROOT/.snap-after.list" 2>/dev/null | while IFS= read -r _d; do
        [ -n "$_d" ] && rm -rf "$_d"
      done
    fi

    VERDICT="INCONCLUSIVE"; DETAIL="oracle did not run"
    if LINE="$( BT_JAVA_HOME="$BT_JAVA_HOME" bash "$TRAP_DIR/oracle.sh" \
                  "$WORK" "$WORKROOT/result.json" 2>"$WORKROOT/oracle.err" )"; then
      :
    fi
    if [ -n "${LINE:-}" ]; then
      VERDICT="${LINE%%|*}"
      DETAIL="${LINE#*|}"
    else
      DETAIL="oracle produced no verdict line"
    fi
    printf '%s\n' "$LINE" > "$WORKROOT/verdict.txt"

    python "$HERE/lib/append_row.py" "$OUT" "$WORKROOT/result.json" \
      "$slug" "$i" "$VERDICT" "$DETAIL" "$MODEL" "$WALL" "$STAMP" "$CONDITION"

    printf '%-12s %s (%ss)\n' "$VERDICT" "$DETAIL" "$WALL"

    # The build output is large and it is not evidence. Drop it, then keep
    # the source tree the agent left behind, so a verdict can be checked by hand.
    # Maven writes target/, Gradle writes build/ and .gradle/.
    rm -rf "$WORK"/*/build "$WORK/build" "$WORK/.gradle" "$WORK/buildSrc/build" "$WORK/buildSrc/.gradle" 2>/dev/null
    find "$WORK" -type d -name target -prune -exec rm -rf {} + 2>/dev/null
    cp -r "$WORK" "$WORKROOT/work-final" 2>/dev/null
    rm -rf "$WORK"
    # Do not leave a copy of the host credentials in the scratch tree.
    rm -rf "$SCRATCH/$slug/run$i/claude-home" 2>/dev/null

    i=$(( i + 1 ))
  done
done

printf '\nDone. Rows in %s\n' "$OUT"
printf 'Summary: python "%s/lib/summarize.py" "%s"\n' "$HERE" "$OUT"
