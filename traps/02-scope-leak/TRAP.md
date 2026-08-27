# 02-scope-leak

## Hidden information

The convention plugin in `buildSrc` puts `:platform-core` into the `compileOnly` bucket
of every service module, so the compile classpath of `:ledger-service` holds the library
and its runtime classpath does not.

## Tier

B.

The word `compileOnly` is not in the project. The convention plugin names the
configuration through the Gradle constant `JavaPlugin.COMPILE_ONLY_CONFIGURATION_NAME`,
which is the normal way a plugin written in Java names it, so
`grep -r compileOnly project/` finds nothing. The dependency and the scope are also two
statements apart: the plugin declares `:platform-core` in a bucket called `platformLibs`,
and a separate line makes the compile-only configuration extend that bucket. To read the
answer out of the source, an agent has to open
`buildSrc/src/main/java/com/acme/conventions/ServiceConventionsPlugin.java`, know what that
constant resolves to, and know that a compile-only dependency never reaches the runtime
classpath. Nothing in `ledger-service/build.gradle.kts` points there: that file has four
lines, and neither `:platform-core` nor any configuration appears in it.

## Failure class

`silent`.

`./gradlew build` is green in the start state. The service compiles, `jar`, `distTar`
and `distZip` succeed, and the four unit tests in `LedgerTest` pass, because they only
touch `Ledger`, which is plain `long` arithmetic. An agent that adds the feature, runs
`./gradlew build`, sees green and reports success leaves an application that cannot
start.

## Why the IDE knows the answer

The Gradle sync in IntelliJ IDEA resolves the project model through the Tooling API and
writes the resolved dependencies of each source-set module into the IDE project model.
A dependency that Gradle reports in `compileClasspath` and not in `runtimeClasspath` is
imported with the `PROVIDED` scope. Three places in the IDE then show it without a build
command:

- **Project Structure | Modules | `acme-ledger.ledger-service.main` | Dependencies** —
  the row `acme-ledger.platform-core.main` carries the scope `Provided`, next to
  `junit:junit:4.13.2` which carries `Test`. Every other dependency in a healthy module
  carries `Compile`.
- **Gradle tool window | acme-ledger | ledger-service | Dependencies** — the node
  `compileClasspath` holds `project :platform-core`, and the sibling node
  `runtimeClasspath` is empty. The difference between the two lists is the whole answer,
  and both lists are on screen at once.
- **Run configuration for `LedgerApp`** — IDEA builds the run classpath from the runtime
  scope of the module, so the gutter run button reproduces the `NoClassDefFoundError`
  without a Gradle invocation.

The scope is in the model even though it is in no build file of the consuming module,
because the model records the result of the resolution and not the text of the scripts.

## What the shell agent must do instead

To see the same fact from the shell, the agent has to compare two resolutions and know
in advance that they can differ:

```
./gradlew :ledger-service:dependencies --configuration compileClasspath
./gradlew :ledger-service:dependencies --configuration runtimeClasspath
```

The first prints `\--- project :platform-core`. The second prints `No dependencies`. Each
call is a separate Gradle invocation of about 15 seconds, and neither is a command an
agent runs by habit; `./gradlew dependencies` with no `--configuration` prints every
configuration of the project and buries the difference in a long report.

The cheaper route, `./gradlew build`, is worse than useless here: it is green, and it is
the command that an agent runs to confirm its work. The runtime failure appears only from
`./gradlew :ledger-service:run`, which is not part of `build` and not part of `check`.

After the agent sees the failure it still has to find the cause. The stack trace names
`com.acme.platform.money.MoneyFormatter`, the service build file does not mention it, and
`grep -rn "platform-core" project/` returns two lines: `settings.gradle.kts`, which only
includes the module, and the constant `PLATFORM_CORE_PATH` in the convention plugin. From
there the agent must read the plugin and resolve the Gradle constant on the line above.

## The fix

Any of these puts the library on the runtime classpath:

- `PLATFORM_SCOPE` becomes `JavaPlugin.IMPLEMENTATION_CONFIGURATION_NAME` in the
  convention plugin. This is the intended fix.
- `JavaPlugin.RUNTIME_ONLY_CONFIGURATION_NAME` also extends `platformLibs`.
- `runtimeOnly(project(":platform-core"))` in `ledger-service/build.gradle.kts`.
