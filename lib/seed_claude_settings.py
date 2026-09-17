#!/usr/bin/env python
"""Write a minimal Claude settings.json for an isolated eval run.

Copy only the keys the agent needs to reach the same API as the host: apiKeyHelper,
env, and effortLevel. Everything else is dropped on purpose, so the agent under test
carries no plugins, personal skills, permissions, or model default from the host.

Usage: seed_claude_settings.py <src settings.json> <dst settings.json>
"""
import json
import sys

KEEP = ("apiKeyHelper", "env", "effortLevel")


def main():
    src = sys.argv[1]
    dst = sys.argv[2]
    out = {}
    try:
        with open(src, encoding="utf-8") as f:
            data = json.load(f)
        for k in KEEP:
            if k in data:
                out[k] = data[k]
    except (FileNotFoundError, ValueError, OSError):
        pass
    with open(dst, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=2)


if __name__ == "__main__":
    main()
