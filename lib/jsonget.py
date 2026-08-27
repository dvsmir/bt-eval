#!/usr/bin/env python3
"""Read one value out of a JSON file.

Usage: python jsonget.py <file> <dotted.path> [default]
Prints the value, or the default, or an empty line.
"""
import json
import sys

# The Windows console defaults to cp1252, and agent text often holds characters it
# cannot encode (an arrow, a dash, a box drawing character). Without this, printing a
# result string raises UnicodeEncodeError and the oracle that called us dies.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass


def main() -> int:
    if len(sys.argv) < 3:
        sys.stderr.write("usage: jsonget.py <file> <dotted.path> [default]\n")
        return 2
    path, dotted = sys.argv[1], sys.argv[2]
    default = sys.argv[3] if len(sys.argv) > 3 else ""
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            data = json.load(handle)
    except (OSError, ValueError):
        print(default)
        return 0
    node = data
    for part in dotted.split("."):
        if isinstance(node, dict) and part in node:
            node = node[part]
        else:
            print(default)
            return 0
    if isinstance(node, (dict, list)):
        print(json.dumps(node))
    elif isinstance(node, bool):
        print("true" if node else "false")
    elif node is None:
        print(default)
    else:
        print(node)
    return 0


if __name__ == "__main__":
    sys.exit(main())
