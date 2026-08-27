#!/usr/bin/env python3
"""Append one measured run to the results CSV.

Usage:
  append_row.py <csv> <result.json> <trap> <run> <verdict> <detail> <model> <wall_s> <ts>

The script creates the header when the file does not exist. It also computes
total_tokens, because the token target of the Order needs one comparable number.
"""
import csv
import json
import os
import sys

FIELDS = [
    "trap", "run", "verdict", "detail", "is_error", "stop_reason", "num_turns",
    "duration_ms", "input_tokens", "output_tokens", "cache_read", "cache_creation",
    "total_tokens", "billable_tokens", "cost_usd", "model", "wall_s", "ts",
]


def main() -> int:
    if len(sys.argv) < 10:
        sys.stderr.write("append_row.py: wrong number of arguments\n")
        return 2
    csv_path, json_path = sys.argv[1], sys.argv[2]
    trap, run_no, verdict, detail = sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6]
    model, wall_s, stamp = sys.argv[7], sys.argv[8], sys.argv[9]

    data = {}
    try:
        with open(json_path, encoding="utf-8", errors="replace") as handle:
            data = json.load(handle)
    except (OSError, ValueError):
        pass
    if not isinstance(data, dict):
        data = {}

    usage = data.get("usage") or {}
    if not isinstance(usage, dict):
        usage = {}

    def num(key: str) -> int:
        value = usage.get(key, 0)
        return value if isinstance(value, int) else 0

    inp, out = num("input_tokens"), num("output_tokens")
    creation = num("cache_creation_input_tokens")
    read = num("cache_read_input_tokens")

    row = {
        "trap": trap,
        "run": run_no,
        "verdict": verdict,
        "detail": detail,
        "is_error": data.get("is_error", ""),
        "stop_reason": data.get("stop_reason", ""),
        "num_turns": data.get("num_turns", ""),
        "duration_ms": data.get("duration_ms", ""),
        "input_tokens": inp,
        "output_tokens": out,
        "cache_read": read,
        "cache_creation": creation,
        # Everything the model processed. Use this for a like-for-like comparison.
        "total_tokens": inp + out + read + creation,
        # Cache reads are much cheaper. This number tracks cost more closely.
        "billable_tokens": inp + out + creation,
        "cost_usd": data.get("total_cost_usd", ""),
        "model": model,
        "wall_s": wall_s,
        "ts": stamp,
    }

    exists = os.path.exists(csv_path) and os.path.getsize(csv_path) > 0
    with open(csv_path, "a", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS)
        if not exists:
            writer.writeheader()
        writer.writerow(row)
    return 0


if __name__ == "__main__":
    sys.exit(main())
