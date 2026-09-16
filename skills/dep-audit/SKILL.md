---
name: dep-audit
description: Audit a project's dependencies for known vulnerabilities by running the bt-ide CLI, which has already resolved the dependency graph and returns the findings as JSON. Use it instead of resolving the graph by hand or searching advisories online.
---

# Auditing dependencies with bt-ide

This environment has `bt-ide`, an IDE-backed CLI that already resolved the project's
dependency graph. Call it instead of running `./gradlew dependencies`, `mvn
dependency:tree`, or an online advisory search. It is faster and it sees transitive
dependencies that the build files do not name.

## Find vulnerable dependencies

Run this in the project root:

```
bt-ide audit
```

It prints JSON with a `vulnerabilities` array. Each entry has:

- `coordinate`, the group:artifact:version that resolved.
- `path`, the chain that pulled it in, so you can see whether it is transitive.
- `scope`, for example `runtime` or `compile`.
- `advisory`, the CVE or advisory id.
- `severity`.
- `fixedVersion`, the first version that is not affected.

## Act on the result

Read the array. For each entry, report the coordinate, the resolved version, the advisory
and the safe version. If the task asks for a fix, set the dependency to `fixedVersion`. An
empty array means the tool found no known vulnerability.
