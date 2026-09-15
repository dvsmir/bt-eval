# 06-latest-usable-version

## Hidden information

`com.acme:widgets` is published at `1.0.0`, `1.1.0`, `1.4.2`, and `2.0.0`, and only
`1.4.2` is the newest version that the project can take, because `2.0.0` removes
`WidgetFormatter.describe(String, long)`, which `BasketPrinter` calls.

## Tier

`B`

**Be honest about this one. It is a token-cost trap, not a correctness moat.** Every
fact it hides is reachable from the shell. The four versions are directories under
`local-repo/`, and `maven-metadata.xml` lists them. The removed method is inside a jar,
which `javap` or an unzip can read, and a build shows it in one compile error.

So the trap does not claim that a shell agent cannot answer. It claims the answer costs
turns: list the repository, decide which version to try, edit the catalog, run a build,
read the error, step back one version, run the build again. An IDE with an indexed
repository has the version list and the class index already, and answers in one call.

The trap still discriminates on correctness, because the cheapest route gives the wrong
answer. `maven-metadata.xml` says:

```xml
<latest>2.0.0</latest>
<release>2.0.0</release>
```

An agent that reads that file, or that reasons "take the highest version", answers
`2.0.0`. That answer is wrong, and it is wrong in a way the agent finds only if it
builds.

## Failure class

`silent`

The project starts green and the wrong outcomes stay quiet in different ways:

- The agent writes `2.0.0` into the catalog and does not build. The report says the
  project moved to the newest version. The build is red and nobody looked.
- The agent moves to `1.1.0`, because it is the newest version that "looks safe", and
  reports success. The build is green, so nothing complains. `1.4.2` was available.

Only the agent that builds discovers that `2.0.0` breaks, and the cost of that discovery
is the measurement.

## Why the IDE knows the answer

- The **Gradle tool window** and the version catalog editor read the repository index
  for `com.acme:widgets`. IntelliJ IDEA marks the declaration in
  `gradle/libs.versions.toml` with the "Newer version available" inspection and lists
  every version in the completion popup, from the same `maven-metadata.xml` the agent
  would have to fetch and parse.
- The IDE holds a **class index of the resolved jars**. `WidgetFormatter` in `2.0.0` has
  no `describe` member, so completion, Find Usages, and the compile-error highlighting
  answer "does 2.0.0 keep this method" with no build execution.
- A single **Gradle sync** after a version change re-indexes both, so the loop the shell
  agent pays for in build invocations is one incremental sync in the IDE.

## What the shell agent must do instead

1. Discover that a file repository exists and list it:
   `ls local-repo/com/acme/widgets` or read `maven-metadata.xml`.
2. Decide the candidate. The cheap answer, `2.0.0`, is wrong.
3. Edit `gradle/libs.versions.toml`.
4. Run `./gradlew build` -- about 20 to 40 s with `--no-daemon` -- and read
   `cannot find symbol: method describe(String,long)`.
5. Step back to `1.4.2` and build again to confirm.

That is two full builds minimum, and three if the agent tries `1.1.0` first. The
alternative is `javap -classpath local-repo/com/acme/widgets/2.0.0/widgets-2.0.0.jar
com.acme.widgets.WidgetFormatter`, which is cheap but which the agent must think of.

## Verified compatibility matrix

| version | `./gradlew build` |
|---|---|
| 1.0.0 | green, the start state |
| 1.1.0 | green |
| 1.4.2 | green, the correct answer |
| 2.0.0 | red, `cannot find symbol: method describe(String,long)` |
