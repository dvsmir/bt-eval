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

The two closed routes make the cost real:

- `mvn help:active-profiles` is the direct answer, and `maven-help-plugin` is not in the
  local repository. Offline, that plugin cannot be downloaded, so the command fails.
- `mvn help:effective-pom` fails for the same reason.

What is left is a full `clean package` and then reading the filtered file, or the
three-step chain of reasoning above. Both cost turns. That is the token signal.

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
  computed. An agent-callable form of this is one call that returns the active profiles
  and the effective property values -- against a Maven `clean package` plus a file read.

The honest claim is therefore about **cost and about being right by default**, not about
reach. A patient shell agent gets there. The measurement is how many of them are patient,
and how much the patience costs.

## What the shell agent must do instead

1. `./mvnw -o clean package`
2. `cat service/target/classes/build-info.properties`

or

1. `cat pom.xml`, notice the profile and its `<jdk>` activation
2. `java -version` (or `./mvnw -o -version`)
3. compose the two

The oracle accepts either, because it judges the report and the shipped state, not the
route.

## Offline

`env.sh` pins `JAVA_HOME` to a JDK 21 on the machine, because the whole trap depends on
the running JDK. The oracle builds with `-o`. Every plugin the build needs is pinned in
`pluginManagement` and is expected in the local repository; `maven-help-plugin` is
deliberately not.
