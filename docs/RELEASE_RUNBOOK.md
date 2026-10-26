# Release runbook

Everything below runs in GitHub Actions. You never need to edit code to sign or ship —
only add repository **secrets** (Settings → Secrets and variables → Actions).
Secret values are never printed; decoded files live in `$RUNNER_TEMP` and are deleted.

## 1. Versioning
- Marketing version: `config/version` in `project.godot` (e.g. `0.1.0`).
- Build number: the workflow run number, stamped by `tools/build_metadata.py --apply` into
  Android `version/code` and iOS `CFBundleVersion`. Every artefact ships `build/metadata.json`
  (version, build, commit SHA, workflow URL, timestamp) and a `SHA256SUMS.txt`.

## 2. Android

### Secrets
| Secret | Format | Purpose |
|---|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 upload.keystore` | Upload/release keystore |
| `ANDROID_KEYSTORE_PASSWORD` | text | Keystore password (**key password must be the same** — Godot passes one password) |
| `ANDROID_KEY_ALIAS` | text | Alias of the key inside the keystore |

Create a keystore once (keep it and its password backed up offline — losing it means you
cannot update the app unless you use Play App Signing):
```bash
keytool -genkeypair -keystore upload.keystore -alias luma-upload -keyalg RSA -keysize 2048 -validity 10000
base64 -w0 upload.keystore   # paste output into ANDROID_KEYSTORE_BASE64
```
Enrol in **Play App Signing** in the Play Console; this keystore then acts as the upload key.

### Outputs (`Android build` workflow)
- Always: `luma-debug.apk` (ephemeral debug key, installable with `adb install`, not for Play).
- With secrets: `luma-release.apk` (direct testing) and `luma-release.aab` (Play upload;
  built with Gradle via the Android build template installed during the job).
- Checks: `apksigner verify`, package `com.scyde.luma`, version code = run number, level data
  present, no `tests/`/`tools/` files, no INTERNET permission.

### Play Console (manual, requires your Google Play developer account)
1. Create app "LUMA: Restore the Wild", package `com.scyde.luma`.
2. Complete Data safety (no data collected/shared in 0.1.0 — see PRIVACY_AND_COMPLIANCE),
   content rating questionnaire, target audience, store listing (STORE_METADATA.md).
3. Upload `luma-release.aab` to **Internal testing** first. Never promote to production
   without playtest evidence (see MASTER_PLAN gates).

## 3. iOS

### What runs without credentials
Xcode project export → **simulator build** → **unsigned device archive** → **unsigned IPA**
(`LUMA-unsigned.ipa` in the run's artefact). Neither installs on an iPhone as-is: iOS only runs
signed apps. The unsigned IPA can be re-signed with the tester's own Apple ID by a sideloading
tool (e.g. Sideloadly/AltStore; a free Apple ID gives a 7-day signature, ≤3 apps), or by
`codesign` with a development certificate + a profile listing the device. For TestFlight or
anything beyond personal testing, use the signed path below.

Every successful direct `iOS build` run (push or manual dispatch) also publishes the unsigned
IPA as a GitHub **pre-release** under
[Releases](https://github.com/byscyde/luma-game/releases), tagged `ios-build-<run number>`,
asset `LUMA-<version>-ios-build<run>-unsigned.ipa` plus `SHA256SUMS.txt` (job
`publish-release`, D-016). Download it there and re-sign it (the owner uses Feather).

### Secrets for a signed IPA
| Secret | Format | Purpose |
|---|---|---|
| `APPLE_TEAM_ID` | 10-character team ID | Written into the export preset and xcodebuild |
| `IOS_CERTIFICATE_P12_BASE64` | `base64 -i dist.p12` | Apple Distribution certificate + private key |
| `IOS_CERTIFICATE_PASSWORD` | text | Password of the .p12 |
| `IOS_PROVISIONING_PROFILE_BASE64` | `base64 -i LUMA_AppStore.mobileprovision` | App Store (or Ad Hoc) profile for `com.scyde.luma` |

Profiles with a device list export as `release-testing` (Ad Hoc); others as
`app-store-connect`.

Steps (Apple Developer account required, manual):
1. Register App ID `com.scyde.luma` (no special capabilities needed).
2. Create an Apple Distribution certificate, export it from Keychain as .p12.
3. Create an App Store provisioning profile for the App ID.
4. Add the four secrets. The next `iOS build` run produces `ipa/*.ipa`, verified with
   `codesign --verify --deep --strict`.

### TestFlight
| Secret | Format |
|---|---|
| `APP_STORE_CONNECT_API_KEY_ID` | key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | issuer UUID |
| `APP_STORE_CONNECT_API_KEY_BASE64` | `base64 -i AuthKey_XXXX.p8` |

Create the app record in App Store Connect first. Then run **Release** workflow manually
with `testflight: true`. Upload uses `xcrun altool --upload-app` with the API key.
*This path has not been executed yet because no credentials exist; treat its first run as a
test.* App Store review submission is always manual.

## 4. Release procedure
1. Update `config/version` and add `## [x.y.z]` to `CHANGELOG.md` on a `release/x.y.z` branch.
2. CI green on the branch; run a manual playtest of the build artefacts.
3. Merge to `main`, tag `vx.y.z`, push the tag.
4. `Release` workflow: version/changelog check → full tests → Android + iOS builds →
   **draft** GitHub Release with artefacts and notes generated from commits. Nothing public.
5. Review the draft, then upload the AAB/IPA to store testing tracks manually (or TestFlight
   via the opt-in step). Optionally add required reviewers to the `release` environment
   (Settings → Environments) to gate releases on manual approval.

## 5. Rollback
- Stores: halt the staged rollout (Play) / remove the build from testing (TestFlight);
  ship the previous tag rebuilt with a higher build number.
- Save compatibility: saves are forward-tolerant (unknown fields kept, newer versions not
  downgraded), so rolling back app code does not destroy player progress.
- Git: never rewrite tags; create `vx.y.(z+1)` from the last good commit.

## 6. Troubleshooting
| Symptom | Fix |
|---|---|
| `checksum mismatch` in install step | Godot download corrupted or changed upstream; re-run; if persistent, verify SHA-512 against the official release page before updating `tools/ci/install_godot.sh` |
| "Android build template not installed" | `--install-android-build-template` must be passed together with `--export-*` |
| "Could not find version of build tools that matches Target SDK" | warning only; install the matching `build-tools;<target>` |
| iOS: "App Store Team ID not specified" | preset has placeholder `UNSIGNED00` for unsigned builds; set `APPLE_TEAM_ID` for signed builds |
| Scripts fail with "Identifier not declared" | new `class_name` → run the editor import (`run_tests.sh` does it twice) |
| Smoke test FAIL | exported pack missing content; check `include_filter` in `export_presets.cfg` |
