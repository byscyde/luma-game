# Decision log

Newest first. Each entry: context → decision → consequences.

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
