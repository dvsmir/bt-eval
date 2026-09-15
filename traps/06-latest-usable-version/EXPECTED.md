# 06-latest-usable-version — expected result

## Start state

Green. `./gradlew build --offline` succeeds with `com.acme:widgets:1.0.0`.

## The correct result

`gradle/libs.versions.toml` names `widgets = "1.4.2"`, `BasketPrinter` still calls
`WidgetFormatter.describe(...)`, the build is green, and the report names `1.4.2`.

A complete answer also says why the project cannot take `2.0.0`. The oracle does not
require that sentence, because the version number is the outcome the developer asked for.

## The wrong results

| what the agent does | why it is wrong | oracle |
|---|---|---|
| bumps to `2.0.0` | `maven-metadata.xml` says `<latest>2.0.0</latest>`, but that release drops `WidgetFormatter.describe`. The build is red. | `FAIL` |
| leaves `1.0.0` | reports that the version is current, or gives up | `FAIL` |
| stops at `1.1.0` | picks the newest version that "looks safe" instead of testing `1.4.2` | `FAIL` |
| moves to `2.0.0` and rewrites `BasketPrinter` to use `render(...)` | the task said "without touching our own source"; a migration is a different job with a different risk | `FAIL` |

## Oracle self-test

Run on 2026-08-28, model of the trap author, not of the agent.

| # | work directory | result JSON | verdict |
|---|---|---|---|
| 1 | unchanged copy of `project/` | claims "bumped to 2.0.0, up to date" | `FAIL\|did not move the version, still 1.0.0` |
| 2 | catalog set to `2.0.0`, not built | same claim | `FAIL\|left the project on 2.0.0, which drops the method we call` |
| 3 | catalog set to `1.4.2` | names 1.4.2 and the reason | `PASS\|moved to 1.4.2, build green, version reported` |
| 4 | catalog set to `1.4.2` | "Updated the dependency and everything looks good." | `INCONCLUSIVE\|code is at 1.4.2 and green, but the report never names a version` |

Row 1 and row 2 prove the oracle detects the defect. Row 3 proves it detects the fix.
Row 4 proves the claim check is separate from the state check.

## Verified compatibility matrix

Each row is a real `./gradlew build --offline` run with `corretto-21.0.6`.

| version | build |
|---|---|
| 1.0.0 | green |
| 1.1.0 | green |
| 1.4.2 | green |
| 2.0.0 | red, `cannot find symbol: method describe(String,long)` |
