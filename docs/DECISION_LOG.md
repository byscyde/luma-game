# Decision log

Newest first. Each entry: context → decision → consequences.

### D-020 · Archipelago: five more islands, each a puzzle game + a merge location (2026-10-27)
Owner chose: every island has its own puzzle game **and** its own merge location, with the
Lantern Café as hub (café tasks unlock islands; finishing an island opens the next café
chapter). Order: Ember Reef (sliding rows/columns), Lantern Bay (mirrors & light), Stone Steps
(Sokoban), Rope Isles (bridges), Moon Grove (match-3). Registry `resources/islands/islands.json`;
progress `save["islands"]`. Ember Reef reuses the shared `WaterSimulation` on a framed board so
there is still one connectivity model. Its hint follows a solution plan (inverse of off-plan
moves + stored solution) instead of a search, so it is instant on phones. Plan:
`docs/ISLANDS_PLAN.md`.

### D-019 · Merge-2 mode "LUMA Harbour" after level 30 (2026-10-27)
Owner asked for Gossip Harbor's mechanics, progression and look after the 30 puzzle levels.
Mechanics/genre conventions are followed closely (energy, generators, merging, crates,
bubbles, scissors, chests, orders, XP levels, coins/gems, storage, sell with undo, renovation
tasks with story scenes and free-switchable designs); Microfun's characters, story, setting,
names and artwork are **not** copied — original cast/mystery and procedural icons
(`ItemArt`). Rules are a pure `MergeGame` on `save["merge"]` with wall-clock energy; content
in `resources/merge/*.json`. Real-money purchases, ads and online live-ops are excluded until
the owner decides (offline app, no INTERNET permission). Full plan: `docs/MERGE_DESIGN.md`.

### D-018 · 2D puzzle board; iosgame-style loading screen (2026-10-26)
Owner rejected the 3D low-poly board ("worst look ever"). The board is now drawn crisp and
top-down in 2D (`BoardView` tray + `TileView` per tile): dark teal tray with recessed slots,
raised ivory discs with notches (rotatable), riveted square slabs (fixed), carved slate
grooves with flowing water glints, water bridges across connected gaps, wooden sluice
gates and toggle levers tagged by link colour **and** shape, saplings that leaf out. It is
also far cheaper than the 3D SubViewport (120 Hz budget). Supersedes the board part of
D-015/D-017; the island stays 3D.
Loading screen follows the owner's iosgame project: key art rendered from the real 3D
island (`tools/render_key_art.gd`, graded by `tools/paint_key_art.py`), Ken Burns drift and
cross-dissolve, chapter captions (numeral between gold rules, name, line, pips), rising
fireflies, title at the top, status + percent + bar with a glowing head, rotating tips.

### D-017 · Dark mode, brand assets, 120 Hz, redesigned board (2026-10-26)
- **Theme**: Settings → Appearance (System / Light / Dark, default System). UI design-system
  colours in `Palette` are static and swapped by `Palette.apply()`; `Game.refresh_theme()`
  follows the device (system theme callback + app focus/resume) and rebuilds the current
  screen. The 3D island and board stay daylight dioramas in both modes.
- **Brand**: owner-supplied app icon art and SCYDE logo live in `art/source` (not shipped);
  `tools/build_brand_assets.py` builds the icon set, the boot splash (SCYDE wordmark redrawn
  at high resolution with Inter Display ExtraBold, since the supplied logo is 98×49 px) and
  the loading key art. Boot: native splash → identical in-game SCYDE logo → loading screen
  with threaded scene load. Credits say "Developer: SCYDE".
- **120 Hz**: vsync follows the display; iOS gets `CADisableMinimumFrameDurationOnPhone` so
  ProMotion iPhones can run at 120 Hz; 2× MSAA and a 2048 shadow map on phones; only
  animated island props process per frame. Settings → "Show FPS counter" to verify on device.
- **Board**: checkered lawn under every cell, round cream discs with four notches (whole
  disc turns), grey slabs with rivets for fixed tiles, slate grooves with bright water;
  gameplay dock with icon-over-label Undo / Reset / Hint.

### D-016 · Unsigned iOS builds are published as GitHub pre-releases (2026-10-26)
The owner asked that the iOS `.ipa` always end up under the repository's Releases page, so
they can fetch it on the phone and re-sign it with Feather. Every successful direct run of
`ios-build.yml` now creates a pre-release `ios-build-<run>` (not marked latest) with the
unsigned IPA and its SHA-256. This is an owner-authorized exception to D-013 for unsigned
test builds only: version releases from `release.yml` stay drafts, and store submission is
still never automated. If the repository is public, these pre-releases are public too.

### D-015 · Low-poly 3D island and board; reference-guided cove layout (2026-10-26)
Owner feedback rejected the 2D look. The island and puzzle board are now real-time low-poly
3D (procedural meshes, flat shading, GL Compatibility) inside SubViewports; the UI moved to a
light lagoon theme. World 1 was re-laid out as a cove island (sandy central cove, rock-cliff
plateaus, huts, stairs, rowboat, turquoise shallows) following an owner-supplied reference
image's composition and palette. The reference is used for direction only: all geometry,
textures and code are original and procedural; no third-party image is copied or shipped.

### D-014 · Repository licence: proprietary (2026-10-25)
The repo is public but no licence was specified. Defaulted to **all rights reserved (SCYDE)**,
the safest choice for a commercial product. The owner can switch to an open licence at any
time; nothing in the codebase depends on this choice.

### D-013 · Draft-only releases (2026-10-25)
`release.yml` creates a **draft** GitHub Release; TestFlight upload is manual opt-in; store
submission is never automated (spec §15.5, §18).

### D-012 · Local-only analytics (2026-10-25)
No analytics SDK or network permission in 0.1.0. Events go to a bounded local queue with a
parameter whitelist; players can opt out. A provider can be added behind
`Analytics._dispatch` after a privacy review. Consequence: Data safety form = "no data collected".

### D-011 · Android permissions: VIBRATE only (2026-10-25)
`INTERNET` disabled in the export preset and asserted absent by CI.

### D-010 · Android outputs: non-Gradle APK + Gradle AAB (2026-10-25)
Debug/release APKs export without Gradle (fast, no Maven downloads). The Play-required AAB
uses the Gradle build template installed during CI (`--install-android-build-template`
together with `--export-release`). The generated `android/` folder is not committed.

### D-009 · iOS: export Xcode project, build with xcodebuild (2026-10-25)
`export_project_only=true` and a placeholder team ID `UNSIGNED00` let CI export and build for
the simulator and an unsigned device archive without credentials. Signing happens in
xcodebuild only when secrets exist.

### D-008 · Max board 6×7 for MVP (2026-10-25)
Cells stay ≥ ~110 px at 720 px width (comfortable thumb targets). Larger boards wait for
device usability testing (spec §3.2).

### D-007 · Undo reduces the move count; hints are free and unlimited (2026-10-25)
Spec: "do not penalize the player". Move targets are optional bonuses; hints come from the
solver. Revisit hint economy only with playtest data (MONETIZATION_PLAN).

### D-006 · Targets accept water from any side and are sinks (2026-10-25)
A dry tree reads naturally as "water anywhere next to me". Sinks prevent ambiguous chains.
Multi-target levels use splitters/crossings instead.

### D-005 · Solver: uniform-cost search over partial assignments (2026-10-25)
Branching only on tiles water actually reaches keeps 6×7 boards tractable (≤ 7k expansions)
and yields provably minimal tap counts, which become move targets and power hints.

### D-004 · Levels authored from intended solutions (2026-10-25)
`tools/level_designer.py` builds tiles from hand-drawn water paths and scrambles rotations
deterministically; the solver then proves solvability and minimum moves. JSON stays canonical;
nothing procedural ships unvalidated.

### D-003 · Procedural art, generated audio (2026-10-25)
No image-generation tool was available. Drawing in code gives an original, cohesive,
resolution-independent look with a ~1.3 MB pack. Audio is synthesised by a deterministic
script. All provenance in `assets/ASSET_MANIFEST.json`.

### D-002 · Godot 4.7.2 + GDScript + GL Compatibility (2026-10-25)
The repository was empty (README only), so the spec's preferred stack was adopted. 4.7.2 was
the newest stable release (Aug 2026). Compatibility renderer: broadest device support and
software-GL rendering for CI screenshots.

### D-001 · Custom headless test runner instead of a test addon (2026-10-25)
No third-party dependency to vendor or pin; uses Godot's `Logger` API so any engine/script
error during a test fails it. Emits JUnit XML for CI.
