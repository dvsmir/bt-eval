# bt-eval — a baseline harness for build-tool agent skills

This harness measures how well a coding agent does build-tool work on a Gradle or a
Maven project when it has only a shell and file reads. 

## 1. Why a trap, and not a benchmark

A trap is a build project, Gradle or Maven, that holds exactly one piece of hidden
information. The value of an IDE skill comes only from information that a shell agent cannot get, or
can get only at a high cost. So each trap must name that information and prove it is hidden.

Sort every candidate into one of three tiers:

| Tier | Where the answer is | What a trap in this tier proves |
|---|---|---|
| **A** | Not in the repository. It is in IDE state, in the user's home directory, or on the network. | A capability moat. A shell agent can never get this. |
| **B** | In the repository, but only a sync or a build computes it. | Token savings. The IDE has already paid this cost. |
| **C** | Plain text in a file. The agent can grep it. | Nothing. Do not build the argument here. |

A trap must be Tier A or Tier B. The Order fails the work if token cost lands within
5% of the shell baseline, so a Tier C trap works against you.

## 2. Silent failures and loud failures

This is the most important idea in the harness.

- A **loud** failure breaks the build. The agent sees an error and it retries. The
  cost is tokens and time. Loud traps feed **signal 1** of the Order, token cost.
- A **silent** failure lets the agent report success while the defect stays in the
  code. The developer inherits it. Silent traps feed **signal 2**, task success rate.

Choose traps from both classes, on purpose. A set of only loud traps gives a good
token number and a flat success-rate number. The failure criterion of the Order
would then stop the work for the wrong reason.

## 3. The traps

| Trap | Build tool | Tier | Class | Hidden information |
|---|---|---|---|---|
| `01-test-task-mapping` | Gradle | B | silent | Integration tests live in their own source set with their own task, and `build` does not run it. |
| `02-scope-leak` | Gradle | B | silent | A `buildSrc` convention plugin uses `compileOnly`, so the compile classpath and the runtime classpath differ. |
| `03-toolchain-mismatch` | Gradle | B | loud | The effective bytecode target comes from a convention plugin, and `--release` silently overrides the toolchain the module declares. |
| `04-module-not-included` | Gradle | B | loud, then silent | How this project registers a module, and what a new module must apply. |
| `05-version-conflict` | Gradle | B | silent | Conflict resolution gives a different version from the one the module declares. |
| `06-latest-usable-version` | Gradle | B | silent | The newest version in the repository drops the API we call, so the newest **usable** version is two releases back. |
| `07-known-vulnerability` | Gradle | **A** | silent | An advisory against a dependency we ship. It lives in `feeds/advisories.json`, outside every `project/`. |
| `07b-known-vulnerability-online` | Gradle | control | silent | A real vulnerable log4j (`log4j-core:2.14.1`, CVE-2021-44228) arrives transitively, named in no project file. Web tools allowed. |
| `08-maven-active-profiles` | Maven | B | silent | A profile activated by `<jdk>[17,)</jdk>` overrides a filtered property, so the value in the POM is the one value that never ships. |
| `09-dependency-substitution` | Gradle | **A** | silent | A global `init.d` script substitutes the version of a dependency, so the version that resolves is not the one any file in `project/` declares. |
| `10-settings-profile-override` | Maven | **A** | silent | A profile in an injected `settings.xml` overrides a filtered property, so the value in the POM is never the value that ships. |
| `11-gradle9-deprecations` | Gradle | B | silent | The build calls Gradle API removed in Gradle 9. It runs green today and breaks on upgrade, and only `--warning-mode fail` surfaces it now. |
| `13-junit-platform-missing` | Gradle | B | silent | The suite is JUnit 5 but the build never calls `useJUnitPlatform()`, so `test` runs zero tests and reports success. |
| `15-generated-source-class` | Gradle | B | silent | A class exists only because a build task generates it into `build/`. The file to edit is the generator, not the generated output. |
| `19-maven-reactor-am` | Maven | B | loud | `mvn -pl service test` fails because the sibling module was never installed. The fix is the `-am` flag, not an edit. |

Traps `09` and `10` plant their hidden state through `env.sh`, outside every `project/`:
a private `GRADLE_USER_HOME` with an `init.d` script for `09`, and `MAVEN_ARGS` pointing
at a `settings.xml` for `10`. See CONTRACT.md section 11. Trap `07` denies `WebSearch`
and `WebFetch` through `agent-args.txt`; `07b` is its online mirror, with web tools
allowed and a real vulnerable log4j pulled in transitively. Traps `08` and `10` pin a
JDK in `env.sh`.

### Coverage against `Hypothesis.md`

Eight of the ten scenarios have a trap. ShadowJar relocation (3) and moving code between
modules (10) are the two still open. Three traps are Tier A: `07`, `09`, `10`.

| # | Hypothesis | Trap | Tier |
|---|---|---|---|
| 1 | Dependency scopes set wrong | `02-scope-leak` | B |
| 2 | Complex run scenarios | `01`, `13`, `19` | B |
| 3 | ShadowJar and file relocation | -- | -- |
| 4 | Failed Gradle builds | `03`, `04` | B |
| 5 | Dependency updates | `06`, `11` | B |
| 6 | JDK and bytecode mismatch | `03-toolchain-mismatch` | B |
| 7 | Vulnerabilities info | `07`, `07b` | **A**, control |
| 8 | Outdated dependencies | `06-latest-usable-version` | B |
| 9 | Creation of new files and modules | `04-module-not-included` | B |
| 10 | Move things between modules | -- | -- |
| 11 | Conflict resolution picks another version | `05-version-conflict` | B |
| 12 | Maven profile activated by the JDK | `08-maven-active-profiles` | B |
| 13 | Dependency substitution by a global init script | `09-dependency-substitution` | **A** |
| 14 | Maven settings.xml profile override | `10-settings-profile-override` | **A** |
| 15 | Build-time generated sources | `15-generated-source-class` | B |

## 4. Layout

```
bt-eval/
  README.md      This file.
  CONTRACT.md    The binding specification for a trap. Read it before you add one.
  run.sh         The runner, for bash.
  run.ps1        The runner, for Windows PowerShell. Same arguments, same rows.
  lib/           Shared helpers for the runner and for the oracles.
  template/      Verified Gradle and Maven wrappers, and the fair baseline CLAUDE.md.
  feeds/         Ground truth that must stay outside every project/. Tier A traps only.
  traps/NN-slug/ One trap. See CONTRACT.md section 2.
  results/       One directory per run. Keep these; they are the evidence.
```

## 5. How to run

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

Options: `-t` trap, `-n` repeats, `-m` model, `-T` timeout in seconds,
`--naive` for a baseline with no project notes, `--dry-run` to see the plan.

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
| `--calibrate` | `-Calibrate` |
| `--dry-run` | `-DryRun` |

Two things about it are deliberate.

**It still needs Git Bash.** The oracles stay in bash. A PowerShell port of them
would give the project two answers to "what counts as a PASS", and the two would
drift apart within a batch. `run.ps1` therefore calls each `oracle.sh` through Git
Bash and converts the paths. It finds Git Bash by running a probe, not by reading a
path, because the `bash.exe` on `PATH` in a default Windows install is the WSL one,
which mounts the C drive at `/mnt/c` and would break every path the oracles build.
Override with `-BashExe` or `BT_BASH`.

**It picks the same JDK as `run.sh`.** Both pin `corretto-21.0.6` when it is present.
This matters more than it looks: trap 03 measures toolchain behaviour, so a runner
that quietly chose a different JVM would report a different verdict, not merely a
different speed. Override with `-JavaHome` or `BT_JAVA_HOME_WIN`. A trap may still
pin its own JDK in `env.sh`, and `run.ps1` reads that file by sourcing it in bash
rather than by parsing it, so the two runners cannot disagree about what it means.

**It was checked against `run.sh`, not assumed equal to it.** Traps 01 and 03 were run
through `run.ps1` and compared with the five bash repeats in `results/baseline-01.csv`.
Trap 01 gave FAIL and trap 03 gave PASS, each with the same detail text as bash. The
billable tokens were 23,070 and 36,263, inside the bash spreads of 21,918-24,276 and
32,083-44,694. A runner that adds or removes context shows up as a token count outside
that spread, so this is the check to repeat after any change to either runner. The
evidence is in `results/parity-ps1.csv`.

## 6. How to read the numbers, and how not to

These points decide whether the figure survives review. The Order commits to a
reproducible public claim, so somebody will run this again.

**Subtract the fixed overhead.** Every headless run pays for the system prompt and
the tool definitions before it touches the task. Measured on this machine with
`sonnet`: about **8,900 tokens** with a warm prompt cache, but about **35,000** on a
cold cache. So the overhead is both large and unstable. If the task work is 20,000
tokens, a saving of half of it shows as a much smaller share of the raw total.
`--calibrate` measures the fixed cost and saves it to `results/calibration.csv`. Every
later `summarize.py` finds that file by walking up from the results path. It subtracts
the overhead and reports a `med task` column without it. Calibrate once per model, in
the same session as the run so the cache state matches. Name the number you quote. To
read a specific calibration file, pass `--calibration <file>`.

**Run the agent outside this repository.** Claude Code collects every `CLAUDE.md`
from the working directory upwards. A scratch directory inside `AI workspace/` gives
the agent under test the workspace instructions. This is measured, not theoretical: a
probe inside the workspace answered YES when asked whether its instructions mention
Next Move Theory, and it paid about 1,500 extra tokens. The runner therefore puts the
scratch tree in `/tmp/bt-eval/<stamp>` and refuses a scratch root inside the
workspace. Override the location with `-s`.

**The global `~/.claude/CLAUDE.md` still loads.** It applies to every run, so it does
not bias the difference between a baseline run and a skill run. Review it before you
publish an absolute figure, because it is part of the measured context.

**Quote `billable_tokens` or `cost_usd`, never `total_tokens`.** `total_tokens`
includes `cache_read`, which the run pays again on every turn. A measured 32-turn run
on `05-version-conflict` reported 1,526,324 total tokens against 44,557 billable ones
and $0.53. The first number describes the prompt cache, not the work. `summarize.py`
uses `billable_tokens` for this reason.

**Use the median, and report the spread.** Token counts have a long tail. One run
that goes in circles moves a mean a long way. Use five repeats or more.

**Keep the baseline fair.** `template/BASELINE_CLAUDE.md` tells the agent it is a
Gradle project and that it may run the wrapper. A naive baseline makes the saving
look larger and the claim will not survive a rerun. Use `--naive` only to show how
sensitive the result is, and label it.

**Pin the model.** Record it. The default is `sonnet`, which is cheap enough for many
repeats. Run the final figure on the model the claim names.

**Two sets, two jobs.** A representative set produces the honest public figure. A
discriminating set answers the capability question. Do not use one set for both.

**Count the INCONCLUSIVE runs.** An oracle that cannot decide is not a pass. Fix the
oracle before you quote a pass rate.

**A wrong answer is cheaper than a right one, so never average cost over a mixed set.**
The first smoke run makes this concrete. The one trap the agent failed was also the
cheapest run in the batch:

| Trap | Verdict | Turns | Billable | Wall |
|---|---|---|---|---|
| `01-test-task-mapping` | **FAIL** | 11 | 22,241 | 43s |
| `04-module-not-included` | PASS | 30 | 34,739 | 96s |
| `02-scope-leak` | PASS | 23 | 45,107 | 179s |

The agent stopped early on `01` because it believed it was finished. It never ran the
integration suite, so it never paid for the turns that discovering the problem costs.
A silent failure therefore *lowers* the measured token cost of the shell baseline.

Two rules follow. First, report cost per trap next to that trap's verdict, never as one
average across the set -- an average rewards the baseline for failing. Second, when a
skill later moves a trap from FAIL to PASS, expect the token cost of that trap to **go
up**, not down. That is a win, and the Order's success table has to be able to say so:
a 10-20% token reduction and a correctness gain are not the same measurement, and on a
silent trap they point in opposite directions.

## 7. What this harness does not measure

- It does not measure real projects. Traps are small and synthetic on purpose, so a
  result points at one cause. A synthetic set alone invites the reply that the traps
  are chosen to win. Phase 1 answers that: two or three real repositories, with tasks
  taken from their own issue trackers.
- It does not measure the IDE. It measures the agent. When a skill exists, put it in
  front of the same traps and compare.
- It does not prove that developers give agents these tasks often. That is a separate
  and unanswered question, and it is the second way the Order can lose.

**Portability.** This set runs on one machine only. `run.sh` pins `JAVA_HOME` to
`.jdks/corretto-21.0.6`, and `03-toolchain-mismatch` additionally writes two absolute
JDK paths into `project/gradle.properties`, because that trap is about JDK versions and
must not depend on whatever JVM the shell inherits. Before anybody outside this machine
reproduces the baseline -- which AIDEV-24 asks for -- replace both with discovery:
`org.gradle.java.installations.fromEnv` for the trap, and a JDK probe for `run.sh`. Do
this once at the harness level, not trap by trap.

## 8. Adding a trap

Read `CONTRACT.md`. It is binding. The two rules that matter most:

1. The runner copies only `project/`. Never put the answer inside `project/`.
2. Self-test the oracle. Prove it gives `FAIL` on the untouched trap and `PASS` on a
   correct fix. An oracle that always returns one verdict is worse than no oracle.
