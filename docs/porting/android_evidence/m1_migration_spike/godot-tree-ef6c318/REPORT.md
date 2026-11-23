# M1 legacy-save migration spike — evidence (Godot tree `ef6c318`)

Controlled feasibility spike (MILESTONES.md M1). The spike code is
`godot/platform/android/m1_migration_spike/` (README there); the tested `godot/` tree is
`ef6c3188da5b9d9a8c2c836afa0119c54b9f7e50`, equal to `git rev-parse <spike commit>:godot`. All three
spike APKs were built from a fresh clone of that tree; the old APK from a fresh clone of `f7cf91f`
(the PixiJS/Capacitor sources are the same in both). Decision: `DECISION.md`.

Logs are sanitized: ANSI codes and carriage returns stripped, the local user name and paths replaced
by placeholders, the test keystore passwords would be replaced by
`<redacted-test-keystore-password>` (none appeared in any log). No APK, keystore, password, SDK file
or device data is in this folder.

## Environment

| Item | Version |
|---|---|
| Host | Windows 11 Pro N for Workstations 25H2; PowerShell 7.7.0 (portable); Eclipse Temurin JDK 21.0.13; Node v24.15.0, npm 11.12.1 |
| Android SDK (portable, outside the repo) | platform-tools 37.0.3, build-tools 36.1.0 (35.0.0 fetched by the old project's Gradle build), platforms/android-36 (rev 2), emulator 37.3.10, cmdline-tools 23.0; system images `android-36/google_apis/x86_64` (rev 7) and `android-34/google_apis/x86_64` (rev 14, installed for this spike) |
| Emulator 1 | AVD `sv_m1_api36` (Pixel 6), `emulator-5554`: Android 16 / API 36, `google/sdk_gphone64_x86_64/emu64xa:16/BE2A.250530.026.F3/13894323:userdebug/dev-keys`, Android System WebView `com.google.android.webview` 133.0.6943.137 |
| Emulator 2 | AVD `sv_m1_api34` (Pixel 6), `emulator-5556`: Android 14 / API 34, `google/sdk_gphone64_x86_64/emu64xa:14/UE1A.230829.050/12077443:userdebug/dev-keys`, WebView 113.0.5672.136 |
| Godot | 4.7.2-stable editor (a self-contained copy, so the global editor settings were not touched); Android export templates `4.7.2.stable` (`android_source.zip` SHA-256 `a15416b528efb0a19a7d187e4d9f4e5336d0689144b111329fb4bd12c4447ad`); gradle build template: Gradle 8.11.1, AGP 8.6.1, compile/target SDK 36, min SDK 24 |
| Old Capacitor project | Capacitor 8.6.2 (`@capacitor/android`), Gradle 8.14.3, AGP 8.13.0, compile/target SDK 36, min SDK 24, `versionCode 1` / `versionName "1.0"` (`android/app/build.gradle`) |

**Capacitor origin and storage (audited):** `capacitor.config.ts` sets `appId`
`com.zampano.supervillained` and no `server` block; Capacitor 8.6.2's `CapConfig` defaults are
`androidScheme = "https"` and `hostname = "localhost"`, so the app is served from
`https://localhost/`; `Bridge` enables DOM storage and sets no WebView data-directory suffix (default
profile `app_webview`); WebView remote debugging defaults to the app's debuggable flag. At runtime
the old app's page reported `location.origin` `https://localhost` on both emulators
(`device_*/02_old_read_before_seed.json`). The game stores
`JSON.stringify(value)` under `supervillained:<key>` (`src/core/storage.ts`).

## Controlled lineage

| APK | Package | versionCode / name | Signer certificate SHA-256 | APK SHA-256, size |
|---|---|---|---|---|
| old Capacitor (`debug` variant, re-signed) | `com.zampano.supervillained` | 1 / 1.0 | `034b187e0b72e1567af589678c888f03dd48e58d4a920a13e9a08ace512d2191` | `0771cd78c699d71b685507fa1267ce6b67b4b3618f8b813ea8191f885d11a89d`, 40,256,561 B; debuggable; INTERNET (Capacitor's own manifest) |
| spike (upgrade) | `com.zampano.supervillained` | 2 / 0.2.0-godot | `034b187e…2191` (same) | `f281f9a975246b78eab3afffdf8d8dc13910fee61c9b056bba48c0bd416ef627`, 277,092,976 B; debuggable; **no permissions**; x86_64, arm64-v8a, armeabi-v7a |
| spike, wrong key (negative) | `com.zampano.supervillained` | 2 / 0.2.0-godot | `b2df28e1e40cefe5918371dc1228976e5ee796f3f7a9bdb920bb3b06def97a26` | `9dfadc5875b24686b7460176b7907749348e66cde069ec1ce93870b753f8060e` |
| spike, wrong package (negative) | `com.zampano.supervillained.m1negative` | 2 / 0.2.0-godot | `034b187e…2191` | `48b8d91e66a59390a9c9b61a7b563a5732b01cea410d4830f2782a98ccac7c14` |

The installed old and upgraded APKs were pulled back from each emulator and their certificates
checked again (`device_*/01_old_installed_certs.txt`, `device_*/05_spike_installed_certs.txt`).
Keys: two throwaway PKCS12 keystores created outside the repository (`builds/new_test_keystores.txt`).

## Expected legacy values (read from the old app after a cold restart)

Seeded through the old app's own WebView runtime (`tools/legacy_seed.js` over DevTools): settings,
a `level1` record and coins as the game's storage wrapper writes them, and a **version-1** campaign
under `story`; on the reload the old game's boot (`StoryFlow` → `loadCampaign`) migrated it itself,
keeping the v1 save under `story-v1-backup` and writing the v2 campaign under `story`. Exactly the
five `supervillained:` keys existed. Values after a cold restart (`device_*/expected.json`, identical
on both emulators):

| Key | Length | SHA-256 (UTF-8) |
|---|---|---|
| `supervillained:settings` | 175 | `bcdce14982bb6f0bc3a35cf348252689a9f3e66a1523e185c1b4822d0c895427` |
| `supervillained:records` | 49 | `00b8ac69b590194adaeaac22c9652ee2a00bf38248525f6e5ce160758c0aa308` |
| `supervillained:coins` | 2 | `73475cb40a568e8da8a045ced110137e159f890ac4da883b6b17dc651b3a8049` |
| `supervillained:story` (v2, migrated by the old app) | 472 | `6e7b6d6e1106308ca653b25b656b67bec6c3b33df8d35c3d41cca60e84f75f5d` |
| `supervillained:story-v1-backup` (the v1 save) | 543 | `54677975bfe04a490900b5cb8d8c6b54fb815a8b19be074b4ea784093851b084` |

## Results (`tools/run_upgrade_test.ps1`, `device_api36/`, `device_api34/`)

| Check | API 36 / WebView 133 | API 34 / WebView 113 |
|---|---|---|
| old APK normal install, versionCode 1, certificate recorded, origin `https://localhost` | pass | pass |
| seeding through the old runtime; v1→v2 migration by the old boot; exactly five keys; values identical after a cold restart | pass | pass |
| wrong-key update: `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, old app untouched | pass | pass |
| wrong package beside the old store: 2 reads `not_found` (origin `https://localhost`) | pass | pass |
| `adb install -r`: versionCode 2, same firstInstallTime, new lastUpdateTime, same certificate | pass | pass |
| spike run 1 and run 2 (separate processes), 2 reads each: `success`, origin `https://localhost`, all five raw values identical to expected (49/49 checks per run) | pass | pass |
| four reads identical across the two processes | pass | pass |
| no production save (`run-as ls files`: no `save_v3*`); WebView `Local Storage` still present | pass | pass |
| fresh install after uninstall: 2 reads `not_found`, no WebView profile before the first read | pass | pass |
| **Total** | **30/30** | **30/30** |

Plugin results: the reassembled raw JSON per read is in `device_*/<run>.parsed.json` (status,
`verified_origin`, per-key `present` / `raw` / `error`, WebView package and version, UTC timestamp,
diagnostics); the harness's logcat lines in `<run>.godot_raw.txt`; per-run comparisons in
`<run>.compare.json`; every adb command and exit code in `commands.txt`.

## Development attempts (kept as found)

- Old APK build, first run: Gradle failed with "Unable to establish loopback connection" (Java on
  this host); the script got `-JavaTmpDir` and the second run built the APK (`builds/old_capacitor_apk.txt`).
- Trial spike builds from the working tree (not evidence): Godot's `has_method()` does not list a
  Java singleton's methods, so the harness checks the signal and lets the call itself fail.
- Attempt 1 (tree `f80ebd6`, API 36): 27/29 — every read's raw values matched, but the harness's
  per-read summary line was cut at 1023 characters by Godot's Android logger, so its per-key hash
  check could not be read (`dev_attempts/attempt1_*`). Fixed: per-key lines and a truncation check.
- Attempt 2 (tree `e285294`, API 36): 28/29 — all reads matched (49/49 per run); pulling the
  277 MB installed APK back for the certificate check failed once (adb exit 1,
  `dev_attempts/attempt2_*`). Fixed: retry with logging.
- Final (tree `ef6c318`): 30/30 on both emulators.

## Host checks on a fresh clone of the spike commit

Fresh `git clone` of the spike commit's code (`core.autocrlf=true`, the same `godot/` tree
`ef6c318`), logs in `host_checks/` (`exit_codes.txt` has every exit code and duration):

| Command | Result |
|---|---|
| `npm ci`; `npx playwright install chromium` | exit 0 each |
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` | exit 0: 206 outputs identical (72 copies); `build_resources check (all): OK, 55 outputs identical` |
| `<console exe> --headless --path godot --import` (clean import) | exit 0, no ERROR/WARNING line |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all` | exit 0: **138 passed, 0 failed, 138 total** |
| `<console exe> --headless --path godot --quit-after 600` (600-frame desktop launch) | exit 0, engine banner only |
| `… --suite integration --file test_export_pack` (Android-preset PCK smoke) | exit 0: PCK 32,905,976 bytes, 512 packed files (both unchanged), **257** runtime resources checked (254 before; see below) |
| `npm test`; `npm run build` | exit 0: 30 files, 248 tests passed; build OK |
| `git status --porcelain` (before and after); `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | exit 0, all empty |
| `bash godot/tools/source_tree_guard.sh` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |

**PCK smoke count (254 → 257).** The test lists "runtime resources" by walking `res://` with
DirAccess, which also sees the spike's three Godot files (`harness/m1_spike_harness.gd`,
`harness/m1_spike_harness.tscn`, `editor/sv_m1_spike_editor_plugin.gd`) although `.gdignore` keeps
them out of the import and the export. The exported pack is unchanged: an `--export-pack Android`
of the same clone (32,905,976 bytes) contains no `platform/android`, `m1_spike` or `svspike` path,
while it does contain the game's scenes and autoloads. Because those three paths are not in the pack
yet were not reported missing, the packed probe resolved them outside the pack (its working
directory is the project directory): the probe's "loads from the pack" check does not by itself
prove pack membership. That is a limit of the existing check, left unchanged here.

## Commands run (PowerShell 7.7.0; `<spike>` = `godot/platform/android/m1_migration_spike/tools`, `<work>` = a folder outside the repository)

| Command | Exit | Log |
|---|---|---|
| `<spike>/new_test_keystores.ps1 -OutDir <work>\keys -JavaHome <JDK 21>` | 0 | `builds/new_test_keystores.txt` |
| `<spike>/build_old_capacitor_apk.ps1 -SourceRepo <repo> -Commit f7cf91fc6fd2f0784d4bb60be687fbedd3058b28 -WorkDir <work>\old-capacitor-src -Keystore <work>\keys\upgrade.p12 -OutApk <work>\apk\old_capacitor_v1_testkey.apk -AndroidSdk … -JavaHome … -GradleUserHome … -JavaTmpDir …` (clean clone, `npm ci`, `npm run build`, `npx cap sync android`, `gradlew assembleDebug`, `apksigner sign/verify`, `aapt2 dump badging`) | 0 | `builds/old_capacitor_apk.txt` |
| `<spike>/build_spike_apk.ps1 -GodotProject <fresh clone>\godot -Keystore <work>\keys\upgrade.p12 -KeyAlias sv_m1_upgrade -PassEnv SV_M1_UPGRADE_PASS -OutApk <work>\apk\spike_upgrade_testkey.apk …` (javac `--release 17`, `jar`, scratch project, `godot --headless --import`, `godot --headless --install-android-build-template --export-debug Android`, `apksigner verify`, `aapt2 dump badging`) | 0 | `builds/spike_upgrade.txt` |
| the same with `-Keystore <work>\keys\wrongkey.p12 -KeyAlias sv_m1_wrongkey -PassEnv SV_M1_WRONGKEY_PASS` | 0 | `builds/spike_wrong_key.txt` |
| the same with `-Package com.zampano.supervillained.m1negative` | 0 | `builds/spike_wrong_package.txt` |
| `<spike>/run_upgrade_test.ps1 -Serial emulator-5554 -OldApk … -SpikeApk … -WrongKeyApk … -WrongPackageApk … -WrongPackage com.zampano.supervillained.m1negative -OutDir …` | 0 (30/30) | `device_api36/` (`commands.txt`: every adb command and its exit code) |
| the same with `-Serial emulator-5556 -DevToolsPort 9334` | 0 (30/30) | `device_api34/` |
