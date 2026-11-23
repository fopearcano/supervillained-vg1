# M1 legacy-save migration spike, hardened — evidence (Godot tree `cd87171`)

Correction report 15 (IMPLEMENTATION_LOG.md). The tested `godot/` tree is
`cd8717124f23ef03e16ebb0e71a1d73ba628e39d`, equal to `git rev-parse <correction-15 commit>:godot`;
the three spike APKs were built from a fresh clone of it and the host checks ran on another fresh
clone. The old Capacitor APK is the unchanged file of progress report 14 (SHA-256
`0771cd78c699d71b685507fa1267ce6b67b4b3618f8b813ea8191f885d11a89d`; its build log is
`../godot-tree-ef6c318/builds/old_capacitor_apk.txt`). Decision: `DECISION.md` (unchanged:
`native_bridge_viable_for_controlled_lineage`).

Logs are sanitized like the earlier folders (ANSI and carriage returns stripped, the local user
name and paths replaced, the test keystore passwords would be redacted; none appears). No APK,
keystore, password, SDK file or device data is committed.

## What changed since `ef6c318`

- **PCK smoke (main project tests):** the packed probe and the 600-frame packed startup run with an
  empty isolated `--path`; `.gdignore` folders and `platform/` are not runtime data; a source-only
  sentinel (`tests/automation/pck_source_only_sentinel.tres`) and every `platform/` file must not
  resolve, while a control run with the checkout as `--path` must resolve them; `platform/` paths are
  rejected in the pack.
- **Plugin:** API 26/28 calls guarded (`webview_package: null` plus a diagnostic below API 26, the user
  agent always recorded); Throwable-guarded diagnostics and emission; active WebView, timeout and
  generation kept as fields, cancelled on the UI thread by `onMainDestroy` / `onGodotTerminating`,
  late callbacks ignored; development-only hooks `readLegacyStoreHeldForLifecycleTest()` and
  `finishActivityForLifecycleTest()`.
- **Harness:** shape validation of every result, `keys` / `diagnostics` / `_values` on every path, a
  watchdog and single-finish guard (exactly one `M1_SPIKE_DONE`), lifecycle modes; a desktop
  self-test with fake plugins.
- **Tools:** `api_level_check.py` (bytecode constant pools against `api-versions.xml`, run by
  `build_spike_apk.ps1`); `run_upgrade_test.ps1` gained the lifecycle tests, a third run, `-SeedMode
  direct`, the Android 7 pull fallback and the active WebView provider record.

## Environment

As in `../godot-tree-ef6c318/REPORT.md`, plus the third emulator: AVD `sv_m1_api24` (device
`pixel`, `system-images/android-24/google_apis/x86_64` rev 27, installed for this correction; host GPU
enabled in its AVD config and booted with `-gpu host -feature GLESDynamicVersion`: OpenGL ES 3.1
translator on the RTX 3090), `emulator-5558`, Android 7.0 / API 24,
`Android/sdk_google_phone_x86_64/generic_x86_64:7.0/NYC/6696031:userdebug/dev-keys`; WebView
provider `com.android.chrome` 69.0.3497.100 (`settings get global webview_provider`; the installed
`com.google.android.webview` 53.0.2785.124 is not the active provider), recorded in
`device_api24/00_webview.txt`.

## APKs

| APK | Package | versionCode | minSdk | Certificate SHA-256 | APK SHA-256 |
|---|---|---|---|---|---|
| old Capacitor (unchanged) | `com.zampano.supervillained` | 1 | 24 | `034b187e0b72e1567af589678c888f03dd48e58d4a920a13e9a08ace512d2191` | `0771cd78…a89d` |
| spike (upgrade) | `com.zampano.supervillained` | 2 | 24 | the same | `f1d68d11156ed5a95640bb1fdf2c9da9945c29371e95ca9c1cad68c272d29af7` (277,102,725 B) |
| spike, wrong key | `com.zampano.supervillained` | 2 | 24 | `b2df28e1e40cefe5918371dc1228976e5ee796f3f7a9bdb920bb3b06def97a26` | `3244d870fc20d8f47167bfabdb0e5c7c009d3eacc8bd18a5d5c4de4472a73f3a` |
| spike, wrong package | `com.zampano.supervillained.m1negative` | 2 | 24 | `034b187e…2191` | `a201ebbfc8aa786cd578738a6814f2ae9ed9786a82ee5ec7bfe23f57b459ed2b` |

All spike APKs: debuggable, no `uses-permission`, native code x86_64 / arm64-v8a / armeabi-v7a
(`builds/spike_badging.txt`). Static API-level check in every build: 66 Android references, all
available at API 24 except the guarded `WebView.getCurrentWebViewPackage()` (26) and
`PackageInfo.getLongVersionCode()` (28) (`builds/spike_*.txt`, step "api level check").

## Results (`tools/run_upgrade_test.ps1`)

Expected values: identical on all three emulators and to progress report 14 (settings
`bcdce149…5427`, records `00b8ac69…a308`, coins `73475cb4…8049`, story `6e7b6d6e…5f5d`,
story-v1-backup `54677975…b084`; `device_*/expected.json`).

| Check | API 36 / WebView 133 | API 34 / WebView 113 | API 24 / Chrome 69 |
|---|---|---|---|
| old install (versionCode 1, certificate, origin `https://localhost`) | pass | pass | pass |
| seeding: the old boot migrates v1 → v2 (API 24: the five strings written with `setItem`, `02_seed_direct.js.txt`); exactly five keys; stable across a cold restart | pass | pass | pass |
| wrong key rejected (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`), old app untouched | pass | pass | pass |
| wrong package beside the old store: `not_found` | pass | pass | pass |
| `adb install -r`: versionCode 2, same firstInstallTime, same certificate (installed APK pulled back) | pass | pass | pass |
| runs 1 and 2 (two processes × two reads): `success`, every raw value identical to the old app's | pass | pass | pass |
| Godot quit during an active read: cancelled (`godot_terminating`), teardown on thread `main`, nothing emitted, no crash | pass | pass | pass |
| Activity finished during an active read: cancelled (`activity_destroy`), teardown on `main`, nothing emitted, no crash | pass | pass | pass |
| run 3 after the lifecycle tests: identical values | pass | pass | pass |
| no production save (`files/` has no `save_v3*`); WebView `Local Storage` present | pass | pass | pass |
| fresh install: `not_found`, no WebView profile before the first read | pass | pass | pass |
| `webview_package` in the plugin result | `com.google.android.webview` 133.0.6943.137 | … 113.0.5672.136 | `null` + `webview_package_unavailable`; user agent `Chrome/69.0.3497.100` |
| **Total** | **43/43** | **43/43** | **42/42** |

Where the process outlived the cancellation (API 36: both cases; API 34: the Activity-finish case),
the held page request returned afterwards and was logged as `ignored late page request of
generation 1`; in the other cases the process ended first (`device_*/06*_late_callbacks.txt`). On API 24 the old
game's bundle fails on Chrome 69 (`Uncaught SyntaxError: Unexpected token .`,
`device_api24/02_old_capacitor_logcat.txt`), so its own v1 → v2 migration could not run there; the
page, its origin and its storage worked.

## Host checks (fresh clone of this commit's code, `host_checks/`)

| Command | Result |
|---|---|
| `npm ci`; `npx playwright install chromium` | exit 0 each |
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` | exit 0: 206 + 55 outputs identical |
| `<console exe> --headless --path godot --import` | exit 0, no ERROR/WARNING line |
| `… --script res://tests/test_runner.gd -- --suite all` | exit 0: **138 passed, 0 failed, 138 total** |
| `<console exe> --headless --path godot --quit-after 600` | exit 0, engine banner only |
| `… --suite integration --file test_export_pack` (hermetic PCK smoke) | exit 0: 32,905,976 bytes, **254** runtime resources, **512** packed files, 18 source-only paths unresolved, control resolved 18 |
| `… --script res://platform/android/m1_migration_spike/harness/m1_spike_harness_selftest.gd` | exit 0: **27 passed, 0 failed** |
| `npm test`; `npm run build` | exit 0: 30 files, 248 tests; build OK |
| `git status --porcelain` (before and after); `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | exit 0, empty |
| `bash godot/tools/source_tree_guard.sh` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |

## Development attempts (`dev_attempts/`)

- Attempt 1 (tree `e69b0a2`, API 36, 40/43): the Activity-destroy case relied on the
  `always_finish_activities` setting, which Android 16 did not apply; the held read completed and the
  three checks failed as intended (`attempt1_*`). Replaced by `finishActivityForLifecycleTest()`.
- Attempt 2 (tree `ea97dc6`): API 36 and 34 passed; API 24 stopped because Android 7's `adb pull`
  cannot read `/data/app` (`attempt2_api24_*`); fixed (copy through `/data/local/tmp`), with the
  older profile layout handled. A dry run of the fixed script with those APKs passed 42/42.
- Attempt 3 (tree `ad79fe0`): 43/43, 43/43, 42/42, but the API-level check listed 47 references and
  missed the method-reference target `Activity::finish` (API 1); fixed to read the constant pools (66
  references), and the device test now records the active WebView provider. Rebuilt and rerun here.
