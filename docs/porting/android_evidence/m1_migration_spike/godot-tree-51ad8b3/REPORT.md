# M1 legacy-save migration spike, same-process queued cancellation — evidence (Godot tree `51ad8b3`)

Correction report 17 (IMPLEMENTATION_LOG.md). The tested `godot/` tree is
`51ad8b3f029fc565c9d4237dbc903fdeab15381d`, equal to `git rev-parse <correction-17 commit>:godot`;
the three spike APKs and the three mutation APKs were built from a fresh clone of it and the host
checks ran on another fresh clone. The old Capacitor APK is the unchanged file of progress report 14
(SHA-256 `0771cd78c699d71b685507fa1267ce6b67b4b3618f8b813ea8191f885d11a89d`; its build log is
`../godot-tree-ef6c318/builds/old_capacitor_apk.txt`). Decision: `DECISION.md` (unchanged:
`native_bridge_viable_for_controlled_lineage`; not a production approval). The evidence of
correction reports 16 (`../godot-tree-591e2df/`) and 15 (`../godot-tree-cd87171/`) and progress
report 14 (`../godot-tree-ef6c318/`) is kept unchanged.

Logs are sanitized like the earlier folders (ANSI and carriage returns stripped, the local user
name and paths replaced, the test keystore passwords would be redacted; none appears). No APK,
keystore, password, SDK file or device data is committed.

## What changed since `591e2df`

- **Plugin:** one development-only hook, `cancelForLifecycleTest()`, which calls
  `cancelForLifecycle("lifecycle_test_cancel")`: the state transition that `onMainDestroy` and
  `onGodotTerminating` run (plugin terminated, epoch bumped, reservation cleared on the calling
  thread, then the UI-thread step), without ending the process or the Activity. No production path
  changed. A cancelled queued start is not removed from the UI queue (option a of the review): it
  runs when due and discards itself through `start()`'s stale check, logged as `discarded queued
  start`. That check is needed in any case for a start that has already been taken off the queue
  when the cancellation lands, which removing the runnable could not stop.
- **Harness:** mode `user://m1_lifecycle_same_process_cancel.flag`: the queued read
  (`readLegacyStoreQueuedForLifecycleTest()`, its start posted 5 s later) and, in the same frame,
  `cancelForLifecycleTest()`; no quit, no Activity finish; `M1_SPIKE_LIFECYCLE_SAME_PROCESS_DONE`
  9 s after the cancellation, then the harness idles until the device test stops the app. Self-test
  37/37 (new: this mode with nothing received, and with a fake that emits a result anyway, which
  must be reported as `result_received: true`).
- **Device test:** 06f, the same-process case (7 checks), between the same-frame termination tests
  and the recovery run, which is now 06g. Its discard check requires the exact stale reasons
  (`plugin terminated, stale epoch E (now E+1), generation invalidated (reserved: 0)`), the same
  process id on the reservation and discard lines and at the end, and the discard at least the
  queue delay after the reservation. `-SameProcessCancelCaseOnly` installs a spike build fresh and
  runs only this case (used for the mutation checks).

## Environment

As in `../godot-tree-591e2df/REPORT.md` (the same three emulators, booted the same way): `sv_m1_api36`
(`emulator-5554`, Android 16 / API 36, Android System WebView 133.0.6943.137), `sv_m1_api34`
(`emulator-5556`, Android 14 / API 34, WebView 113.0.5672.136), `sv_m1_api24` (`emulator-5558`,
Android 7.0 / API 24, WebView provider `com.android.chrome` 69.0.3497.100); `device_*/00_*.txt`.

## APKs

| APK | Package | versionCode | minSdk | Certificate SHA-256 | APK SHA-256 |
|---|---|---|---|---|---|
| old Capacitor (unchanged) | `com.zampano.supervillained` | 1 | 24 | `034b187e0b72e1567af589678c888f03dd48e58d4a920a13e9a08ace512d2191` | `0771cd78…a89d` |
| spike (upgrade) | `com.zampano.supervillained` | 2 | 24 | the same | `c01004c27d27445018058ffc2b5d585b80e2b2328651c17a9540b3567184ef82` (277,107,269 B) |
| spike, wrong key | `com.zampano.supervillained` | 2 | 24 | `b2df28e1e40cefe5918371dc1228976e5ee796f3f7a9bdb920bb3b06def97a26` | `084e1a0653e8e32792013c2b5bc9dd34c204b180391c712e8c017595dea58396` |
| spike, wrong package | `com.zampano.supervillained.m1negative` | 2 | 24 | `034b187e…2191` | `7fada722cfbfc49ead6767d1f3fd32c617bf529545170c6f6033ac4dbfb1951e` |
| mutation `no_stale_check` (API 36 case only) | `com.zampano.supervillained` | 2 | 24 | `034b187e…2191` | `dda6559b99412d80fa36f622cf1e8b63dff8f91d60fb350ca445b8e2e91ab28a` |
| mutation `no_epoch_check` (API 36 case only) | `com.zampano.supervillained` | 2 | 24 | `034b187e…2191` | `0a59180d630b9fa38d72ab8ccc2d5e8e1582263ad73d167c4722ac30b9d1641b` |
| mutation `epoch_only` (API 36 case only) | `com.zampano.supervillained` | 2 | 24 | `034b187e…2191` | `1b39be00ffad3b96ec7456c0bcdea52d20161584ae95bdda0351b37325e5cfae` |

All spike APKs: debuggable, no `uses-permission`, native code x86_64 / arm64-v8a / armeabi-v7a
(`builds/spike_badging.txt`). Static API-level check in every build: 68 Android references,
all available at API 24 except the guarded `WebView.getCurrentWebViewPackage()` (26) and
`PackageInfo.getLongVersionCode()` (28) (`builds/*.txt`, step "api level check").

## Results (`tools/run_upgrade_test.ps1`)

Expected values: identical on all three emulators and to correction reports 15 and 16 (settings
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
| 06f same process: a queued request and `cancelForLifecycleTest()` in the same frame, no quit or finish; invalidated while pending; the queued start ran in the same process after its delay and discarded itself with exactly `plugin terminated, stale epoch 0 (now 1), generation invalidated (reserved: 0)`; no WebView; nothing emitted; process and Activity still running; no crash (7 checks) | pass | pass | pass |
| 06g run 3 after the lifecycle tests: identical values | pass | pass | pass |
| no production save (`files/` has no `save_v3*`); WebView `Local Storage` present | pass | pass | pass |
| fresh install: `not_found` with a null error on every key, no WebView profile before the first read | pass | pass | pass |
| `webview_package` in the plugin result | `com.google.android.webview` 133.0.6943.137 | … 113.0.5672.136 | `null` + `webview_package_unavailable`; user agent `Chrome/69.0.3497.100` |
| **Total** | **62/62** | **62/62** | **61/61** |

API 36: the second full run of this tree (`device_api36/`). The first (`device_api36_attempt1/`, the
same APKs) ended **58/62**: in 06b the harness never started. Godot printed its banner and, 12.9 s
later, its OpenGL line (3.4–6.5 s in that run's other launches), and then neither the harness
(no `M1_SPIKE_START`) nor the plugin logged anything for the rest of the test (about 105 s); the
crash buffer had no entry. 06b's four checks that need the held read failed; its "nothing emitted"
and "no crash" checks and all of 06c–06g passed in that run, 06f included (discarded at +5,006 ms,
same process). The test records only the `godot`, `SvMigrationSpike` and `AndroidRuntime` tags, so
the cause of this start-up stall is not known; no spike code had run. The second run, with an
unfiltered logcat recorded alongside (a session file, not committed), passed 62/62 without a stall
(OpenGL line 3.6–7.7 s after the banner, harness start 0.8–1.6 s after it). The API 24 run took its
direct-seed values from the first run's `expected.json`, which is byte-identical to the second
run's, API 34's, API 24's and correction report 16's.

Same process (06f; `device_*/06f_*`: `plugin_raw`, `logcat`, `godot_raw`, `process`). Times after
the reservation line (logcat):

| 06f | API 36 | API 34 | API 24 |
|---|---|---|---|
| `lifecycle_test_cancel` invalidated the reservation (GL thread) | +0 ms | +1 ms | +0 ms |
| UI step | `generation 1 was still queued (no WebView); its start is discarded, nothing emitted` | the same | the same |
| `discarded queued start of attempt 1 (generation 1): plugin terminated, stale epoch 0 (now 1), generation invalidated (reserved: 0)` | +5,003 ms | +5,004 ms | +5,004 ms |
| process id: reservation / discard / after the case | 31170 / 31170 / 31170 | 21242 / 21242 / 21242 | 13649 / 13649 / 13649 |
| `M1_SPIKE_LIFECYCLE_SAME_PROCESS_DONE` | `ms_since_cancel` 9,256, `result_received` false | 8,935, false | 8,931, false |
| Activity after the case | `topResumedActivity` / `ResumedActivity` the spike | the same | `mResumedActivity` the spike |

No `creating the WebView`, `teardown`, `holding the page` or `emit attempt` line, no
`M1_SPIKE_LIFECYCLE_RESULT_RECEIVED` or `M1_SPIKE_DONE`, no crash-buffer entry. The device test then
stops the idling app.

Same-frame termination (06d, 06e), times after the reservation (logcat; process end from
ActivityManager): as in correction report 16, `godot_terminating` (GL thread) invalidated the
reservation while its start was queued and the process ended before the start was due at +5,000 ms
(`pidof` empty after the wait).

| Test | API 36 | API 34 | API 24 |
|---|---|---|---|
| 06d Godot quit: invalidated / process ended | +62 ms / +88 ms | +34 ms / +47 ms | +24 ms / +29 ms |
| 06e Activity finish: invalidated / process ended | +2,890 ms / +3,220 ms | +2,421 ms / +2,619 ms | +832 ms / +1,031 ms |

## Mutation checks (`mutation_api36/`)

Each mutation was applied to the plugin source of the fresh clone (`builds/mutation_*.diff.txt`),
built exactly like the upgrade APK (same test key), and the source restored; its SHA-256 was
identical after every restore (`builds/run_status.txt`). The `mutation_*.diff.txt` files were
regenerated after the runs with `git diff -U0` from the same mutation script and restored again,
because the context lines of the build-time diffs fail `git diff --check` (a space before the tab
indent); the regenerated diffs name the same post-mutation blobs (`c6a0775..3205684`,
`c6a0775..d74de62`, `c6a0775..e5a283b`). `run_upgrade_test.ps1 -SameProcessCancelCaseOnly`
installed each build fresh on API 36, ran 06f and uninstalled it, next to the unmutated upgrade APK:

| Build | Mutation | 06f | What happened |
|---|---|---|---|
| baseline (the tested source) | none | **9/9 pass** | discarded at +5,006 ms with all three reasons, same process, no WebView |
| `no_stale_check` | `start()` ignores `staleReason()` | **7/9, fail** | the queued start created a WebView at +5,009 ms (`creating the WebView`, then `ignored late page request` / `ignored late onPageFinished`); "discarded itself" and "no WebView created" failed. The late-callback guards still kept anything from being emitted |
| `no_epoch_check` | the epoch comparison removed from `staleReason()` | **8/9, fail** | discarded at +5,006 ms by the two other conditions (`plugin terminated, generation invalidated (reserved: 0)`), no WebView; the exact-reasons check failed |
| `epoch_only` | the terminated and generation conditions removed | **8/9, fail** | discarded at +5,008 ms by the epoch condition alone (`stale epoch 0 (now 1)`), no WebView; the exact-reasons check failed |

(9 checks each: the precondition, the install and the 7 of 06f.) The review's other mutation,
removing the queued-runnable removal, belongs to option b and does not apply: nothing removes the
runnable.

## Host checks (fresh clone of this commit's code, `host_checks/`)

| Command | Result |
|---|---|
| `npm ci`; `npx playwright install chromium` | exit 0 each |
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` | exit 0: 206 + 55 outputs identical |
| `<console exe> --headless --path godot --import` | exit 0, no ERROR/WARNING line |
| `… --script res://tests/test_runner.gd -- --suite all` | exit 0: **138 passed, 0 failed, 138 total** |
| `<console exe> --headless --path godot --quit-after 600` | exit 0, engine banner only |
| `… --suite integration --file test_export_pack` (hermetic PCK smoke) | exit 0: 32,905,976 bytes, **254** runtime resources, **512** packed files, 18 source-only paths unresolved, control resolved 18 |
| `… --script res://platform/android/m1_migration_spike/harness/m1_spike_harness_selftest.gd` | exit 0: **37 passed, 0 failed** |
| `node godot/platform/android/m1_migration_spike/tools/m1_spike_tool.mjs selftest` | exit 0: **6 passed, 0 failed** |
| `npm test`; `npm run build` | exit 0: 30 files, 248 tests; build OK |
| `git status --porcelain` (before and after); `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | exit 0, empty (HEAD was the code-only commit `e20cde0`, folded into the correction-17 commit with the same `godot/` tree; both diff checks were rerun on the final commit, IMPLEMENTATION_LOG.md) |
| `bash godot/tools/source_tree_guard.sh` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |

## Development attempts (`dev_attempts/`)

- Harness self-test, first version of the new case (working tree): it required `ms_since_cancel`
  of at least 500 for a 0.5 s wait and failed with 450: the headless timer runs on game time, which
  drifts from the wall clock. The self-test now requires only the field; the device test times the
  queued start from logcat timestamps.
- Trial 1 (working tree, API 36, `-SameProcessCancelCaseOnly`, the upgrade APK built from the
  working tree): 9/9; discarded at +5,006 ms with all three reasons, same process, no WebView
  (`trial1_*`).
- The first full API 36 run of this tree (58/62, a start-up stall in 06b) is described under
  Results; its logs are `device_api36_attempt1/`.
