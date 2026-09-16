# Trap contract

Every trap must obey this contract. The runner and the report generator depend on it.
Read this file completely before you create a trap.

## 1. What a trap is

A trap is one complete build-tool project, Gradle or Maven. It contains exactly one
piece of hidden information. An agent that works only through the shell and through
file reads must have difficulty with that information. An agent that can ask a synced
IDE must not.

One trap tests one cause. Do not combine two causes in one trap. If the result is a
failure, the reader must know which cause produced it.

## 2. Directory layout

```
traps/NN-slug/
  TRAP.md        Documentation of the hidden information.
  TASK.md        The prompt that the runner gives to the agent. Nothing else.
  EXPECTED.md    The correct result, and the wrong result.
  oracle.sh      The script that decides PASS or FAIL.
  env.sh         Optional. The runner sources it to set JAVA_HOME or other variables.
  agent-args.txt Optional. Extra command line arguments for the agent. See section 10.
  project/       The complete build project. The agent gets a copy of this directory.
```

## 3. The isolation rule

The runner copies **only `project/`** into the scratch directory. The agent never sees
`TRAP.md`, `TASK.md`, `EXPECTED.md`, or `oracle.sh`.

Never put the answer inside `project/`. Do not put the answer in a comment, a README,
a commit message, or a task name. A trap that explains itself measures nothing.

## 4. TRAP.md

Use these headings:

- **Hidden information** — the one fact that the agent cannot see, in one sentence.
- **Tier** — `A`, `B`, or `C`. See `README.md` for the definitions. A trap must be Tier A
  or Tier B. Tier C is not acceptable, because a shell agent can grep the answer.
- **Failure class** — `silent` or `loud`.
  - `silent` means the agent reports success and the defect stays in the code.
  - `loud` means the build breaks, so the agent sees an error and can retry.
- **Why the IDE knows the answer** — name the model, the sync result, or the IDE setting
  that holds it. Be specific. If you cannot name it, the trap does not support the Order.
- **What the shell agent must do instead** — the commands and the files, and the reason
  the cost is high or the result is wrong.

## 5. TASK.md

Write the prompt as a developer writes it. Keep it short. Give no hints.

- Do not name the trap.
- Do not name the file that holds the cause.
- Do not tell the agent to be careful.
- Ask for the outcome only.

Good: `Add a health check endpoint to the service module, then run all the tests and tell me if they pass.`
Bad: `Note that integration tests use a separate source set. Run them too.`

## 6. oracle.sh

The runner calls the oracle like this:

```
bash oracle.sh <WORKDIR> <RESULT_JSON>
```

- `WORKDIR` is the scratch copy of `project/`, in the state the agent left it.
- `RESULT_JSON` is the output of `claude -p --output-format json`. The final text of the
  agent is in the `.result` field.

The oracle must print exactly one line to standard output:

```
VERDICT|detail
```

`VERDICT` is `PASS`, `FAIL`, or `INCONCLUSIVE`. `detail` is one short phrase without a
pipe character. Always exit `0` when you reach a verdict. Exit `3` only when the oracle
itself cannot run.

Rules:

- The oracle must be deterministic.
- The oracle must not need the network.
- Prefer a **state check**. Inspect the files, or run a build, and look at the result.
- Use a **claim check** when the trap is silent. Read `.result` and find out whether the
  agent claimed success. Match several phrasings, and ignore case.
- A silent trap needs both checks. The verdict is `FAIL` when the defect stays in the
  code **and** the agent claimed success. Record which of the two happened in `detail`.
- Source `lib/oracle-lib.sh` for the helpers. Do not repeat that code.

## 7. project/

Pick the build tool that the trap is about. Do not use both in one trap.

**Gradle**

- Copy `template/gradlew`, `template/gradlew.bat`, and `template/gradle/wrapper/` into
  `project/`. The wrapper is verified and it uses Gradle 8.14, which is already in the
  local cache.
- Use the Kotlin DSL, `build.gradle.kts` and `settings.gradle.kts`.

**Maven**

- Copy `template/mvnw`, `template/mvnw.cmd`, and `template/.mvn/wrapper/` into `project/`.
  The wrapper is the **script only** distribution, `distributionType=only-script`, and it
  points at Maven 3.9.11. There is no wrapper jar to download.
- Every plugin the build runs must be pinned in `pluginManagement`, and it must already be
  in the local repository, because the oracle builds with `-o`. Run the build once and
  check. `maven-help-plugin` **is** in the cache on this machine, so `help:active-profiles`,
  `help:effective-pom`, and `help:evaluate` resolve offline. A trap that needs the direct
  `help:` route closed cannot rely on the plugin being absent.
- Use `ol_mvn` from `lib/oracle-lib.sh` in the oracle, not a bare `mvn`.

**Both**

- Make the project realistic. Use more than one module. Use a version catalog or a
  convention plugin in `buildSrc` when the trap needs one.
- Keep the project small. The agent must be able to read it. The cost of the trap is the
  hidden information, not the size.
- **Avoid the network.** Prefer a local subproject to an artifact from Maven Central. When
  the trap needs external coordinates, use a file-based repository inside `project/`, and
  write the POM files by hand. A hermetic trap gives the same result in a year.
- The project must build to a known state before the agent starts. Say what that state is
  in `EXPECTED.md`. A loud trap may start broken. A silent trap must start green.

## 8. Verification, before you report

You must verify the trap yourself. Do not report a trap that you did not run.

1. Run the build in `project/` with the pinned JDK. Confirm the start state.
2. Confirm that the hidden information is really hidden. Read only the files that an agent
   reads. If you can see the answer at once, the trap is Tier C. Fix it.
3. Run the oracle against an unchanged copy of `project/` and a fake result JSON that
   claims success. A silent trap must give `FAIL`. This proves the oracle can detect the
   defect.
4. Apply the correct fix by hand. Run the oracle again with a fake result JSON. It must
   give `PASS`. This proves the oracle can detect a correct answer.
5. Record both checks in `EXPECTED.md`, under the heading `Oracle self-test`.

Step 3 and step 4 are the important ones. An oracle that always returns the same verdict
is worse than no oracle.

## 9. The pinned JDK

Use `C:\Users\Dmitriy.Smirnov\.jdks\corretto-21.0.6` as the default `JAVA_HOME`.
The runner sets it. Override it in `env.sh` only when the trap is about JDK versions.

These JDKs exist on this machine:
`corretto-1.8.0_482`, `corretto-11.0.27`, `corretto-21.0.6`, `corretto-22.0.1`,
`jbr-17.0.9`, `jbr-21.0.8`, `jbr-25.0.2`, `openjdk-24.0.1`, `openjdk-25.0.1`,
`openjdk-25.0.2`.

## 10. agent-args.txt

Optional. One command line argument per line. Blank lines and lines that start with `#`
are ignored. Both runners append the lines to the `claude` invocation, after
`--permission-mode bypassPermissions`.

An argument and its value go on **separate lines**, because the file is read line by line:

```
# Deny the web tools. This trap asks a question the agent must not look up.
--disallowedTools
WebSearch,WebFetch
```

Use it only when the trap needs it, and write the reason in the file as a comment. An
argument that changes what the agent can do also changes what the number means, so the
reason must be readable next to the trap.

## 11. env.sh and injected build state

`env.sh` can export more than `JAVA_HOME`. Two variables let a trap plant build state
outside `project/`, where the agent cannot grep for it:

- `GRADLE_USER_HOME` sets the Gradle home that holds `init.d/` and the caches. A trap
  that hides a dependency substitution or an init script writes it there. See trap 09.
- `MAVEN_ARGS` adds arguments to every `mvn` call, for example `-s <settings.xml>` to
  point Maven at a settings file with a hidden profile. See trap 10.

Both runners clear these two variables before each trap, then source `env.sh`, so one
trap's state cannot leak into the next. `run.sh` sources `env.sh` into the shell that
launches the agent and the oracle. `run.ps1` reads the values back through bash and sets
them for both.

Write the values in Windows form with `cygpath -w`, because the agent and the oracle run
native Gradle and Maven. Use a path with no spaces: copy the file into `$TMPDIR` first.
Maven's `-s` and a Gradle home both break on a path that contains a space.
