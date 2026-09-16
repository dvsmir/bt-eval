---
name: effective-build
description: Get a project's effective build model, its resolved properties, active profiles and per-module compiler settings, by running the bt-ide CLI, which returns them as JSON. Use it instead of computing the effective POM or reading generated resources.
---

# Reading the effective build model with bt-ide

This environment has `bt-ide`, an IDE-backed CLI that holds the resolved build model.
Call it instead of running `mvn help:effective-pom`, building the project to read a
generated resource, or composing profiles and toolchains by hand.

## The effective model

Run this in the project root:

```
bt-ide effective-model
```

It prints JSON describing the model after profiles and conventions apply:

- `activeProfiles`, the profiles in effect and how each one activated.
- `properties`, the effective value of each property, with its `source` and the
  `pomDefault` it replaced.
- `modules`, per-module settings, including a `java` block with the toolchain language
  version and the effective `compileRelease`.

A property `source` can lie outside the project, for example a profile in a user settings
file. Then the value the build ships is in no file you can read in the project, so trust
the effective value here.

## Act on the result

Report the effective value, not the POM default, because the default is the value that
never ships. For a compiler problem, read each module's `compileRelease`: a release that
overrides the module toolchain explains a compile failure, and the `source` field names
where the release came from.
