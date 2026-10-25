# Game design document — LUMA: Restore the Wild (MVP 0.1.0)

## Fantasy
You discover a silent island whose springs failed long ago. By turning ancient stone channels
you send water back to dry saplings; every success visibly brings a corner of the island back
to life. The island becomes yours.

## Pillars (and how the build meets them)
| Pillar | Implementation |
|---|---|
| Instantly understandable | Level 1: one source, one round stone to tap, one dry sapling. Pointing hand + "Tap the stone to turn it." No text walls. |
| Visible transformation | Water fills channels ring by ring; saplings grow on the board; the island then animates the specific trees/ponds/waterfalls the level restored. |
| Short sessions, long progression | Levels take 30 s–3 min; 30 levels + optional objectives + discoveries + achievements. |
| Creativity & ownership | Discoveries (decorations) appear on the island and can be shown/hidden (first step toward decoration placement). |
| Sustainable solo dev | Levels are JSON validated by the solver; mechanics are data definitions; art is procedural. |

## Core loop
Select puzzle → read source/targets → tap stones (rotate) and levers (toggle) → water
connects → targets bloom → result card (objectives, essence, discoveries, achievements) →
island restoration plays → next puzzle / awaken next area.

## Rules
- Taps rotate round stones 90° clockwise; levers toggle every gate with the same symbol.
- Square stones (rivets) are fixed. Rocks block. Water spills from any open channel end.
- A level is complete the moment every sapling (target) has water. Flower beds are optional.
- Undo (unlimited, also reduces the move count), reset, unlimited hints (highlight one helpful
  tile computed by the solver). No fail state, no timers, no lives.

## Objectives & rewards
| | Essence |
|---|---|
| First completion | 10 |
| Each optional objective, first time met (move target, no spills, bloom flowers) | 5 |

Move targets = proven minimum + 2–5 taps of slack. Essence is spent to awaken areas
(0/40/40/45/45/50). Base rewards alone always cover the next area (validated in CI), so an
imperfect player can never soft-lock.

## Mechanics progression (Verdant Isle)
| Area | Levels | Teaches |
|---|---|---|
| Spring Glade | 1–5 | tap to rotate, elbows, several turns, routing around rocks, first milestone |
| Willow Brook | 6–10 | fixed stones, choosing between two routes, longer 6×6 routes, decoys |
| Stone Terraces | 11–15 | stair routes, obstacles, route choice under constraints, 6×7 boards |
| Lily Ponds | 16–20 | splitters → two targets, optional flower beds, no-spill networks, crossings, three-way networks |
| Old Mill | 21–25 | levers & gates, two links, inverted gates (a tempting shortcut that closes), gates + branches |
| Heart Falls | 26–30 | everything combined; finale with three targets, two links, bonus, sealed network |

## First-time user experience
1. Boot → straight into Level 1 (no menu). Pointer on the only rotatable stone.
2. Level 2: "Guide the water to the dry sapling" — the sapling grows on the board, then the
   island shows the Old Oak restoring.
3. Level 3: several turns, free experimentation; first discovery (Stone Lantern).
4. Level 4: rocks. 5: long route; the whole Spring Glade comes alive; milestone message
   explains essence and awakening areas.
Tutorial steps are saved individually, so an interrupted onboarding resumes at the same step;
in-level board state is also saved and restored.

## Island
Isometric diorama of six areas on three height levels. 29 restoration objects with 1–2 stages
(dry → young → mature/blooming; dry bed → flowing; empty → filled → lilies; ruin → repaired →
working mill), wildlife (rabbits, deer, ducks, birds), 8 decorations. Locked areas sit under
mist with a lock badge; awakening clears the mist.

## Screens
Boot · Main menu (Play/Continue, Island, Collection, Settings) · Gameplay · Result card ·
Island (area panel with level buttons and progress) · Collection (Discoveries, Achievements) ·
Settings. Every visible control works; there are no placeholder buttons.

## Audio & haptics
Generated ambient loop + 12 effects (tap, rotate, lever, flow, connect, bloom, complete,
unlock, hint, UI). Short vibrations on rotate, solve and restoration (toggle in settings).

## Out of scope for MVP (planned)
Daily puzzles, weekly challenges, decoration placement, cloud save, store achievements,
monetization, social features — see FRANCHISE_ROADMAP.md.
