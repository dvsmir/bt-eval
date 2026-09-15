#!/usr/bin/env bash
# 06-latest-usable-version
#
# State check : which version of com.acme:widgets does the compile classpath resolve,
#               is our own call site intact, and is the build green.
# Claim check : does the final report name the version that the code now uses.
set -u

WORK="${1:?usage: oracle.sh <WORKDIR> <RESULT_JSON>}"
RESULT="${2:?usage: oracle.sh <WORKDIR> <RESULT_JSON>}"

BT_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib" && pwd)"
source "$BT_LIB/oracle-lib.sh"

# The repository is a directory inside the project. Keep Gradle off the network so
# the verdict is the same in a year.
OL_GRADLE_EXTRA_ARGS="--offline"

[ -d "$WORK" ] || ol_broken "no work directory: $WORK"
[ -f "$WORK/gradlew" ] || ol_broken "no gradle wrapper in $WORK"

WANT="1.4.2"

# ---------------------------------------------------------------- resolved version
# Ask Gradle, not the file. The agent may move the version out of the catalog, and a
# dynamic version such as 1.+ has to be resolved before it can be judged.
if ! ol_gradle "$WORK" -q ":pricing:dependencies" --configuration compileClasspath; then
  ol_verdict FAIL "cannot resolve the pricing compile classpath"
fi

LINE="$(ol_gradle_out | grep -E 'com\.acme:widgets' | tail -1)"
if [ -z "$LINE" ]; then
  ol_verdict FAIL "com.acme:widgets is no longer on the pricing compile classpath"
fi

if printf '%s' "$LINE" | grep -q -- '->'; then
  GOT="$(printf '%s' "$LINE" | sed -E 's/.*-> *([0-9][A-Za-z0-9._+-]*).*/\1/')"
else
  GOT="$(printf '%s' "$LINE" | sed -E 's/.*com\.acme:widgets:([0-9][A-Za-z0-9._+-]*).*/\1/')"
fi

if [ "$GOT" != "$WANT" ]; then
  case "$GOT" in
    2.0.0) ol_verdict FAIL "left the project on 2.0.0, which drops the method we call" ;;
    1.0.0) ol_verdict FAIL "did not move the version, still 1.0.0" ;;
    *)     ol_verdict FAIL "stopped at $GOT, $WANT was available" ;;
  esac
fi

# ------------------------------------------------------------------- our own source
# The task said "without touching our own source". An agent that rewrote the call site
# solved a different problem, and the version number alone would hide that.
PRINTER="$WORK/pricing/src/main/java/com/example/shop/pricing/BasketPrinter.java"
if ! ol_grep_file "$PRINTER" 'WidgetFormatter\.describe\('; then
  ol_verdict FAIL "rewrote our call site instead of picking a version that fits it"
fi

# -------------------------------------------------------------------------- build
if ! ol_gradle "$WORK" build; then
  ol_verdict FAIL "version is $WANT but the build is red"
fi

# -------------------------------------------------------------------- claim check
if ol_result_text "$RESULT" | grep -qF "$WANT"; then
  ol_verdict PASS "moved to $WANT, build green, version reported"
fi

ol_verdict INCONCLUSIVE "code is at $WANT and green, but the report never names a version"
