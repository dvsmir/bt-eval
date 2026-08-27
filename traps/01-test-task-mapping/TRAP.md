# 01 — test task mapping

## Hidden information

The `integrationTest` source set of every module gets its own `Test` task from a
`buildSrc` convention plugin, and that task is not a dependency of `check` or `build`, so
`test`, `check` and `build` all report green while `checkout/src/integrationTest` never
runs and holds a failing test.

## Tier

B.

The fact is in the repository, but it is in none of the files that an agent opens for
this task. `checkout/build.gradle.kts` holds four lines and names one plugin id.
`build.gradle.kts` at the root holds the `base` plugin only. The wiring lives in
`buildSrc/src/main/java/com/shopkit/conventions/TestingConventionsPlugin.java`, a Java class,
so a grep for `integrationTest` in the build scripts finds nothing. The agent must know
that a `Test` task can exist outside `check`, and must then go and look for one.

## Failure class

Silent.

`./gradlew build` prints `BUILD SUCCESSFUL`. Every task that the agent is likely to run
prints `BUILD SUCCESSFUL`. The failing test in `checkout/src/integrationTest` stays red
and stays invisible, and the agent reports that all tests pass.

## Why the IDE knows the answer

After a Gradle sync, IntelliJ IDEA holds the resolved Gradle model of the build, not the
text of the build scripts:

- The **Gradle tool window** lists, under `shopkit > checkout > Tasks > verification`,
  three tasks side by side: `check`, `integrationTest` and `test`. The task
  `integrationTest` carries the description `Runs the integration test suite.`
  A question such as "what verification tasks does the checkout module have" is answered
  from this model in one step.
- The **Project view** marks `checkout/src/integrationTest/java` as a *Test Sources Root*
  (green folder). The source set exists in the IDE module model
  (`GradleSourceSetData` / `IdeaModule` content roots) because the sync resolved it, not
  because a directory name looked like a test.
- The **task dependency information** in the same model shows that `check` depends on
  `test` alone. The IDE can therefore answer "which tasks does `check` run" without
  running anything.
- `Run > Run All Tests` and the gutter run marks in the IDE act on the resolved source
  sets, so an IDE-driven run picks up `CheckoutFlowIT` while `./gradlew build` does not.

## What the shell agent must do instead

To reach the same fact from the shell the agent must do one of the following, and each of
them needs the agent to first suspect that a second suite exists:

- `./gradlew tasks` (or `tasks --all`) and read the `Verification tasks` block.
  `integrationTest - Runs the integration test suite.` sits between `check` and `test`
  and looks ordinary. Seeing the line is not enough: the agent must also work out that
  `check` does not reach it.
- `./gradlew :checkout:build --dry-run` and notice that no task named `integrationTest`
  appears in the list, then ask why the directory `checkout/src/integrationTest` exists.
- `find . -path '*/src/*' -maxdepth 4 -type d` and notice the third source directory, then
  read `buildSrc/src/main/java/com/shopkit/conventions/TestingConventionsPlugin.java` to find
  out whether anything runs it.
- Read the two Java files in `buildSrc/src/main/java/com/shopkit/conventions/` and see that
  `TestingConventionsPlugin` registers the task and calls `shouldRunAfter(test)` — which
  is an ordering rule, not a dependency, and therefore does not make `check` run it.

The cost is high because nothing in the build output, in the module build scripts or in
the task the agent runs points at any of this. The agent has to spend the search budget on
a suspicion. The usual result is that it does not, and reports a green build.
