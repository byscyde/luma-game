# QA strategy

## Gates
Every push runs `CI` (static checks → Godot tests + solver → exported-build smoke test).
A red CI blocks merging. Nothing reports success when a required step failed: the test runner
exits non-zero on any failure or engine error, and the smoke test greps for an explicit PASS.

## Automated coverage

| Area | Tests |
|---|---|
| Tile connectivity, rotation, pinning, gates/levers, snapshots | `tests/unit/test_tiles.gd` |
| Water propagation, leaks by reason, branching, cycles, bonus, sinks, determinism | `tests/unit/test_water_simulation.gd` |
| Solver optimality, impossibility, budget → unverified, switches, goals (bonus / sealed), hints | `tests/puzzles/test_solver.gd` |
| Save round trip, backup, corrupt/empty/truncated files, non-save JSON, defaults merge, repairs, newer version, migration | `tests/saves/test_save_store.gd` |
| Rewards idempotency, optional objectives, restoration forward-only, locked levels, discoveries, area unlock rules, essence never negative, full no-soft-lock playthrough, achievements, tutorial model | `tests/unit/test_progression.gd` |
| Every level valid, not pre-solved, solvable, par = proven minimum, replays; board sizes; onboarding order; translations | `tests/content_validation/test_levels.gd` |
| Every script compiles; every scene loads | `tests/unit/test_scripts_compile.gd` |
| Real scenes through real input: tutorial L1 → result → island; non-interactive taps; undo/reset; hints; objectives; locked level redirect; interrupted level resumes after app pause + cold reload; restart persistence; island restoration sequence; area unlock; every screen opens/closes; boot routing; settings persist; reset requires confirmation; analytics whitelist/opt-out | `tests/integration/test_gameplay_flow.gd` |
| Exported package contains and loads all content | CI `export-smoke` (`--smoke-test`) |
| APK: signature, package id, version code, no test/tool files, only VIBRATE + INTERNET permissions | `android-build.yml` |
| iOS: Xcode project, bundle id, simulator build, device archive | `ios-build.yml` |
| Visual: real renders of every screen at 720×1280, 640×1136, 1536×2048 | `nightly-tests.yml` (screenshot tour) |

## Visual QA checklist (per screenshot set)
Text clipping · safe-area overlap · tile rotations match logic · water only in connected
channels · restoration states correct · touch targets ≥ 84 px at 720 width (≈ 44 pt) ·
locked/disabled states readable · no overlapping UI.

Findings already fixed from tours: buttons rendered with engine default theme; settings title
wrapping vertically; objective chips overflowing on 3-objective levels; menu island
overlapping subtitle; badge positions; an infinite loop when the island drew before layout.

## Not yet verified (requires hardware or accounts)
- Real-device performance, memory, thermal, battery. **No frame rate is claimed.**
  Targets to measure: 60 FPS gameplay on mid-range 2021+ devices; island ≥ 30 FPS.
- Touch feel, haptics strength, audio interruption (calls, other apps), notch/home-indicator
  layouts on physical devices, iPad multitasking.
- Signed installs from TestFlight / Play internal testing.

## Manual playtest protocol
See `docs/PLAYTEST_KIT.md` (session script, observation sheet, feedback form, retention
definitions).

## Bug triage
P0 crash/data loss/progress loss → fix before anything else · P1 blocks progression or
misleading UI · P2 visual/animation defects · P3 polish. Every fixed P0/P1 gets a regression
test.
