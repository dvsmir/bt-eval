---
name: resolve-deps
description: Get a project's resolved dependency versions and scopes by running the bt-ide CLI, which has already resolved the graph and returns it as JSON. Use it instead of running gradlew dependencies once per configuration.
---

# Resolving dependencies with bt-ide

This environment has `bt-ide`, an IDE-backed CLI that already resolved the project's
dependency graph. Call it instead of running `./gradlew dependencies` or
`./gradlew dependencyInsight` once per configuration. One call returns every
configuration, so you see the declared and resolved versions in one place.

## The resolved graph

Run this in the project root:

```
bt-ide deps
```

It prints JSON with a `configurations` object, one entry per configuration such as
`compileClasspath` and `runtimeClasspath`. Each dependency entry has:

- `coordinate`, the group:artifact:version that resolved.
- `requested`, the version the build asked for.
- `selected`, the version that actually resolved.
- `bucket`, the declaration bucket, for example `implementation` or `compileOnly`.
- `selectionReason`, why `selected` differs from `requested`, when it does.

## Why one version resolved

To see why a single coordinate resolved to a version, run:

```
bt-ide dependency-insight --dependency <group:artifact> --configuration <name>
```

It prints the `requested` and `selected` versions, the `selectionReason`, and the
`paths` that pulled the coordinate in.

## Act on the result

Report the `selected` version on the runtime classpath, not the declared one, because the
two can differ. A dependency on `compileClasspath` but absent from `runtimeClasspath`
compiles and then fails at run time with a missing class. When `selected` differs from
`requested`, name the reason from `selectionReason`.
