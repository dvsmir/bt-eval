# 10-settings-profile-override injects a Maven user settings file.
#
# The trap is a property override the repository cannot see. A profile in a corporate
# settings.xml sets sink.format, and every jar is filtered with that value, not the
# csv default in the pom. The settings file lives under the trap directory, out of the
# project the agent sees. env.sh copies it to a path with no spaces, because Maven
# splits MAVEN_ARGS on whitespace, then points -s at the copy. env.sh is idempotent.

# Pin a JDK, the same discovery the other traps use.
for _c in "$HOME/.jdks/corretto-21.0.6" "$HOME/.jdks"/*21* "$HOME/.sdkman/candidates/java"/*21* \
          /usr/lib/jvm/*21* "/c/Program Files/Java"/*21*; do
  if [ -x "$_c/bin/javac" ]; then BT_JAVA_HOME="$_c"; break; fi
done
unset _c
export JAVA_HOME="$BT_JAVA_HOME"
export PATH="$JAVA_HOME/bin:$PATH"
export BT_JAVA_HOME

# Copy the settings file to a space-free path, because MAVEN_ARGS is split on spaces
# and the checkout path contains a space.
_self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_dst="${TMPDIR:-/tmp}/bt-eval/m2-10"
mkdir -p "$_dst"
cp "$_self/home/settings.xml" "$_dst/settings.xml"

if command -v cygpath >/dev/null 2>&1; then
  export MAVEN_ARGS="-s $(cygpath -w "$_dst/settings.xml")"
else
  export MAVEN_ARGS="-s $_dst/settings.xml"
fi
unset _self _dst
