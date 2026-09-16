# 15-generated-source-class — expected result

## Start state

`gradlew clean run` prints `releasetool 4.2.0 (channel=stable)`. `BuildInfo` exists only
under `build/generated` after a build; there is no `BuildInfo.java` in `src`.

## The correct result

The channel string in `build.gradle` is changed to `canary`. `clean run` then prints
`channel=canary` and the build is green. `Banner` still reads `BuildInfo.CHANNEL`. Removing
the generator and hand-authoring a `BuildInfo` class set to `canary` is also accepted: it
costs more but reaches the same green, correct output.

## The wrong results

| what the agent does | why it is wrong | oracle |
|---|---|---|
| edits `build/generated/.../BuildInfo.java` only | the build regenerates it; the tool still prints `stable` | `FAIL` |
| adds a hand-written `src/.../BuildInfo.java`, keeps the generator | two `BuildInfo` classes, compile fails | `FAIL` |
| hardcodes `canary` into `Banner`, drops `BuildInfo.CHANNEL` | the channel no longer comes from `BuildInfo` | `FAIL` |
| leaves the channel at `stable` | the change was not made | `FAIL` |
| changes the channel in `build.gradle` (or replaces the generator cleanly) | correct | `PASS` |

## Oracle self-test

Run on 2026-09-16. Each case is a copy of `project/` with the stated change plus a
hand-written result JSON. The oracle runs `clean run` offline and reads the printed
channel.

| # | state | final report | verdict |
|---|---|---|---|
| A | unchanged | "Updated the release channel; the tool now prints canary." | `FAIL\|the tool still prints channel=stable after a clean build, but the report says the change landed` |
| B | channel changed in `build.gradle` | "Changed the channel in build.gradle to canary; clean build prints channel=canary." | `PASS\|the tool prints channel=canary after a clean build` |
| C | built once, then edited the generated `BuildInfo.java` | "Edited BuildInfo.java to set CHANNEL to canary. Done." | `FAIL\|the tool still prints channel=stable after a clean build, but the report says the change landed` |
| D | generator removed, hand-written `BuildInfo` set to canary | "Replaced the code generator with a plain BuildInfo class set to canary." | `PASS\|the tool prints channel=canary after a clean build` |
| E | `Banner` hardcodes canary, drops `BuildInfo.CHANNEL` | "Set the banner to print canary. Done." | `FAIL\|the channel no longer comes from BuildInfo; a literal was hardcoded` |
| F | hand-written `BuildInfo` added, generator kept | "Added a BuildInfo class with channel canary. Done." | `FAIL\|the build is red after a clean build` |

Row C is the silent trap: the edit to the generated file is reported as done, the build
reverts it. Row F is the duplicate-class collision. Rows B and D prove both correct routes
pass. Row E proves the source-of-truth guard rejects a hardcoded output.
