# 03-toolchain-mismatch

## Hidden information

The `report` module compiles with `--release 11`, because the `telemetry.library`
convention plugin reads `telemetry.collectorRuntime` from `gradle.properties` and applies
it to every `JavaCompile` task, and that setting beats the Java 21 toolchain that
`report/build.gradle.kts` declares for itself.

## Tier

`B`.

No file states the effective compile level of `report`. The level is a resolution result.
To get it, the reader must join three files and one Gradle rule:

1. `report/build.gradle.kts` applies `telemetry.library` and declares toolchain 21.
2. `buildSrc/src/main/java/telemetry/conventions/LibraryConventionPlugin.java` sets
   `options.release` from a property.
3. `gradle.properties` holds the value `11` under the name `telemetry.collectorRuntime`.
4. Gradle sends `--release` to `javac` and drops `-source` and `-target`. A toolchain
   selects the compiler, it does not select the release level.

A grep for `11` finds the property, but the property alone does not say which modules it
touches, and it does not say that the module's own toolchain declaration cannot win.

## Failure class

`loud`. The build breaks at `:report:compileJava`. The agent sees the error and can retry.
The cost of this trap is the number of tokens that the agent spends, not a silent defect.

## The error that the agent sees

```
> Task :report:compileJava FAILED
...\report\src\main\java\telemetry\report\Window.java:6: error: records are not supported in -source 11
public record Window(String name, double low, double high, double mean) {
       ^
  (use -source 16 or higher to enable records)
1 error

FAILURE: Build failed with an exception.

* What went wrong:
Execution failed for task ':report:compileJava'.
> Compilation failed; see the compiler output below.
```

The message is misleading in two ways.

- It says `-source 11`. The string `11` is in no file of the `report` module, and the
  module declares Java 21.
- It says `use -source 16 or higher`. Release 16 is not enough. `Rollup.java` calls
  `List.getFirst()` and `List.getLast()`, which arrived in Java 21. An agent that trusts
  the hint gets a second, different error:

```
...\report\src\main\java\telemetry\report\Rollup.java:26: error: cannot find symbol
        return new Window(name, values.getFirst(), values.getLast(), total / values.size());
                                      ^
  symbol:   method getFirst()
  location: variable values of type List<Double>
```

## Why the IDE knows the answer

IntelliJ IDEA reads the Gradle project through the Tooling API. The model that comes back
carries per-module Java settings (`org.gradle.tooling.model.java.JavaSourceSettings`,
plus the `ExternalProject` compile-task model), and Gradle fills those from the effective
compile configuration, `options.release` included. After a sync, the IDE therefore holds
the resolved number for each module and shows it in two places:

- **Project Structure -> Modules -> `report` -> Sources -> Language level** shows `11`,
  next to a module SDK of 21.
- **Settings -> Build, Execution, Deployment -> Compiler -> Java Compiler** lists the
  per-module bytecode target.

The contradiction is one screen: the module says 21, the resolved level says 11. An agent
that can query the synced IDE reads the effective value directly and never has to
reconstruct the plugin chain.

Note: this mechanism is documented from the Gradle and IntelliJ models. I did not open the
IDE on this machine to confirm the screenshot.

## What the shell agent must do instead

The shell agent has no resolved model. It must rebuild the chain by hand:

1. Read `report/build.gradle.kts`. It declares toolchain 21, so the module looks correct.
2. Notice that the module applies `telemetry.library`, and find the plugin id. The id maps
   to a class through `buildSrc/build.gradle.kts`, not through a file name.
3. Read `LibraryConventionPlugin.java`, which is Java, not Kotlin DSL, and see that it
   sets `options.release` from a property name that never mentions `release`.
4. Read `gradle.properties` to get the number.
5. Know that `options.release` wins over the module toolchain, and that
   `sourceCompatibility` and `targetCompatibility` are ignored once `release` is set.
   An agent that tries `sourceCompatibility = JavaVersion.VERSION_21` in the module gets
   exactly the same error again.
6. Know that the fix must stay inside `report`. The build refuses the global fix, so an
   agent that raises `telemetry.collectorRuntime` burns a whole build cycle before it
   learns that.

Cheaper looking routes exist and all of them are wrong: rewrite the record as a class,
delete the module, or switch the compile task off. The oracle rejects each one.

## Environment

`env.sh` pins `JAVA_HOME` to `corretto-21.0.6`. The trap is about JDK versions, so the
launcher JVM must not be inherited. Without the pin the wrapper on this machine starts on
JBR 17.0.9 and the toolchains resolve differently.

The build asks for two toolchains and gets both without a download:

- Java 21 -> `corretto-21.0.6`, detected by Gradle as `Current JVM`.
- Java 17 -> `jbr-17.0.9`, detected through `org.gradle.java.installations.paths` in
  `gradle.properties`.

The project is hermetic. It has no repositories and no external dependencies. `buildSrc`
uses `java-gradle-plugin` with plugins written in Java, because a `kotlin-dsl` `buildSrc`
needs `kotlin-stdlib` and `kotlin-reflect` from the network.
