# Playtest kit (Phase 6)

## Build
Install the debug APK from the latest `Android build` artefact (`adb install luma-debug.apk`)
or, once signing exists, TestFlight / Play internal testing.

## Session script (moderated, 20 min)
1. Hand over the phone on a fresh install. Say only: "This is a puzzle game. Think aloud."
2. Do not help unless stuck > 60 s. Note the exact moment and screen.
3. After level 5 ask: "What do you think essence is for?"
4. Let them play freely to ~level 10 or 15 minutes.
5. Debrief questions below.

## Observation sheet
| Moment | Time to first tap | Understood source→target? (Y/N) | Hint used | Confusion notes |
|---|---|---|---|---|
| L1 | | | | |
| L2 (tree grows) | | | | |
| L4 (rocks) | | | | |
| L5 (milestone) | | | | |
| First splitter (L16) | | | | |
| First gate (L21) | | | | |

## Debrief
1. In one sentence, what is the game about?
2. Which moment felt best? Which felt slow or annoying?
3. Did the island changes matter to you? Why?
4. Was anything on screen unclear (buttons, symbols, rules)?
5. Would you play again tomorrow? (1–5) What would make you come back?

## Retention definitions
See ANALYTICS_PLAN.md. With local-only analytics, gather retention via test-group check-ins
(day 1/7) until a disclosed analytics provider is approved.

## Decision rules
- Tutorial understood by < 85% of testers → redesign the failing step first.
- A level abandoned by > 30% → reduce its minimum taps or add a clearer decoy.
- Change one problem at a time, retest, record the outcome in DECISION_LOG.
