# 09-dependency-substitution injects a global Gradle init script.
#
# The trap is a version pin the repository cannot see. The real machine ~/.gradle
# must stay untouched and parallel jobs must not collide, so this builds a private
# GRADLE_USER_HOME in a temp directory, borrows the wrapper distribution from the
# real home so the offline build finds Gradle 8.14, and drops the init script there.
# env.sh is idempotent: it is safe to source again.

# Pin a JDK 21 launcher, the same discovery the other traps use.
for _c in "$HOME/.jdks/corretto-21.0.6" "$HOME/.jdks"/*21* "$HOME/.sdkman/candidates/java"/*21* \
          /usr/lib/jvm/*21* "/c/Program Files/Java"/*21*; do
  if [ -x "$_c/bin/javac" ]; then BT_JAVA_HOME="$_c"; break; fi
done
unset _c
export JAVA_HOME="$BT_JAVA_HOME"
export PATH="$JAVA_HOME/bin:$PATH"
export BT_JAVA_HOME

# Private Gradle home for this trap.
_gh="${TMPDIR:-/tmp}/bt-eval/gradle-home-09"
mkdir -p "$_gh/init.d"

# Borrow the wrapper distribution from the real home so the offline wrapper finds
# the Gradle build without a download. Junction on Windows, symlink elsewhere.
if [ ! -e "$_gh/wrapper" ]; then
  if command -v cygpath >/dev/null 2>&1; then
    MSYS_NO_PATHCONV=1 cmd /c mklink /J "$(cygpath -w "$_gh")\wrapper" \
      "$(cygpath -w "$HOME/.gradle/wrapper")" >/dev/null 2>&1 || true
  else
    ln -s "$HOME/.gradle/wrapper" "$_gh/wrapper" 2>/dev/null || true
  fi
fi

# The policy the repository cannot see: pin com.acme:widgets to 1.0.0 whatever the
# version catalog asks for.
cat > "$_gh/init.d/00-platform-policy.gradle" <<'INIT'
allprojects {
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == 'com.acme' && requested.name == 'widgets') {
                useVersion('1.0.0')
                because('pinned to 1.0.0 by platform policy')
            }
        }
    }
}
INIT

# Export a native path so the Windows JVM understands GRADLE_USER_HOME.
if command -v cygpath >/dev/null 2>&1; then
  GRADLE_USER_HOME="$(cygpath -w "$_gh")"
else
  GRADLE_USER_HOME="$_gh"
fi
export GRADLE_USER_HOME
unset _gh
