# LUMA: Restore the Wild

*Restore a forgotten world, one satisfying puzzle at a time.*

A premium, accessible mobile puzzle game for iOS and Android by **SCYDE**. Rotate ancient
stone channels to guide water from a spring to dry saplings. Every solved puzzle visibly
restores a small isometric island: trees grow, ponds fill, waterfalls return and wildlife
comes back.

| | |
|---|---|
| Engine | Godot 4.7.2 (GDScript, GL Compatibility renderer) |
| Platforms | iPhone, iPad, Android phones and tablets (portrait) |
| Content | 1 world (Verdant Isle), 6 areas, 30 hand-designed levels, all proven solvable by the solver |
| Mechanics | rotating channels, elbows, splitters (tees), crossings, fixed stones, levers + gates, inverted gates, optional flower beds |
| Systems | tutorial (resumable), island restoration, essence + area unlocks, discoveries, achievements, settings, local analytics, versioned save |
| Network | none required; no accounts; no ads or purchases in this version |

Screenshots from real engine runs are produced by the nightly workflow (`Nightly` → artefact
`screenshots-*`) or locally with the screenshot tour (below).

## Quick start

```bash
# 1. Install Godot 4.7.2 (or let the script fetch and checksum-verify it)
tools/ci/install_godot.sh linux          # prints GODOT=/path/to/godot
export GODOT=/path/to/godot

# 2. Run every test, the content validators and the level solver
tools/run_tests.sh

# 3. Play in the editor or run directly
$GODOT --path .                          # editor: press F5
$GODOT --path . --resolution 720x1280    # run the game window
```

Mouse clicks work like taps when running on desktop.

## Repository layout

```
scenes/        thin .tscn roots for each screen (boot, menus, gameplay, island)
scripts/
  puzzle/      Dir, TileTypes, PuzzleTile, PuzzleBoard, LevelData, PuzzleValidator, PuzzleSolver,
               BoardView/TileView (rendering + input)
  water/       WaterSimulation (deterministic BFS) + WaterResult
  restoration/ IslandView (isometric island renderer + area picking)
  progression/ ProgressionModel (idempotent rewards, unlocks, achievements)
  save/        SaveStore (versioned atomic save, backup, recovery, migration)
  core/        Game, Router, ContentDB, TutorialModel
  ui/          screens, theme, procedural Painter, widgets
  audio/ analytics/ platform/
resources/     levels (JSON), world definition, achievements, localization CSV
assets/        generated audio, icons, Nunito font (+ ASSET_MANIFEST.json provenance)
tests/         unit, puzzles, saves, content_validation, integration (+ headless runner)
tools/         validators, level designer, generators, CI scripts, screenshot tour
docs/          design, architecture, QA, release runbook, roadmap, status
```

## Testing

`tools/run_tests.sh` imports the project, runs all tests headlessly
(`tests/run_tests.tscn`, JUnit at `build/reports/junit.xml`) and re-solves every level
(`tools/validate_levels.gd`, report at `build/reports/levels.json`). A test fails on any
failed assertion **or** any engine/script error logged while it runs.

Engine-free checks used first in CI:

```bash
python3 tools/check_repo_hygiene.py   # no build outputs / credentials / secrets tracked
python3 tools/validate_levels.py      # level JSON schema and references
python3 tools/validate_assets.py      # res:// references, provenance manifest, icon sizes, audio format
```

Visual QA from real renders (needs a display; Xvfb + Mesa works headless):

```bash
xvfb-run -a -s "-screen 0 1280x1400x24" $GODOT --path . --resolution 720x1280 \
  --rendering-driver opengl3 --audio-driver Dummy res://tools/screenshot_tour.tscn -- --save-path=user://tour.json
# -> build/screenshots/*.png
```

## Building

| Output | How | Credentials |
|---|---|---|
| Android debug APK | `Android build` workflow (pushes to main, develop, release/*, ci/*) | none (ephemeral debug key) |
| Android release APK + AAB | same workflow | `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` |
| iOS Xcode project, simulator build, unsigned archive | `iOS build` workflow | none |
| iOS signed IPA | same workflow | `IOS_CERTIFICATE_P12_BASE64`, `IOS_CERTIFICATE_PASSWORD`, `IOS_PROVISIONING_PROFILE_BASE64`, `APPLE_TEAM_ID` |
| TestFlight upload | `Release` workflow, manual, opt-in | `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_BASE64` |
| Draft GitHub Release | push tag `vX.Y.Z` matching `project.godot` version | none (draft only) |

Local export (after installing templates with `tools/ci/install_godot.sh linux --templates`):

```bash
GODOT_ANDROID_KEYSTORE_DEBUG_PATH=~/debug.keystore GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey \
GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android $GODOT --headless --path . --export-debug "Android" build/android/luma-debug.apk
```

Full signing and release instructions: [`docs/RELEASE_RUNBOOK.md`](docs/RELEASE_RUNBOOK.md).

## Documentation

- [Current status](docs/CURRENT_STATUS.md) — what works, what was verified, what is next
- [Master plan](docs/MASTER_PLAN.md) · [Game design](docs/GAME_DESIGN_DOCUMENT.md) · [Art direction](docs/ART_DIRECTION.md)
- [Technical architecture](docs/TECHNICAL_ARCHITECTURE.md) · [Level authoring](docs/LEVEL_AUTHORING.md) · [QA strategy](docs/QA_STRATEGY.md)
- [Release runbook](docs/RELEASE_RUNBOOK.md) · [Privacy & compliance](docs/PRIVACY_AND_COMPLIANCE.md) · [Store metadata draft](docs/STORE_METADATA.md)
- [Analytics plan](docs/ANALYTICS_PLAN.md) · [Monetization plan](docs/MONETIZATION_PLAN.md) · [Playtest kit](docs/PLAYTEST_KIT.md)
- [Franchise roadmap](docs/FRANCHISE_ROADMAP.md) · [Decision log](docs/DECISION_LOG.md) · [Changelog](CHANGELOG.md)

## Licence

Game code, art, audio and design © SCYDE, all rights reserved (see `LICENSE`).
Nunito font: SIL Open Font License 1.1 (`assets/fonts/OFL-Nunito.txt`).
