# Privacy & compliance

## Facts (verifiable in code and CI)
- **Cloud save (D-021)**: the game uploads a copy of the save (game progress and settings, no
  personal data) to SCYDE's own server (`server/luma-cloud`, HTTPS). Each device gets a random
  guest id and token; no name, e-mail or device identifier is sent.
- **Optional sign-in** with Apple, Google or Facebook: the server checks the provider's token and
  stores only the provider's stable user id, to restore the save on another device. No e-mail,
  name, friends or profile data are requested or stored.
- **Account deletion** in the game (Settings → Cloud save → Delete cloud account) removes the
  player, sign-ins and every cloud copy (App Store rule 5.1.1(v)).
- No ads, no purchases, no tracking (Facebook Limited Login style: no advertising identifiers).
- Local analytics queue stays on the device (whitelisted, non-identifying; can be disabled).
- Permissions: Android `VIBRATE` and `INTERNET` (CI fails on anything else). iOS: none requiring
  usage descriptions; the Sign in with Apple capability.

## Store declarations (draft answers)
| Form | Answer for 0.1.0 |
|---|---|
| Google Play Data safety | Collected: App activity (game progress) and User IDs (account id from sign-in), for app functionality; not shared; encrypted in transit; users can request deletion (in-app) |
| Apple App Privacy | Data Linked to You: User ID, Gameplay Content — purpose App Functionality; no tracking |
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
> Developer: SCYDE. The game keeps a copy of your game progress on SCYDE's server so it is not
> lost. If you sign in with Apple, Google or Facebook, we store only that service's account id
> for you, to restore your progress on another device; we do not receive or store your name,
> e-mail or contacts. We do not sell or share your data and the game contains no ads. You can
> delete your cloud account and every copy of your progress at any time in Settings → Cloud save.
> Optional anonymous gameplay statistics stay on your device. Contact: dev@scyde.dev.

## Third-party licences
Nunito and Fredoka (SIL OFL 1.1, licence files shipped in `assets/fonts`); Godot Engine (MIT). These
notices are shown in-app: Settings → Licences (uses `Engine.get_license_text()`; covered by an
integration test).
