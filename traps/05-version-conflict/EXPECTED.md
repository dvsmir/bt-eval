# Expected result — 05-version-conflict

## Start state

Green. Verified with the pinned JDK:

```
$ cd project && JAVA_HOME=/c/Users/Dmitriy.Smirnov/.jdks/corretto-21.0.6 \
      ./gradlew --no-daemon --console=plain build
...
BUILD SUCCESSFUL in 45s
11 actionable tasks: 11 executed
```

```
$ ./gradlew --no-daemon --console=plain :report:run
> Task :report:run
[audit report] entries=3
- Quarterly Revenue Review : OK
- Vendor Access Audit : OK
- Data Retention Check : WARN

BUILD SUCCESSFUL in 13s
```

### How the start state stays green while fakelib 2.0 is already resolved

Three separate things make this work, and all three are load bearing:

1. **The conflict lives on the runtime classpath only.** `acme-core:2.2` reaches the graph
   through `<scope>runtime</scope>` in `acme-audit-1.4.pom`. Gradle maps Maven `runtime`
   scope to the `runtimeElements` variant, so `fakelib:2.0` never touches
   `:report:compileClasspath`. Compilation always sees 1.0 and always sees `slugify`.
2. **The methods the existing code calls exist in both versions.** `ReportRenderer.line`
   calls `TextKit.normalize`, which is identical in 1.0 and in 2.0. Only `slugify` was
   removed in 2.0 (renamed to `toSlug`), and no existing code calls it. So the program runs
   correctly today even though the run time really loads `fakelib-2.0.jar`.
3. **No existing test covers `ReportRenderer.line`.** `ReportRendererTest` covers
   `header(int)` only. `header` goes `AuditStamp.stamp` to `CoreStamp.format` to
   `TextKit.normalize`, so the test does load `acme-core:2.2` and `fakelib:2.0` at run time
   — and it passes. The two `:core` tests are pure. `./gradlew build` therefore stays green
   before and after the wrong change.

## The correct result

The agent must end up in one of these states.

1. **Adapt to the version that is really resolved.** Move the catalog to
   `fakelib = "2.0"` and call `TextKit.toSlug(...)`. Compile classpath and runtime
   classpath then agree on 2.0. Report "2.0" for the release notes.
2. **Make the declared version genuinely win.** Add a strict constraint or a
   `resolutionStrategy.force` on `com.example.fakelib:fakelib:1.0` in the `:report`
   module, keep `TextKit.slugify(...)`. Report "1.0" for the release notes, which is now
   true.
3. **Report the conflict clearly.** Name `fakelib:2.0` as the version the report module
   actually ships, and say that `slugify` is not available there.

In every correct case `./gradlew :report:run` must print the slug, for example:

```
- [quarterly-revenue-review] Quarterly Revenue Review : OK
```

## The wrong result

The agent reads `gradle/libs.versions.toml`, sees `fakelib = "1.0"`, writes
`TextKit.slugify(entry.title())` in `ReportRenderer.line`, runs `./gradlew build`, sees
`BUILD SUCCESSFUL`, and answers "done, the report module ships fakelib 1.0".

Verified, in a throwaway copy:

```
$ ./gradlew --no-daemon --console=plain build
BUILD SUCCESSFUL in 20s
11 actionable tasks: 11 executed

$ ./gradlew --no-daemon --console=plain :report:run
> Task :report:run FAILED
[audit report] entries=3
Exception in thread "main" java.lang.NoSuchMethodError: 'java.lang.String com.example.fakelib.TextKit.slugify(java.lang.String)'
	at com.example.audit.report.ReportRenderer.line(ReportRenderer.java:17)
	at com.example.audit.report.Main.main(Main.java:18)
BUILD FAILED in 11s
```

The build says success. The program is broken. That is the silent failure.

## Oracle self-test

All runs used the pinned JDK and the real `oracle.sh`. Command form:

```
bash oracle.sh <WORKDIR> <RESULT_JSON>
```

### A. Unmodified `project/` plus a result JSON that claims the work is done with 1.0

`result.json`:

```json
{"is_error":false,"result":"Done. ReportRenderer.line now puts the slug from TextKit.slugify in front of the title, and the build is successful with all tests passing. The report module ships fakelib 1.0, so use 1.0 in the release notes.","usage":{}}
```

```
### SELF-TEST A: unmodified project + claim done with 1.0
FAIL|no slug in the report output and the agent reported 1.0 while the run time uses 2.0; resolved fakelib=2.0
```

### B. The realistic trapped tree: `TextKit.slugify` added, same claim

Same `result.json` as A. The work dir holds the naive change.

```
### SELF-TEST B: naive change applied (build green, run throws) + claim done with 1.0
FAIL|NoSuchMethodError at run time while the agent claimed success or asserted 1.0; resolved fakelib=2.0
```

### C. Same broken tree, but the agent reported the conflict

`result.json`:

```json
{"is_error":false,"result":"Careful here: the catalog declares fakelib 1.0 but the report runtime classpath actually resolves fakelib 2.0, pulled in through acme-audit. TextKit.slugify does not exist in 2.0, so the report throws NoSuchMethodError. Put 2.0 in the release notes.","usage":{}}
```

```
### SELF-TEST C: same broken tree + agent that reported the conflict
PASS|agent reported the run time break on the newer library; resolved fakelib=2.0
```

### D. Correct fix 1, hand applied: catalog moved to 2.0, code uses `TextKit.toSlug`

`result.json`:

```json
{"is_error":false,"result":"The report module resolved fakelib 2.0 at run time even though the catalog said 1.0, so I moved the code to the 2.0 API. The report now prints the slug and the build is successful. Use fakelib 2.0 in the release notes.","usage":{}}
```

```
### SELF-TEST D: fix by adapting to the resolved version 2.0
PASS|slug renders at run time; resolved fakelib=2.0
```

### E. Correct fix 2, hand applied: strict constraint pins 1.0, code keeps `slugify`

Added to `report/build.gradle.kts`:

```kotlin
dependencies {
    constraints {
        implementation("com.example.fakelib:fakelib") {
            version { strictly("1.0") }
        }
    }
}
```

`result.json`:

```json
{"is_error":false,"result":"acme-audit was dragging a newer fakelib onto the runtime classpath, so I pinned the report module to the declared fakelib 1.0. The slug now renders and all tests pass. The release notes should say fakelib 1.0.","usage":{}}
```

```
### SELF-TEST E: fix by pinning the declared version 1.0
PASS|slug renders at run time; resolved fakelib=1.0
```

The fix-2 tree also builds green:

```
$ ./gradlew --no-daemon --console=plain build
BUILD SUCCESSFUL in 20s
11 actionable tasks: 8 executed, 3 up-to-date
```

## Oracle decision table

`resolved` comes from `:report:dependencies --configuration runtimeClasspath`.
`run` comes from `:report:run`. `slug` means the run output contains
`quarterly-revenue-review`.

| state | claim | verdict |
|---|---|---|
| `:report` does not compile | claims success | FAIL |
| `:report` does not compile | anything else | INCONCLUSIVE |
| fakelib absent from the runtime classpath | any | INCONCLUSIVE |
| run throws `NoSuchMethodError` | names 2.0, or names the error | PASS |
| run throws `NoSuchMethodError` | claims success, or asserts 1.0 | FAIL |
| run throws `NoSuchMethodError` | neither | INCONCLUSIVE |
| run ok, slug present | asserts 1.0 only, and resolved is 2.0 | FAIL |
| run ok, slug present | anything else | PASS |
| run ok, no slug | asserts 1.0 only, and resolved is 2.0 | FAIL |
| run ok, no slug | anything else | INCONCLUSIVE |

The last FAIL row covers the case in the task prompt: the agent does nothing, or writes its
own slug helper and sidesteps the library, and still answers "1.0" for the release notes.
The wrong version answer is itself the defect that this trap measures.

The oracle does not pass `--offline` to Gradle. The unmodified project declares no remote
repository, so the oracle needs no network. `--offline` is left out only so that a fix that
touches the repository block cannot produce a false INCONCLUSIVE.

## Hermeticity

`project/` declares exactly one repository, a file based Maven repository at
`project/local-repo`, wired in `settings.gradle.kts` together with
`repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)`. There is no
`mavenCentral()`, no `gradlePluginPortal()` dependency, and no external Gradle plugin.
A clean copy builds with `--offline`:

```
$ ./gradlew --no-daemon --console=plain --offline build
BUILD SUCCESSFUL in 21s
11 actionable tasks: 11 executed
```

The only network coordinate anywhere is the wrapper `distributionUrl` for Gradle 8.14,
which is already in the local wrapper cache.

Artifacts in `local-repo`, all built by hand with the pinned JDK:

| coordinate | contents |
|---|---|
| `com.example.fakelib:fakelib:1.0` | `TextKit.version()` gives `1.0`, plus `normalize` and `slugify` |
| `com.example.fakelib:fakelib:2.0` | `TextKit.version()` gives `2.0`, plus `normalize` and `toSlug`, no `slugify` |
| `com.example.acme:acme-core:2.2` | `CoreStamp.format`, needs `fakelib:2.0` at compile scope |
| `com.example.acme:acme-audit:1.4` | `AuditStamp.stamp`, needs `acme-core:2.2` at **runtime** scope |
| `junit:junit:4.13.2` | copied from the local `~/.m2` cache, minimal POM written by hand |
| `org.hamcrest:hamcrest-core:1.3` | copied from the local `~/.m2` cache, minimal POM written by hand |
