#!/usr/bin/env bash
# Runner for the build-tool agent eval.
#
# For every trap and every repeat it does this:
#   1. It copies traps/<slug>/project into a fresh scratch directory.
#   2. It runs `claude -p` on traps/<slug>/TASK.md in that directory.
#   3. It calls traps/<slug>/oracle.sh to get a verdict.
#   4. It appends one row to the results CSV.
#
# Usage:
#   ./run.sh                          all traps, 5 repeats, model sonnet
#   ./run.sh -t 01-test-task-mapping  one trap
#   ./run.sh -t 01-a,02-b -n 3        two traps, 3 repeats
#   ./run.sh --calibrate              measure the fixed harness overhead only
#   ./run.sh --naive                  remove the fair baseline CLAUDE.md
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

TRAPS=""
REPEATS=5
MODEL="sonnet"
OUT=""
TIMEOUT_S=1200
NAIVE=0
CALIBRATE=0
SCRATCH_ROOT="$DEFAULT_SCRATCH_ROOT"
DRYRUN=0

die() { printf 'run.sh: %s\n' "$1" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    -t) TRAPS="${TRAPS}${TRAPS:+,}$2"; shift 2 ;;
    -n) REPEATS="$2"; shift 2 ;;
    -m) MODEL="$2"; shift 2 ;;
    -o) OUT="$2"; shift 2 ;;
    -T) TIMEOUT_S="$2"; shift 2 ;;
    -s) SCRATCH_ROOT="$2"; shift 2 ;;
    --naive) NAIVE=1; shift ;;
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
  ( cd "$dir" && claude -p "Reply with exactly: OK" \
      --output-format json --model "$MODEL" ) >"$dir/result.json" 2>"$dir/stderr.log"
  python "$HERE/lib/append_row.py" "$OUT" "$dir/result.json" \
    "_calibration" "0" "PASS" "fixed harness overhead" "$MODEL" "0" "$STAMP"
  local total
  total="$(python "$HERE/lib/jsonget.py" "$dir/result.json" usage.cache_creation_input_tokens 0)"
  printf 'Fixed overhead (cache_creation_input_tokens): %s\n' "$total"
  printf 'Recorded as trap "_calibration" in %s\n' "$OUT"
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
  # shellcheck disable=SC1091
  [ -f "$TRAP_DIR/env.sh" ] && . "$TRAP_DIR/env.sh"
  export BT_JAVA_HOME

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

    if [ "$NAIVE" = "0" ] && [ -f "$HERE/template/BASELINE_CLAUDE.md" ]; then
      cp "$HERE/template/BASELINE_CLAUDE.md" "$WORK/CLAUDE.md"
    fi

    printf '%-28s run %s/%s ... ' "$slug" "$i" "$REPEATS"
    START="$(date +%s)"
    if [ "$HAVE_TIMEOUT" = "1" ]; then
      ( cd "$WORK" && JAVA_HOME="$BT_JAVA_HOME" timeout "${TIMEOUT_S}s" \
          claude -p "$(cat "$TRAP_DIR/TASK.md")" \
            --output-format json --model "$MODEL" \
            --permission-mode bypassPermissions ) \
        >"$WORKROOT/result.json" 2>"$WORKROOT/stderr.log"
    else
      ( cd "$WORK" && JAVA_HOME="$BT_JAVA_HOME" \
          claude -p "$(cat "$TRAP_DIR/TASK.md")" \
            --output-format json --model "$MODEL" \
            --permission-mode bypassPermissions ) \
        >"$WORKROOT/result.json" 2>"$WORKROOT/stderr.log"
    fi
    END="$(date +%s)"
    WALL=$(( END - START ))

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
      "$slug" "$i" "$VERDICT" "$DETAIL" "$MODEL" "$WALL" "$STAMP"

    printf '%-12s %s (%ss)\n' "$VERDICT" "$DETAIL" "$WALL"

    # The Gradle build output is large and it is not evidence. Drop it, then keep
    # the source tree the agent left behind, so a verdict can be checked by hand.
    rm -rf "$WORK"/*/build "$WORK/build" "$WORK/.gradle"            "$WORK/buildSrc/build" "$WORK/buildSrc/.gradle" 2>/dev/null
    cp -r "$WORK" "$WORKROOT/work-final" 2>/dev/null
    rm -rf "$WORK"

    i=$(( i + 1 ))
  done
done

printf '\nDone. Rows in %s\n' "$OUT"
printf 'Summary: python "%s/lib/summarize.py" "%s"\n' "$HERE" "$OUT"
