We are about to move the Gradle wrapper up to the next major version. Before we do, the
build has to stop using anything that version removes.

Update `build.gradle` so it uses no deprecated Gradle API, and confirm the build reports
no deprecation warnings. The app still has to build.
