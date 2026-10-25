# Franchise roadmap

Strategic possibilities, **not commitments**. Each step requires the previous gate's evidence
(MASTER_PLAN §Gates). Everything reuses the puzzle engine, tile framework (`TileTypes.DEFS`),
restoration model, save system, validators, UI framework, localization and analytics seam —
new worlds are mostly JSON + Painter shapes.

## Near term (after MVP playtests)
1. **Polish from playtest data** — difficulty curve (some 6×6 levels need ~20 taps), onboarding
   drop-off, hint usage.
2. **Decoration placement** — choose slots for discoveries on the island (data: slot list per
   area; save: slot → decoration).
3. **Store achievements** — Game Center / Play Games behind `PlatformServices.report_achievement`.
4. **Localization** — CSV already in place; add languages + a Latin-Extended/CJK font fallback.

## Phase B — daily content (only after retention ≥ targets)
- Daily puzzle from a pool of validated templates; seeded by date; validated by the solver
  before shipping in a content pack. Streaks that never punish missed days.
- Weekly challenge (e.g. sealed network, move target).

## Expansion 1 — Tropical Worlds
Coral lagoons, rainforest, waterfalls. Mechanics: water splitting with **flow amounts**
(each splitter halves pressure), interconnected ponds, wildlife restoration chains.
Engine work: `WaterResult` gains per-cell flow values; validator gains a flow goal.

## Expansion 2 — Frozen Frontier
Ice channels (water freezes after N steps unless heated), heat stones, melting gates.
Engine work: time-free rule — "temperature" as a second BFS layer, keeping determinism.

## Expansion 3 — Ancient Sky
Floating islands linked by energy channels (a second "fluid" type), moving platforms
(tiles that swap positions), multi-stage restoration puzzles.

## Expansion 4 — Community Islands (only with meaningful audience)
Visit islands, share layouts, weekly creative challenges, challenge codes. Requires backend,
moderation, reporting, rate limits, privacy review, server-side validation. **No public chat
or free text without a moderation plan.**

## Expansion 5 — Creative Mode
Local puzzle builder using the level format + solver (players can only publish puzzles the
solver proves solvable); share as compact codes.

## Expansion 6 — Premium Edition
Curated bundle of worlds, offline-first, no ads — only after the core game proves demand.
