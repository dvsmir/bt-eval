# 19-maven-reactor-am

## Hidden information

`service` depends on the sibling module `ledger-common` at the shared version
`1.0.0-SNAPSHOT`. That snapshot has never been installed into the local repository. The
obvious command for "test one module", `mvn -pl service test`, builds only `service` and
resolves `ledger-common` from the repository, where it is absent. The build fails:

    Could not find artifact com.example.ledger:ledger-common:jar:1.0.0-SNAPSHOT

The recovery is a flag, not an edit: `-pl service -am` widens the reactor to build the
sibling first, or `mvn test` from the root builds everything. Maven does not print either
suggestion. Knowing that `-pl` alone excludes upstream modules, and that `-am` includes
them, is Maven reactor knowledge.

## Tier

`B`

The break is loud, so this trap measures cost and recovery, not a silent wrong answer.
The sibling coordinate is visible in `service/pom.xml`, but the fact that `-pl` needs
`-am` to build an uninstalled sibling is not written anywhere in the repository. An agent
that knows the reactor reaches for `-am` at once. An agent that does not may try to
install the sibling, edit the dependency, or give up, each of which costs tokens or
breaks the module.

## Failure class

`loud`

`mvn -pl service test` exits non-zero with a clear resolution error. The signal is how
many attempts the agent spends before it runs the tests, and whether it recovers with a
flag or by changing the project.

## The route to the answer

- `mvn -pl service -am test` builds `ledger-common` in the same reactor, then tests
  `service`. No install, no file change.
- `mvn test` from the root does the same by building everything.

Both leave the repository untouched. The wrong routes, `mvn install` of the sibling or an
edit to the dependency, either write to the local repository or change the module.

## Why the IDE knows the answer

- IntelliJ IDEA runs a module's tests from the reactor model it already holds. The green
  run arrow on `InvoiceTest` builds the dependency modules first, because the IDE resolves
  `ledger-common` to the sibling in the project, not to the local repository. The user
  never meets the missing-artifact error.
- The Maven tool window builds the reactor in dependency order for the same reason.

An agent-callable form is "run the tests of module X, building whatever it depends on,"
which is what `-am` expresses and what the IDE does by default. The cost saved is the
attempts spent rediscovering `-am` from a resolution error.

## The second failure this trap catches

An agent that "fixes" the error by deleting the `ledger-common` dependency, or by
rewriting `Invoice` so it no longer uses the sibling, has changed the module rather than
run its tests. The oracle checks the dependency and the usage are intact, so that path
fails.

## Offline

The oracle purges the synthetic `com.example.ledger` coordinate from the local repository
at the start of every run, so a repeat where the agent ran `mvn install` cannot mask the
trap for the next repeat. It then runs `-pl service -am test` with `-o`; the sibling
builds from source in the reactor, and JUnit 5 and the plugins come from `~/.m2`.
