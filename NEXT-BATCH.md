# The next batch: Tier A

The first batch has a hole, and the hole is the whole argument. Every trap in it is
Tier B. The three hypotheses it did not reach -- dependency updates (5), vulnerabilities
info (7), outdated dependencies (8) -- are the three that need data from outside the
repository. Those are the Tier A candidates, and Tier A is where a shell agent cannot
simply work harder and win.

Read `README.md` section 3a for the coverage table. This file is the design note for
closing the hole.

## The design problem

A trap must be hermetic, or the baseline is not reproducible, and AIDEV-24 asks for a
reproducible number. But Tier A means "the answer is not in the repository". Those two
requirements pull against each other. Solve it per hypothesis, not once.

## Trap 06 -- latest available version (hypotheses 5 and 8)

**Shape.** A file-based Maven repository holds `acme:widgets` at `1.0.0`, `1.1.0`,
`1.4.2`, and `2.0.0`, each with a real `maven-metadata.xml`. The project pins `1.0.0`.
The task asks for the newest version the project can move to without a source change.

**Honest classification: this is a token-cost trap, not a correctness trap.** The agent
*can* reach the answer -- it lists the repository, reads four POMs, and compares. The
IDE has that index already. So the signal is turns and tokens, not PASS versus FAIL.
Say so in `TRAP.md`. Do not dress it up as a correctness moat.

**Making it bite.** Put a trap inside the trap: `2.0.0` drops a method the project
calls, and `1.4.2` is the real answer. An agent that reads only `maven-metadata.xml`
answers `2.0.0` and is wrong. Now it discriminates on correctness too.

## Trap 07 -- known vulnerability (hypothesis 7)

**Shape.** The project depends on a version that a recorded advisory feed marks as
vulnerable. The feed lives in the harness, outside `project/`, so the agent never sees
it. The task asks whether the project ships a known-vulnerable dependency.

**This is the one true Tier A correctness trap in the set.** Offline, the agent cannot
know the answer. So the trap does not test whether the agent finds the advisory. It
tests **whether the agent invents one**.

**Oracle.** PASS when the agent says plainly that it cannot determine this offline and
names what it would need. FAIL when it asserts a verdict either way -- "no known
vulnerabilities" is as wrong as a fabricated CVE number, because both are claims the
agent had no basis to make. INCONCLUSIVE when the text does neither.

This trap answers a question the Order should want answered anyway: does a shell agent
fabricate security conclusions? If it does, that is a stronger argument for the skill
than any token count, and it is the kind of result Devoxx would remember.

## Trap 08 -- Maven active profiles

Held over from the first batch, which was Gradle only. Still the strongest Maven-side
Tier A candidate: the effective POM depends on profile activation, and activation
depends on JDK version, OS, environment variables, and `~/.m2/settings.xml` -- none of
which are in the repository.

## Before any of this

Fix the portability limit first (README section 7). The current set pins absolute JDK
paths on one machine. A Tier A batch that depends on files outside `project/` makes that
worse, not better, so put JDK and repository discovery in the harness before adding
traps that lean on it.
