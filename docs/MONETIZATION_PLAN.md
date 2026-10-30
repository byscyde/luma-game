# Monetization plan

**Status: none implemented, deliberately.** Phase priority is proving the loop is fun and
retains players. No ads, purchases, premium currency or subscriptions exist in 0.1.0.

## Candidate model (decide only with playtest + retention evidence)
1. **Cosmetic purchases** — island themes, bridge/waterfall styles, flower sets, effects.
   Never affect puzzle fairness.
2. **Premium content packs** — Tropical Worlds, Frozen Frontier, Ancient Sky, each with new
   mechanics, ~30 levels and restoration content.
3. **Rewarded ads (optional)** — e.g. a bonus decoration; never required to finish a level;
   hints stay free unless data shows a reason to change.
4. **One-time "Peaceful Edition"** purchase removing all optional ads.
No subscriptions without a substantial ongoing service.

## Requirements before any release with purchases
Official billing (StoreKit 2 / Play Billing) via maintained Godot plugins; handle failed,
cancelled, pending and restored purchases; validate product IDs; clear prices and
descriptions; purchases work offline once owned; never fake success in production; update
privacy disclosures and age-rating answers; test with sandbox/license testers.
