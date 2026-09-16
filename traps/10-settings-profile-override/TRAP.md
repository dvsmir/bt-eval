# 10-settings-profile-override

## Hidden information

The parent POM sets `sink.format` to `csv`. A profile in the Maven user settings file,
`corp-runtime`, is active by default and overrides it to `avro`. Every jar the build
publishes is filtered with `avro`. The value written in the POM is the one value that
never ships.

The settings file is not in the project. It lives under the trap directory and is passed
to Maven through `MAVEN_ARGS="-s ..."`, set by `env.sh`. So no file the agent can read
holds `avro`. Resource filtering carries the property into
`service/target/classes/build-info.properties`, which exists only after a build.

## Tier

`A`

The answer is not in the repository. Every file the agent can read says `csv`. The value
that ships, `avro`, comes from a settings file outside the project and exists only in the
model Maven computes from the POM plus those settings. Reasoning over repository files
cannot produce it, which is the line between this trap and trap 08. In trap 08 the
override sits in the POM and a careful reader derives the answer with no build. Here the
override is invisible to reading, so the build tool or the IDE is the only route.

The cheap answer is wrong and it looks right: `grep sink.format pom.xml` returns one
line, `csv`, with no sign that anything overrides it.

## Failure class

`silent`

The build stays green in every wrong outcome. The defect is one word in a runbook, and
the code that produced it is correct. The system it describes works. Only the runbook is
wrong.

## The routes to the answer

- `./mvnw -o clean package`, then read `service/target/classes/build-info.properties`.
- `./mvnw -o help:evaluate -Dexpression=sink.format -DforceStdout` prints `avro`.
- `./mvnw -o help:active-profiles` lists `corp-runtime (source: external)`.

All three run the build tool. None of them read a value off a file. `maven-help-plugin`
is in the local repository on this machine, so the `help:*` routes work offline; do not
rely on its absence as the moat. The moat is that the agent must execute Maven at all,
rather than trust the POM it just read.

## Why the IDE knows the answer

- The Maven tool window has a **Profiles** node. `corp-runtime` is listed and ticked as
  active, sourced from settings, with no build run.
- **Show Effective POM** prints the model after settings and profile application, so
  `sink.format` reads `avro` directly.
- IDEA keeps a resolved project model in memory, so both answers are already computed. An
  agent-callable form is one call returning the active profiles and the effective
  property values, against a Maven `clean package` plus a file read.

The honest claim is about being right by default. A patient shell agent gets there. The
measurement is how many are patient, and what the patience costs.

## The second failure this trap catches

An agent that pins `sink.format` to `avro` in the POM, or edits the `csv` default, has
answered the question by changing what ships. It was never asked to. The state check runs
before the claim check and rejects that even when the reported string is right.

## Offline

`env.sh` copies the settings file to a path with no spaces, because Maven splits
`MAVEN_ARGS` on whitespace and the checkout path contains a space. It exports
`MAVEN_ARGS="-s <copy>"`. The oracle sources `env.sh`, so the override is active under
either runner. The oracle builds with `-o`, and `run.sh` clears `MAVEN_ARGS` between
traps so the settings file does not leak into the next one.
