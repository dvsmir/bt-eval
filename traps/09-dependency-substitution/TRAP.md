# 09-dependency-substitution

## Hidden information

A global Gradle init script pins `com.acme:widgets` to `1.0.0`:

    resolutionStrategy.eachDependency { useVersion('1.0.0') ... }

The version catalog (`gradle/libs.versions.toml`) asks for `2.0.0`. The pin wins, so
the runtime classpath resolves to `1.0.0` whatever the catalog says. Bumping the
catalog to `2.0.0` changes nothing, and the build stays green.

The init script lives in `GRADLE_USER_HOME/init.d/`, which is outside the project. No
file the agent can read explains why the version will not move. The catalog says
`2.0.0`, the resolved version is `1.0.0`, and only Gradle knows.

## Tier

`A`

Reading the repository cannot give the answer. The catalog states `2.0.0`, and every
source file is consistent with `2.0.0`. The value that ships, `1.0.0`, exists only in
the resolved model that Gradle computes from the project plus the hidden init script.
An agent that trusts the file it just edited reports `2.0.0` and is wrong.

The only ways to the truth run through the build tool:

- `./gradlew :app:dependencies --configuration runtimeClasspath` prints
  `com.acme:widgets:2.0.0 -> 1.0.0`.
- `./gradlew :app:dependencyInsight --dependency com.acme:widgets` prints the reason:
  `Selected by rule: pinned to 1.0.0 by platform policy`.

## Failure class

`silent`

Every wrong outcome is green. The agent edits the catalog, the build passes, and the
release note says `2.0.0`. The shipped app is on `1.0.0`. Nothing breaks, so nothing
prompts a second look.

## Why the IDE knows the answer

IDEA imports the resolved Gradle model, init scripts included. The dependency view for
`:app` shows `widgets 1.0.0`, not `2.0.0`, before any command is typed. An
agent-callable form is one call that returns the resolved dependency for a module, set
against a shell agent that must think to run `:app:dependencies` and then read a
version off an arrow.

The claim is about being right by default. A shell agent that queries resolution gets
there. The measurement is how many do, when the file they edited already looks correct.

## What the shell agent must do instead

1. Edit the catalog to `2.0.0`.
2. `./gradlew :app:dependencies --configuration runtimeClasspath`, and read the arrow.
3. Report that the effective version is `1.0.0`, held by a rule the project cannot see.

The oracle accepts any report that names `1.0.0` as the effective version, or that
names the pin. It rejects a report that presents `2.0.0` as the outcome.

## The second failure this trap catches

An agent that rewrites `App.java` to print `2.0.0`, or that drops the dependency to
force the build one way or another, has changed the code to fit the story. The state
check runs before the claim check and rejects both.

## Offline

`env.sh` builds a private `GRADLE_USER_HOME` under the temp directory, borrows the
`wrapper` distribution from the real `~/.gradle` by junction (Windows) or symlink, and
writes the pin into `init.d`. It exports `GRADLE_USER_HOME` as a native path so the
Windows JVM understands it. The oracle sources `env.sh` itself, so the pin is active
under either runner. All dependencies come from the project `local-repo`, so the build
needs no network. `run.sh` clears `GRADLE_USER_HOME` between traps so the pin does not
leak into the next one.
