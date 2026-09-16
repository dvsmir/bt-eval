# 13-junit-platform-missing

## Hidden information

`metrics` has two JUnit 5 tests. The build never calls `useJUnitPlatform()`, so the
Gradle `test` task runs on its default JUnit 4 engine. That engine finds no JUnit 4
tests, runs nothing, and the task reports `BUILD SUCCESSFUL`. `gradlew :metrics:test`
prints a green build and no test count.

Nothing in the source says the tests did not run. The test file has `@Test` methods and
real assertions. The only place the truth exists is the build result: zero test XML files
under `metrics/build/test-results/test`. An agent that reads the exit code, or the words
`BUILD SUCCESSFUL`, and stops there ships a module whose tests never execute.

The fix is `useJUnitPlatform()`, either on the `test` task in `metrics/build.gradle` or in
the shared `subprojects` block. No source file changes.

## Tier

`B`

The count of tests that ran is in the repository the moment you build it, so this is not a
capability moat. It is a token-and-attention trap: the answer is one build away, but only
if the agent knows a green Gradle build can still have run nothing, and checks the count.
There is no `useJUnitPlatform()` anywhere in the project to grep for and copy, so the fix
is knowledge, not a nearby example.

## Failure class

`silent`

The build is green before and after. The defect does not announce itself. The signal is
task success: does the agent notice that "tests pass" is false because no test ran.

## The capability under test

Capability 2, complex run scenarios: does the agent figure out how to run the tests
properly when the default does not. The default `test` task appears to work and does not.
Recognising that, and knowing Gradle needs `useJUnitPlatform()` to run a JUnit 5 suite, is
the capability.

## Why the IDE knows the answer

- IntelliJ IDEA runs JUnit 5 tests through its own JUnit runner, from the test's green run
  arrow, and reports two tests run and passed. The user sees the count, not a bare "build
  succeeded".
- Running the module's test task from the Gradle tool window surfaces the executed-test
  count in the test tree, where zero is visible at a glance.

The agent-callable form is "run these tests and report how many ran and passed", which is
what the IDE test runner reports by default. The trap catches an agent that treats a green
Gradle build as proof the tests ran.

## The second failure this trap catches

An agent that "makes the tests pass" by deleting the failing-to-run test, or by hollowing
out `MetricsReport` so nothing depends on `core`, has removed the work rather than run it.
The oracle checks the test still has `@Test` and assertions, and that `MetricsReport`
still calls `Stats`, so those paths fail.

## Offline

JUnit 5.10.3 resolves from the local Maven repository via `mavenLocal()`; the Gradle
distribution is the one already in the real Gradle home. The oracle runs
`clean :metrics:test` with `--offline`, then counts the executed tests from the test-result
XML.
