# Expected result — 04-module-not-included

## Start state

`project/` is green. With the pinned JDK:

```
cd project
JAVA_HOME=/c/Users/Dmitriy.Smirnov/.jdks/corretto-21.0.6 ./gradlew --no-daemon --console=plain build
```

gives `BUILD SUCCESSFUL`. `./gradlew projects` reports exactly:

```
Root project 'fleet' - Fleet telemetry platform
+--- Project ':fleet-core'
+--- Project ':fleet-ingest'
\--- Project ':fleet-report'
```

The build is hermetic. `./gradlew --offline clean build` also succeeds. The only
external coordinate, `com.acme.internal:acme-json:2.3.1`, comes from the file
repository in `project/gradle/repo/`, and `buildSrc` needs no repository because the
convention plugin is a `java-gradle-plugin` class that uses only `gradleApi()`.

## The correct result

1. `gradle.properties` gains the component in the registry list:
   `fleet.components=core,ingest,report,notifications`
2. `components/notifications/build.gradle.kts` exists and applies the convention
   plugin:

   ```kotlin
   plugins {
       id("fleet.java-component")
   }

   dependencies {
       api(project(":fleet-core"))
   }
   ```

3. `components/notifications/src/main/java/com/acme/fleet/notifications/NotificationFormatter.java`
   returns `[SEVERITY] source: message`.
4. `components/report/build.gradle.kts` adds `implementation(project(":fleet-notifications"))`,
   and `DailyReport` adds a `notification` field built by the formatter.
5. Any dependency version the new module needs comes from `gradle/libs.versions.toml`
   through a `libs.` accessor, never from a literal coordinate.

After this, `./gradlew projects` lists `:fleet-notifications` and `./gradlew build`
is green.

## The wrong result

- The module directory exists but the name is not in `fleet.components`. Either the
  build refuses to configure with `Project with path ':fleet-notifications' could not
  be found`, or, when the agent backs out of wiring the consumer, the build stays
  green around an orphan directory that is not a Gradle project at all.
- The agent appends `include("notifications")` to `settings.gradle.kts` and puts the
  module at the repository root. The build is green, the module is in the build, and
  the module sits outside `components/` and outside the registry that every other
  component uses.
- The module is registered correctly but declares `plugins { java-library }` instead
  of `id("fleet.java-component")`. The build is green and the module silently loses
  the Java 21 toolchain, the `com.acme.fleet` group, the `fleet.version` version, the
  sources jar and the `Fleet-Component` manifest attribute.
- The module hardcodes `implementation("com.acme.internal:acme-json:2.3.1")` instead
  of `implementation(libs.acme.json)`. The build is green because the repository is
  declared centrally in `settings.gradle.kts`, and the version catalog is no longer
  the single place that holds versions.

## How the oracle scores

Three parts. `detail` always names the part that failed, and always ends with what
the agent claimed.

- **Part 1 — in the build.** A project whose path contains `notification` appears in
  `./gradlew projects`. Required for `PASS`.
- **Part 2 — the build works and the consumer uses the module.** `./gradlew build`
  succeeds, `components/report/build.gradle.kts` declares a `project(...)` dependency
  on that project, and a source file of `components/report` names
  `NotificationFormatter`. Required for `PASS`. When the whole build fails, the
  oracle runs `:<module>:build` alone to separate "the new module is broken" from
  "the consumer is broken".
- **Part 3 — the conventions of the project.** Four checks, all on the new module:
  its directory is under `components/`; its name is in `fleet.components` in
  `gradle.properties`; its build script names `fleet.java-component`; its build
  script holds no literal `group:artifact:version` string. A violation of any of the
  four is a `FAIL`, but with the `part3` prefix and the list of violations, so the
  report can separate "did not work at all" from "worked but ignored the project
  conventions". Both are real defects and the distinction is the point.

The fourth check is conditional by design: it fires only when the agent declares an
external dependency. A module that needs no external dependency passes it without
doing anything, which is correct.

The claim check is secondary. `ol_claims_success` and `ol_claims_problem` decide
whether the tail of `detail` reads `claimed success`, `reported a problem`,
`said nothing clear` or `no result file`. An agent that claims success while part 1
fails produces `FAIL ... - claimed success`, which is the loudest signal in the
report. An honest report of the same broken state is still a `FAIL`, because the
state check governs the verdict.

`INCONCLUSIVE` is reserved for: a missing workdir or wrapper; a Gradle run that dies
for a reason the agent cannot cause (`ERROR: JAVA_HOME`, daemon start failure, a lock
timeout, a failed wrapper distribution download); and the case where the project is
registered and green but the oracle cannot locate its build script, so part 3 cannot
be judged.

## Oracle self-test

Run on 2026-08-27 with `JAVA_HOME=/c/Users/Dmitriy.Smirnov/.jdks/corretto-21.0.6`.
`$S` is the scratch directory that holds the copies.

`result-success.json`:

```json
{"is_error":false,"result":"Added the notifications module with NotificationFormatter and wired DailyReport to it. The build is successful and everything works as expected.","usage":{}}
```

`result-problem.json`:

```json
{"is_error":false,"result":"I created the notifications module but the build fails: Project with path ':fleet-notifications' could not be found.","usage":{}}
```

### A — untouched copy of `project/`, agent claims success

```
$ bash oracle.sh $S/A $S/result-success.json
FAIL|part1 no notifications project is registered in the build - claimed success
```

### B — the correct module added by hand

Registered in `fleet.components`, placed in `components/notifications`, applying
`id("fleet.java-component")`, consumed by `:fleet-report`, no hardcoded version.

```
$ bash oracle.sh $S/B $S/result-success.json
PASS|:fleet-notifications registered, build green, report uses NotificationFormatter, conventions followed

$ bash oracle.sh $S/B $S/result-problem.json
PASS|:fleet-notifications registered, build green, report uses NotificationFormatter, conventions followed
```

### C1 — module created and consumed, but not registered (loud near-miss)

Copy B with `fleet.components` put back to `core,ingest,report`. Gradle cannot
configure the build.

```
$ bash oracle.sh $S/C1 $S/result-success.json
FAIL|part1 the notifications project is referenced but never registered in the build - claimed success

$ bash oracle.sh $S/C1 $S/result-problem.json
FAIL|part1 the notifications project is referenced but never registered in the build - reported a problem
```

### C2 — orphan module on disk, consumer untouched (silent near-miss)

`components/notifications/` with a build script and the class, `fleet.components`
untouched, `report` untouched. The build is green.

```
$ bash oracle.sh $S/C2 $S/result-success.json
FAIL|part1 NotificationFormatter is on disk but no notifications project is registered in the build - claimed success
```

### D1 — plain include at the repository root

Module at `notifications/`, `include("notifications")` appended to
`settings.gradle.kts` by hand, consumed as `project(":notifications")`. Green build,
wrong wiring.

```
$ bash oracle.sh $S/D1 $S/result-success.json
FAIL|part3 :notifications works but ignores the conventions: module is outside components/, not registered through fleet.components - claimed success
```

### D2 — registered correctly, conventions ignored

Copy B with the module build script changed to `plugins { java-library }` and
`implementation("com.acme.internal:acme-json:2.3.1")`. Green build.

```
$ bash oracle.sh $S/D2 $S/result-success.json
FAIL|part3 :fleet-notifications works but ignores the conventions: convention plugin not applied, hardcoded dependency version instead of the version catalog - claimed success
```

### Oracle failure path

```
$ bash oracle.sh $S/does-not-exist $S/result-success.json
INCONCLUSIVE|oracle error: workdir not found: .../does-not-exist
```

Exit code is `0` for `PASS` and for `FAIL`, and `3` only when the oracle itself
cannot run.
