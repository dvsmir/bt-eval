#!/usr/bin/env python3
"""Summarize a results CSV.

Usage: python summarize.py <results.csv> [<baseline.csv>]

With one file it reports the pass rate and the token cost of each trap.
With two files it reports the change from the baseline to the new run, which is
the number the Order needs.

The report gives the median, not the mean. Token counts have a long tail, and one
run that goes in circles moves a mean a long way.
"""
import csv
import statistics
import sys

TOKEN_COLS = ("total_tokens", "billable_tokens")
CAL = "_calibration"


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


def overhead(groups):
    """The fixed harness cost, from a calibration row if one exists."""
    if CAL not in groups:
        return 0
    return med(groups[CAL], "billable_tokens")


def report(path):
    rows = load(path)
    groups = group(rows)
    fixed = overhead(groups)

    print(f"\nFile: {path}")
    print(f"Runs: {len([r for r in rows if r.get('trap') != CAL])}")
    if fixed:
        print(f"Fixed harness overhead (calibrated): {fixed:,} billable tokens per run")
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


def compare(path_a, path_b):
    groups_a, fixed_a = report(path_a)
    groups_b, fixed_b = report(path_b)
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


def main() -> int:
    if len(sys.argv) < 2:
        sys.stderr.write("usage: summarize.py <results.csv> [<baseline.csv>]\n")
        return 2
    if len(sys.argv) >= 3:
        compare(sys.argv[1], sys.argv[2])
    else:
        report(sys.argv[1])
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
