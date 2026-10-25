#!/usr/bin/env python3
"""Turns build/reports/levels.json (from tools/validate_levels.gd) into a
Markdown report, and appends it to the GitHub job summary when available.

    python3 tools/generate_level_report.py [build/reports/levels.json]
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "build", "reports", "levels.json")
    with open(src) as f:
        rep = json.load(f)
    lines = [
        "# Level validation report",
        "",
        "Engine: %s · generated %s" % (rep.get("engine", "?"), rep.get("generated_at", "?")),
        "",
        "**%d levels · %d errors · %d warnings**" % (rep["level_count"], len(rep["errors"]), len(rep["warnings"])),
        "",
        "| Level | Name | Size | Mechanic | Min moves | Move target | Bonus min | No-spill min | Search nodes | Status |",
        "|---|---|---|---|---|---|---|---|---|---|",
    ]
    for l in rep["levels"]:
        def fmt(v):
            return "–" if v is None else str(v)
        lines.append("| %s | %s | %dx%d | %s | %s | %s | %s | %s | %s | %s |" % (
            l["id"], l["name"], l["width"], l["height"], l["mechanic"], fmt(l["min_moves"]),
            fmt(l["par"] or None), fmt(l["bonus_min"]), fmt(l["no_leaks_min"]), l["expansions"], l["status"]))
    if rep["errors"]:
        lines += ["", "## Errors", ""] + ["- " + e for e in rep["errors"]]
    if rep["warnings"]:
        lines += ["", "## Warnings", ""] + ["- " + w for w in rep["warnings"]]
    text = "\n".join(lines) + "\n"
    out = os.path.join(os.path.dirname(src), "LEVEL_REPORT.md")
    with open(out, "w") as f:
        f.write(text)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as f:
            f.write(text)
    print("wrote", os.path.relpath(out, ROOT))
    return 1 if rep["errors"] else 0


if __name__ == "__main__":
    sys.exit(main())
