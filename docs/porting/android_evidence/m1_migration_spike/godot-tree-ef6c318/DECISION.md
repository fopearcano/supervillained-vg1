# M1 migration spike — decision

**Decision: `native_bridge_viable_for_controlled_lineage`**

A native Godot Android plugin (`SvMigrationSpike`, `godot/platform/android/m1_migration_spike/`) read
all five legacy keys (`supervillained:settings`, `records`, `coins`, `story`, `story-v1-backup`) with
raw values identical to the old Capacitor app's, after a genuine in-place upgrade
(`adb install -r`, same package, same signing key, no uninstall, no data clearing). It did so on two
emulators: Android 16 / API 36 with Android System WebView 133.0.6943.137, and Android 14 / API 34
with WebView 113.0.5672.136 (30/30 checks on each, `device_api36/checks.json`,
`device_api34/checks.json`).

## Verified constraints (all must hold for the bridge to work)

1. **Same application id and signing certificate.** The upgrade kept `com.zampano.supervillained`
   and the test certificate `034b187e…2191`. Android rejected an update signed with another key
   (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`; the old app stayed installed and unchanged). A different
   application id (`com.zampano.supervillained.m1negative`) has its own, empty WebView profile and
   reported `not_found` while the old store existed.
2. **The default WebView profile and the Capacitor origin.** The old app (Capacitor 8.6.2, no
   `server` config) stores under origin `https://localhost` in the app's default WebView profile (no
   data-directory suffix). The plugin opens that profile and that origin; it checks
   `location.origin` and fails with `origin_mismatch` otherwise. An old build with another scheme or
   hostname (for example `androidScheme: 'http'` from older Capacitor defaults) needs that origin.
3. **A WebView at runtime, no network.** The read runs `localStorage.getItem` in a hidden WebView;
   the page is served by request interception, so the spike APK requests no INTERNET permission.
4. **Read-only and repeatable.** Only `getItem` on the five keys; no set/remove/clear, no
   LevelDB/SQLite access, no value parsing, no save written (`run-as` listing: no `save_v3*` file).
   Four reads in two processes per emulator returned identical values.
5. **Explicit failure, no fabricated success.** A fresh install (no old store) reports `not_found`
   with `webview_data_dir_existed_before_read: false`; a missing singleton, a timeout, an origin
   mismatch, an unavailable WebView or storage, or a per-key error reports `error`.

## Limits (not claimed)

- Emulators only (x86_64 Google APIs images); no physical device.
- A throwaway test key, debuggable builds (the old APK is the stock Capacitor `debug` variant, so
  its WebView could be driven through DevTools for seeding), and seeded representative values, not
  real user data.
- Not the production migration: M4 still owns the deterministic format-3 converter, SaveService
  integration and fixture/simulated MIG-005 (raw payload with timestamp and SHA-256 written before
  any parsing); M9 still owns the actual installed signing certificate and lineage, representative
  real user data, two representative WebView/device versions in production conditions, and
  MIG-001–010 end to end.
- Audit note for M9: the repository's Capacitor `release` build type is signed with the builder's
  debug signing config (`android/app/build.gradle`), so an in-place update of installed copies needs
  that same key; without it no in-place update is possible, whichever migration path is chosen.

## Recommendation

Use the native bridge for the M4 importer (read the five raw strings once, store them with their
SHA-256 before any parsing, then convert). Keep the staged final Capacitor export as the fallback
only if M9's production lineage cannot meet constraints 1–2.
