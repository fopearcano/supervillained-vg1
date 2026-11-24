# M1 migration spike — decision (Godot tree `51ad8b3`)

**Decision: `native_bridge_viable_for_controlled_lineage`** (unchanged from progress report 14,
`../godot-tree-ef6c318/DECISION.md`, correction report 15, `../godot-tree-cd87171/DECISION.md`, and
correction report 16, `../godot-tree-591e2df/DECISION.md`; this tree adds a same-process test of a
cancelled queued start and reruns the spike). It is a feasibility result for a controlled lineage,
not a production approval.

After a genuine in-place upgrade (`adb install -r`, same package `com.zampano.supervillained`, same
test signing key, no uninstall, no data clearing), the native Godot Android plugin
(`SvMigrationSpike`) read all five legacy keys (`supervillained:settings`, `records`, `coins`,
`story`, `story-v1-backup`) with raw values identical to the old Capacitor app's, on three
emulators: Android 16 / API 36 (Android System WebView 133.0.6943.137, 62/62 checks on the second
full run of this tree; in the first, one lifecycle test failed because Godot stalled at start-up
before the harness ran, `REPORT.md`), Android 14 /
API 34 (WebView 113.0.5672.136, 62/62) and Android 7.0 / API 24, the min SDK (WebView provider
Chrome 69.0.3497.100, 61/61).

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
   across processes and after the lifecycle tests.
5. **Explicit failure, never fabricated success:** fresh install → `not_found`; missing singleton,
   signal or method, timeout, malformed/empty/non-string/wrong-shape result, success or not_found
   with a non-null per-key error, origin mismatch, unavailable WebView or storage, per-key read
   error → `error`, with exactly one final harness line.
6. **minSdk 24 safe:** API 26/28 calls are guarded (`webview_package: null` with a diagnostic below
   API 26), checked statically against `api-versions.xml` and by running on API 24.
7. **Lifecycle:** the read's generation is reserved before its start is posted to the UI thread.
   Godot termination or Activity destruction invalidates it whether it is pending or active: an
   active read's timeout and WebView are destroyed on the UI thread and nothing is emitted; late
   callbacks are ignored. A cancelled start that is still queued stays queued and, when it runs,
   discards itself: `start()` rejects a terminated plugin, a stale epoch and an invalidated
   generation (and a finishing or destroyed Activity) before it creates a WebView. Tested on all three
   emulators with termination during an active read, in the same frame as the request (the process
   ends before the queued start is due), and with the same cancellation in a process and Activity
   that keep running past the queue delay: the queued start ran in that process and discarded
   itself with all three stale reasons, no WebView, nothing emitted. On API 36, builds without the
   stale check, without its epoch condition, or with the epoch condition alone fail that test.

## Limits (not claimed)

- Emulators only (x86_64 images); no physical device.
- Throwaway test key, debuggable builds, seeded representative values; not real user data.
- On API 24 the old game's bundle cannot boot on Chrome 69 (`Uncaught SyntaxError: Unexpected
  token .`), so the five strings it produced on API 36 were written with `setItem` in the old app's
  page: plugin compatibility evidence, not evidence of the old game's own migration on that version.
- The queued-start tests use development-only hooks: the start is posted 5 s later (the reservation
  is the production path's), and the same-process test calls the lifecycle cancellation itself
  (`cancelForLifecycleTest()`, the same `cancelForLifecycle` transition that `onMainDestroy` and
  `onGodotTerminating` run) instead of a real termination, which ends the process before the delayed
  start is due. The natural window between a request and its start was not measured.
- The spike treats a termination as final for its plugin instance (its single Activity does not come
  back); a production plugin whose host can be re-created would have to start a new epoch.
- Not the production migration: M4 owns the format-3 converter, SaveService integration and
  fixture/simulated MIG-005; M9 owns the actual installed signing certificate and lineage, real user
  data, two representative WebView/device versions in production conditions and MIG-001–010.
- Audit note for M9: the repository's Capacitor `release` build type signs with the builder's debug
  signing config, so an in-place update of installed copies needs that same key.

## Recommendation

Unchanged: use the native bridge for the M4 importer (read the five raw strings once, store them
with their SHA-256 before any parsing, then convert); keep the staged final Capacitor export as the
fallback only if M9's production lineage cannot meet constraints 1–2.
