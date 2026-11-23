# M1 legacy-save migration spike (throwaway)

Feasibility spike for MILESTONES.md M1: can a native Godot Android plugin read the five legacy
Capacitor WebView localStorage keys (`supervillained:settings`, `records`, `coins`, `story`,
`story-v1-backup`) after a genuine same-package/same-signature in-place upgrade? Results, logs and
the decision: `docs/porting/android_evidence/m1_migration_spike/`.

It is not production code. M4 owns the format-3 converter and SaveService integration; M9 owns the
production signing lineage, real user data, two WebView/device versions and MIG-001–010.

## Isolation and removal

- `platform/android/.gdignore` keeps the committed Godot project from importing, testing or packing
  anything here. Removing the spike = deleting `godot/platform/android/`.
- Nothing outside this folder is changed. `tools/build_spike_apk.ps1` builds from a scratch copy of
  `godot/` where it removes the `.gdignore`, enables `editor/plugin.cfg`, makes
  `harness/m1_spike_harness.tscn` the main scene and switches the Android preset to a gradle build
  with x86_64 (the emulator); the copy is thrown away afterwards.
- No APK, keystore, password, SDK file or device data is committed. Keystores are created outside
  the repository by `tools/new_test_keystores.ps1`.

## Parts

| Path | What |
|---|---|
| `native/src/com/zampano/svspike/MigrationSpikePlugin.java` | Godot Android v2 plugin `SvMigrationSpike`: opens the default WebView profile on `https://localhost` (Capacitor 8's origin) through request interception, calls `localStorage.getItem` for the five keys only, returns status, origin, per-key presence, raw string or null, per-key error, WebView version (API 26+; `null` with a diagnostic below) and timestamp as JSON (signal `legacy_read_completed`). No set/remove/clear, no LevelDB/SQLite parsing, no value parsing, no save, no INTERNET permission. minSdk-24 safe (guarded API 26/28 calls, Throwable-guarded diagnostics); one active read whose WebView, timeout and generation are cancelled on the UI thread on Activity destruction or Godot termination, late callbacks ignored. `readLegacyStoreHeldForLifecycleTest()` and `finishActivityForLifecycleTest()` are development-only hooks for the lifecycle test. |
| `editor/` | Editor/export plugin: adds the compiled JAR to the gradle build and its `org.godotengine.plugin.v2.SvMigrationSpike` manifest entry. |
| `harness/` | Spike main scene: checks the singleton and API, reads twice, prints `M1_SPIKE_*` logcat lines (chunked raw JSON, per-key SHA-256, idempotence, final status), quits. Malformed, empty, non-string and wrong-shape results become error results; a watchdog guarantees exactly one `M1_SPIKE_DONE`. Lifecycle modes through `user://m1_lifecycle_{quit,finish}.flag`. Driven by `adb shell am start`. `m1_spike_harness_selftest.gd` tests it on the desktop with fake plugins (`godot --headless --path godot --script res://platform/android/m1_migration_spike/harness/m1_spike_harness_selftest.gd`). |
| `tools/new_test_keystores.ps1` | Two throwaway PKCS12 keys outside the repo (upgrade lineage, wrong key). |
| `tools/build_old_capacitor_apk.ps1` | The controlled old Capacitor APK from a clean temporary clone (stock debug variant, versionCode 1, re-signed with the test key). |
| `tools/build_spike_apk.ps1` | The spike APK (javac JAR, `api_level_check.py` against the SDK's `api-versions.xml` for min SDK 24, scratch project, `--install-android-build-template --export-debug`). |
| `tools/run_upgrade_test.ps1` | The device sequence: old install, seeding through the old app's runtime (or `-SeedMode direct` where the old game cannot boot), wrong-key and wrong-package negatives, `adb install -r`, two spike runs, termination during an active read (Godot quit, Activity finished), a third run, run-as checks, fresh-install negative. |
| `tools/m1_spike_tool.mjs`, `tools/legacy_*.js` | DevTools client and page scripts for the old app; logcat reassembly and comparison. |
