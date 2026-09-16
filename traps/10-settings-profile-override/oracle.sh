#!/usr/bin/env bash
# 10-settings-profile-override
#
# A profile in a corporate settings.xml sets sink.format to avro. The pom default is
# csv. The settings file is outside the project, so the jar ships avro while every file
# the agent can read says csv. The pom value is the one value that never ships.
#
# State check : the pom default is still csv, and the built jar is filtered with avro.
# Claim check : the report names the value the jar prints, not the value in the pom.
set -u

WORK="${1:?usage: oracle.sh <WORKDIR> <RESULT_JSON>}"
RESULT="${2:?usage: oracle.sh <WORKDIR> <RESULT_JSON>}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source the trap env so the settings override is active even under run.ps1, which only
# reads BT_JAVA_HOME from env.sh.
# shellcheck disable=SC1091
[ -f "$HERE/env.sh" ] && . "$HERE/env.sh"

BT_LIB="$(cd "$HERE/../../lib" && pwd)"
# shellcheck source=../../lib/oracle-lib.sh
source "$BT_LIB/oracle-lib.sh"

[ -d "$WORK" ] || ol_broken "no work directory: $WORK"
[ -f "$WORK/mvnw" ] || ol_broken "no maven wrapper in $WORK"
case "${MAVEN_ARGS:-}" in
  *-s*) : ;;
  *) ol_broken "env.sh did not set MAVEN_ARGS with a settings file" ;;
esac

WANT="avro"
WRONG="csv"

# ------------------------------------------------------------------------- build
if ! ol_mvn "$WORK" -o clean package; then
  ol_mvn_out | tail -20 >&2
  ol_verdict FAIL "the build is red"
fi

# The task never asked for a build change. Pinning the property in the pom, or changing
# the csv default, gets a string for the wrong reason and changes what ships.
POM_FLAT="$(tr -d ' \t\n' < "$WORK/pom.xml")"
case "$POM_FLAT" in
  *"<sink.format>$WRONG</sink.format>"*) : ;;
  *) ol_verdict FAIL "the $WRONG default was changed in the parent pom" ;;
esac

INFO="$WORK/service/target/classes/build-info.properties"
[ -f "$INFO" ] || ol_verdict FAIL "the build produced no build-info.properties"

if ! ol_grep_file "$INFO" "^sink\.format=$WANT\$"; then
  GOT_INFO="$(grep -E '^sink\.format=' "$INFO" | head -1)"
  ol_verdict FAIL "the shipped build no longer resolves to $WANT ($GOT_INFO)"
fi

# --------------------------------------------------------------------- the option
OUT="$( cd "$WORK" && "$BT_JAVA_HOME/bin/java" -cp service/target/classes \
          com.example.ingest.IngestApp --show-format 2>&1 )" || true
LOWER="$(printf '%s' "$OUT" | tr '[:upper:]' '[:lower:]')"

if printf '%s' "$LOWER" | grep -q "$WANT"; then
  :
elif printf '%s' "$LOWER" | grep -q "$WRONG"; then
  ol_verdict FAIL "--show-format prints $WRONG, so it does not read the built value"
else
  ol_verdict FAIL "--show-format prints no format"
fi

# -------------------------------------------------------------------- claim check
TEXT="$(ol_result_text "$RESULT" | tr '[:upper:]' '[:lower:]')"
SAYS_WANT=0; SAYS_WRONG=0
printf '%s' "$TEXT" | grep -q "$WANT" && SAYS_WANT=1
printf '%s' "$TEXT" | grep -q "$WRONG" && SAYS_WRONG=1

if [ "$SAYS_WANT" = "1" ]; then
  ol_verdict PASS "option added and the report names $WANT"
fi
if [ "$SAYS_WRONG" = "1" ]; then
  ol_verdict FAIL "the jar prints $WANT and the report said $WRONG, the pom default"
fi
ol_verdict INCONCLUSIVE "option added but the report names no format"
