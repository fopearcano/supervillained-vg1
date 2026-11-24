# M1 legacy-save migration spike, pre-start race closed — evidence (Godot tree `591e2df`)

Correction report 16 (IMPLEMENTATION_LOG.md). The tested `godot/` tree is
`591e2df2f1826de798024d9b0f237afe07eea6da`, equal to `git rev-parse <correction-16 commit>:godot`;
the three spike APKs were built from a fresh clone of it and the host checks ran on another fresh
clone. The old Capacitor APK is the unchanged file of progress report 14 (SHA-256
`0771cd78c699d71b685507fa1267ce6b67b4b3618f8b813ea8191f885d11a89d`; its build log is
`../godot-tree-ef6c318/builds/old_capacitor_apk.txt`). Decision: `DECISION.md` (unchanged:
`native_bridge_viable_for_controlled_lineage`; not a production approval). The evidence of
correction report 15 (`../godot-tree-cd87171/`) and progress report 14 (`../godot-tree-ef6c318/`)
is kept unchanged.

Logs are sanitized like the earlier folders (ANSI and carriage returns stripped, the local user
name and paths replaced, the test keystore passwords would be redacted; none appears). No APK,
keystore, password, SDK file or device data is committed.

## What changed since `cd87171`

- **Plugin, pre-start lifecycle race:** `request()` reserves the generation (compare-and-set) and
  records the lifecycle epoch on the caller's thread before posting `start()` to the UI thread.
  `onMainDestroy` / `onGodotTerminating` mark the plugin terminated, bump the epoch and clear the
  reservation on the thread that delivers them (pending and active reads alike), then destroy an
  active read's timeout and WebView on the UI thread. `start()` creates no WebView for a terminated
  plugin, a stale epoch, an invalidated generation or a finishing/destroyed Activity. New
  development-only hook `readLegacyStoreQueuedForLifecycleTest()`: the same reservation, its
  `start()` posted 5 s later.
- **Validation:** success and not_found need a null error on every key, in the harness
  (`wrong_shape_plugin_result` otherwise) and in `m1_spike_tool.mjs compare` (not_found now checked
  too); `m1_spike_tool.mjs selftest`; harness self-test 35/35 (new: both per-key-error shapes as
  `_summarize` and whole-run cases, the four lifecycle modes against a recording fake).
- **Device test:** 06d (Godot quit) and 06e (Activity finish) in the same frame as a queued request,
  without waiting for `M1_SPIKE_LIFECYCLE_ACTIVE`; the active-read tests stay as 06b/06c and the
  recovery run is now 06f. The process's end (ActivityManager) and `pidof` after the wait are
  recorded in `06d/06e_*.process.txt`.

## Environment

As in `../godot-tree-cd87171/REPORT.md` (the same three emulators, booted the same way): `sv_m1_api36`
(`emulator-5554`, Android 16 / API 36, Android System WebView 133.0.6943.137), `sv_m1_api34`
(`emulator-5556`, Android 14 / API 34, WebView 113.0.5672.136), `sv_m1_api24` (`emulator-5558`,
Android 7.0 / API 24, WebView provider `com.android.chrome` 69.0.3497.100); `device_*/00_*.txt`.

## APKs

| APK | Package | versionCode | minSdk | Certificate SHA-256 | APK SHA-256 |
|---|---|---|---|---|---|
| old Capacitor (unchanged) | `com.zampano.supervillained` | 1 | 24 | `034b187e0b72e1567af589678c888f03dd48e58d4a920a13e9a08ace512d2191` | `0771cd78…a89d` |
| spike (upgrade) | `com.zampano.supervillained` | 2 | 24 | the same | `1fb37c71ec77bb55f3cd866bbf18b71de0bad5e984d187881b84adb24132e40d` (277,105,397 B) |
| spike, wrong key | `com.zampano.supervillained` | 2 | 24 | `b2df28e1e40cefe5918371dc1228976e5ee796f3f7a9bdb920bb3b06def97a26` | `ad9feb6837339aab1525cb2515a2a3c5c373217703090b0b1edf58a651b8f420` |
| spike, wrong package | `com.zampano.supervillained.m1negative` | 2 | 24 | `034b187e…2191` | `65453e103eed33341f673af09c7927510829234140d8ea1f4b9984b71bed505b` |

All spike APKs: debuggable, no `uses-permission`, native code x86_64 / arm64-v8a / armeabi-v7a
(`builds/spike_badging.txt`). Static API-level check in every build: 68 Android references,
all available at API 24 except the guarded `WebView.getCurrentWebViewPackage()` (26) and
`PackageInfo.getLongVersionCode()` (28); the new `Activity.isDestroyed()` is API 17
(`builds/spike_*.txt`, step "api level check").

## Results (`tools/run_upgrade_test.ps1`)

Expected values: identical on all three emulators and to correction report 15 (settings
`bcdce149…5427`, records `00b8ac69…a308`, coins `73475cb4…8049`, story `6e7b6d6e…5f5d`,
story-v1-backup `54677975…b084`; `device_*/expected.json`).

| Check | API 36 / WebView 133 | API 34 / WebView 113 | API 24 / Chrome 69 |
|---|---|---|---|
| old install (versionCode 1, certificate, origin `https://localhost`) | pass | pass | pass |
| seeding: the old boot migrates v1 → v2 (API 24: the five strings written with `setItem`, `02_seed_direct.js.txt`); exactly five keys; stable across a cold restart | pass | pass | pass |
| wrong key rejected (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`), old app untouched | pass | pass | pass |
| wrong package beside the old store: `not_found`, a null error on every key | pass | pass | pass |
| `adb install -r`: versionCode 2, same firstInstallTime, same certificate (installed APK pulled back) | pass | pass | pass |
| runs 1 and 2 (two processes × two reads): `success`, every raw value identical to the old app's, a null error on every key | pass | pass | pass |
| 06b Godot quit during an active read: cancelled (`godot_terminating`), teardown on thread `main`, nothing emitted, the lifecycle log consistent, no crash | pass | pass | pass |
| 06c Activity finished during an active read: invalidated by `godot_terminating`, WebView destroyed by `activity_destroy` on `main`, nothing emitted, the lifecycle log consistent, no crash | pass | pass | pass |
| 06d Godot quit in the same frame as a queued request (no wait for `M1_SPIKE_LIFECYCLE_ACTIVE`): the reserved generation invalidated while pending, no WebView created, nothing emitted, no crash | pass | pass | pass |
| 06e Activity finished in the same frame as a queued request: the same | pass | pass | pass |
| 06f run 3 after the lifecycle tests: identical values | pass | pass | pass |
| no production save (`files/` has no `save_v3*`); WebView `Local Storage` present | pass | pass | pass |
| fresh install: `not_found` with a null error on every key, no WebView profile before the first read | pass | pass | pass |
| `webview_package` in the plugin result | `com.google.android.webview` 133.0.6943.137 | … 113.0.5672.136 | `null` + `webview_package_unavailable`; user agent `Chrome/69.0.3497.100` |
| **Total** | **55/55** | **55/55** | **54/54** |

Same-frame termination (06d, 06e; `device_*/06d_*` and `06e_*`: `plugin_raw`, `logcat`, `process`).
In all six runs the harness printed `frames_since_request: 0`, the reservation was logged on the GL
thread before the termination, and `godot_terminating` (GL thread) invalidated it while its start
was still queued; the UI step then logged `generation 1 was still queued (no WebView); its start is
discarded, nothing emitted`. Times after the request (logcat; process end from ActivityManager):

| Test | API 36 | API 34 | API 24 |
|---|---|---|---|
| 06d Godot quit: invalidated / process ended | +38 ms / +55 ms | +32 ms / +44 ms | +19 ms / +24 ms |
| 06e Activity finish: invalidated / process ended | +1,803 ms / +2,217 ms | +1,639 ms / +1,751 ms | +559 ms / +743 ms |

The delayed start was due at +5,000 ms, after the process had ended (`pidof` empty after the wait),
so no `discarded queued start` line appears: `start()`'s own stale-request rejection was not reached
on a device. In every Activity-finish case (06c, 06e) Godot 4.7.2 delivered `onGodotTerminating`
before `onMainDestroy`; `activity_destroy` found no reservation and, in 06c, destroyed the
still-active WebView. Correction report 15 handled both callbacks entirely on the UI thread, which
is why its logs showed `activity_destroy` first.

## Host checks (fresh clone of this commit's code, `host_checks/`)

| Command | Result |
|---|---|
| `npm ci`; `npx playwright install chromium` | exit 0 each |
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` | exit 0: 206 + 55 outputs identical |
| `<console exe> --headless --path godot --import` | exit 0, no ERROR/WARNING line |
| `… --script res://tests/test_runner.gd -- --suite all` | exit 0: **138 passed, 0 failed, 138 total** |
| `<console exe> --headless --path godot --quit-after 600` | exit 0, engine banner only |
| `… --suite integration --file test_export_pack` (hermetic PCK smoke) | exit 0: 32,905,976 bytes, **254** runtime resources, **512** packed files, 18 source-only paths unresolved, control resolved 18 |
| `… --script res://platform/android/m1_migration_spike/harness/m1_spike_harness_selftest.gd` | exit 0: **35 passed, 0 failed** |
| `node godot/platform/android/m1_migration_spike/tools/m1_spike_tool.mjs selftest` | exit 0: **6 passed, 0 failed** |
| `npm test`; `npm run build` | exit 0: 30 files, 248 tests; build OK |
| `git status --porcelain` (before and after); `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | exit 0, empty (HEAD was the code-only commit `c2ac3b2`, folded into the correction-16 commit with the same `godot/` tree; both diff checks were rerun on the final commit, IMPLEMENTATION_LOG.md) |
| `bash godot/tools/source_tree_guard.sh` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |

## Development attempts (`dev_attempts/`)

- Trial 1 (working tree, API 36; the upgrade APK from the working tree, the two negative APKs from
  correction report 15): 51/53. The new same-frame tests' invalidation check expected a thread name
  without spaces and missed `GLThread 48`; the plugin logs show the reservation invalidated while
  pending, no WebView and nothing emitted (`trial1_*`). The pattern was fixed and the device test now
  also records when the process ended.
- Attempt 1 (tree `329d05f`, all three emulators): 53/53, 53/53, 52/52, but in 06c the plugin
  logged `godot_terminating: generation 1 was still queued (no WebView)` after `activity_destroy`
  had destroyed that active read: the Godot-termination UI step reported any missing WebView as a
  queued start (`attempt1_*_06c_plugin_log.txt`). The behaviour was right (teardown on `main`,
  nothing emitted), the log was not. Fixed (`startedGeneration` separates "still queued" from
  "already torn down"; an invalidation with nothing reserved says `no reserved generation`), and
  06b/06c gained a log-consistency check, which fails on attempt 1's logs. Attempt 1's host checks
  were stopped after the asset check. Everything was rebuilt and rerun on this tree.
