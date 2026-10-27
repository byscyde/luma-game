# Current status

_Last updated: 2026-10-26 (session 2)._

## Session 2 (visual overhaul)
Owner rejected the 2D art. Rebuilt the island and board as low-poly 3D, restyled every
screen (light lagoon theme, Fredoka/Nunito, SVG icons), and re-laid out World 1 as a
cove island following the owner's reference image (see D-015). Verified locally: 75/75 tests,
30/30 levels, validators pass, visual tour at 720×1280 reviewed. The owner asked for a
"1:1 identical" copy of a reference / Midjourney images: this is approximated in style and
composition, not reproduced pixel-for-pixel (procedural real-time art; no copying of
third-party images). A Medium article with prompts could not be fetched (HTTP 403).
Repository transferred to `byscyde/luma-game` (owner's new account); contact `dev@scyde.dev`.
Old run links redirect. iOS builds now also emit `LUMA-unsigned.ipa` (owner re-signs with Feather).
Each successful iOS build run is now also published as a pre-release `ios-build-<run>` under
GitHub Releases with the unsigned IPA (D-016).

## Session 8 (cloud save)
Cloud save like FOUNDERS (D-021): `server/luma-cloud` (Node + MariaDB, separate service on the
FOUNDERS server, web admin `/admin`), `Cloud` autoload (guest player, automatic upload, conflict
choice, account deletion), Settings → Cloud save, native sign-in plugins (`plugins/luma_auth`:
Apple/Google/Facebook on iOS, Google/Facebook on Android). Loading screen now tours all six
islands. **Waiting on the owner**: server setup (`server/luma-cloud/README.md`), the domain
(config assumes `https://luma.scyde.dev`), Google client ids, Facebook app id/secret, Sign in with
Apple capability. Sign-in has not been tried on a device yet (needs those ids).

## Session 7
Archipelago started (D-020): islands map, Ember Reef (sliding rows/columns) with 30 generated,
verified levels, unlocked by the café task "Open the doors"; café chapter 2 needs Ember Reef;
island levels pay café coins. Reef Grill (Ember Reef's merge location) added: own board, chains,
cast and two chapters; opens when Ember Reef is complete. Lantern Bay (island 3, mirrors &
light) added: `scripts/light/`, 30 generated levels with solver-proven par, unlocked by café task
"c2_fountain". Lighthouse Workshop (its merge location: glass, candles, lamps, charts; cast
Isolde, Bram, Wick) opens when Lantern Bay is complete; café chapter 3 now needs Lantern Bay.
Stone Steps (island 4, Sokoban, `scripts/push/`, 30 levels, unlocked by café task
"c3_festival") and its Terrace Tea House added. Café chapter 4 (needs Stone Steps) launches the
ferry to Rope Isles (island 5, Hashi bridges, `scripts/bridges/`, 30 unique-solution levels) and
its Rope Market. Café chapter 5 opens Moon Grove (island 6, match-3 with moss and collect goals,
`scripts/match/`, 30 levels replayed by CI) and its Moonlight Bakery; café chapter 6 is the finale.
All six islands are playable (180 island levels). Next: playtest balancing, café phase 2 art.

## Session 6
Merge-2 mode "LUMA Harbour" (Lantern Café) unlocks after level 30 (D-019,
`docs/MERGE_DESIGN.md` phase 1): 7×9 board, 4 dish chains + generators, free planter with
cooldown, crates, bubbles, scissors, chests, storage, sell/undo, energy (100, 1/2 min,
offline regen, gem refills), 3 orders from characters, XP levels with unlocks, 3 story
chapters (18 tasks, dialogues, designs). Verified: 102/102 tests (19 rules + 6 merge
integration), screenshots light/dark. Not done yet: café scene art (phase 2), live-ops (3).

## Session 5
Board redrawn as a crisp 2D tray (owner rejected the 3D board) and a new loading screen in
the style of the owner's iosgame project, with key art rendered from the real island
(D-018). iOS CI moved to `macos-26` (no macos-15 runner was being assigned). Verified
locally: 77/77 tests, 30/30 levels, validators, screenshot tour.

## Session 4
Board and level screen redesigned; dark mode following the device (plus manual choice);
SCYDE boot logo + LUMA loading screen; owner's app icon; 120 Hz settings and mobile render
budget; FPS counter in Settings; "Developer: SCYDE" wording. See D-017. Verified locally:
77/77 tests, 30/30 levels, validators, screenshot tour in light and dark at 720×1280 and
level 30 at 640×1136. Not verifiable here: real-device frame rate (use the FPS counter).

## Session 3 (handoff)
Fixed double rotation per tap on touch devices (level 3 unsolvable). iOS IPA now published to
Releases per build. Board redesign started on `wip/board-redesign` (unverified). Full handoff
and next tasks: `docs/HANDOFF.md`.

## Summary
Repository started empty (README only). Session 1 built the complete MVP: puzzle engine,
30 validated levels, island restoration, progression, save, tutorial, settings, audio,
tests, validators, CI/CD workflows and documentation. **Version 0.1.0 (internal).**

## Verified in this session (actually executed)
| Check | Result |
|---|---|
| `tools/run_tests.sh` (Godot 4.7.2 headless) | **75/75 tests pass**; 30/30 levels solvable, 0 errors, 0 warnings |
| Python validators (`check_repo_hygiene`, `validate_levels`, `validate_assets`) | pass |
| Visual QA tour under Xvfb + Mesa (720×1280) | 10 screenshots of every screen; defects found were fixed and re-verified |
| Android debug APK export (local, no Gradle) | built + signed (debug key); `aapt`: `com.scyde.luma`, minSdk 24, targetSdk 36, only `VIBRATE`; levels present |
| Android release AAB export (local, Gradle, throwaway local test key) | built; `jarsigner -verify`: verified (first attempt hit Maven HTTP 429 through the sandbox proxy, retry succeeded) |
| Exported Linux pack smoke test | `SMOKE_TEST levels=30 errors=0 result=PASS` |
| GitHub Actions runs | see "CI runs" below |

## CI runs (GitHub Actions, commit `cc7e007`)
| Workflow | Run | Result |
|---|---|---|
| CI (static checks, 75 tests + solver, exported-build smoke test) | [40202228260](https://github.com/byscyde/luma-game/actions/runs/40202228260) | ✅ success |
| Android build (debug APK, apksigner/aapt/content/permission checks) | [40202230026](https://github.com/byscyde/luma-game/actions/runs/40202230026) | ✅ success — artefact `luma-android-3-…` (debug APK). Release APK/AAB step skipped: no keystore secrets |
| iOS build (Xcode 26 export, simulator build, unsigned device archive) | [40202230045](https://github.com/byscyde/luma-game/actions/runs/40202230045) | ✅ success — artefact `luma-ios-3-…` (unsigned .xcarchive, **not installable**). Signed IPA skipped: no Apple secrets |

| Nightly (tests via workflow_call + visual QA tour at 720×1280, 640×1136, 1536×2048) | [40202706450](https://github.com/byscyde/luma-game/actions/runs/40202706450) | ✅ success — artefact `screenshots-*` |

Not yet executed: `release.yml` (needs a `v0.1.0` tag; creates a draft release only) and its
TestFlight step (needs App Store Connect credentials).

Failures found and fixed on the way (each re-run to green): asset validator flagged
`res://build/...` output paths on a clean checkout; Godot's iOS simulator library is x86_64-only
(build for x86_64); Godot 4.7 device libraries require the iOS 26 SDK (select Xcode 26).

## Not verified / blocked (needs owner action or hardware)
- **Real devices**: no physical phone/tablet or simulator was available here. Performance,
  touch feel, haptics, audio interruption and notch layouts are untested on hardware.
  No frame rate is claimed.
- **iOS signed IPA / TestFlight**: requires Apple Developer account secrets
  (`APPLE_TEAM_ID`, `IOS_CERTIFICATE_P12_BASE64`, `IOS_CERTIFICATE_PASSWORD`,
  `IOS_PROVISIONING_PROFILE_BASE64`; App Store Connect API key for TestFlight).
- **Android release signing in CI**: requires `ANDROID_KEYSTORE_BASE64`,
  `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`.
- **Store listings**: privacy policy URL, support contact and legal entity details must be
  supplied by the owner (templates in PRIVACY_AND_COMPLIANCE.md).
- **Playtesting / retention**: needs human testers (PLAYTEST_KIT.md). No metrics exist.

## Known limitations
- Several 6×6/6×7 levels need ~20 taps minimum; difficulty curve should be tuned with
  playtest data.
- Decorations can be shown/hidden but not yet placed by the player.
- English only (localization pipeline ready).
- Analytics are local-only by design (no provider).

## Final acceptance checklist
**Game** — [x] launches · [x] tutorial · [x] first 5 levels · [x] 30 levels validated ·
[x] deterministic water · [x] restoration effects · [x] progression & rewards · [x] save/reload ·
[x] settings · [x] no dead controls · [~] mobile layouts (emulated resolutions only)

**Code & tests** — [x] critical logic unit-tested · [x] save + migration tests ·
[x] content validation automated · [x] CI fails on real failures · [x] no known critical defects (tested configuration)

**Build automation** — [x] CI runs · [x] Android workflow runs · [x] Android artefacts validated ·
[x] iOS workflow runs · [ ] IPA export (blocked: signing secrets) · [x] signing absence reported clearly · [x] credentials never committed/logged ·
[x] artefacts carry metadata · [x] release requires tag + produces draft only

**Documentation** — [x] README · [x] CLAUDE.md · [x] architecture · [x] build commands ·
[x] signing prerequisites · [x] test results recorded · [x] blockers explicit · [x] roadmap

**Release** — [x] store metadata draft · [~] icons done / screenshots from tour (store sizes
pending) · [x] privacy review for 0.1.0 · [x] versioning · [ ] signed distribution artefacts
(blocked on credentials) · [x] no public release performed

## Next actionable tasks
1. Owner: add Android keystore secrets → release APK/AAB in CI; install debug APK on a phone.
2. Owner: add Apple signing secrets → signed IPA; then TestFlight via `Release` (manual).
3. Run 5–8 moderated playtests with PLAYTEST_KIT.md; tune levels 9, 10, 14, 22–30.
4. Decoration placement on the island (FRANCHISE_ROADMAP near-term #2).
5. Store-size screenshots from release builds.
