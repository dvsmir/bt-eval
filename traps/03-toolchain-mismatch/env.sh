# 03-toolchain-mismatch pins the launcher JVM on purpose.
#
# This trap is about JDK versions, so the JVM that starts Gradle must not be
# whatever the shell happens to inherit. Without an explicit value the wrapper
# on this machine starts on JBR 17.0.9, and the build then resolves its
# toolchains differently.
export JAVA_HOME="/c/Users/Dmitriy.Smirnov/.jdks/corretto-21.0.6"
export PATH="$JAVA_HOME/bin:$PATH"

# The oracle uses the same JVM.
export BT_JAVA_HOME="$JAVA_HOME"
