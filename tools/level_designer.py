#!/usr/bin/env python3
"""Authoring aid for LUMA levels.

A designer describes the *intended solution* of a level (water paths from the
source, targets, pinned stones, gates) plus decor; this tool derives each
tile's shape, scrambles rotations deterministically, writes the canonical JSON
level files, then runs the real solver (tools/validate_levels.gd) and sets the
move target from the proven minimum.

The JSON files in resources/levels are the canonical content. This tool and
tools/level_specs/*.py are kept so every shipped level is reproducible and
reviewable. Nothing here runs at game runtime, and nothing ships unvalidated:
CI re-solves every level on every push.

    python3 tools/level_designer.py            # regenerate all world_01 levels
    python3 tools/level_designer.py w1_l07     # regenerate one level
"""
import importlib.util
import json
import os
import random
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
N, E, S, W = 1, 2, 4, 8
DIRS = {N: (0, -1), E: (1, 0), S: (0, 1), W: (-1, 0)}
BASE = {"I": N | S, "L": N | E, "Y": N | E | S, "+": 15}


def rot(mask, r):
    for _ in range(r % 4):
        mask = ((mask << 1) | (mask >> 3)) & 15
    return mask


def shape_for(mask):
    """mask -> (letter, rotation) with the canonical lowest rotation."""
    n = bin(mask).count("1")
    if n == 4:
        return "+", 0
    for letter in ("I", "L", "Y"):
        for r in range(4):
            if rot(BASE[letter], r) == mask:
                return letter, r
    raise ValueError("unsupported connection mask %d" % mask)


def dir_between(a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    for d, off in DIRS.items():
        if off == (dx, dy):
            return d
    raise ValueError("cells %s and %s are not adjacent" % (a, b))


def cells(spec_str):
    out = []
    for tok in spec_str.split():
        x, y = tok.split(",")
        out.append((int(x), int(y)))
    return out


def build(spec):
    w, h = spec["size"]
    rng = random.Random(spec.get("seed", hash(spec["id"]) & 0xFFFF))
    conn = {}
    src = cells(spec["source"])[0]
    for path in spec["paths"]:
        pts = cells(path)
        for a, b in zip(pts, pts[1:]):
            conn[a] = conn.get(a, 0) | dir_between(a, b)
            conn[b] = conn.get(b, 0) | dir_between(b, a)
    targets = {tuple(map(int, k.split(","))): v for k, v in spec.get("targets", {}).items()}
    pinned = set(cells(spec.get("pinned", "")))
    keep = set(cells(spec.get("keep", "")))
    init = {tuple(map(int, k.split(","))): v for k, v in spec.get("init", {}).items()}
    gates = {tuple(map(int, k.split(","))): v for k, v in spec.get("gates", {}).items()}
    switches = {tuple(map(int, k.split(","))): v for k, v in spec.get("switches", {}).items()}
    extra = {tuple(map(int, k.split(","))): v for k, v in spec.get("extra", {}).items()}
    decor = spec.get("decor", ["." * w] * h)
    assert len(decor) == h and all(len(r) == w for r in decor), spec["id"] + ": decor size"
    grid = [["." for _ in range(w)] for _ in range(h)]
    for y in range(h):
        for x in range(w):
            p = (x, y)
            if p in targets:
                grid[y][x] = targets[p]
                continue
            if p in extra:
                assert p not in conn, spec["id"] + ": extra token on a solution path"
                grid[y][x] = extra[p]
                continue
            if p in switches:
                grid[y][x] = ("k" if switches[p].endswith("+") else "K") + switches[p].rstrip("+")
                continue
            if p == src:
                m = conn[p]
                assert bin(m).count("1") == 1, spec["id"] + ": source needs one outlet"
                grid[y][x] = "S%d" % {N: 0, E: 1, S: 2, W: 3}[m]
                continue
            if p in conn:
                letter, r = shape_for(conn[p])
                if p in gates:
                    assert letter == "I", spec["id"] + ": gates must sit on straight runs"
                    link = gates[p]
                    grid[y][x] = ("g" if link.startswith("!") else "G") + str(r) + link.lstrip("!")
                    continue
                if letter == "+":
                    grid[y][x] = "+"
                    continue
                if p in pinned:
                    grid[y][x] = "%s%d!" % (letter, r)
                    continue
                if p in init:
                    r0 = init[p]
                elif p in keep:
                    r0 = r
                else:
                    sol_mask = rot(BASE[letter], r)
                    options = [k for k in range(4) if rot(BASE[letter], k) != sol_mask]
                    if letter == "I":
                        options = [(r + 1) % 2]
                    r0 = rng.choice(options)
                grid[y][x] = "%s%d" % (letter, r0)
                continue
            c = decor[y][x]
            if c == ".":
                grid[y][x] = "."
            elif c == "#":
                grid[y][x] = "#"
            elif c in "LIY":
                grid[y][x] = "%s%d" % (c, rng.randrange(4) if c != "I" else rng.randrange(2))
            elif c in "liy":
                grid[y][x] = "%s%d!" % (c.upper(), rng.randrange(4))
            elif c == "+":
                grid[y][x] = "+"
            else:
                raise ValueError("%s: unknown decor char %r" % (spec["id"], c))
    level = {
        "format_version": 1,
        "id": spec["id"],
        "name": spec["name"],
        "world": "world_01",
        "area": spec["area"],
        "mechanic": spec["mechanic"],
        "difficulty": spec.get("difficulty", 1),
        "grid": [" ".join(row) for row in grid],
        "targets": spec.get("target_meta", {v: {"kind": "tree" if v.startswith("T") else "flowers"} for v in targets.values()}),
        "objectives": {"required": [{"type": "reach_all_targets"}], "optional": spec.get("optional", [])},
        "par_moves": 0,
        "restores": spec.get("restores", []),
        "rewards": {"essence": 10, "optional_essence": 5},
    }
    if spec.get("discovery"):
        level["rewards"]["discovery"] = spec["discovery"]
    if spec.get("tutorial"):
        level["tutorial"] = spec["tutorial"]
    return level


def level_path(level):
    return os.path.join(ROOT, "resources", "levels", level["world"], level["id"] + ".json")


def write(level):
    with open(level_path(level), "w") as f:
        json.dump(level, f, indent=2)
        f.write("\n")


def run_validator():
    godot = os.environ.get("GODOT", "godot")
    report = os.path.join(ROOT, "build", "reports", "levels.json")
    res = subprocess.run([godot, "--headless", "--path", ROOT, "--script", "res://tools/validate_levels.gd"],
                         capture_output=True, text=True)
    print(res.stdout[-6000:])
    with open(report) as f:
        return json.load(f)


def main():
    spec_file = os.path.join(ROOT, "tools", "level_specs", "world_01.py")
    mod_spec = importlib.util.spec_from_file_location("world_01", spec_file)
    mod = importlib.util.module_from_spec(mod_spec)
    mod_spec.loader.exec_module(mod)
    only = set(sys.argv[1:])
    specs = [s for s in mod.LEVELS if not only or s["id"] in only]
    built = {}
    for s in specs:
        lvl = build(s)
        built[s["id"]] = (s, lvl)
        write(lvl)
    report = run_validator()
    by_id = {l["id"]: l for l in report["levels"]}
    for lid, (s, lvl) in built.items():
        info = by_id.get(lid)
        if not info or info["min_moves"] is None:
            print("!! %s unsolved; left without move target" % lid)
            continue
        mn = int(info["min_moves"])
        lvl["par_moves"] = mn
        opts = []
        for o in lvl["objectives"]["optional"]:
            if o["type"] == "moves_at_most":
                o = dict(o)
                o["value"] = mn + int(s.get("par_slack", 2))
            opts.append(o)
        lvl["objectives"]["optional"] = opts
        write(lvl)
    run_validator()


if __name__ == "__main__":
    main()
