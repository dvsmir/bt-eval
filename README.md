# bt-eval: a baseline harness for build-tool agent skills

This harness measures how well a coding agent does build-tool work on a Gradle or Maven
project when it has only a shell and file reads. It also measures whether a skill lowers
that cost.

## 1. Why a trap, not a benchmark

A trap is a build project, Gradle or Maven, that holds one piece of hidden information. An
IDE skill earns its cost only from information a shell agent cannot get, or can get only at
a high price. So each trap names that information and proves it is hidden.

Sort every candidate into one of three tiers.

| Tier | Where the answer is | What a trap here proves |
|---|---|---|
| **A** | Not in the repository. It sits in IDE state, the user's home, or on the network. | A capability moat. A shell agent can never reach it. |
| **B** | In the repository, but only a sync or a build computes it. | Token savings. The IDE has already paid this cost. |
| **C** | Plain text in a file. The agent can grep it. | Nothing. Do not build the argument here. |

A trap must be Tier A or Tier B. The Order fails the work if token cost lands within 5% of
the shell baseline, so a Tier C trap works against you.

## 2. Silent failures and loud failures

This is the most important idea in the harness.

- A **loud** failure breaks the build. The agent sees an error and retries. The cost is
  tokens and time. Loud traps feed signal 1 of the Order, token cost.

- A **silent** failure lets the agent report success while the defect stays in the code.
  The developer inherits it. Silent traps feed signal 2, task success rate.

Choose traps from both classes on purpose. A set of only loud traps gives a good token
number and a flat success rate. The failure criterion of the Order would then stop the
work for the wrong reason.

## 3. The traps

| Trap | Build tool | Tier | Class | Hidden information |
|---|---|---|---|---|
| `01-test-task-mapping` | Gradle | B | silent | Integration tests live in their own source set with their own task, and `build` does not run it. |
| `02-scope-leak` | Gradle | B | silent | A `buildSrc` convention plugin uses `compileOnly`, so the compile classpath and the runtime classpath differ. |
| `03-toolchain-mismatch` | Gradle | B | loud | The effective bytecode target comes from a convention plugin, and `--release` silently overrides the toolchain the module declares. |
| `04-module-not-included` | Gradle | B | loud, then silent | How this project registers a module, and what a new module must apply. |
| `05-version-conflict` | Gradle | B | silent | Conflict resolution gives a different version from the one the module declares. |
| `06-latest-usable-version` | Gradle | B | silent | The newest version in the repository drops the API we call, so the newest usable version is two releases back. |
| `07-known-vulnerability` | Gradle | **A** | silent | An advisory against a dependency we ship. It lives in `feeds/advisories.json`, outside every `project/`. |
| `07b-known-vulnerability-online` | Gradle | control | silent | A real vulnerable log4j (`log4j-core:2.14.1`, CVE-2021-44228) arrives transitively, named in no project file. Web tools allowed. |
| `08-maven-active-profiles` | Maven | B | silent | A profile activated by `<jdk>[17,)</jdk>` overrides a filtered property, so the value in the POM is the one value that never ships. |
| `09-dependency-substitution` | Gradle | **A** | silent | A global `init.d` script substitutes the version of a dependency, so the version that resolves is not the one any file in `project/` declares. |
| `10-settings-profile-override` | Maven | **A** | silent | A profile in an injected `settings.xml` overrides a filtered property, so the value in the POM is never the value that ships. |
| `11-gradle9-deprecations` | Gradle | B | silent | The build calls Gradle API removed in Gradle 9. It runs green today and breaks on upgrade, and only `--warning-mode fail` surfaces it now. |
| `13-junit-platform-missing` | Gradle | B | silent | The suite is JUnit 5 but the build never calls `useJUnitPlatform()`, so `test` runs zero tests and reports success. |
| `15-generated-source-class` | Gradle | B | silent | A class exists only because a build task generates it into `build/`. The file to edit is the generator, not the generated output. |
| `19-maven-reactor-am` | Maven | B | loud | `mvn -pl service test` fails because the sibling module was never installed. The fix is the `-am` flag, not an edit. |

Several traps plant hidden state through `env.sh`, outside every `project/`. See
CONTRACT.md section 11. Trap `09` sets a private `GRADLE_USER_HOME` with an `init.d` script
that pins a dependency version. Trap `10` points `MAVEN_ARGS` at an injected `settings.xml`.
Traps `03`, `08`, `09`, and `10` also pin a JDK there, because their result depends on the
JVM. Trap `07` denies `WebSearch` and `WebFetch` through `agent-args.txt`. Trap `07b` is its
online mirror, with web tools allowed and a real vulnerable log4j pulled in transitively.

### Coverage against `Hypothesis.md`

The hypothesis list has fourteen scenarios. Twelve have a trap. Two stay open: ShadowJar
and file relocation, and moving code between modules. Three traps are Tier A: `07`, `09`,
and `10`.

| Hypothesis | Trap | Tier |
|---|---|---|
| Dependency scopes set wrong | `02-scope-leak` | B |
| Complex run scenarios | `01`, `13`, `19` | B |
| ShadowJar and file relocation | -- | open |
| Failed Gradle builds | `03`, `04` | B |
| Dependency updates | `06`, `11` | B |
| JDK and bytecode mismatch | `03-toolchain-mismatch` | B |
| Vulnerabilities info | `07`, `07b` | **A**, control |
| Outdated dependencies | `06-latest-usable-version` | B |
| Creation of new files and modules | `04-module-not-included` | B |
| Move code between modules | -- | open |
| Conflict resolution picks another version | `05-version-conflict` | B |
| Profile overrides a filtered property | `08` (POM), `10` (`settings.xml`) | B, **A** |
| Dependency swapped by a global init script | `09-dependency-substitution` | **A** |
| Build-time generated source | `15-generated-source-class` | B |

## 4. Skills and the mock CLI

A skill is knowledge a session loads. Most skills here teach the agent to call `bt-ide`, a
mocked IDE-backed CLI that returns a resolved fact as JSON. The agent reads the JSON and
skips the discovery the baseline pays for. The eval installs a skill only under `--skill`,
so each skill is measured against its own baseline.

The library holds four skills.

| Skill | `bt-ide` command(s) | What it returns |
|---|---|---|
| `resolve-deps` | `deps`, `dependency-insight` | Resolved versions and scopes, per configuration. |
| `effective-build` | `effective-model` | Active profiles, effective properties, per-module compiler settings. |
| `inspect` | `inspect` | Deprecated build APIs and their replacements. |
| `dep-audit` | `audit` | Known vulnerabilities in the resolved graph. |

The CLI is mocked. The shared shim is `lib/mock/bt-ide`, a small script that prints a canned
answer. It reads `BT_MOCK_DIR/<command>.json` and writes that file verbatim. `bt-ide.cmd`
lets Windows resolve the bare name. A trap that uses a skill ships a `mock/` directory with
one JSON file per command. Under `--skill` the runner copies the shim to a scratch `bin/` on
PATH and points `BT_MOCK_DIR` at the copied `mock/`. The fixture sits outside the agent's
working tree, so the answer reaches the agent only through the tool.

Eight traps carry a skill.

| Trap | Skill | Mocked command(s) |
|---|---|---|
| `02-scope-leak` | `resolve-deps` | `deps` |
| `03-toolchain-mismatch` | `effective-build` | `effective-model` |
| `05-version-conflict` | `resolve-deps` | `deps`, `dependency-insight` |
| `07b-known-vulnerability-online` | `dep-audit` | `audit` |
| `08-maven-active-profiles` | `effective-build` | `effective-model` |
| `09-dependency-substitution` | `resolve-deps` | `deps`, `dependency-insight` |
| `10-settings-profile-override` | `effective-build` | `effective-model` |
| `11-gradle9-deprecations` | `inspect` | `inspect` |

Trap `07` has no skill and no mock on purpose. It is the honesty control. Its oracle passes
a disclaimer and fails any assertion, so a tool that answered the vulnerability question
would invert what the trap measures. Every mock returns realistic tool output, never the
oracle's answer string. See CONTRACT.md section 12 for how to author a skill.

## 5. Layout

```
bt-eval/
  README.md      This file.
  CONTRACT.md    The binding specification for a trap. Read it before you add one.
  NEXT-BATCH.md  Design notes for the Tier A and third batches.
  run.sh         The runner, for bash.
  run.ps1        The runner, for Windows PowerShell. Same arguments, same rows.
  lib/           Shared helpers for the runner and the oracles.
  lib/mock/      The mock CLI bt-ide, shared by every skill that calls a tool.
  skills/        The skills library. One directory per skill, each with a SKILL.md.
  template/      Verified Gradle and Maven wrappers, and the fair baseline CLAUDE.md.
  feeds/         Ground truth kept outside every project/. Tier A traps only.
  traps/NN-slug/ One trap. See CONTRACT.md section 2.
  results/       One directory per run. Keep these; they are the evidence.
```

## 6. How to run

```bash
./run.sh --calibrate                     # do this first, once per model
./run.sh -t 01-test-task-mapping -n 1    # try one trap once
./run.sh -n 5                            # the real run: all traps, 5 repeats
python lib/summarize.py results/<stamp>/results.csv
```

Compare two runs, for example a shell baseline against a run with the skills:

```bash
python lib/summarize.py results/<new>/results.csv results/<baseline>/results.csv
```

Options: `-t` trap, `-n` repeats, `-m` model, `-T` timeout in seconds, `--skill` to install
the trap's declared skill, `--naive` for a baseline with no project notes, `--dry-run` to
see the plan.

### Each run starts clean

Every run of a trap is isolated from every other run. No run passes or fails because of
state a previous run left behind.

Before each run the runner does four things:

- It gives the agent a fresh Claude config directory. The copy carries only the keys that
  reach the API. It has no transcript, memory, command history, plugin, or personal skill
  from a previous run or from your own machine.
- It gives Gradle a fresh home with the daemon off, so no build state survives between
  runs. The download cache and the wrapper are shared through a link, so isolation costs
  no re-download.
- It removes any committed `build/`, `.gradle/`, or `target/` from the copied project, so
  the agent starts from source.
- It keeps the shared Maven cache, but records its snapshot set first and removes any
  module the agent installed after the run. An installed snapshot would mask the trap for
  the next repeat.

A trap that pins its own Gradle home in `env.sh` keeps it, and the runner forces the
daemon off there too. Trap state you plant in `env.sh` survives, because it is in place
before the snapshot is taken.

### Checking whether a skill helps

Run the trap without the skill, then with it, then compare the two result files.

```bash
./run.sh -t 07b-known-vulnerability-online -n 5              # baseline
./run.sh -t 07b-known-vulnerability-online -n 5 --skill      # with the trap's skill
python lib/summarize.py results/<skill>/results.csv results/<baseline>/results.csv
```

`--skill` installs the skills the trap names in its `skill.txt`, copied from `skills/` into
the session. When the trap ships a `mock/` directory, the runner also serves it through
`bt-ide`, so the agent calls the tool instead of resolving the graph and searching online.
The `condition` column of each CSV says which run was which: `baseline` or `skill`. Judge the
cost by the raw `billable` number, because a skill also costs tokens on every turn, and that
cost counts against it. See CONTRACT.md section 12.

### On Windows, from PowerShell

`run.ps1` is the twin of `run.sh`. It takes the same steps and writes the same CSV.

```powershell
.\run.ps1 -Calibrate
.\run.ps1 -Traps 01-test-task-mapping -Repeats 1
.\run.ps1 -Repeats 5
python lib\summarize.py results\<stamp>\results.csv
```

| `run.sh` | `run.ps1` |
|---|---|
| `-t a,b` | `-Traps a,b` |
| `-n 5` | `-Repeats 5` |
| `-m sonnet` | `-Model sonnet` |
| `-o file.csv` | `-Out file.csv` |
| `-T 1800` | `-TimeoutSec 1800` |
| `-s <dir>` | `-ScratchRoot <dir>` |
| `--naive` | `-Naive` |
| `--skill` | `-Skill` |
| `--calibrate` | `-Calibrate` |
| `--dry-run` | `-DryRun` |

Three things about it are deliberate.

**It still needs Git Bash.** The oracles stay in bash. A PowerShell port would give the
project two answers to "what counts as a PASS", and the two would drift apart within a
batch. `run.ps1` calls each `oracle.sh` through Git Bash and converts the paths. It finds
Git Bash by running a probe, not by reading a path, because the `bash.exe` on PATH in a
default Windows install is the WSL one. That one mounts the C drive at `/mnt/c` and would
break every path the oracles build. Override with `-BashExe` or `BT_BASH`.

**It picks the same JDK as `run.sh`.** Both pin `corretto-21.0.6` when it is present. This
matters more than it looks. Trap `03` measures toolchain behaviour, so a runner that chose a
different JVM would report a different verdict, not a different speed. Override with
`-JavaHome` or `BT_JAVA_HOME_WIN`. A trap may still pin its own JDK in `env.sh`. `run.ps1`
reads that file by sourcing it in bash, not by parsing it, so the two runners cannot
disagree about what it means.

**It was checked against `run.sh`, not assumed equal.** Traps `01` and `03` ran through
`run.ps1` and matched the five bash repeats in `results/baseline-01.csv`.

| Trap | run.ps1 verdict | run.ps1 billable | Bash spread |
|---|---|---|---|
| `01-test-task-mapping` | FAIL | 23,070 | 21,918 to 24,276 |
| `03-toolchain-mismatch` | PASS | 36,263 | 32,083 to 44,694 |

Each verdict carried the same detail text as bash. A runner that adds or removes context
shows up as a token count outside that spread. Repeat this check after any change to either
runner. The evidence is in `results/parity-ps1.csv`.

## 7. How to read the numbers, and how not to

These points decide whether the figure survives review. The Order commits to a reproducible
public claim, so somebody will run this again.

**Subtract the overhead.** Every headless run pays for the system prompt and the tool
definitions before it touches the task. Measured on this machine with `sonnet`: about 8,900
tokens on a warm prompt cache, about 35,000 on a cold one. The overhead is large and
unstable. If the task work is 20,000 tokens, a saving of half of it shows as a smaller share
of the raw total. `--calibrate` measures the fixed cost and saves it to
`results/calibration.csv`. Every later `summarize.py` finds that file by walking up from the
results path. It subtracts the overhead and reports a `med task` column without it. Calibrate
once per model, in the same session as the run, so the cache state matches. Name the number
you quote. To read a specific calibration file, pass `--calibration <file>`.

**Run the agent outside this repository.** Claude Code collects every `CLAUDE.md` from the
working directory upwards. A scratch directory inside `AI workspace/` gives the agent under
test the workspace instructions. This is measured, not theoretical. A probe inside the
workspace answered YES when asked whether its instructions mention Next Move Theory, and it
paid about 1,500 extra tokens. The runner puts the scratch tree in `/tmp/bt-eval/<stamp>`
and refuses a scratch root inside the workspace. Override the location with `-s`.

**The global `~/.claude/CLAUDE.md` still loads.** It applies to every run, so it does not
bias the difference between a baseline run and a skill run. Review it before you publish an
absolute figure, because it is part of the measured context.

**Quote `billable_tokens` or `cost_usd`, never `total_tokens`.** `total_tokens` includes
`cache_read`, which the run pays again on every turn. A 32-turn run on `05-version-conflict`
reported 1,526,324 total tokens against 44,557 billable ones and $0.53. The first number
describes the prompt cache, not the work. `summarize.py` uses `billable_tokens` for this
reason.

**Use the median, and report the spread.** Token counts have a long tail. One run that goes
in circles moves a mean a long way. Use five repeats or more.

**Keep the baseline fair.** `template/BASELINE_CLAUDE.md` tells the agent it is a Gradle
project and that it may run the wrapper. A naive baseline makes the saving look larger, and
the claim will not survive a rerun. Use `--naive` only to show how sensitive the result is,
and label it.

**Pin the model.** Record it. The default is `sonnet`, which is cheap enough for many
repeats. Run the final figure on the model the claim names.

**Count the INCONCLUSIVE runs.** An oracle that cannot decide is not a pass. Fix the oracle
before you quote a pass rate.

**A wrong answer is cheaper than a right one.** Never average cost over a mixed set. The
first smoke run makes this concrete. The one trap the agent failed was also the cheapest run
in the batch.

| Trap | Verdict | Turns | Billable | Wall |
|---|---|---|---|---|
| `01-test-task-mapping` | **FAIL** | 11 | 22,241 | 43s |
| `04-module-not-included` | PASS | 30 | 34,739 | 96s |
| `02-scope-leak` | PASS | 23 | 45,107 | 179s |

The agent stopped early on `01` because it believed it was finished. It never ran the
integration suite, so it never paid for the turns that finding the problem costs. A silent
failure lowers the measured token cost of the shell baseline.

Two rules follow. Report cost per trap next to that trap's verdict, never as one average
across the set, because an average rewards the baseline for failing. When a skill later moves
a trap from FAIL to PASS, expect the token cost of that trap to go up, not down. That is a
win. The Order's success table must be able to say so. A token reduction and a correctness
gain are not the same measurement, and on a silent trap they point in opposite directions.

## 8. What this harness does not measure

- It does not measure real projects. Traps are small and synthetic on purpose, so a result
  points at one cause. A synthetic set alone invites the reply that the traps are chosen to
  win. Phase 1 answers that with two or three real repositories, using tasks from their own
  issue trackers.

- It does not measure the IDE. It measures the agent. When a skill exists, put it in front
  of the same traps and compare.

- It does not prove that developers give agents these tasks often. That is a separate and
  open question, and it is the second way the Order can lose.

**Portability.** This set runs on one machine only. `run.sh` pins `JAVA_HOME` to
`.jdks/corretto-21.0.6`. Trap `03` also writes two absolute JDK paths into
`project/gradle.properties`, because that trap is about JDK versions and must not depend on
the inherited JVM. AIDEV-24 asks for a reproducible baseline elsewhere. Before that, replace
both with discovery: `org.gradle.java.installations.fromEnv` for the trap, and a JDK probe
for `run.sh`. Do this once at the harness level, not trap by trap.

## 9. Adding a trap

Read `CONTRACT.md`. It is binding. Two rules matter most.

1. The runner copies only `project/`. Never put the answer inside `project/`.
2. Self-test the oracle. Prove it gives FAIL on the untouched trap and PASS on a correct
   fix. An oracle that always returns one verdict is worse than no oracle.
