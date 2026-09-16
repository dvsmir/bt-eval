#!/usr/bin/env python3
"""Summarize a results CSV.

Usage: python summarize.py <results.csv> [<baseline.csv>] [--calibration <cal.csv>]

With one file it reports the pass rate and the token cost of each trap.
With two files it reports the change from the baseline to the new run, which is
the number the Order needs.

The report gives the median, not the mean. Token counts have a long tail, and one
run that goes in circles moves a mean a long way.

Calibration. The fixed harness overhead (the system prompt and tool definitions that
every headless run pays before it touches the task) is measured by run.sh --calibrate.
That row is stored two ways, and this script reads whichever it finds, in order:

  1. an explicit --calibration <file> on the command line,
  2. a _calibration row inside the results file itself,
  3. a calibration.csv found by walking up from the results file (the runner writes
     results/calibration.csv).

The calibration is matched by model, and the most recent one wins. So you calibrate once
and every later run subtracts it, without having to force both into the same CSV.
"""
import csv
import os
import statistics
import sys

TOKEN_COLS = ("total_tokens", "billable_tokens")
CAL = "_calibration"
CAL_FILENAME = "calibration.csv"


def load(path):
    with open(path, newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def to_int(value):
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return 0


def group(rows):
    out = {}
    for row in rows:
        out.setdefault(row.get("trap", "?"), []).append(row)
    return out


def med(rows, col):
    values = [to_int(r.get(col)) for r in rows if to_int(r.get(col)) > 0]
    return int(statistics.median(values)) if values else 0


def spread(rows, col):
    values = [to_int(r.get(col)) for r in rows if to_int(r.get(col)) > 0]
    if len(values) < 2:
        return 0
    return int(max(values) - min(values))


def calibration_rows(rows):
    return [r for r in rows if r.get("trap") == CAL]


def discover_calibration(results_path):
    """Walk up from the results file looking for a calibration.csv."""
    start = os.path.dirname(os.path.abspath(results_path))
    seen = set()
    directory = start
    for _ in range(8):
        if directory in seen:
            break
        seen.add(directory)
        candidate = os.path.join(directory, CAL_FILENAME)
        if os.path.isfile(candidate):
            return candidate
        parent = os.path.dirname(directory)
        if parent == directory:
            break
        directory = parent
    return None


def pick_overhead(cal_rows, models):
    """Fixed overhead from calibration rows: match the model, take the most recent."""
    if not cal_rows:
        return 0
    matching = [r for r in cal_rows if r.get("model") in models] if models else []
    use = matching or cal_rows
    latest_ts = max((r.get("ts", "") for r in use), default="")
    newest = [r for r in use if r.get("ts", "") == latest_ts] or use
    return med(newest, "billable_tokens")


def resolve_overhead(path, rows, explicit_cal):
    """Return (fixed_tokens, source_label). See the module docstring for the order."""
    models = {r.get("model") for r in rows
              if r.get("trap") != CAL and r.get("model")}

    if explicit_cal:
        fixed = pick_overhead(calibration_rows(load(explicit_cal)), models)
        if fixed:
            return fixed, f"from {explicit_cal}"

    infile = calibration_rows(rows)
    if infile:
        fixed = pick_overhead(infile, models)
        if fixed:
            return fixed, "in-file row"

    found = discover_calibration(path)
    if found:
        fixed = pick_overhead(calibration_rows(load(found)), models)
        if fixed:
            try:
                label = os.path.relpath(found)
            except ValueError:
                label = found
            return fixed, f"from {label}"

    return 0, None


def report(path, explicit_cal=None):
    rows = load(path)
    groups = group(rows)
    fixed, source = resolve_overhead(path, rows, explicit_cal)

    print(f"\nFile: {path}")
    print(f"Runs: {len([r for r in rows if r.get('trap') != CAL])}")
    if fixed:
        print(f"Fixed harness overhead (calibrated, {source}): "
              f"{fixed:,} billable tokens per run")
    else:
        print("Fixed harness overhead: NOT calibrated. Run ./run.sh --calibrate.")
        print("  Without it, the token numbers below include the system prompt cost")
        print("  and they understate any real saving on the task itself.")

    header = (f"\n{'trap':<28} {'n':>3} {'pass':>5} {'fail':>5} {'inc':>4} "
              f"{'med total':>10} {'med task':>9} {'spread':>8} {'med turns':>9}")
    print(header)
    print("-" * len(header))

    for trap in sorted(groups):
        if trap == CAL:
            continue
        rows_t = groups[trap]
        n = len(rows_t)
        passed = sum(1 for r in rows_t if r.get("verdict") == "PASS")
        failed = sum(1 for r in rows_t if r.get("verdict") == "FAIL")
        inc = sum(1 for r in rows_t if r.get("verdict") == "INCONCLUSIVE")
        total = med(rows_t, "billable_tokens")
        # Print a dash, not a zero, when there is no calibration row. A zero in this
        # column reads as "the task itself cost nothing", which is the opposite of
        # what an uncalibrated run means.
        task = f"{max(total - fixed, 0):,}" if fixed else "--"
        print(f"{trap:<28} {n:>3} {passed:>5} {failed:>5} {inc:>4} "
              f"{total:>10,} {task:>9} {spread(rows_t,'billable_tokens'):>8,} "
              f"{med(rows_t,'num_turns'):>9}")

    print("\nVerdict detail, most common per trap:")
    for trap in sorted(groups):
        if trap == CAL:
            continue
        counts = {}
        for row in groups[trap]:
            key = f"{row.get('verdict')}: {row.get('detail')}"
            counts[key] = counts.get(key, 0) + 1
        for key, count in sorted(counts.items(), key=lambda kv: -kv[1])[:3]:
            print(f"  {trap:<28} {count:>2}x  {key}")

    inconclusive = sum(1 for r in rows if r.get("verdict") == "INCONCLUSIVE"
                       and r.get("trap") != CAL)
    if inconclusive:
        print(f"\nWARNING: {inconclusive} run(s) are INCONCLUSIVE. Fix the oracle "
              f"before you quote a pass rate.")
    return groups, fixed


def compare(path_a, path_b, explicit_cal=None):
    groups_a, fixed_a = report(path_a, explicit_cal)
    groups_b, fixed_b = report(path_b, explicit_cal)
    fixed = fixed_a or fixed_b

    header = (f"\n{'trap':<28} {'base task':>10} {'new task':>9} {'change':>8} "
              f"{'base pass':>10} {'new pass':>9}")
    print("\n=== Change from baseline to new run ===")
    print(header)
    print("-" * len(header))
    for trap in sorted(set(groups_a) | set(groups_b)):
        if trap == CAL:
            continue
        ra, rb = groups_a.get(trap, []), groups_b.get(trap, [])
        if not ra or not rb:
            print(f"{trap:<28} {'(only in one file)':>40}")
            continue
        ta = max(med(ra, "billable_tokens") - fixed, 0)
        tb = max(med(rb, "billable_tokens") - fixed, 0)
        change = f"{((tb - ta) / ta * 100):+.0f}%" if ta else "n/a"
        pa = f"{sum(1 for r in ra if r.get('verdict')=='PASS')}/{len(ra)}"
        pb = f"{sum(1 for r in rb if r.get('verdict')=='PASS')}/{len(rb)}"
        print(f"{trap:<28} {ta:>10,} {tb:>9,} {change:>8} {pa:>10} {pb:>9}")
    if not fixed:
        print("\nNOTE: no calibration row. The change above is diluted by the fixed")
        print("harness overhead. Calibrate both runs before you publish a figure.")


def main():
    args = [a for a in sys.argv[1:]]
    explicit_cal = None
    if "--calibration" in args:
        i = args.index("--calibration")
        try:
            explicit_cal = args[i + 1]
        except IndexError:
            sys.stderr.write("summarize.py: --calibration needs a file path\n")
            return 2
        del args[i:i + 2]

    if len(args) < 1:
        sys.stderr.write(
            "usage: summarize.py <results.csv> [<baseline.csv>] "
            "[--calibration <cal.csv>]\n")
        return 2
    if len(args) >= 2:
        compare(args[0], args[1], explicit_cal)
    else:
        report(args[0], explicit_cal)
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
