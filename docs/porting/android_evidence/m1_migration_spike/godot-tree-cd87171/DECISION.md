# M1 migration spike — decision (Godot tree `cd87171`)

**Decision: `native_bridge_viable_for_controlled_lineage`** (unchanged from progress report 14,
`../godot-tree-ef6c318/DECISION.md`; this tree hardens the spike and reruns it).

After a genuine in-place upgrade (`adb install -r`, same package `com.zampano.supervillained`, same
test signing key, no uninstall, no data clearing), the native Godot Android plugin
(`SvMigrationSpike`) read all five legacy keys (`supervillained:settings`, `records`, `coins`,
`story`, `story-v1-backup`) with raw values identical to the old Capacitor app's, on three
emulators: Android 16 / API 36 (Android System WebView 133.0.6943.137, 43/43 checks), Android 14 /
API 34 (WebView 113.0.5672.136, 43/43) and Android 7.0 / API 24, the min SDK (WebView provider
Chrome 69.0.3497.100, 42/42).

## Verified constraints

1. **Same application id and signing certificate.** A different key cannot update the old app
   (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`, old app unchanged); a different application id has its own
   empty WebView profile and reports `not_found` while the old store exists.
2. **The default WebView profile and the Capacitor origin** `https://localhost` (Capacitor 8.6.2
   defaults, no `server` config). The plugin checks `location.origin` and fails with
   `origin_mismatch` otherwise. On Android 7 the active WebView provider was Chrome and its profile
   keeps `Local Storage` directly under `app_webview`; the read is the same.
3. **A WebView at runtime, no network:** the page is served by request interception; the spike APK
   requests no permission.
4. **Read-only and repeatable:** only `getItem` on the five keys; no save written; reads identical
   across processes and after termination tests.
5. **Explicit failure, never fabricated success:** fresh install → `not_found`; missing singleton,
   signal or method, timeout, malformed/empty/non-string/wrong-shape result, origin mismatch,
   unavailable WebView or storage, per-key error → `error`, with exactly one final harness line.
6. **minSdk 24 safe:** API 26/28 calls are guarded (`webview_package: null` with a diagnostic below
   API 26), checked statically against `api-versions.xml` and by running on API 24.
7. **Lifecycle:** Godot termination and Activity destruction during an active read cancel the
   timeout and destroy the WebView on the UI thread, emit nothing, and late callbacks are ignored.

## Limits (not claimed)

- Emulators only (x86_64 images); no physical device.
- Throwaway test key, debuggable builds, seeded representative values; not real user data.
- On API 24 the old game's bundle cannot boot on Chrome 69 (`Uncaught SyntaxError: Unexpected
  token .`), so the five strings it produced on API 36 were written with `setItem` in the old app's
  page: plugin compatibility evidence, not evidence of the old game's own migration on that version.
- Not the production migration: M4 owns the format-3 converter, SaveService integration and
  fixture/simulated MIG-005; M9 owns the actual installed signing certificate and lineage, real user
  data, two representative WebView/device versions in production conditions and MIG-001–010.
- Audit note for M9: the repository's Capacitor `release` build type signs with the builder's debug
  signing config, so an in-place update of installed copies needs that same key.

## Recommendation

Unchanged: use the native bridge for the M4 importer (read the five raw strings once, store them
with their SHA-256 before any parsing, then convert); keep the staged final Capacitor export as the
fallback only if M9's production lineage cannot meet constraints 1–2.
