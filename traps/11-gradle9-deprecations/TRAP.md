# 11-gradle9-deprecations

## Hidden information

The build script uses two conventions that the next Gradle major removes:
`archivesBaseName` on `BasePluginConvention`, and `mainClassName` on
`ApplicationPluginConvention`. A plain `gradlew build` is green. It prints one summary
line, "Deprecated Gradle features were used in this build," and nothing about which
features or what to do.

Two things are hidden from a reader of the repository:

- That these two APIs are deprecated and removed, and what replaces them. That is
  cross-version Gradle knowledge, not a fact in any file here.
- Whether the build is actually clean after an edit. A green `build` does not prove it.
  Only `--warning-mode all` lists the individual warnings, and only `--warning-mode fail`
  turns them into a build failure, so passing it is the proof.

## Tier

`B`

The two property names are visible in `build.gradle`, so a reader sees the text. What is
not in the repository is that they are removed in the next major and what the
replacements are: `base { archivesName }` and `application { mainClass }`. That is
capability-5 knowledge, what changed between tool versions. The build tool confirms the
result: `--warning-mode fail` is red before the migration and green after. An agent that
only reads the file cannot tell it is deprecated, and an agent that only runs `build`
cannot tell it is clean.

## Failure class

`silent`

`gradlew build` exits 0 before and after the migration. The deprecated code ships and
the app keeps working, until the wrapper is bumped and the same build stops configuring.
The one-line summary is easy to miss, and an agent that reports "build is clean" on a
green `build` has shipped the defect.

## The route to the answer

- `gradlew build --warning-mode all` prints each deprecation with its location and its
  replacement.
- `gradlew build --warning-mode fail` fails the build while any deprecation remains, and
  passes once they are gone. It is the check that proves the work.

Both run the build. Neither is suggested by the task, which asks only for "no deprecation
warnings." Knowing that phrase means `--warning-mode` is the capability under test.

## Why the IDE knows the answer

- IntelliJ IDEA marks `archivesBaseName` and `mainClassName` with a deprecation strike-
  through in the Gradle build script, from the Gradle model it already resolved, with the
  replacement offered as a quick-fix. No build run needed to find them.
- The Gradle tool window surfaces deprecation warnings from the last sync.

An agent-callable form is the set of deprecated API uses in the build scripts with their
replacements, computed from the resolved Gradle model, against a `build --warning-mode
all` plus knowledge of each replacement.

## The second failure this trap catches

An agent that "silences" the warning by deleting the property, or by removing the
`application` plugin, breaks the app instead of migrating it. The oracle checks the entry
point still exists and the build still assembles, so a gutted build fails.

## Offline

The oracle runs Gradle with `--offline` against the real `~/.gradle`, which holds the
8.14 distribution and needs no toolchain download because the run JDK is already 21. No
env.sh, because the trap injects nothing: the deprecated API is in the build script the
agent can see.
