# Master plan — LUMA: Restore the Wild

Condensed, adapted record of the master development specification (SCYDE, 2026-10-25).
Where the implementation adapts the spec, the reason is in DECISION_LOG.md.

## Objective
Build an original, polished, globally marketable mobile puzzle + world-restoration game for
iOS and Android, by one developer, with maximal automation (tests, content validation,
CI/CD, documentation). Priority order: **playable game → validated content → retention →
automated builds → release readiness → franchise expansion.** A small, polished, genuinely
playable product beats a large unfinished one.

## Non-negotiables
Inspect before modifying; preserve existing work; branches + commits, never force-push;
real playable functionality (no mockups or dead buttons); acceptance criteria + tests per
feature; never claim unverified success; never fabricate results, assets or credentials;
never commit secrets; continue with unsigned builds when credentials are missing and report
the exact blocker; maintain CURRENT_STATUS; no paid services or public releases without
authorization; polished English with localization-ready architecture; no copied assets.

## Product pillars
A. Instantly understandable · B. Visible, satisfying transformation · C. Short sessions,
long progression · D. Creativity and ownership · E. Sustainable solo development.

## Gameplay requirements (status)
| Requirement | Status |
|---|---|
| Data-driven boards 3×3 tutorial → 6×7 | done |
| Tiles: empty, straight, elbow, source, destination, obstacle, gate+switch | done |
| Later tiles: 3-way (tee), 4-way (cross), splitter, fixed/pinned, inverted gate | done |
| Pressure/timed/one-way/elevation/ice/energy tiles | roadmap |
| Clear tile states (normal, rotating, connected, flowing, blocked, target reached, spills) | done (shape+motion+colour) |
| Tap rotate 90°, responsive animation, reset, undo, mouse support, suspension-safe | done |
| Deterministic water simulation with structured result | done |
| Validation: single/multiple targets, required/optional, move targets, special tiles | done |
| Offline bounded solver: solvable/impossible/minimum/complexity/unverified | done |
| Restoration states, persistent + deterministic, layered effects, reduced motion | done |
| FTUE 5 steps, resumable | done |
| 5 prototype levels, 30 MVP levels with metadata and validation pipeline | done |
| Essence + discoveries, achievements, progression integrity | done |
| Versioned atomic save, backup, corruption recovery, migration tests | done |
| Daily/weekly content, social, cloud save | roadmap (gated) |
| Privacy-conscious analytics abstraction | done (local-only) |
| Monetization | intentionally not started |

## Phases and exit criteria
| Phase | Exit criterion | Status |
|---|---|---|
| 0 Audit | Repo understood, toolchain chosen, docs created | done |
| 1 Core puzzle prototype | 5 levels end-to-end | done |
| 2 Restoration prototype | Puzzle visibly changes the island and persists after restart | done |
| 3 MVP content | Complete initial experience (30 levels, tutorial, progression, save, settings, audio) | done |
| 4 QA & optimization | No known critical defects in tested configuration | done for automated/emulated scope; device testing pending |
| 5 CI/CD | Workflows executed for capabilities available | see CURRENT_STATUS for run results |
| 6 Controlled playtesting | Evidence to continue/improve/pivot | kit ready; needs human testers |
| 7 Launch preparation | Requirements verified or blockers documented | drafts ready; owner inputs needed |
| 8 Post-launch expansion | Only after engagement evidence | not started |

## Validation gates
- **Prototype**: 5 playable levels, no critical defects, first interaction understood, reset works.
- **MVP**: 30 validated levels, stable save, no known crashes, tutorial, restoration loop,
  representative device testing.
- **Early retention** (sufficient cohort): D1 ≈ 30%, D7 ≈ 10%, D30 ≈ 4%, tutorial ≈ 85%.
  If missed: inspect onboarding, difficulty, session length, abandonment; change one thing;
  retest; document. No paid acquisition before retention + monetization evidence.

## Release & marketing
Controlled experiment: internal → closed testing → limited beta/soft launch → analyse →
fix → test store creatives → expand. Marketing shows only real gameplay
(STORE_METADATA.md). Never claim store approval.

## Final acceptance checklist
Tracked live in CURRENT_STATUS.md.
