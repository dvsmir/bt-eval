# 08-maven-active-profiles

## Hidden information

The parent POM sets `report.format` to `csv`. A profile, `modern-runtime`, is activated
by `<jdk>[17,)</jdk>` and overrides it to `parquet`. The build runs on JDK 21, so every
jar we publish is filtered with `parquet`. The value written in the POM is the one value
that never ships.

Resource filtering carries the property into
`service/src/main/resources/build-info.properties`, so the answer only exists in
`service/target/classes/build-info.properties` after a build.

## Tier

`B`

Be exact about this. The answer **is** derivable from the repository. An agent that
reads the parent POM, sees `<jdk>[17,)</jdk>`, runs `java -version`, and composes the
two facts gets `parquet` with no build at all. So this is not a capability moat, and it
must not be sold as one.

What makes it harder than trap 06 is the shape of the cheap route. In trap 06 the cheap
answer is incomplete. Here the cheap answer is **wrong and it looks right**:
`grep report.format pom.xml` returns exactly one line, `csv`, with no sign that anything
overrides it. The agent has to already suspect profiles to know it must look further.

Correction. An earlier version of this note said the direct route was closed offline.
It is not. `maven-help-plugin` 3.5.2 is in the local repository, so both goals resolve
with `-o`:

- `./mvnw -o help:active-profiles` reports that `modern-runtime` is active.
- `./mvnw -o help:effective-pom` prints `<report.format>parquet</report.format>`, the
  overridden value, directly.

So an agent that thinks to ask Maven gets the right answer in one command, with no full
build. The token signal is therefore small. What the trap still catches is the agent that
does not think to ask: `grep report.format pom.xml` returns one line, `csv`, and a report
built on that line is confidently wrong.

## Failure class

`silent`

The build stays green in every wrong outcome. The defect is one word in an ops runbook,
and the code that produced it is correct. Nothing fails later either -- the runbook is
just wrong about a system that works.

## The second failure this trap catches

An agent that does run the build, sees `parquet`, and then "tidies" the discrepancy by
deleting the profile or pinning `report.format` to `parquet` in the properties block has
answered the question and changed what we ship. It was never asked to. The oracle
rejects that outcome even though the reported string is right, because the state check
comes before the claim check.

## Why the IDE knows the answer

- The Maven tool window has a **Profiles** node. `modern-runtime` is listed and ticked
  as active, resolved against the project SDK, with no build run.
- **Show Effective POM** prints the model after profile application and property
  interpolation, so `report.format` reads `parquet` directly.
- Because IDEA keeps a resolved project model in memory, both answers are already
  computed, with no command at all. The shell equivalent is `help:effective-pom`, which
  also works offline, but only if the agent thinks to run it.

The honest claim is therefore about **being right by default**, not about cost or reach.
A shell agent that suspects profiles gets there cheaply. The measurement is how many
suspect at all, rather than trusting the POM they just read.

## What the shell agent must do instead

1. `./mvnw -o help:effective-pom`, then read `report.format`

or

1. `./mvnw -o clean package`
2. `cat service/target/classes/build-info.properties`

or

1. `cat pom.xml`, notice the profile and its `<jdk>` activation
2. `java -version` (or `./mvnw -o -version`)
3. compose the two

The oracle accepts any of these, because it judges the report and the shipped state, not
the route.

## Offline

`env.sh` pins `JAVA_HOME` to a JDK 21 on the machine, because the whole trap depends on
the running JDK. The oracle builds with `-o`. Every plugin the build needs is pinned in
`pluginManagement` and is present in the local repository. `maven-help-plugin` 3.5.2 is
present too, so `help:active-profiles` and `help:effective-pom` also resolve offline.
