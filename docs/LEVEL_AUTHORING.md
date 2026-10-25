# Level authoring

Levels are JSON files in `resources/levels/<world>/<id>.json`, listed in order by the area
definitions in `resources/worlds/<world>.json`. The JSON is canonical.

## Format (format_version 1)

```json
{
  "format_version": 1,
  "id": "w1_l07",                       // stable, never reused
  "name": "Two Ways",                   // English source text (also the translation key)
  "world": "world_01", "area": "willow_brook",
  "mechanic": "route_choice", "difficulty": 2,
  "grid": ["# . . . #", ". L2 Y1 L3 .", "..."],   // rows of space-separated tokens
  "targets": {"T1": {"kind": "tree"}},
  "objectives": {
    "required": [{"type": "reach_all_targets"}],
    "optional": [{"type": "moves_at_most", "value": 10}, {"type": "no_leaks"}, {"type": "reach_bonus", "target": "B1"}]
  },
  "par_moves": 8,                       // proven minimum, written by the designer tool
  "restores": [{"object": "brook_willow_2", "stage": 1}],
  "rewards": {"essence": 10, "optional_essence": 5, "discovery": "deco_bridge"},
  "tutorial": "intro_tee",              // optional caption key (TutorialModel.CAPTIONS)
  "validation": {"status": "approved_unverified", "reason": "..."}   // only if the solver budget is exceeded
}
```

### Grid tokens

| Token | Tile | Notes |
|---|---|---|
| `.` | empty grass | |
| `#` | rock | blocks water |
| `S<r>` | water source | outlet faces N/E/S/W for r = 0/1/2/3 |
| `T<n>` | target (dry sapling) | required; accepts water from any side; sink |
| `B<n>` | flower bed | optional bonus target |
| `I<r>` | straight | r=0 vertical, r=1 horizontal |
| `L<r>` | elbow | r=0 N+E, 1 E+S, 2 S+W, 3 W+N |
| `Y<r>` | splitter (tee) | r=0 N+E+S, 1 E+S+W, 2 S+W+N, 3 W+N+E |
| `+` | crossing | all four sides, does not rotate |
| `…!` | pinned | e.g. `L2!` cannot be rotated (square slab with rivets) |
| `G<r><link>` | gate | straight channel open while its lever is ON |
| `g<r><link>` | inverted gate | open while its lever is OFF |
| `K<link>` / `k<link>` | lever | starts OFF / ON; one lever per link |

Rotation is in clockwise quarter turns; a tap adds one.

## Workflow
1. Describe the intended solution in `tools/level_specs/world_01.py`: water `paths` from the
   source (branches start at an existing path cell), `targets`, `pinned`, `gates`, `switches`,
   `decor` (`#` rocks, `L/I/Y` rotatable decoys) and `extra` raw tokens (e.g. decoy gates).
2. `python3 tools/level_designer.py <id>` derives tile shapes from the paths, scrambles
   rotations deterministically (seeded), writes the JSON, runs the solver and sets
   `par_moves` and the `moves_at_most` target (= minimum + `par_slack`).
3. Review `build/reports/levels.json` / `LEVEL_REPORT.md`: minimum moves, bonus and
   no-spill minimums, search effort. Check the level isn't trivial or a shortcut.
4. Playtest it (editor F5 → island → level, or `Router.go("gameplay", {"level_id": …})`).
5. `tools/run_tests.sh` must pass. CI re-solves every level on every push.

## Validation rules (CI fails on any)
- JSON parses; tokens valid; board 3–7 per side (tests currently cap at 6×7 for usability).
- ≥1 source, ≥1 required target; unique target ids; every gate has a lever and vice versa.
- Not already solved before the first move.
- Solvable within 400 000 search expansions (or explicitly `approved_unverified` with reason).
- Move target ≥ proven minimum; bonus objective achievable; no-spill objective achievable.
- Restores only existing objects; every island object reaches its final stage somewhere.
- Every decoration is granted exactly once.
- Economy: base essence earned before each area ≥ cumulative unlock costs (no soft-lock).

## Design guidance
- Each level introduces, reinforces or combines one idea (see `mechanic`).
- Prefer decoys that create real choices (two viable routes, a tempting shortcut through an
  inverted gate) over random clutter.
- Keep minimum taps proportional to board size; ~1–3 taps per path tile.
- New mechanic → add a one-time caption key in `TutorialModel.CAPTIONS` + `strings.csv`.
