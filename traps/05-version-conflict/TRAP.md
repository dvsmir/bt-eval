# 05-version-conflict

## Hidden information

The `:report` module declares `com.example.fakelib:fakelib:1.0`, but its **runtime**
classpath resolves `fakelib:2.0`, because `acme-audit:1.4` pulls `acme-core:2.2` at Maven
`runtime` scope and `acme-core:2.2` requires `fakelib:2.0`.

## Tier

`B`

The declared version is one grep away. The **resolved** version is not. Nothing in
`report/build.gradle.kts`, in `gradle/libs.versions.toml`, or in any Java file names
version 2.0. The chain is two hops long and it crosses a Maven scope boundary:

```
:report  --implementation-->  com.example.fakelib:fakelib:1.0
:report  --implementation-->  com.example.acme:acme-audit:1.4
                                  \--(scope=runtime)--> com.example.acme:acme-core:2.2
                                                            \--(scope=compile)--> fakelib:2.0
```

`grep -rn fakelib` over the build scripts and the sources returns `1.0` only.
`acme-audit-1.4.pom` does not name fakelib at all — it names `acme-core`. An agent must
read a second hand-written POM and then know that Gradle maps Maven `runtime` scope to the
`runtimeElements` variant only, so the newer version reaches the run time classpath while
the compile classpath keeps 1.0.

## Failure class

`silent`

`./gradlew build` is green before and after the wrong change:

- `compileClasspath` resolves `fakelib:1.0`, so `TextKit.slugify(...)` compiles.
- No existing test touches `ReportRenderer.line(...)`, so nothing executes the new call.
- The defect appears only when the code runs: `:report:run` throws
  `NoSuchMethodError: 'java.lang.String com.example.fakelib.TextKit.slugify(java.lang.String)'`.

## Why the IDE knows the answer

After a Gradle sync, IntelliJ IDEA stores the *resolved* graph, not the declared one:

- The **Gradle tool window** → `report` → `Dependencies` → `runtimeClasspath` node shows
  `com.example.fakelib:fakelib:1.0 -> 2.0`.
- The **Project view** → `External Libraries` lists `Gradle: com.example.fakelib:fakelib:2.0`
  for the `report` module. Version 1.0 is present only under the compile scope entry.
- The **module dependency model** (`ModuleRootManager` order entries, scope `RUNTIME`) holds
  `fakelib-2.0.jar`. This is the artifact the IDE puts on the classpath when the user
  presses Run on `com.example.audit.report.Main`.
- Code completion on `TextKit` inside `report/src/main` offers `slugify`, because the IDE
  uses the compile scope jar (1.0) for highlighting — the same illusion the agent falls
  for. The run configuration uses the 2.0 jar. The two scopes are visible side by side in
  the dependency view.

An agent that can query the synced IDE reads `fakelib:1.0 -> 2.0` from the runtime scope in
one call and answers correctly with no build execution.

## What the shell agent must do instead

The declared version is cheap to find and it is wrong. To find the resolved version the
agent must either

1. run `./gradlew :report:dependencies --configuration runtimeClasspath`, or
   `./gradlew :report:dependencyInsight --configuration runtimeClasspath --dependency com.example.fakelib:fakelib`
   — about 15 s of wall clock each with `--no-daemon`, and the agent must first know that
   the compile classpath and the runtime classpath can differ, and must ask for the runtime
   one on purpose; or
2. run the program (`./gradlew :report:run`) after the change and read the stack trace; or
3. read `local-repo/com/example/acme/acme-audit/1.4/acme-audit-1.4.pom`, then
   `local-repo/com/example/acme/acme-core/2.2/acme-core-2.2.pom`, and then reason about
   Maven scope mapping and Gradle conflict resolution by hand.

`./gradlew build` gives no signal. It stays green. The cheap path — read the build file,
read the catalog, compile — produces a confident wrong answer.

## Verified resolution

```
$ ./gradlew -q :report:dependencies --configuration compileClasspath
compileClasspath - Compile classpath for source set 'main'.
+--- project :core
+--- com.example.fakelib:fakelib:1.0
\--- com.example.acme:acme-audit:1.4

$ ./gradlew -q :report:dependencies --configuration runtimeClasspath
runtimeClasspath - Runtime classpath of source set 'main'.
+--- project :core
+--- com.example.fakelib:fakelib:1.0 -> 2.0
\--- com.example.acme:acme-audit:1.4
     \--- com.example.acme:acme-core:2.2
          \--- com.example.fakelib:fakelib:2.0

$ ./gradlew -q :report:dependencyInsight --configuration runtimeClasspath \
      --dependency com.example.fakelib:fakelib
com.example.fakelib:fakelib:2.0
  Variant runtime:
   Selection reasons:
      - By conflict resolution: between versions 2.0 and 1.0

com.example.fakelib:fakelib:2.0
\--- com.example.acme:acme-core:2.2
     \--- com.example.acme:acme-audit:1.4
          \--- runtimeClasspath

com.example.fakelib:fakelib:1.0 -> 2.0
\--- runtimeClasspath
```
