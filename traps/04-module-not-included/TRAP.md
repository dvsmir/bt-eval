# 04-module-not-included

## Hidden information

A new module becomes part of this build only when its name is added to the
`fleet.components` list in `gradle.properties`, from which `settings.gradle.kts`
generates the project path `:fleet-<name>` and remaps its directory to
`components/<name>`; the module must then apply the `fleet.java-component`
convention plugin from `buildSrc` and take every dependency version from
`gradle/libs.versions.toml`.

## Tier

`B`

Nothing in the repository states the answer as text. Every part of it is a value
that only a sync or a build computes:

- the set of registered project paths does not exist until Gradle evaluates the
  Kotlin in `settings.gradle.kts` against the comma list in `gradle.properties`;
- the plugin id `fleet.java-component` is not written in any descriptor file on
  disk, it is generated into the plugin descriptor when `buildSrc` is built from
  the `gradlePlugin { }` block;
- the `libs.acme.json` accessor that the existing modules use is generated from
  `gradle/libs.versions.toml` at configuration time.

The mechanism is spread over four files that never name each other:
`gradle.properties` holds a bare comma list with no comment, `settings.gradle.kts`
turns that list into project paths that do not match the directory names,
`buildSrc/src/main/java/fleet/build/JavaComponentPlugin.java` defines the plugin id
`fleet.java-component`, and `gradle/libs.versions.toml` holds the only sanctioned
versions. No file in `project/` states the rule. Grepping for a literal
`include("` finds nothing, because the single `include(path)` call takes a
variable. The agent must read and join all four files, and it must notice that
the project path `:fleet-core` and the directory `components/core` differ.

## Failure class

`silent` (loud first, then silent)

The first attempt is usually loud: the agent creates `components/notifications`,
points `DailyReport` at it, and Gradle refuses to configure with
`Project with path ':fleet-notifications' could not be found`. The interesting
part is what the agent does next. The cheap repairs all stay green and all stay
wrong:

- append `include("notifications")` to `settings.gradle.kts` and put the module at
  the root, so the module is in the build but outside `components/` and absent from
  `fleet.components`;
- keep the module directory but move the class into `components/report`, leaving an
  orphan directory that looks like a module and is not one;
- register the module correctly but write `plugins { java-library }` and
  `implementation("com.acme.internal:acme-json:2.3.1")`, which compiles because the
  repository is declared in `settings.gradle.kts`, and which silently drops the
  toolchain, the group, the version, the sources jar and the manifest attribute that
  every other component has.

Each of these ends with `BUILD SUCCESSFUL`, so the agent reports success.

## Why the IDE knows the answer

After a Gradle sync, IntelliJ IDEA holds the resolved Gradle model:

- The Gradle tool window lists exactly the registered projects, `:fleet-core`,
  `:fleet-ingest`, `:fleet-report`, with their real content roots. A directory that
  is not in the model carries no module icon, and IDEA marks its
  `build.gradle.kts` with the banner *"Project is not linked to a Gradle project"*
  plus a *Link Gradle Project* action. The orphan module is visible at a glance.
- The External Libraries and the module dependency list show that `:fleet-report`
  does not see the new code, before anything is compiled.
- The Kotlin DSL script model gives completion for the `libs.` accessors that the
  version catalog generates, and for the `fleet.java-component` plugin id inside
  the `plugins { }` block, because IDEA indexes the precompiled and the
  `java-gradle-plugin` descriptors of `buildSrc`. The sanctioned dependency
  notation is offered; the hardcoded coordinate is not.
- IDEA renders the project paths next to the directories, so the
  `components/core` to `:fleet-core` remapping is on screen and needs no reading of
  `settings.gradle.kts`.

## What the shell agent must do instead

- `cat settings.gradle.kts`, then understand that the include list is generated,
  not written, and that `providers.gradleProperty("fleet.components")` points at
  `gradle.properties`.
- `cat gradle.properties` and recognise a bare comma list as the module registry.
- `./gradlew projects` to learn the real project paths, and infer the
  `:fleet-<name>` naming rule and the `components/<name>` directory remap from the
  three existing components.
- Read one existing `components/*/build.gradle.kts` to find `id("fleet.java-component")`,
  then `find buildSrc` and read the plugin class to know what applying it buys.
- Read `gradle/libs.versions.toml` and connect `libs.acme.json` in
  `components/report/build.gradle.kts` to the `acme-json` entry there.
- Each of these steps costs a command, and nothing in the repository tells the
  agent that the steps are needed. Skipping the last two costs nothing at build
  time, which is why the result is green and wrong.
