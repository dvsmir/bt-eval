# 15-generated-source-class

## Hidden information

`BuildInfo` is not a source file. The `generateBuildInfo` task writes it into
`build/generated` on every build, from a channel string set in `build.gradle`. `Banner`
and `Main` compile against `BuildInfo.CHANNEL`, so the class looks like any other, but no
file for it exists in `src`.

The source of truth is the generator. Three routes an agent takes here, only one works:

- Edit the copy under `build/generated`. The next build regenerates it from
  `build.gradle` and the edit is gone. The tool still prints `stable`.
- Add a hand-written `src/.../BuildInfo.java`. Now two `BuildInfo` classes are on the
  compile path, the generated one and the written one, and the compile fails with
  "duplicate class".
- Change the one string in `build.gradle`. The generator emits `canary`, the tool prints
  `canary`, the build is green.

Nothing tells the agent the class is generated except the absence of its source and the
presence of the task. A `grep` for the class in `src` finds only its uses, never its
definition.

## Tier

`B`

The generator is in the repository, so this is not a capability moat. It is a
token-and-attention trap. The cheap fix is one line, but only if the agent works out that
the class is generated. An agent that does not can burn a cycle editing the generated file,
watch it revert, then hit a duplicate-class error, before it looks at the build script.

## Failure class

`silent`

Editing the generated file leaves the build green. It just does not change what the tool
prints, because the build overwrites the edit. The signal is task success: the agent
reports the channel changed when a clean build still prints `stable`.

## The capability under test

Build-time generated sources. A class can be produced by the build rather than authored,
so the file on disk under `build/` is output, not input, and the thing to edit is the
generator. This is the same shape as annotation processors, protobuf, and OpenAPI
stubs: the code you see is not the code you change.

## Why the IDE knows the answer

- IntelliJ IDEA marks `build/generated` as a generated-sources root and shows the file
  with a generated badge. Go-to-definition on `BuildInfo.CHANNEL` lands in a file the IDE
  labels as generated, which tells the user not to edit it there.
- The Gradle tool window lists `generateBuildInfo` as the task that produces it, so the
  path from the class to its generator is one click, not a guess.

The agent-callable form is "where does this class come from, and what produces it". The
IDE answers from the project model. A shell agent has to infer it from a missing source
file and a task in the build script.

## The second failure this trap catches

An agent that hardcodes `canary` into `Banner` or `Main`, dropping `BuildInfo.CHANNEL`,
makes the output right and the design wrong: the channel no longer flows from `BuildInfo`.
The oracle checks the printed channel still comes from `BuildInfo.CHANNEL` in the source,
so that path fails.

## Offline

No dependencies. The application plugin and the Java toolchain come from the Gradle
distribution already in the real home. The oracle runs `clean run` with `--offline` and
reads the channel from the tool's output.
