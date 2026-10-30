#!/usr/bin/env python3
"""Engine-free schema validation of world and level JSON.

Fast first gate for CI (no Godot needed). The authoritative solvability check
runs in the engine with the game's own model: tools/validate_levels.gd.

    python3 tools/validate_levels.py            # exit 1 on any error
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOKEN = re.compile(r"^(\.|#|\+|S[0-3]|[TB][0-9]+|[ILY][0-3]!?|[Gg][0-3][a-z]+|[Kk][a-z]+)$")
REQUIRED_LEVEL_KEYS = ["format_version", "id", "name", "world", "area", "grid", "objectives", "restores", "rewards"]
OPTIONAL_TYPES = {"moves_at_most", "no_leaks", "reach_bonus"}
MIN_SIZE, MAX_SIZE = 3, 7


def load(path, errors):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception as e:  # noqa: BLE001 - report any parse problem
        errors.append("%s: invalid JSON (%s)" % (os.path.relpath(path, ROOT), e))
        return None


def check_level(path, level, world, errors):
    rel = os.path.relpath(path, ROOT)
    for k in REQUIRED_LEVEL_KEYS:
        if k not in level:
            errors.append("%s: missing key '%s'" % (rel, k))
    if level.get("format_version") != 1:
        errors.append("%s: unsupported format_version %r" % (rel, level.get("format_version")))
    rows = [r.split() for r in level.get("grid", [])]
    h = len(rows)
    w = len(rows[0]) if rows else 0
    if not (MIN_SIZE <= w <= MAX_SIZE and MIN_SIZE <= h <= MAX_SIZE):
        errors.append("%s: board %dx%d outside %d..%d" % (rel, w, h, MIN_SIZE, MAX_SIZE))
    sources, targets, links, switches = 0, set(), set(), set()
    for y, row in enumerate(rows):
        if len(row) != w:
            errors.append("%s: row %d has %d tokens, expected %d" % (rel, y, len(row), w))
        for tok in row:
            if not TOKEN.match(tok):
                errors.append("%s: bad token '%s' in row %d" % (rel, tok, y))
                continue
            if tok[0] == "S":
                sources += 1
            elif tok[0] in "TB":
                if tok in targets:
                    errors.append("%s: duplicate target %s" % (rel, tok))
                targets.add(tok)
            elif tok[0] in "Gg":
                links.add(tok[2:])
            elif tok[0] in "Kk":
                if tok[1:] in switches:
                    errors.append("%s: two switches for link %s" % (rel, tok[1:]))
                switches.add(tok[1:])
    if sources == 0:
        errors.append("%s: no source" % rel)
    if not any(t.startswith("T") for t in targets):
        errors.append("%s: no required target" % rel)
    for link in links - switches:
        errors.append("%s: gate link '%s' has no switch" % (rel, link))
    for link in switches - links:
        errors.append("%s: switch '%s' controls no gate" % (rel, link))
    for o in level.get("objectives", {}).get("optional", []):
        if o.get("type") not in OPTIONAL_TYPES:
            errors.append("%s: unknown optional objective %r" % (rel, o.get("type")))
        if o.get("type") == "reach_bonus" and o.get("target") not in targets:
            errors.append("%s: bonus objective target %r not on board" % (rel, o.get("target")))
        if o.get("type") == "moves_at_most" and not isinstance(o.get("value"), int):
            errors.append("%s: moves_at_most needs an integer value" % rel)
    objects = {o["id"] for o in world.get("objects", [])}
    for r in level.get("restores", []):
        if r.get("object") not in objects:
            errors.append("%s: restores unknown object %r" % (rel, r.get("object")))
    decos = {d["id"] for d in world.get("decorations", [])}
    disc = level.get("rewards", {}).get("discovery")
    if disc and disc not in decos:
        errors.append("%s: unknown discovery %r" % (rel, disc))
    areas = {a["id"] for a in world.get("areas", [])}
    if level.get("area") not in areas:
        errors.append("%s: unknown area %r" % (rel, level.get("area")))


def main():
    errors = []
    worlds_dir = os.path.join(ROOT, "resources", "worlds")
    seen_levels = set()
    count = 0
    for wf in sorted(os.listdir(worlds_dir)):
        if not wf.endswith(".json"):
            continue
        world = load(os.path.join(worlds_dir, wf), errors)
        if world is None:
            continue
        ids = [o["id"] for o in world.get("objects", [])] + [a["id"] for a in world.get("areas", [])]
        for dup in {i for i in ids if ids.count(i) > 1}:
            errors.append("%s: duplicate id %s" % (wf, dup))
        for area in world.get("areas", []):
            for lid in area.get("levels", []):
                if lid in seen_levels:
                    errors.append("level %s listed twice" % lid)
                seen_levels.add(lid)
                path = os.path.join(ROOT, "resources", "levels", world["id"], lid + ".json")
                if not os.path.exists(path):
                    errors.append("missing level file for %s" % lid)
                    continue
                level = load(path, errors)
                if level is None:
                    continue
                if level.get("id") != lid:
                    errors.append("%s declares id %r" % (lid, level.get("id")))
                if level.get("area") != area["id"]:
                    errors.append("%s is listed in %s but declares area %r" % (lid, area["id"], level.get("area")))
                check_level(path, level, world, errors)
                count += 1
        # orphan level files
        ldir = os.path.join(ROOT, "resources", "levels", world["id"])
        for f in sorted(os.listdir(ldir)):
            if f.endswith(".json") and f[:-5] not in seen_levels:
                errors.append("orphan level file %s (not listed in any area)" % f)
    for e in errors:
        print("ERROR", e)
    print("%d levels checked, %d errors" % (count, len(errors)))
    return 1 if errors or count == 0 else 0


if __name__ == "__main__":
    sys.exit(main())
