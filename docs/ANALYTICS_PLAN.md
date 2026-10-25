# Analytics plan

## Current implementation (0.1.0)
`scripts/analytics/analytics_manager.gd` — **local only**: events are appended to
`user://analytics_queue.jsonl` (bounded) and kept in memory for debugging. No SDK, no network
permission, nothing leaves the device. Settings → "Anonymous usage statistics" disables it.

Only whitelisted parameters are recorded (`level_id, area_id, moves, par, optional_met,
duration_s, hint_count, undo_count, decoration_id, achievement_id, status, session_s,
levels_completed, build`). Names, emails, device identifiers, location are never collected;
unknown parameters are dropped (tested).

## Events
| Event | When | Params |
|---|---|---|
| app_started | launch | build |
| tutorial_started | first L1 start | level_id |
| tutorial_completed | onboarding step 5 done | level_id |
| level_started / level_completed | start / logical solve | level_id, moves, par, optional_met, hint_count, undo_count, duration_s |
| level_restarted | reset pressed | level_id |
| hint_used | hint pressed | level_id, hint_count |
| island_restoration_completed | area reaches 100% | area_id |
| area_unlocked | essence spent | area_id |
| decoration_unlocked / achievement_unlocked | first time | id |
| save_recovered | save loaded from backup/defaults | status |
| session_ended | window close | session_s |

`level_failed` from the spec does not apply: there is no fail state. Abandonment is derived
from `level_started` without `level_completed`.

## Metric definitions (for when a provider is added)
- **Cohort**: players by first `app_started` UTC date, per platform and build.
- **D1/D7/D30 retention**: share of cohort with ≥1 `app_started` on calendar day 1/7/30
  after install day (day 0).
- **Tutorial completion**: `tutorial_completed` / `tutorial_started` within cohort.
- **Level funnel**: completions per level / starts of level 1.
- **Hint dependence**: hints per completion per level.
Targets (internal evaluation only): D1 ≈ 30%, D7 ≈ 10%, D30 ≈ 4%, tutorial ≈ 85%. **No metrics
exist yet; none are reported or invented.**

## Adding a provider (future)
1. Privacy review + store disclosure update (PRIVACY_AND_COMPLIANCE).
2. Consent UI where required (GDPR/UK: opt-in before any non-essential processing).
3. Implement `_dispatch` to batch-upload the queue; enable `INTERNET` permission deliberately
   and update the CI permission assertion.
