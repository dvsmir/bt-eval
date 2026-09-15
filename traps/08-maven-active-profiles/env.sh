# 08-maven-active-profiles pins the JDK on purpose.
#
# The whole trap is that a profile activates on the JDK version, so the JVM that
# starts Maven decides the answer. Discover a 21 first, rather than hardcode one
# path, so the trap survives a move to another machine. If nothing is found the
# runner default applies, and the trap still works on any JDK 17 or newer.
for _c in "$HOME/.jdks/corretto-21.0.6" "$HOME/.jdks"/*21* "$HOME/.sdkman/candidates/java"/*21* \
          /usr/lib/jvm/*21* "/c/Program Files/Java"/*21*; do
  if [ -x "$_c/bin/javac" ]; then
    BT_JAVA_HOME="$_c"
    break
  fi
done
unset _c

export JAVA_HOME="$BT_JAVA_HOME"
export PATH="$JAVA_HOME/bin:$PATH"
export BT_JAVA_HOME
