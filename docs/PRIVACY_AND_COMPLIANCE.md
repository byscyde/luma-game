# Privacy & compliance

## Facts about 0.1.0 (verifiable in code and CI)
- No accounts, no network access (Android `INTERNET` permission absent — asserted in CI), no
  third-party SDKs, no ads, no purchases.
- Data stored on device only: save file (progress, settings) and a local analytics queue
  (whitelisted, non-identifying game events; can be disabled in Settings).
- Permissions: Android `VIBRATE`. iOS: none requiring usage descriptions.

## Store declarations (draft answers)
| Form | Answer for 0.1.0 |
|---|---|
| Google Play Data safety | No data collected, no data shared (data stays on device) |
| Apple App Privacy | Data Not Collected |
| Ads | Contains ads: No |
| In-app purchases | No |
| Age rating | Questionnaires: no violence, no user-generated content, no chat, no gambling → expected lowest rating (to be confirmed in the consoles) |
| Target audience | General audience. If children under 13 are targeted, Play Families policy and COPPA review are required before adding any analytics/ads. |

## Required before public release (owner must supply — not invented here)
- [ ] Public **privacy policy URL** (template below)
- [x] **Support contact**: dev@scyde.dev
- Outgoing automated mail (if any is ever sent, e.g. from a website form): `no-reply@scyde.dev`.
  The game itself sends no email and has no SMTP; SMTP credentials, if needed later, go only
  into the hosting provider's / GitHub Actions secrets, never into this repository.
- [ ] Developer/legal entity name and address as required by each store (e.g. EU trader status)
- [ ] Re-verify current Apple App Store Review Guidelines and Google Play policies at submission time
- [ ] Re-run this checklist whenever an SDK, permission or data flow is added

## Privacy policy template
> **LUMA: Restore the Wild — Privacy Policy** (last updated: ____)
> LUMA is developed by ____ ("SCYDE"). The game does not collect, transmit or share personal
> data. Your progress and settings are stored only on your device. Optional anonymous gameplay
> statistics, if enabled, are stored only on your device in this version and can be turned off
> in Settings. The game contains no ads and no in-app purchases. Contact: dev@scyde.dev.

## Third-party licences
Nunito and Fredoka (SIL OFL 1.1, licence files shipped in `assets/fonts`); Godot Engine (MIT). These
notices are shown in-app: Settings → Licences (uses `Engine.get_license_text()`; covered by an
integration test).
