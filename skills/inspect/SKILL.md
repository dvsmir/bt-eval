---
name: inspect
description: Find deprecated build APIs and their replacements by running the bt-ide CLI, which inspects the build against a target version and returns findings as JSON. Use it instead of parsing warning-mode output or recalling cross-version API changes.
---

# Inspecting the build with bt-ide

This environment has `bt-ide`, an IDE-backed CLI that inspects the build for deprecated
API. Call it instead of reading `--warning-mode all` output or recalling which API a
future Gradle version removes.

## Deprecations and replacements

Run this in the project root:

```
bt-ide inspect
```

It prints JSON with a `deprecations` array. Each entry has:

- `api`, the deprecated property or method.
- `location`, the file that uses it.
- `removedIn`, the version that removes it.
- `replacement`, the code that replaces it.
- `detail`, why it is deprecated and what the replacement does.

## Act on the result

For each entry, replace the `api` at `location` with `replacement`. After the edits,
confirm the build is clean, for example with `./gradlew build --warning-mode fail`, which
turns any remaining deprecation into a failure.
