# SUPERVILLAINED VG1 — Godot port implementation log

Evidence record per milestone (TEST_PLAN.md §21). Feature-matrix boxes stay unchecked until the
architect accepts the evidence; the matrix carries a pending-review status section instead.

The first section is the current report. Every later section is a **historical** record of the
commit it names: where one says Windows evidence was not obtained, that was true then and is
superseded by the real Windows evidence in correction report 4 and the Windows and Linux evidence
in progress report 5. Correction report 12 is current. Erratum for the historical reports: their
"nothing accepted" in the milestone-status rows means that neither milestone completion was
accepted; individual architect decisions recorded in them (for example AST-007 / finding F-15 in
correction report 11) were accepted.

---

## Correction report 12: rendered IDs back to Partial, ARCH-001a combined evidence, totals (M1 Partial, M2 Partial) — current

Scope: the architect's review of `f580fa4`, in one evidence-correction commit. The code changes are
comments in two test files (`godot/tests/integration/test_main_and_rates.gd`, `test_world.gd`); no
assertion, gameplay module, restart flow, movement, collision, camera, `PlayableDog`, animation,
audio, save, asset-pipeline, tool (the rendered probe included) or PixiJS file changed.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (neither milestone completion accepted); open M1 blocker: the migration-plugin spike; open M2 items: the rendered clauses of VIEW-004, CAM-004 and DOG-008a, and the manual desktop and touch play checks |
| Base | `f580fa4` (correction report 11) |
| Current `godot/` tree | `9bbe179546b3b600340eebe26fc364d64abd933c`, verified on a fresh Windows clone (below) |
| Host | Windows 11 Pro N for Workstations 25H2 (RTX 3090, WASAPI audio); Linux not rerun |
| Android on this host | available: Android SDK (platform-tools/adb 37.0.3, build-tools 36.1.0, platform 36), Godot's 4.7.2 Android export templates, JDK 21, emulator device `sv_m1_api36` (adb serial `emulator-5554`, Android 16 / API 36, Google WebView 133.0.6943.137). Remaining blocker: the migration plugin and a controlled signed old→new APK lineage |

### Architect decisions recorded (review of `f580fa4`)

- The acceptance of `tools/interpolation_probe.gd` as satisfying the rendered clauses of VIEW-004,
  CAM-004 and DOG-008a is withdrawn. The three IDs are **Partial** again and the probe's runs are
  **supplemental command evidence**. DOG-008a's restart-reset subclause stays satisfied.
- A probe closes them only with renderer-backed checks: exactly one connected dog component per
  frame; stable dog bounding-box dimensions, shape and pixel intensity, so a trail is rejected;
  total displacement over elapsed time compared with the expected speed tightly enough to reject
  sustained double interpolation; each static marker's absolute centroid, bounding box and pixel
  pattern; an intentional fractional-camera negative control proving shimmer detection; 30/60/90/120
  FPS; and the first rendered frame after spawn, camera snap and restart where required.
- ARCH-001a is classified as **combined evidence**: the automated dummy-host case plus the
  architect's named static review confirming no duplicate playable controller.
- AST-019 is counted consistently as command evidence; "nothing accepted" becomes "neither
  milestone completion accepted".

### Changes

1. **VIEW-004, CAM-004 and DOG-008a back to Partial.** The review allows either a strengthened probe
   or leaving the IDs partial; this correction leaves them partial and does not change the probe.
   Their suite parts are unchanged: `test_P_VIEW_004_whole_pixel_world_and_nearest_filtering`; the
   whole-pixel camera origin in `test_CAM_002_camera_clamps_small_and_large_maps` and
   `test_P_VIEW_004_…`; for DOG-008a, `test_CORE_002_logic_independent_of_render_rate` (spawn,
   teleport and camera-snap resets, shipped test-hook defaults) and
   `test_P_DOG_008a_main_restart_resets_interpolation_and_run_state`, which keeps the
   **restart-reset subclause satisfied**. Open: the rendered clauses (VIEW-004: no streak, double
   interpolation or static shimmer at 30/60/90/120 FPS; CAM-004: no static shimmer; DOG-008a: the
   30/60/90/120 FPS presentation without streaks, including the first rendered frame after spawn,
   camera snap and restart where required). TEST_PLAN.md lists the probe checks above as the
   condition for closing them. The probe's run on this tree is recorded below as supplemental
   command evidence.
2. **Restart case wording.** The case's comments now say that the replacement dog and camera reset
   physics interpolation in the entry process frame (the process frame in which they enter the
   tree), before the test's next awaited frame. The case reads back no rendered frame or pixel
   (no `frame_post_draw` or pixel-readback assertion), so correction report 11's "before that frame
   is drawn" is withdrawn. Its assertions are unchanged.
3. **ARCH-001a on combined evidence.** TEST_PLAN.md's combined-evidence rule now has two forms: a
   named architect static review for a static code-review requirement, or an architect-accepted
   renderer-backed probe for rendered clauses (none is accepted). ARCH-001a =
   `test_ARCH_001a_dummy_story_host_shares_the_green_zone_world` (dummy host scene, shared classes and
   public interfaces, chapter environment resources, `IsoGrid`/`IsoDepthSorter`, tick-for-tick
   movement, recursive cleanup) + the architect's static review of `f580fa4` (no duplicate
   playable/input movement controller). The case's comment says so.
4. **Totals.** 92 IDs by full suite cases (ARCH-001a moved out of that list) + 1 on combined
   evidence (ARCH-001a) + 1 on command evidence (AST-019) = **94**. VIEW-004, CAM-004 and DOG-008a
   are not counted until their rendered clauses pass. Correction report 11's 96 (93 + 3) counted the
   three rendered IDs and left AST-019 out of the total.
5. **"Nothing accepted".** This report says "neither milestone completion accepted"; the
   introduction of this log carries the erratum for the historical reports' "nothing accepted".
6. **FEATURE_MATRIX.md rows.** The viewport, camera and state-controller rows name their open
   rendered clauses (camera and state controller back to Partial); the shared-world row names the
   static review; the project-isolation row and the host verification name this tree.

### Legacy-save plan (unchanged; MILESTONES.md M1/M4/M9, ARCHITECTURE.md §17.2–17.3)

1. **M1 — feasibility spike, open M1 blocker:** a throwaway native migration plugin under
   `/godot/platform/android/` on a controlled same-package/same-signature old→new APK lineage; the
   five legacy keys read without mutation, or a documented reproducible failure, plus the written
   native-bridge versus staged-Capacitor decision. Not started; the tools are available (above).
2. **M4 — deterministic format-3 converter and SaveService integration**, plus the fixture/simulated
   MIG-005.
3. **M9 — production proof:** the installed lineage and signing certificate, two WebView/device
   versions, end-to-end MIG-001–010.

### M2 automated acceptance IDs

| ID | Status | Evidence |
|---|---|---|
| ARCH-001a | **satisfied (combined)** | `test_ARCH_001a_dummy_story_host_shares_the_green_zone_world` + the architect's static review of `f580fa4` (no duplicate playable/input movement controller) |
| COLL-005a | **satisfied** | `test_COLL_005a_maps_start_exit_treats_and_markers_reachable_under_the_solver` |
| DOG-005a | **satisfied** | `test_DOG_005a_…` |
| VIEW-004 | Partial | `test_P_VIEW_004_whole_pixel_world_and_nearest_filtering`; open: the rendered streak, double-interpolation and shimmer clauses (the probe is supplemental) |
| CAM-004 | Partial | whole-pixel origin in `test_CAM_002_…` and `test_P_VIEW_004_…`; open: the rendered static-shimmer clause (the probe is supplemental) |
| DOG-008a | Partial | `test_CORE_002_…` (spawn, teleport, camera snap, hook defaults); restart-reset subclause **satisfied** by `test_P_DOG_008a_main_restart_resets_interpolation_and_run_state`; open: the rendered 30/60/90/120 FPS presentation (the probe is supplemental) |
| ARCH-001b, DOG-008b / COLL-005b / DOG-005b | later | M5 / M5–M7 (aggregate M7) / M3 |

### Commands executed and results (Windows 11)

| Command | Result |
|---|---|
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all --case ARCH_001a`, then `--case DOG_008a` (working tree, after the comment edits) | `1 passed, 0 failed` each |
| Fresh `git clone` of this commit's code (`core.autocrlf=true`; tested `godot/` tree `9bbe179546b3b600340eebe26fc364d64abd933c` = `git rev-parse HEAD:godot` of this commit; only the docs and the log folder were written after it), `npm ci`, `npx playwright install chromium` | exit 0 each |
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` (deterministic asset check, AST-019) | exit 0: `asset check OK: 206 outputs identical (72 copies) …`; `build_resources check (all): OK, 55 outputs identical` |
| `<console exe> --headless --path godot --import` (clean import) | exit 0, no ERROR/WARNING lines |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all` | exit 0: **138 passed, 0 failed, 138 total** |
| `… --suite all --case ARCH_001a` (focused, fresh clone) | exit 0: `PASS test_ARCH_001a_dummy_story_host_shares_the_green_zone_world`, `1 passed, 0 failed` |
| `… --suite all --case DOG_008a` (focused restart case, fresh clone) | exit 0: `PASS test_P_DOG_008a_main_restart_resets_interpolation_and_run_state`, `1 passed, 0 failed`; recorded resets: the dog entered in process frame 549 with resets at (0, 0) (its `_ready`, before placement), then (0, 1448) twice (spawn placement, camera snap); the camera entered in process frame 549 with one reset at (0, 1328) (snapped spawn view, view 216×432); all in the entry process frame, before the test's next awaited frame (no rendered frame read back) |
| `<console exe> --headless --path godot --quit-after 600` (600-frame Main launch) | exit 0, engine banner only |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite integration --file test_export_pack` (Android-preset PCK smoke) | exit 0: PCK 32,905,976 bytes, 254 runtime resources, 512 packed files, packed 600-frame startup clean |
| `<console exe> --path godot --rendering-driver opengl3 --disable-vsync --script res://tools/interpolation_probe.gd` (unchanged probe, VSync off, RTX 3090; supplemental) | exit 0 (table below) |
| `<console exe> --path godot --script res://tools/audio_suspend_probe.gd` (real WASAPI device; run by the same script) | exit 0, `"ok":true` |
| `npm test`; `npm run build` | exit 0: 30 files, 248 tests passed; build OK |
| `git status --porcelain` (before and after every other step); `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | exit 0, all empty |
| `bash godot/tools/source_tree_guard.sh` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |
| `git diff --stat f580fa4 HEAD -- godot` | only `godot/tests/integration/test_main_and_rates.gd` and `godot/tests/integration/test_world.gd` |
| `git diff -U0 f580fa4 HEAD -- godot`, changed lines that are not `#` / `##` comments | none: comments only, no assertion changed |
| `git diff --stat f580fa4 HEAD -- godot/tests/support godot/entities godot/world godot/iso godot/main godot/scenes godot/autoload godot/systems godot/core godot/tools godot/data godot/assets src docs/porting/windows_evidence docs/porting/linux_evidence docs/porting/captures` (before the new log folder was added) | empty: runtime code, the restart flow, the dummy Story host, tools (the probe included), assets, the PixiJS source and historical evidence unchanged |
| `git diff --check` (working tree) | clean |
| `python docs_consistency_check.py` (session tool, not committed) | `OK: 55 checks` |

Logs of the fresh-clone run: `docs/porting/windows_evidence/correction-12-godot-tree-9bbe179/`. Not
run: Linux; Android device or emulator; manual play; listening to the audio.

### Rendered interpolation probe (supplemental command evidence; current tree, VSync off, RTX 3090)

`tools/interpolation_probe.gd` (unchanged since correction report 11) on the fresh clone of the
current tree, OpenGL 3.3 Compatibility on the NVIDIA GeForce RTX 3090 (driver 610.47),
`--disable-vsync`, 432×432 window; exit 0. **Supplemental command evidence**: it satisfies no
rendered clause (TEST_PLAN.md combined evidence lists the checks a probe needs for that) and is not
a suite result.

| Run | FPS cap | Achieved FPS | Repeated frames | Max px/frame (expected) | Teleport error px | ok |
|---|---|---|---|---|---|---|
| interpolation on | 30 | 30.0 | 0 | 6.5 (5.66) | 3.5 | true |
| interpolation on | 60 | 60.0 | 0 | 3.5 (2.83) | 0.5 | true |
| interpolation on | 90 | 90.0 | 0 | 2.5 (1.88) | 1.0 | true |
| interpolation on | 120 | 119.4 | 0 | 2.0 (1.42) | 1.0 | true |
| control, interpolation off | 120 | 119.9 | **21** (expected above 60 FPS) | 3.0 (1.42) | 1.0 | false by design |

Moving `CameraRig`, static markers: one distinct marker gap, 40 px, on all 48 measured frames at
90 and at 120 FPS (`ok: true` both). What this probe measures: the midpoint of the dog's bright-pixel
horizontal extent in a fixed band (repeated frames, the largest per-frame step, the teleport error)
and the gap between the two static markers' column runs. It does not check the items the architect
listed for closing the rendered clauses: one connected dog component, a stable dog bounding box,
shape and intensity, total displacement over elapsed time, each marker's absolute centroid,
bounding box and pattern, a fractional-camera negative control, and the first rendered frame after
spawn, camera snap and restart.

Host evidence: current tree above. Previous Windows trees: `a06b1df` (correction report 11, 138
passed), `1532143` (correction report 10, 137 passed), `6a3c53b` (correction report 9, 137 passed),
`b1c3595` (correction report 8, 137 passed), `b8535ab` (correction report 7 addendum, 137 passed),
`81906cd` / `fd20ac1f3c8ac95fb197fd7bcca6a5d4c2c95876` (correction report 6, 134 passed). Linux: the
prior tree `d12bedd`, 128 passed (progress report 5). Correction 6 was not rerun on Linux, and
neither were correction 7's addendum and corrections 8, 9, 10, 11 and 12.

### Deviations

| ID | Status |
|---|---|
| D-11 | Campaign save: the pure v1→v2 rules are ported (SAV-013–017). Remaining, per the approved plan: the M1 migration-plugin spike (open M1 blocker), the M4 format-3 converter, SaveService integration and fixture/simulated MIG-005, the M9 production-lineage / two WebView-device / MIG-001–010 proof |
| D-13 | Not done from M1: the Android migration-plugin spike (open M1 blocker). The Android tools and the emulator are available; missing are the plugin and a controlled signed old→new APK lineage |
| D-05, D-14, D-15 | As in progress report 5 |
| D-01–D-04, D-06–D-10 | As in correction report 1 |

### Still required before requesting M1/M2 completion review

- **M1 migration-plugin spike (open M1 blocker):** a controlled test keystore, the old Capacitor
  APK built and signed with it, a few representative saves, the spike plugin and APK with the same
  package and signature installed over it without uninstalling (`adb install -r`) on
  `sv_m1_api36`; result: the five keys read unmutated, or a documented reproducible failure, plus
  the written native-bridge / staged-Capacitor decision.
- **Manual M1 checks:** editor preview of every playable animation/direction; listening to the
  recorded and synthesized audio; approval of the title images (`captures/title_m1/`).
- **Rendered clauses of VIEW-004, CAM-004 and DOG-008a (M2):** a strengthened renderer-backed probe
  with the checks listed above (TEST_PLAN.md combined evidence), run at 30/60/90/120 FPS and accepted
  by the architect. Until then the three IDs stay Partial and are not counted.
- **Manual desktop play (M2):** five minutes with keyboard/controller; occlusion at every approach
  angle; camera bounds at map edges; crisp rendering at two window sizes and one non-integer aspect.
- **Manual touch play (M2):** five minutes on a portrait Android device or touch surface (move,
  simultaneous RUN, PEE, pointer ownership, left/right edges); touch video/capture.

### Architect review result

Pending.

---

## Historical — correction report 11: architect decisions, real restart coverage, gate removal (`f580fa4`; M1 Partial, M2 Partial)

> Historical record of `f580fa4`, superseded by correction report 12 (text below kept as
> submitted). **Supersession:** on review of `f580fa4` the architect withdrew the acceptance of the
> rendered probe for the rendered clauses of VIEW-004, CAM-004 and DOG-008a: the three IDs are
> Partial again and the probe is supplemental command evidence, so the "Architect decisions
> recorded" below, the "satisfied (combined)" rows, "No automated M2 acceptance ID remains
> unsatisfied" and the total of 96 are superseded (correction report 12: 94, with AST-019 counted
> as command evidence). DOG-008a's restart-reset subclause stays satisfied. ARCH-001a is combined
> evidence (its case plus the architect's static review of `f580fa4`). The restart case's "before
> that frame is drawn" is restated as "in the entry process frame, before the test's next awaited
> frame": the case reads back no rendered frame or pixel. "Nothing accepted" means that neither
> milestone completion was accepted.

Scope: the architect's decisions and required changes on `6b91fd3`, in one commit. Code changes
are in two test files (`godot/tests/integration/test_world.gd`, `test_main_and_rates.gd`); no
gameplay module, movement, collision, camera, `PlayableDog`, animation, audio, save, asset-pipeline
or PixiJS file changed.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (nothing accepted); open M1 blocker: the migration-plugin spike; open M2 items: the manual desktop and touch play checks |
| Base | `6b91fd3` (correction report 10) |
| Current `godot/` tree | `a06b1df5e3db91f0fc7690785d94932fdf6bca24`, verified on a fresh Windows clone (below) |
| Host | Windows 11 Pro N for Workstations 25H2 (RTX 3090, WASAPI audio); Linux not rerun |
| Android on this host | available: Android SDK (platform-tools/adb 37.0.3, build-tools 36.1.0, platform 36), Godot's 4.7.2 Android export templates, JDK 21, emulator device `sv_m1_api36` (adb serial `emulator-5554`, Android 16 / API 36, Google WebView 133.0.6943.137). Remaining blocker: the migration plugin and a controlled signed old→new APK lineage |

### Architect decisions recorded (review of `6b91fd3`)

- The current-tree rendered interpolation probe (`tools/interpolation_probe.gd`) was rerun
  independently on an RTX 3090 with VSync disabled and passed at 30/60/90/120 FPS. It is accepted as
  **command-level rendered evidence** (TEST_PLAN.md "Combined evidence"): **VIEW-004** and
  **CAM-004** are accepted; DOG-008a's rendered presentation and teleport-reset clauses are
  accepted, and DOG-008a was left incomplete only for the missing real restart-path assertion.
- **AST-007 / finding F-15 accepted:** the sword and shield are baked into the armoured frames, so
  shared frame and foot-anchor alignment is the applicable contract.
- The rendered clauses did not run in the headless suite; the matrix and this report name the probe
  for them.

### Changes

1. **Source-parser gate removed.** `_code_only()`, `_matches()`, `_duplicate_player_controllers()`,
   their synthetic source samples, the repository-wide source scan and its positive control are gone
   from `test_world.gd`. "No duplicate playable/input movement controller" is now a static
   code-review requirement (TEST_PLAN.md ARCH-001, ARCH-001a): only `PlayableDog` turns player input
   into movement; `ActorBody` controllers (NPCs, cats, Bagnaskiz, companions, combat actors) may use
   approved behaviour controllers with the shared `WorldMapModel` solver. Kept in
   `test_ARCH_001a_dummy_story_host_shares_the_green_zone_world`: the real dummy Story host scene;
   the shared `IsoWorld`, `PlayableDog` and `CameraRig` scenes, scripts and public interfaces; the
   host's distinct chapter environment resources; `IsoGrid` placement and `IsoDepthSorter` ranking;
   tick-for-tick movement equivalence; lifecycle and cleanup, now checked recursively (every
   descendant of the host, world, dog and camera included, is freed).
2. **Real restart coverage for DOG-008a:**
   `test_P_DOG_008a_main_restart_resets_interpolation_and_run_state` (in `test_main_and_rates.gd`)
   uses only the shipped flow. Main starts the Green Zone with its real ticks and briefing; Enter
   (a key event) closes the briefing; the dog walks on `InputService` movement in real 60 Hz physics
   ticks and pees (Space), so the dog and the camera have interpolation history; Esc opens the pause
   menu; Down and Enter choose RESTART, whose `restart_requested` reaches `Main.start_green_zone`
   (the existing deferred scene replacement). No replacement dog is created by the test and there
   is no test-only gameplay path. It verifies:
   - the old scene, dog, camera and pause menu are freed; one scene, one `PlayableDog` and one
     `CameraRig` remain, the replacement camera is current and only the new briefing is shown;
   - the replacement dog starts at the canonical spawn (`GreenZoneLevel` start, exact grid
     coordinates and spawn pixel), at rest;
   - interpolation: an observation-only child node added as each replacement dog and camera enters
     the tree records every `NOTIFICATION_RESET_PHYSICS_INTERPOLATION` with its process frame and
     position. Both reset in the process frame in which they enter the tree, before that frame is
     drawn; the dog's last reset is at the spawn pixel and the camera's at the snapped spawn view;
     no reset of either is at the old run's position; the runtime reset counters agree; the dog then
     stays on the spawn pixel under the briefing;
   - nothing of the old run survives: fresh stats (`ScoringRules.new_stats` with the settings'
     lives), all 30 treats, playing state, full bladder, start hunger and energy, an unpolluted map,
     the briefing music;
   - settings persist: non-default volume, text speed, lives, run toggle and left hand are
     unchanged in `SaveService` and `AppState`, still applied to `InputService` and `AudioService`,
     and the lives setting drives the new run's speed; the selected profile is kept.
   Mutation check (working tree, reverted before the commit; not in the logs): without the dog's
   placement and camera-snap resets the case fails ("dog: last entry-frame reset at the spawn view
   expected (0.0, 1448.0), got (0.0, 0.0)"); without the camera snap's reset it fails ("camera:
   interpolation reset in its entry frame … ([])").
3. **Evidence wording.** TEST_PLAN.md: the combined-evidence rule (a rendered clause may be
   satisfied by an architect-accepted command-level probe; every other clause by named suite cases;
   rendered clauses never presented as suite results); ARCH-001/ARCH-001a state the code-review
   requirement. FEATURE_MATRIX.md: VIEW-004, CAM-004 and DOG-008a satisfied on combined evidence
   (96 IDs in total), the probe listed as accepted command-level evidence, AST-007/F-15 accepted,
   the viewport, camera, state-controller and shared-world rows updated.

### Legacy-save plan (unchanged; MILESTONES.md M1/M4/M9, ARCHITECTURE.md §17.2–17.3)

1. **M1 — feasibility spike, open M1 blocker:** a throwaway native migration plugin under
   `/godot/platform/android/` on a controlled same-package/same-signature old→new APK lineage; the
   five legacy keys read without mutation, or a documented reproducible failure, plus the written
   native-bridge versus staged-Capacitor decision. Not started; the tools are available (above).
2. **M4 — deterministic format-3 converter and SaveService integration**, plus the fixture/simulated
   MIG-005.
3. **M9 — production proof:** the installed lineage and signing certificate, two WebView/device
   versions, end-to-end MIG-001–010.

### M2 automated acceptance IDs

| ID | Status | Evidence |
|---|---|---|
| ARCH-001a | **satisfied** | `test_ARCH_001a_dummy_story_host_shares_the_green_zone_world` (no duplicate controller: static code-review requirement) |
| COLL-005a | **satisfied** | `test_COLL_005a_maps_start_exit_treats_and_markers_reachable_under_the_solver` |
| DOG-005a | **satisfied** | `test_DOG_005a_…` |
| VIEW-004 | **satisfied (combined)** | `test_P_VIEW_004_whole_pixel_world_and_nearest_filtering` + the accepted rendered probe |
| CAM-004 | **satisfied (combined)** | whole-pixel origin in `test_CAM_002_…` and `test_P_VIEW_004_…` + the probe's static-shimmer pass |
| DOG-008a | **satisfied (combined)** | `test_CORE_002_…` (spawn, teleport, camera snap, hook defaults) + `test_P_DOG_008a_main_restart_resets_interpolation_and_run_state` (restart) + the accepted probe (presentation, teleport) |
| ARCH-001b, DOG-008b / COLL-005b / DOG-005b | later | M5 / M5–M7 (aggregate M7) / M3 |

### Commands executed and results (Windows 11)

| Command | Result |
|---|---|
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all --case DOG_008a` (working tree, while writing it) | after two test-side fixes (the selection was read one frame early; a lambda held the freed old scene): `1 passed, 0 failed` |
| Mutation check of that case (working tree; runtime files restored and confirmed by `git status` before the commit) | fails without the dog's placement and camera-snap resets, and fails without the camera snap's reset (messages in "Changes" above) |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all` (working tree) | `138 passed, 0 failed, 138 total` |
| Fresh `git clone` of this commit's code (`core.autocrlf=true`; tested `godot/` tree `a06b1df5e3db91f0fc7690785d94932fdf6bca24` = `git rev-parse HEAD:godot` of this commit; only the docs and the log folder were written after it), `npm ci`, `npx playwright install chromium` | exit 0 each |
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` (deterministic asset check) | exit 0: `asset check OK: 206 outputs identical (72 copies) …`; `build_resources check (all): OK, 55 outputs identical` |
| `<console exe> --headless --path godot --import` (clean import) | exit 0, no ERROR/WARNING lines |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all` | exit 0: **138 passed, 0 failed, 138 total** |
| `… --suite all --case ARCH_001a` (focused, fresh clone) | exit 0: `PASS test_ARCH_001a_dummy_story_host_shares_the_green_zone_world`, `1 passed, 0 failed` |
| `… --suite all --case DOG_008a` (focused restart case, fresh clone) | exit 0: `PASS test_P_DOG_008a_main_restart_resets_interpolation_and_run_state`, `1 passed, 0 failed`; recorded resets: dog entered frame 553 with resets at (0, 0) (its `_ready`, before placement), then (0, 1448) twice (spawn placement, camera snap); camera entered frame 553 with one reset at (0, 1328) (snapped spawn view, view 216×432) |
| `<console exe> --headless --path godot --quit-after 600` (600-frame Main launch) | exit 0, engine banner only |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite integration --file test_export_pack` (Android-preset PCK smoke) | exit 0: PCK 32,905,976 bytes, 254 runtime resources, 512 packed files, packed 600-frame startup clean |
| `<console exe> --path godot --rendering-driver opengl3 --disable-vsync --script res://tools/interpolation_probe.gd` (rendered probe, VSync off, RTX 3090) | exit 0 (table below) |
| `<console exe> --path godot --script res://tools/audio_suspend_probe.gd` (real WASAPI device; run by the same script) | exit 0, `"ok":true` |
| `npm test`; `npm run build` | exit 0: 30 files, 248 tests passed; build OK |
| `git status --porcelain` (before and after every other step); `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | exit 0, all empty |
| `bash godot/tools/source_tree_guard.sh` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |
| `git diff --stat 6b91fd3 HEAD -- godot` | only `godot/tests/integration/test_main_and_rates.gd` and `godot/tests/integration/test_world.gd` |
| `git diff --stat 6b91fd3 HEAD -- godot/tests/support godot/entities godot/world godot/iso godot/main godot/scenes godot/autoload godot/systems godot/core godot/tools godot/data godot/assets src docs/porting/windows_evidence docs/porting/linux_evidence docs/porting/captures` (before the new log folder was added) | empty: runtime code, the dummy Story host, tools, assets, the PixiJS source and historical evidence unchanged |
| `git diff --check` (working tree) | clean |
| `python docs_consistency_check.py` (session tool, not committed) | `OK: 51 checks` |

Logs of the fresh-clone run: `docs/porting/windows_evidence/correction-11-godot-tree-a06b1df/`. Not
run: Linux; Android device or emulator; manual play; listening to the audio.

### Rendered interpolation probe (current tree, VSync off, RTX 3090)

`tools/interpolation_probe.gd` on the fresh clone of the current tree, OpenGL 3.3 Compatibility on the
NVIDIA GeForce RTX 3090 (driver 610.47), `--disable-vsync`, 432×432 window; exit 0. Command-level
rendered evidence, not a suite result.

| Run | FPS cap | Achieved FPS | Repeated frames | Max px/frame (expected) | Teleport error px | ok |
|---|---|---|---|---|---|---|
| interpolation on | 30 | 30.0 | 0 | 6.5 (5.65) | 4.5 | true |
| interpolation on | 60 | 60.0 | 0 | 3.5 (2.83) | 1.5 | true |
| interpolation on | 90 | 90.2 | 0 | 2.5 (1.88) | 1.0 | true |
| interpolation on | 120 | 120.0 | 0 | 2.5 (1.41) | 1.0 | true |
| control, interpolation off | 120 | 120.0 | **21** (expected above 60 FPS) | 3.0 (1.41) | 1.0 | false by design |

Moving `CameraRig`, static markers: one distinct marker gap, 40 px, on all 48 measured frames at
90 and at 120 FPS (`ok: true` both). No repeated frame (stutter or streak), no jump beyond two
frames' worth (double interpolation), the teleport shows the new position at once, and the control
proves the metric detects repeats.

Host evidence: current tree above. Previous Windows trees: `1532143` (correction report 10, 137
passed), `6a3c53b` (correction report 9, 137 passed), `b1c3595` (correction report 8, 137
passed), `b8535ab` (correction report 7 addendum, 137 passed), `81906cd` /
`fd20ac1f3c8ac95fb197fd7bcca6a5d4c2c95876` (correction report 6, 134 passed). Linux: the prior tree
`d12bedd`, 128 passed (progress report 5). Correction 6 was not rerun on Linux, and neither were
correction 7's addendum and corrections 8, 9, 10 and 11.

### Deviations

| ID | Status |
|---|---|
| D-11 | Campaign save: the pure v1→v2 rules are ported (SAV-013–017). Remaining, per the approved plan: the M1 migration-plugin spike (open M1 blocker), the M4 format-3 converter, SaveService integration and fixture/simulated MIG-005, the M9 production-lineage / two WebView-device / MIG-001–010 proof |
| D-13 | Not done from M1: the Android migration-plugin spike (open M1 blocker). The Android tools and the emulator are available; missing are the plugin and a controlled signed old→new APK lineage |
| D-05, D-14, D-15 | As in progress report 5 |
| D-01–D-04, D-06–D-10 | As in correction report 1 |

### Still required before requesting M1/M2 completion review

- **M1 migration-plugin spike (open M1 blocker):** a controlled test keystore, the old Capacitor
  APK built and signed with it, a few representative saves, the spike plugin and APK with the same
  package and signature installed over it without uninstalling (`adb install -r`) on
  `sv_m1_api36`; result: the five keys read unmutated, or a documented reproducible failure, plus
  the written native-bridge / staged-Capacitor decision.
- **Manual M1 checks:** editor preview of every playable animation/direction; listening to the
  recorded and synthesized audio; approval of the title images (`captures/title_m1/`).
- **Manual desktop play (M2):** five minutes with keyboard/controller; occlusion at every approach
  angle; camera bounds at map edges; crisp rendering at two window sizes and one non-integer aspect.
- **Manual touch play (M2):** five minutes on a portrait Android device or touch surface (move,
  simultaneous RUN, PEE, pointer ownership, left/right edges); touch video/capture.
- No automated M2 acceptance ID remains unsatisfied.

### Architect review result

Pending.

---

## Historical — correction report 10: ARCH-001a static gate and collision-row wording (`6b91fd3`; M1 Partial, M2 Partial)

> Historical record of `6b91fd3`, superseded by correction report 11 (text below kept as
> submitted). **Supersession:** on review of `6b91fd3` the architect replaced its ARCH-001a static
> source-parser gate with a static code-review requirement (the gate's code is removed), accepted
> the rendered probe for VIEW-004 and CAM-004 and for DOG-008a's rendered presentation and
> teleport-reset clauses, and accepted AST-007 / finding F-15. Its "Unsatisfied automated M2
> gates" list (VIEW-004, CAM-004 pending the gate decision; DOG-008a) is superseded: VIEW-004 and
> CAM-004 are satisfied on combined evidence, and DOG-008a on combined evidence with the real
> restart case added in correction report 11.

Scope: the architect's two items on `d7933a7`, in one commit. Code changes are in one test file
(`godot/tests/integration/test_world.gd`: the ARCH-001a gate and its synthetic cases); no gameplay
module, no PixiJS file, and neither the dummy Story host scene nor its lifecycle changed.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (nothing accepted); open M1 blocker: the migration-plugin spike |
| Base | `d7933a7` (correction report 9) |
| Current `godot/` tree | `15321434e94325b632bc38bb2a40246e0577ad08`, verified on a fresh Windows clone (below) |
| Host | Windows 11 Pro N for Workstations 25H2 (RTX 3090, WASAPI audio); Linux not rerun |
| Android on this host | available: Android SDK (platform-tools/adb 37.0.3, build-tools 36.1.0, platform 36), Godot's 4.7.2 Android export templates, JDK 21, emulator device `sv_m1_api36` (adb serial `emulator-5554`, Android 16 / API 36, Google WebView 133.0.6943.137). Remaining blocker: the migration plugin and a controlled signed old→new APK lineage |

### Changes per review item

1. **`_duplicate_player_controllers()` refined.** Defining `update_movement` or `set_intent` is no
   longer evidence by itself. A runtime script other than `PlayableDog` is flagged only on
   player-specific evidence: both playable-controller methods outside an `ActorBody` controller; a
   `PlayableDog` subclass overriding either method; direct `InputService`-to-body movement (player
   input fed to the solver or a physics body, actors included); or moving the player's body itself
   (writing a `PlayableDog`/player position or velocity). `ActorBody` controllers (ARCHITECTURE §9:
   NPCs, cats, Bagnaskiz, combat foes, companions; a script that is, extends or owns an `ActorBody`)
   may define both methods and use the shared `WorldMapModel` solver. Comments and string literals
   are blanked before matching (`_code_only`). Synthetic cases in the ARCH-001a case: allowed —
   `ActorBody` itself with both methods, a cat with `update_movement`, a Bagnaskiz behaviour
   controller owning an `ActorBody` with both methods, a companion with both, a script naming the
   methods only in comments and strings, and a rules-like script routing input to the
   `PlayableDog`; flagged — a non-actor body with both methods, a `PlayableDog` subclass overriding
   `update_movement`, an input-fed `move_circle` mover, a script writing `player.gx`, and an
   `ActorBody` driven straight by `InputService`. The scan of every runtime script finds nothing,
   and a positive control on real code (the real `PlayableDog` source under another path) is
   flagged. TEST_PLAN.md (ARCH-001, ARCH-001a) and FEATURE_MATRIX state the same rule.
2. **FEATURE_MATRIX collision row:** "COLL-005b literal-coordinate story objectives" now reads
   "COLL-005b scripted-position story objectives", as in TEST_PLAN.md.

### Legacy-save plan (unchanged; MILESTONES.md M1/M4/M9, ARCHITECTURE.md §17.2–17.3)

1. **M1 — feasibility spike, open M1 blocker:** a throwaway native migration plugin under
   `/godot/platform/android/` on a controlled same-package/same-signature old→new APK lineage; the
   five legacy keys read without mutation, or a documented reproducible failure, plus the written
   native-bridge versus staged-Capacitor decision. Not started; the tools are available (above).
2. **M4 — deterministic format-3 converter and SaveService integration**, plus the fixture/simulated
   MIG-005.
3. **M9 — production proof:** the installed lineage and signing certificate, two WebView/device
   versions, end-to-end MIG-001–010.

### M2 automated gates

| ID | Status | Evidence / milestone |
|---|---|---|
| ARCH-001a | **satisfied** | `test_ARCH_001a_dummy_story_host_shares_the_green_zone_world` (refined gate, this report) |
| COLL-005a | **satisfied** | `test_COLL_005a_maps_start_exit_treats_and_markers_reachable_under_the_solver` (correction report 8) |
| DOG-005a | satisfied | `test_DOG_005a_…` (correction report 7 addendum) |
| VIEW-004, CAM-004 | **not satisfied** | rendered clauses only by `tools/interpolation_probe.gd` outside the suite; gate decision not taken |
| DOG-008a | **not satisfied** | rendered presentation clause (same decision); restart reset not asserted separately |
| ARCH-001b, DOG-008b / COLL-005b / DOG-005b | later | M5 / M5–M7 (aggregate M7) / M3 |

### Commands executed and results (Windows 11)

| Command | Result |
|---|---|
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all --case ARCH_001a` (working tree, twice while writing it) | `1 passed, 0 failed` each |
| Fresh `git clone` of this commit's code (`core.autocrlf=true`; tested `godot/` tree `15321434e94325b632bc38bb2a40246e0577ad08` = `git rev-parse HEAD:godot` of this commit; only the docs and the log folder were written after it), `npm ci`, `npx playwright install chromium` | exit 0 each |
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` (asset check) | exit 0: `asset check OK: 206 outputs identical (72 copies) …`; `build_resources check (all): OK, 55 outputs identical` |
| `<console exe> --headless --path godot --import` | exit 0, no ERROR/WARNING lines |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all` | exit 0: **137 passed, 0 failed, 137 total** |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all --case ARCH_001a` (focused, in the fresh clone) | exit 0: `PASS test_ARCH_001a_dummy_story_host_shares_the_green_zone_world`, `1 passed, 0 failed` |
| `<console exe> --headless --path godot --quit-after 600` | exit 0, engine banner only |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite integration --file test_export_pack` (PCK smoke) | exit 0: PCK 32,905,976 bytes, 254 runtime resources, 512 packed files, packed 600-frame startup clean |
| `<console exe> --path godot --script res://tools/audio_suspend_probe.gd` (real WASAPI device; run by the same script) | exit 0, `"ok":true` |
| `npm test`; `npm run build` | exit 0: 248 tests passed; build OK |
| `git status --porcelain`; `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | exit 0, all empty |
| `bash godot/tools/source_tree_guard.sh` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |
| `git diff --stat d7933a7 -- godot` (working tree) | only `godot/tests/integration/test_world.gd` |
| `git diff --stat d7933a7 -- godot/tests/support` | empty: the dummy Story host scene and its lifecycle are unchanged |
| `git diff --stat d7933a7 -- docs/porting/windows_evidence docs/porting/linux_evidence docs/porting/captures` (before the new log folder was added) | empty: historical evidence unchanged |
| `git diff --check` (working tree) | clean |
| `python docs_consistency_check.py` (session tool, not committed) | `OK: 46 checks` |

Logs of the fresh-clone run: `docs/porting/windows_evidence/correction-10-godot-tree-1532143/`. Not
run: Linux, the rendered interpolation probe (nothing rendered changed).

Host evidence: current tree above. Previous Windows trees: `6a3c53b` (correction report 9, 137
passed), `b1c3595` (correction report 8, 137 passed), `b8535ab` (correction report 7 addendum, 137
passed), `81906cd` / `fd20ac1f3c8ac95fb197fd7bcca6a5d4c2c95876` (correction report 6, 134 passed).
Linux: the prior tree `d12bedd`, 128 passed (progress report 5). Correction 6 was not rerun on
Linux, and neither were correction 7's addendum and corrections 8, 9 and 10.

### Deviations

| ID | Status |
|---|---|
| D-11 | Campaign save: the pure v1→v2 rules are ported (SAV-013–017). Remaining, per the approved plan: the M1 migration-plugin spike (open M1 blocker), the M4 format-3 converter, SaveService integration and fixture/simulated MIG-005, the M9 production-lineage / two WebView-device / MIG-001–010 proof |
| D-13 | Not done from M1: the Android migration-plugin spike (open M1 blocker). The Android tools and the emulator are available; missing are the plugin and a controlled signed old→new APK lineage |
| D-05, D-14, D-15 | As in progress report 5 |
| D-01–D-04, D-06–D-10 | As in correction report 1 |

### Still required before requesting M1/M2 completion review

- **M1 migration-plugin spike (open M1 blocker):** a controlled test keystore, the old Capacitor
  APK built and signed with it, a few representative saves, the spike plugin and APK with the same
  package and signature installed over it without uninstalling (`adb install -r`) on
  `sv_m1_api36`; result: the five keys read unmutated, or a documented reproducible failure, plus
  the written native-bridge / staged-Capacitor decision.
- **Unsatisfied automated M2 gates:** **VIEW-004** and **CAM-004** (gate decision not taken: accept
  the probe evidence, or add an in-suite rendered case); **DOG-008a** (the same rendered clause and
  a restart-reset assertion).
- **Manual desktop play (M2):** five minutes with keyboard/controller; occlusion at every approach
  angle; camera bounds at map edges; crisp rendering at two window sizes and one non-integer aspect.
- **Manual touch play (M2):** five minutes on a portrait Android device or touch surface (move,
  simultaneous RUN, PEE, pointer ownership, left/right edges); touch video/capture.
- **Manual M1 checks:** editor preview of every playable animation/direction; listening to the
  recorded and synthesized audio; approval of the title images (`captures/title_m1/`).

### Architect review result

Pending.

---

## Historical — correction report 9: ARCH-001a contract and COLL-005 ownership (`d7933a7`; M1 Partial, M2 Partial)

> Historical record of `d7933a7`, superseded by correction report 10. **Erratum** (text below kept
> as submitted): its static gate flagged any script other than `PlayableDog` that merely defined
> `update_movement` or `set_intent`, which would also flag approved `ActorBody` controllers, and it
> matched names inside comments and strings; correction report 10 requires player-specific
> evidence and ignores comments and strings. Its FEATURE_MATRIX collision row still said
> "literal-coordinate story objectives" (now "scripted-position", as in TEST_PLAN.md).

Scope: the architect's three items on `5435c32`, in one commit. Code changes are test files only
(the dummy Story host scene and the ARCH-001a case); no gameplay module, the continuous COLL-005a
driver and the PixiJS source are untouched.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (nothing accepted); open M1 blocker: the migration-plugin spike |
| Base | `5435c32` (correction report 8) |
| Current `godot/` tree | `6a3c53bb9bf2c0cfc14e9c569ec03015543b914c`, verified on a fresh Windows clone (below) |
| Host | Windows 11 Pro N for Workstations 25H2 (RTX 3090, WASAPI audio); Linux not rerun |
| Android on this host | available: Android SDK (platform-tools/adb 37.0.3, build-tools 36.1.0, platform 36), Godot's 4.7.2 Android export templates, JDK 21, emulator device `sv_m1_api36` (adb serial `emulator-5554`, Android 16 / API 36, Google WebView 133.0.6943.137). Remaining blocker: the migration plugin and a controlled signed old→new APK lineage |

### Changes per review item

1. **ARCH-001a contract corrected** (TEST_PLAN.md ARCH-001 and ARCH-001a, the case, FEATURE_MATRIX,
   this report). Required now: the same `IsoWorld`, `PlayableDog` and `CameraRig` classes **and
   public interfaces** (public methods with argument counts and public variables, compared), with
   `IsoGrid` placing and `IsoDepthSorter` ranking both worlds; **not** the same tile set or sprite
   catalogue. The dummy Story host gained `environment_tileset`, `environment_catalog` and
   `environment_id`, applied through the world's public properties before `setup()`; the case gives
   it its own resource instances and checks that the story world uses them (ground layers, catalogue,
   bank id) while the Green Zone keeps `ch01_greenzone`. The static no-fork rule is scoped to
   **duplicate playable/input movement controllers**: a runtime script other than `PlayableDog` that
   defines the playable controller API (`update_movement`, `set_intent`) or reads player movement
   input and moves a body. Actor controllers (ActorBody, cats, Bagnaskiz, companions) may move with
   approved behaviour controllers on the shared `WorldMapModel` solver; the case first checks the
   rule's scope on four synthetic scripts (two actor controllers using `move_circle` pass, a second
   playable controller and an input-reading mover are flagged), then scans every runtime script.
   ARCH-001a stays claimed on `test_ARCH_001a_dummy_story_host_shares_the_green_zone_world`, which
   passes in its corrected form.
2. **COLL-005 ownership** (TEST_PLAN.md): COLL-005 is redefined as static and scripted-position
   reachability (spawn/start/exit and every statically placed or scripted-position objective);
   dynamic goals (moving or runtime-placed targets and action zones) are explicitly not COLL-005 and
   are owned by WALK, NPC, MINI and each scene's STY real-input completion. COLL-005a and COLL-005b
   are unchanged: `test_P_COLL_005b_…` evidence in M5/M6, the full `test_COLL_005b_…` aggregate in
   M7. The continuous COLL-005a driver is unchanged.
3. **Project-isolation row** (FEATURE_MATRIX): CORE-001 now cites the current Windows tree
   (this report) and, before it, correction report 8's `b1c3595`; the old `81906cd` reference is
   gone; Linux stays the prior tree `d12bedd`.

### Legacy-save plan (unchanged; MILESTONES.md M1/M4/M9, ARCHITECTURE.md §17.2–17.3)

1. **M1 — feasibility spike, open M1 blocker:** a throwaway native migration plugin under
   `/godot/platform/android/` on a controlled same-package/same-signature old→new APK lineage; the
   five legacy keys read without mutation, or a documented reproducible failure, plus the written
   native-bridge versus staged-Capacitor decision. Not started; the tools are available (above).
2. **M4 — deterministic format-3 converter and SaveService integration**, plus the fixture/simulated
   MIG-005.
3. **M9 — production proof:** the installed lineage and signing certificate, two WebView/device
   versions, end-to-end MIG-001–010.

### M2 automated gates

| ID | Status | Evidence / milestone |
|---|---|---|
| ARCH-001a | **satisfied** | `test_ARCH_001a_dummy_story_host_shares_the_green_zone_world` (corrected contract, this report) |
| COLL-005a | **satisfied** | `test_COLL_005a_maps_start_exit_treats_and_markers_reachable_under_the_solver` (correction report 8) |
| DOG-005a | satisfied | `test_DOG_005a_…` (correction report 7 addendum) |
| VIEW-004, CAM-004 | **not satisfied** | rendered clauses only by `tools/interpolation_probe.gd` outside the suite; gate decision not taken |
| DOG-008a | **not satisfied** | rendered presentation clause (same decision); restart reset not asserted separately |
| ARCH-001b, DOG-008b / COLL-005b / DOG-005b | later | M5 / M5–M7 (aggregate M7) / M3 |

### Commands executed and results (Windows 11)

| Command | Result |
|---|---|
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all --case ARCH_001a` (working tree, while writing it) | `1 passed, 0 failed` |
| Fresh `git clone` of this commit's code (`core.autocrlf=true`; tested `godot/` tree `6a3c53bb9bf2c0cfc14e9c569ec03015543b914c` = `git rev-parse HEAD:godot` of this commit; only the docs and the log folder were written after it), `npm ci`, `npx playwright install chromium` | exit 0 each |
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` (asset reproducibility) | exit 0: `asset check OK: 206 outputs identical (72 copies) …`; `build_resources check (all): OK, 55 outputs identical` |
| `<console exe> --headless --path godot --import` (clean import) | exit 0, no ERROR/WARNING lines |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all` | exit 0: **137 passed, 0 failed, 137 total**, including `test_ARCH_001a_dummy_story_host_shares_the_green_zone_world`, `test_COLL_005a_…`, `test_DOG_005a_…` |
| `<console exe> --headless --path godot --quit-after 600` | exit 0, engine banner only |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite integration --file test_export_pack` (PCK smoke) | exit 0: PCK 32,905,976 bytes, 254 runtime resources, 512 packed files, packed 600-frame startup clean |
| `<console exe> --path godot --script res://tools/audio_suspend_probe.gd` (real WASAPI device; run by the same script) | exit 0, `"ok":true` |
| `npm test`; `npm run build` | exit 0: 248 tests passed; build OK |
| `git status --porcelain`; `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | exit 0, all empty |
| `bash godot/tools/source_tree_guard.sh` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |
| `git diff --stat 5435c32 -- godot` (working tree) | only `godot/tests/integration/test_world.gd` and `godot/tests/support/dummy_story_scene.gd` |
| Python comparison of `test_world.gd` from `## Drives a PlayableDog…` to the end against `git show 5435c32:godot/tests/integration/test_world.gd` | identical: the COLL-005a driver and case are unchanged |
| `git diff --stat 5435c32 -- docs/porting/windows_evidence docs/porting/linux_evidence docs/porting/captures` (working tree, before the new log folder was added) | empty: historical evidence unchanged |
| `git diff --check` (working tree) | clean |
| `python docs_consistency_check.py` (session tool, not committed) | `OK: 42 checks` |

Logs of the fresh-clone run: `docs/porting/windows_evidence/correction-9-godot-tree-6a3c53b/`. Not
run: Linux, the rendered interpolation probe (nothing rendered changed).

Host evidence: current tree above. Previous Windows trees: `b1c3595` (correction report 8, 137
passed), `b8535ab` (correction report 7 addendum, 137 passed), `81906cd` /
`fd20ac1f3c8ac95fb197fd7bcca6a5d4c2c95876` (correction report 6, 134 passed). Linux: the prior tree
`d12bedd`, 128 passed (progress report 5). Correction 6 was not rerun on Linux, and neither were
correction 7's addendum and corrections 8 and 9.

### Deviations

| ID | Status |
|---|---|
| D-11 | Campaign save: the pure v1→v2 rules are ported (SAV-013–017). Remaining, per the approved plan: the M1 migration-plugin spike (open M1 blocker), the M4 format-3 converter, SaveService integration and fixture/simulated MIG-005, the M9 production-lineage / two WebView-device / MIG-001–010 proof |
| D-13 | Not done from M1: the Android migration-plugin spike (open M1 blocker). The Android tools and the emulator are available; missing are the plugin and a controlled signed old→new APK lineage |
| D-05, D-14, D-15 | As in progress report 5 |
| D-01–D-04, D-06–D-10 | As in correction report 1 |

### Still required before requesting M1/M2 completion review

- **M1 migration-plugin spike (open M1 blocker):** a controlled test keystore, the old Capacitor
  APK built and signed with it, a few representative saves, the spike plugin and APK with the same
  package and signature installed over it without uninstalling (`adb install -r`) on
  `sv_m1_api36`; result: the five keys read unmutated, or a documented reproducible failure, plus
  the written native-bridge / staged-Capacitor decision.
- **Unsatisfied automated M2 gates:** **VIEW-004** and **CAM-004** (gate decision not taken: accept
  the probe evidence, or add an in-suite rendered case); **DOG-008a** (the same rendered clause and
  a restart-reset assertion).
- **Manual desktop play (M2):** five minutes with keyboard/controller; occlusion at every approach
  angle; camera bounds at map edges; crisp rendering at two window sizes and one non-integer aspect.
- **Manual touch play (M2):** five minutes on a portrait Android device or touch surface (move,
  simultaneous RUN, PEE, pointer ownership, left/right edges); touch video/capture.
- **Manual M1 checks:** editor preview of every playable animation/direction; listening to the
  recorded and synthesized audio; approval of the title images (`captures/title_m1/`).

### Architect review result

Pending.

---

## Historical — correction report 8: M1/M2 acceptance evidence (`5435c32`; M1 Partial, M2 Partial)

> Historical record of `5435c32`, superseded by correction report 9. **Erratum** (text below kept
> as submitted): its ARCH-001a contract required the dummy Story host to share GreenZoneScene's tile
> set and sprite catalogue instances and flagged every runtime `move_circle` caller other than
> `PlayableDog`; correctly, the classes and public interfaces must be identical, a story stage may
> supply its own environment resources, and the static rule covers duplicate playable/input
> movement controllers only (actor behaviour controllers may use the shared solver). The COLL-005
> parent still read "every current story objective"; it now covers static and scripted-position
> reachability, with dynamic goals owned by WALK/NPC/MINI/STY.

Scope: the architect's five items on `965d0b0`, in one commit. No M3 content. Code changes are test
files only (a dummy Story host scene under `godot/tests/support/` and two rewritten acceptance
cases); no gameplay, audio, animation or isometric module and no PixiJS file changed.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (nothing accepted); open M1 blocker: the migration-plugin spike |
| Base | `965d0b0` (correction report 7 and its addendum) |
| Current `godot/` tree | `b1c3595c49666587c04d2ad3d652d28d774a2bc5`, verified on a fresh Windows clone (below) |
| Host | Windows 11 Pro N for Workstations 25H2 (RTX 3090, WASAPI audio); Linux not rerun |
| Android on this host | available: Android SDK in `%USERPROFILE%\Desktop\android-sdk` (platform-tools/adb 37.0.3, build-tools 36.1.0, platform 36), Godot's 4.7.2 Android export templates, JDK 21, emulator 37.3.10 with the device `sv_m1_api36` (adb serial `emulator-5554`, Android 16 / API 36, Google WebView 133.0.6943.137). Not yet: the migration plugin and a controlled signed old→new APK lineage |

### Changes per review item

1. **ARCH-001a now rests on a real dummy Story host.** `godot/tests/support/dummy_story_scene.tscn`
   (tests/ is excluded from export; the M5 story scene replaces it) instantiates the shared
   `IsoWorld` scene as its child like `GreenZoneScene`, configures a story-style map (no exit,
   markers, water, props) through `IsoWorld.setup()`, ticks in a story walk's order (InputService
   intent → `PlayableDog.update_movement` on the grid solver → `IsoWorld.end_step`) and renders
   through `IsoWorld.render`. `test_ARCH_001a_dummy_story_host_shares_the_green_zone_world`
   replaces the direct-IsoWorld case: the world is the host's child; world scene/class, dog
   scene/class/profile, camera class, tile set and sprite catalogue equal `GreenZoneScene`'s; 200
   ticks driven through `InputService` move the dog east until the grid solver stops it at the
   wall, the camera follows on whole pixels, the visible set is ranked 0..n-1 by `IsoDepthSorter`;
   replaying the same intents on a bare `PlayableDog` and the same map gives the identical position
   every tick (no host-specific movement); freeing the host frees its world and dog. The no-fork
   check is kept as a **static review gate** and strengthened: no runtime script except
   `PlayableDog` calls `move_circle`/`circle_blocked`, defines `update_movement` or uses
   `move_and_slide`/`move_and_collide` (it cannot see future code paths: reviewers re-check new
   movers). ARCH-001a is claimed on this case.
2. **COLL-005a drives continuously to exact targets.** One `PlayableDog` is driven through its own
   controller (walking intent, screen space) and the grid solver from the Green Zone start to each
   treat's exact coordinate, finishing within the rule's pickup radius (`TREAT.PICKUP_RADIUS` 0.55,
   eaten at distance ≤ 0.55); each leg starts at the dog's real end position (no idealized tile
   centres), and from the last treat it continues to the exit (level complete at distance < 0.8).
   The case also keeps the story-map marker drives. COLL-005a is claimed on this case.
3. **COLL-005b planning** (TEST_PLAN.md, MILESTONES.md): every remaining scripted spatial objective
   with a scripted position (marker or literal reach goals, pickups, spots, marvels, action zones
   placed when their walk starts); runtime-placed and moving targets are assigned explicitly to
   WALK-007–009, WALK-014–017, WALK-019–021, NPC-001–006, NPC-008–011, MINI-001–012 and each
   scene's STY real-input completion. `test_P_COLL_005b_…` evidence in M5 (Level 1) and M6
   (Levels 2–4); the full `test_COLL_005b_…` aggregate is reserved for M7.
4. **Android status** updated in FEATURE_MATRIX (legacy-save plan, "Not verified", the Android rows)
   and here; the remaining blocker is the plugin plus a controlled signed old→new lineage.
5. **MIG-005 fixture/simulated portion added to M4** (TEST_PLAN.md MIG-005, MILESTONES.md M4, the
   plan below): the raw five-key payload written exactly with timestamp and SHA-256 before any
   parsing, read back and verified; backup, write and read-back failure tests; M9 still proves it
   through real WebView acquisition.

### The approved three-stage legacy-save plan (MILESTONES.md M1/M4/M9, ARCHITECTURE.md §17.2–17.3)

1. **M1 — feasibility spike, open M1 blocker.** A throwaway native migration plugin under
   `/godot/platform/android/`, tested on a controlled same-package/same-signature old→new APK
   lineage: it either reads the five legacy `supervillained:` keys without mutating them, or a
   reproducible failure is documented; either way the native-bridge versus staged-Capacitor
   decision is written. Not started; the tools are available (above).
2. **M4 — deterministic format-3 converter and SaveService integration**, plus the fixture/simulated
   MIG-005. Today only the pure v1→v2 rules are ported (SAV-013–017).
3. **M9 — production proof:** the actual installed lineage and signing certificate, two
   WebView/device versions, and end-to-end MIG-001–010.

### M2 automated gates

| ID | Status | Evidence / milestone |
|---|---|---|
| ARCH-001a | **satisfied** | `test_ARCH_001a_dummy_story_host_shares_the_green_zone_world` (this report) |
| COLL-005a | **satisfied** | `test_COLL_005a_maps_start_exit_treats_and_markers_reachable_under_the_solver` (this report) |
| DOG-005a | satisfied | `test_DOG_005a_…` (correction report 7 addendum) |
| VIEW-004, CAM-004 | **not satisfied** | rendered clauses only by `tools/interpolation_probe.gd` outside the suite; gate decision not taken |
| DOG-008a | **not satisfied** | rendered presentation clause (same decision); restart reset not asserted separately |
| ARCH-001b, DOG-008b / COLL-005b / DOG-005b | later | M5 / M5–M7 (aggregate M7) / M3 |

### Commands executed and results (Windows 11)

| Command | Result |
|---|---|
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all --case <c>` for `ARCH_001a` and `COLL_005a` (working tree, while writing them) | each `1 passed, 0 failed` |
| Fresh `git clone` of this commit's code (`core.autocrlf=true`; tested `godot/` tree `b1c3595c49666587c04d2ad3d652d28d774a2bc5` = `git rev-parse HEAD:godot` of this commit; only the docs and the log folder were written after it), `npm ci`, `npx playwright install chromium` | exit 0 each |
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` | exit 0: `asset check OK: 206 outputs identical (72 copies) …`; `build_resources check (all): OK, 55 outputs identical` |
| `<console exe> --headless --path godot --import` | exit 0, no ERROR/WARNING lines |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all` | exit 0: **137 passed, 0 failed, 137 total**, including `test_ARCH_001a_dummy_story_host_shares_the_green_zone_world`, `test_COLL_005a_maps_start_exit_treats_and_markers_reachable_under_the_solver`, `test_DOG_005a_…` |
| `<console exe> --headless --path godot --quit-after 600` | exit 0, engine banner only |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite integration --file test_export_pack` | exit 0: PCK 32,905,976 bytes (unchanged: the dummy host under `tests/` is not exported), 254 runtime resources, 512 packed files, packed 600-frame startup clean |
| `<console exe> --path godot --script res://tools/audio_suspend_probe.gd` (real WASAPI device) | exit 0, `"ok":true` |
| `npm test`; `npm run build` | exit 0: 248 tests passed; build OK |
| `git status --porcelain`; `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | exit 0, all empty |
| `bash godot/tools/source_tree_guard.sh` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |
| `git diff --stat 965d0b0 -- godot` (working tree) | only `godot/tests/integration/test_world.gd` and the new `godot/tests/support/dummy_story_scene.{gd,gd.uid,tscn}` |
| `git diff --stat 965d0b0 -- docs/porting/windows_evidence docs/porting/linux_evidence docs/porting/captures` (working tree, before the new log folder was added) | empty: historical evidence unchanged |
| `git diff --check` (working tree) | clean |
| `python docs_consistency_check.py` (session tool, not committed) | `OK: 37 checks` |

Logs of the fresh-clone run: `docs/porting/windows_evidence/correction-8-godot-tree-b1c3595/`. Not
run: Linux, the rendered interpolation probe (nothing rendered changed).

Host evidence: current tree above. Previous Windows trees: `b8535ab` (correction report 7 addendum,
137 passed) and `81906cd` / `fd20ac1f3c8ac95fb197fd7bcca6a5d4c2c95876` (correction report 6,
134 passed). Linux: the prior tree `d12bedd`, 128 passed (progress report 5). Correction 6 was not
rerun on Linux, and neither were correction 7's addendum and this report.

### Deviations

| ID | Status |
|---|---|
| D-11 | Campaign save: the pure v1→v2 rules are ported (SAV-013–017). Remaining, per the approved plan: the M1 migration-plugin spike (open M1 blocker), the M4 format-3 converter, SaveService integration and fixture/simulated MIG-005, the M9 production-lineage / two WebView-device / MIG-001–010 proof |
| D-13 | Not done from M1: the Android migration-plugin spike (open M1 blocker). The Android tools and the emulator are available; missing are the plugin and a controlled signed old→new APK lineage |
| D-05, D-14, D-15 | As in progress report 5 |
| D-01–D-04, D-06–D-10 | As in correction report 1 |

### Still required before requesting M1/M2 completion review

- **M1 migration-plugin spike (open M1 blocker):** a controlled test keystore, the old Capacitor
  APK built and signed with it, a few representative saves, the spike plugin and APK with the same
  package and signature installed over it without uninstalling (`adb install -r`) on
  `sv_m1_api36`; result: the five keys read unmutated, or a documented reproducible failure, plus
  the written native-bridge / staged-Capacitor decision.
- **Unsatisfied automated M2 gates:** **VIEW-004** and **CAM-004** (gate decision not taken: accept
  the probe evidence, or add an in-suite rendered case); **DOG-008a** (the same rendered clause and
  a restart-reset assertion).
- **Manual desktop play (M2):** five minutes with keyboard/controller; occlusion at every approach
  angle; camera bounds at map edges; crisp rendering at two window sizes and one non-integer aspect.
- **Manual touch play (M2):** five minutes on a portrait Android device or touch surface (move,
  simultaneous RUN, PEE, pointer ownership, left/right edges); touch video/capture.
- **Manual M1 checks:** editor preview of every playable animation/direction; listening to the
  recorded and synthesized audio; approval of the title images (`captures/title_m1/`).

### Architect review result

Pending.

---

## Historical — correction report 7: legacy-save plan, host evidence, M2 gates (`cc1ebb3`, addendum `965d0b0`; M1 Partial, M2 Partial)

> Historical record of `cc1ebb3` and its addendum `965d0b0`, superseded by correction report 8.
> **Erratum** (text below kept as submitted): the addendum claimed ARCH-001a on a case that built
> `IsoWorld` directly, without a Story host scene, and COLL-005a on drives to floored treat tiles
> that restarted each leg from an idealized tile centre; both claims rest on the stronger cases of
> correction report 8 instead. Its Android statements ("no Android SDK, adb, emulator or device",
> the spike's needs) are superseded by the current status in correction report 8.

Scope: the architect's three documentation items on `81906cd`, in one documentation commit. No code
changes: `godot/` is identical to `81906cd` (tree `fd20ac1f3c8ac95fb197fd7bcca6a5d4c2c95876`); the
accepted AudioService and PlayableDog corrections and the PixiJS source are untouched.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (nothing accepted); **open M1 blocker: the migration-plugin spike** |
| Base | `81906cd` (correction report 6) |
| Code under test | at `cc1ebb3`: unchanged from `81906cd`. **Addendum** (below): test files only, three acceptance cases added; new `godot/` tree `b8535ab2b041ed91caa74eee1f8e3b5a65130860`, verified on Windows |
| Host | Windows 11 Pro N for Workstations 25H2 (same PC); Ubuntu 26.04 in WSL 2 (checked for Android tools only) |
| Android on this host | at `cc1ebb3`: no Android SDK, adb, emulator or device; no controlled old→new APK lineage; present: JDK 21 (Eclipse Adoptium) and Godot's 4.7.2 Android export templates. Since then, with the owner's OK: an Android SDK (platform-tools 37.0.3, build-tools 36.1.0, platform 36) and the emulator 37.3.10 with the virtual device `sv_m1_api36` (Android 16 / API 36, Google WebView 133.0.6943.137) in `%USERPROFILE%\Desktop\android-sdk`. The spike itself is not started |

### The approved three-stage legacy-save plan (MILESTONES.md M1/M4/M9, ARCHITECTURE.md §17.2–17.3)

1. **M1 — feasibility spike.** A throwaway native migration plugin under `/godot/platform/android/`,
   tested on a controlled same-package/same-signature old→new APK lineage. It either reads the five
   legacy `supervillained:` keys without mutating them, or a reproducible failure is documented;
   either way the native-bridge versus staged-Capacitor decision is written. Missing access to the
   owner's production signing identity is an M9 blocker, not an M1 one.
   **Status: not started, open M1 blocker.** No controlled Android environment exists on the hosts
   used (above), so the spike cannot run here. It is not unnecessary and it is not deferred to M9.
2. **M4 — deterministic format-3 converter and SaveService integration.** Today only the pure
   v1→v2 rules are ported (`CampaignMigration`, SAV-013–017).
3. **M9 — production proof:** the actual installed lineage and signing certificate, two
   WebView/device versions, and end-to-end MIG-001–010.

### Changes per review item

1. **Plan restored everywhere it was misstated.** Correction report 6 (item 3, D-11, D-13) and the
   erratum it added to progress report 5 had collapsed the plan to "M4 converter, M9 Android",
   dropping the M1 spike. Corrected in: FEATURE_MATRIX (status headline, "Not verified", the new
   "Legacy-save plan" paragraph, the campaign row, and the planning row "Legacy Capacitor import",
   whose milestone column now reads "M1 spike, M4 converter, M9 proof" as in MILESTONES.md); this
   report (D-11, D-13, "Still required"); the progress report 5 erratum; an erratum on correction
   report 6, now historical. MILESTONES.md, ARCHITECTURE.md and TEST_PLAN.md already state the
   three stages and are unchanged.
2. **D-11 / D-13 and "Still required"** below. The spike is listed as an open M1 blocker with what
   it needs.
3. **Host evidence in FEATURE_MATRIX.** Current tree: `81906cd` / `godot/` tree
   `fd20ac1f3c8ac95fb197fd7bcca6a5d4c2c95876`, Windows, 134 passed (correction report 6). Linux
   `d12bedd` / 128 passed is prior-tree evidence. Correction 6 was not rerun on Linux, and neither
   was this documentation commit. CORE-001 / AST-019 command evidence and the project-isolation row
   name the tree each host ran.

Historical evidence files (`windows_evidence/`, `linux_evidence/`, `captures/`) are unchanged.

### Commands executed and results

Only these commands were run for this commit (Windows 11, PowerShell 5.1 / Git Bash; WSL where
stated). No build, import, suite or launch was re-run: no code changed.

| Command | Result |
|---|---|
| `Get-Command adb`, `Get-Command emulator`, `Get-Command java` | adb: not found; emulator: not found; java: `C:\Program Files\Eclipse Adoptium\jdk-21.0.13.9-hotspot\bin\java.exe` |
| `$env:ANDROID_HOME`, `$env:ANDROID_SDK_ROOT`; `Test-Path $env:LOCALAPPDATA\Android\Sdk` | both empty; `False` |
| `Test-Path $env:APPDATA\Godot\export_templates\4.7.2.stable`; its listing filtered on `android` | `True`; `android_debug.apk`, `android_release.apk`, `android_source.zip` |
| `Test-Path godot\platform` | `False` (no spike code exists) |
| WSL Ubuntu 26.04: `command -v adb`, `command -v sdkmanager` | both not found |
| `git diff --stat d12bedd 81906cd -- godot/assets godot/data godot/tests/fixtures godot/tools/source_extract godot/tools/build_resources.gd` | empty: the generated outputs are the same on both trees |
| `git diff --stat 81906cd -- godot` (working tree) | empty: no code change |
| `git diff --stat 81906cd -- docs/porting/windows_evidence docs/porting/linux_evidence docs/porting/captures docs/porting/MILESTONES.md docs/porting/ARCHITECTURE.md docs/porting/TEST_PLAN.md` | empty: historical evidence and planning documents unchanged |
| `git diff --check` and `git diff --check 95b69c0` (working tree) | clean |
| `bash godot/tools/source_tree_guard.sh` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |
| `python docs_consistency_check.py` (session tool, not committed) | `OK: 16 checks` — one "— current" report; the plan's three stages, the M1 blocker and the host-evidence facts present in FEATURE_MATRIX and this report; the collapsed "M9 only" wording absent from both |

### Addendum on top of `cc1ebb3`: the automated M2 gates reconciled

The architect's follow-up: list the unsatisfied automated M2 gates (ARCH-001, VIEW-004, CAM-004,
COLL-005, DOG-005, DOG-008) and reconcile MILESTONES.md, TEST_PLAN.md and FEATURE_MATRIX.md without
moving requirements to declare M2 complete. Only test files changed; no game or PixiJS code.

- **Split IDs** (TEST_PLAN.md rule: `<ID>a` = the earlier milestone's clauses, `<ID>b` = the later
  clauses with their own milestone; the parent is satisfied only when both are; no clause is
  dropped). MILESTONES.md lists each part under its milestone (M2, M3, M5–M7) and FEATURE_MATRIX's
  planning rows name the parts.

| Parent | M2 part | Evidence for the M2 part | Later part (milestone) |
|---|---|---|---|
| ARCH-001 | ARCH-001a: a dummy story scene and the Green Zone scene share the `IsoWorld` scene and setup, `PlayableDog`, `IsoGrid`, `IsoDepthSorter`, `CameraRig`; shared controller and grid solver; no forked movement | **satisfied**: new `test_ARCH_001a_dummy_story_scene_shares_the_green_zone_world` (both scenes' world/dog/camera scenes and classes, IsoGrid foot point, story map without exit and with markers, the dog stopped by a wall through the grid solver, depth-sorted, and a static scan finding a single movement implementation) | ARCH-001b: production story scene (M5) |
| COLL-005 | COLL-005a: Green Zone spawn/start, exit and every treat; every story map's start, exit and every marker the source can reach | **satisfied**: new `test_COLL_005a_maps_start_exit_treats_and_markers_reachable_under_the_solver` (runs the earlier partial case, then drives the grid solver start → each of the 30 treats in placement order → exit) | COLL-005b: story objectives at literal coordinates (M5–M7) |
| DOG-005 | DOG-005a: bark, eat/drink, hurt, exit cannot overlap illegally | **satisfied**: new `test_DOG_005a_bark_eat_drink_hurt_exit_never_overlap_like_source` (the source `rules_busy` and `rules_overlap` scenarios tick by tick: states bark, eat, pee, poop, hurt, drink, exit) | DOG-005b: forced fetch (M3, with GZ-034–036) |
| DOG-008 | DOG-008a: spawn/teleport/restart/camera-snap resets; 30/60/90/120 FPS presentation without streak; no test-hook leak | **not satisfied**: spawn, teleport and camera-snap resets and hook isolation are in `test_CORE_002_logic_independent_of_render_rate`; the presentation clause is only the rendered probe (decision below); a restart reset is not asserted separately | DOG-008b: stage change (M5) |

- **VIEW-004 and CAM-004: kept incomplete.** The suite covers nearest filtering and whole-pixel
  world, camera and UI transforms (`test_P_VIEW_004_…`, the CAM-004 assertion in
  `test_CAM_002_…`); the rendered 30/60/90/120 FPS, streak, double-interpolation and static-shimmer
  clauses are measured only by `tools/interpolation_probe.gd` outside the suite (llvmpipe,
  correction report 1; a real RTX 3090 for `d12bedd`, `windows_evidence/d12bedd/` steps f/g).
  **Gate decision: not taken** — accepting that probe evidence for these clauses, or requiring an
  in-suite rendered case, is the architect's call. The same decision covers DOG-008a's
  presentation clause.

Commands executed for the addendum and results (Windows 11):

| Command | Result |
|---|---|
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all --case <c>` for `ARCH_001a`, `COLL_005a`, `DOG_005a` (working tree, while writing them) | each `1 passed, 0 failed` |
| Fresh `git clone` of this commit's code (`core.autocrlf=true`; tested `godot/` tree `b8535ab2b041ed91caa74eee1f8e3b5a65130860` = `git rev-parse HEAD:godot` of this commit; only the docs and the log folder were written after it), `npm ci`, `npx playwright install chromium` | exit 0 each |
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` | exit 0: `asset check OK: 206 outputs identical (72 copies) …`; `build_resources check (all): OK, 55 outputs identical` |
| `<console exe> --headless --path godot --import` | exit 0, no ERROR/WARNING lines |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all` | exit 0: **137 passed, 0 failed, 137 total** (134 + `test_ARCH_001a_…`, `test_COLL_005a_…`, `test_DOG_005a_…`) |
| `<console exe> --headless --path godot --quit-after 600` | exit 0, engine banner only |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite integration --file test_export_pack` | exit 0: PCK 32,905,976 bytes, 254 runtime resources, 512 packed files, packed 600-frame startup clean |
| `<console exe> --path godot --script res://tools/audio_suspend_probe.gd` (real WASAPI device) | exit 0, `"ok":true`, `late_effect_dropped` true, nothing replayed |
| `npm test`; `npm run build` | exit 0: 248 tests passed; build OK |
| `git status --porcelain`; `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | exit 0, all empty |
| `bash godot/tools/source_tree_guard.sh` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |
| `git diff --stat cc1ebb3 -- godot` (working tree) | only `godot/tests/integration/test_world.gd` (+77) and `godot/tests/unit/test_needs_rules.gd` (+10) |
| `git diff --stat cc1ebb3 -- docs/porting/windows_evidence docs/porting/linux_evidence docs/porting/captures` (working tree, before the new log folder was added) | empty: historical evidence unchanged |
| `git diff --check` (working tree) | clean |
| `python docs_consistency_check.py` (session tool, not committed) | `OK: 36 checks` (current report, the M1/M4/M9 plan, host evidence, the split IDs in TEST_PLAN, MILESTONES and FEATURE_MATRIX, claimed IDs backed by `test_<ID>` cases) |

Logs of the fresh-clone run: `docs/porting/windows_evidence/correction-7-godot-tree-b8535ab/`. Not run:
Linux, the rendered interpolation probe (nothing rendered changed).

### Deviations

| ID | Status |
|---|---|
| D-11 | Campaign save: the pure v1→v2 rules are ported (SAV-013–017). Remaining, per the approved plan: the M1 migration-plugin spike (open M1 blocker), the M4 format-3 converter and SaveService integration, the M9 production-lineage / two WebView-device / MIG-001–010 proof |
| D-13 | Not done from M1: the Android migration-plugin spike (open M1 blocker: no Android SDK, adb, emulator, device or controlled APK lineage on the hosts used). Done since report 1: title, synthesized audio, Sbrimbrulòn/Bagnaskiz profiles, cast |
| D-05, D-14, D-15 | As in progress report 5 |
| D-01–D-04, D-06–D-10 | As in correction report 1 |

### Still required before requesting M1/M2 completion review

- **M1 migration-plugin spike (open M1 blocker).** Still to do: a controlled test keystore, the
  old Capacitor APK built and signed with it, a few representative saves, and a spike APK with the
  same package and signature installed over it without uninstalling (`adb install -r`). Result: the
  five keys read unmutated, or a documented reproducible failure, plus the written native-bridge /
  staged-Capacitor decision. Now available on this PC: the Android SDK, the emulator device
  `sv_m1_api36`, JDK 21 and the Godot Android export templates.
- **Unsatisfied automated M2 gates:**
  - **VIEW-004** and **CAM-004**: rendered clauses only by the probe outside the suite; gate
    decision not taken (accept the probe evidence, or add an in-suite rendered case).
  - **DOG-008a**: the rendered presentation clause (same decision) and a restart-reset assertion.
  - ARCH-001, COLL-005 and DOG-005: their M2 parts ARCH-001a, COLL-005a and DOG-005a are satisfied
    by this addendum's cases; ARCH-001b (M5), COLL-005b (M5–M7) and DOG-005b (M3) stay with their
    milestones, as does DOG-008b (M5).
- **Manual desktop play (M2):** five minutes with keyboard/controller; occlusion at every approach
  angle; camera bounds at map edges; crisp rendering at two window sizes and one non-integer aspect.
- **Manual touch play (M2):** five minutes on a portrait Android device or touch surface (move,
  simultaneous RUN, PEE, pointer ownership, left/right edges); touch video/capture.
- **Manual M1 checks:** editor preview of every playable animation/direction; listening to the
  recorded and synthesized audio; approval of the title images (`captures/title_m1/`).

### Architect review result

Pending.

---

## Historical — correction report 6: fifth M1/M2 review (`81906cd`; M1 Partial, M2 Partial)

> Historical record of `81906cd`, superseded by correction report 7. Its Windows results remain the
> current-tree evidence (`godot/` is unchanged since). **Erratum** (text below kept as submitted):
> item 3, D-11 and D-13 dropped the approved M1 stage of the legacy-save plan. Correctly: M1 — a
> migration-plugin feasibility spike on a controlled old→new APK lineage (open M1 blocker, not
> started); M4 — the format-3 converter and SaveService integration; M9 — the production
> lineage/certificate, two WebView/device versions and end-to-end MIG-001–010 proof.

Scope: the architect's three items on `5a4a486`, in one correction-only commit. No M3 content and
no PixiJS source change. Beyond the two places the review names (AudioService effect requests and
the dog scene's profile reference) nothing is rewritten: IsoGrid, GridKinematicSolver, movement,
camera, depth sorting, the TileMap renderer, SaveService, interaction geometry, the asset pipeline,
the test runner and the PCK test are unchanged.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (nothing accepted) |
| Base | `5a4a486` (progress report 5) |
| Host | Windows 11 Pro N for Workstations 25H2, build 26200.8037 (RTX 3090, WASAPI audio) |
| Godot / toolchain | Godot 4.7.2.stable.official.ed1daf0bf (win64 console); PowerShell 7.7.0; Git 2.54.0.windows.1 (`core.autocrlf=true`); Node v24.15.0; Playwright 1.63.0; Chromium 153.0.8010.12 (revision 1243, pinned) |
| Not available | an Android device, SDK, export templates or signing identity; a human tester |

### Changes per review item

1. **AudioService effect requests now follow `src/core/audio.ts` `AudioEngine.play()`
   (finding F-18).** The source returns before scheduling anything while `settings.muted` or while
   its AudioContext is not running (background), drops the same cue again within 45 ms of
   `ctx.currentTime`, and its master gain is `muted ? 0 : volume`. The port had started a request
   made in the background paused (audible on return), had no mute drop and no 45 ms rule, and set
   volume 0 to -80 dB. Now:
   - `muted` and `volume` are tracked explicitly (`apply_settings`);
   - a new immediate or delayed request made while muted or suspended is dropped (counted in
     `dropped` by reason) and nothing is replayed on unmute or resume;
   - sounds already playing and delayed cues already scheduled before suspension still pause and
     resume (an audio clock, `audio_time`, advances only while not suspended, like
     `ctx.currentTime`; delays and the 45 ms rule use it, the time taken when the request is made);
   - the same cue within 45 ms of audio time is dropped;
   - muted or volume 0 mutes the master bus (true silence); otherwise the bus level is the volume.

   Tests: `test_SLICE_audio_background_suspends_music_and_effects` now requires a background
   request to be dropped (not started paused) and nothing replayed on return; new regressions
   `test_SLICE_audio_mute_drops_new_effects_and_unmute_replays_nothing`,
   `test_SLICE_audio_suspend_drops_new_effects_and_resume_replays_nothing`,
   `test_SLICE_audio_delayed_cue_from_before_suspension_resumes`,
   `test_SLICE_audio_volume_zero_is_silence`,
   `test_SLICE_audio_same_cue_within_45_ms_is_suppressed`; the bounded-log case advances audio
   time between requests. `tools/audio_suspend_probe.gd` now requires the late background cue to
   be dropped (`late_effect_dropped`) and nothing to start on resume (`replayed_on_resume: false`).
2. **The dog scene no longer references Zampanò.** `playable_dog.tscn` has no `profile`
   ext_resource; `IsoWorld` injects the selected profile (AppState's `--as` choice or an explicit
   option) before `add_child()`. `PlayableDog.active_profile()` loads Zampanò lazily from a path
   string (no preload, so no static dependency) only when a dog is used unconfigured, and records
   it (`used_fallback_profile`). `test_SLICE_playable_profile_injected_before_add_child`: the
   PackedScene's dependencies and text name no Zampanò resource and the script preloads no profile;
   `--as=zampano|sbrimbrulon|bagnaskiz` each reach the spawned dog with no fallback, and an explicit
   option overrides the `--as` choice; a bare instantiated scene carries no profile and falls back
   to Zampanò only once added.
3. **Milestone wording.** The format-3 campaign converter and its SaveService integration are
   **M4**; the Android legacy-store acquisition and the signed-upgrade/MIG-001–010 proof are
   **M9**. Corrected in the FEATURE_MATRIX status section and campaign row, in the deviations below,
   and by an erratum on progress report 5, which is now historical. Earlier evidence folders and
   reports are kept unchanged as historical records.

### Commands executed and results (Windows 11)

A fresh `git clone` (Git for Windows defaults, `core.autocrlf=true`) of this commit's code, taken
before this table and the log folder were written: the tested `godot/` tree is
`fd20ac1f3c8ac95fb197fd7bcca6a5d4c2c95876`, which equals `git rev-parse HEAD:godot` of this
commit (only this report and its log folder differ). `npm ci` and `npx playwright install
chromium` exit 0; then, from the clone root in PowerShell 7.7.0
(logs: `docs/porting/windows_evidence/correction-6-godot-tree-fd20ac1/`):

| Check | Command | Exit | Result |
|---|---|---|---|
| Deterministic asset check | `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` | 0 | `asset check OK: 206 outputs identical (72 copies), Node v24.15.0, Playwright 1.63.0, Chromium 153.0.8010.12 (revision 1243, pinned; host browser reported 153.0.8010.12)`; `build_resources check (all): OK, 55 outputs identical` |
| Clean Godot import | `<console exe> --headless --path godot --import` | 0 | no ERROR/WARNING lines |
| Full suite | `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all` | 0 | **134 passed, 0 failed, 134 total** (128 earlier cases + 5 audio regressions + the profile-injection case; the background-audio case now requires the drop) |
| 600-frame launch | `<console exe> --headless --path godot --quit-after 600` | 0 | engine banner only |
| PCK smoke | `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite integration --file test_export_pack` | 0 | `test_SLICE_android_pck_has_runtime_data_and_starts_clean` passed: PCK 32,905,976 bytes, 254 runtime resources load from the pack, 512 packed files, no excluded content, packed 600-frame startup with no error or warning |
| Audio probe (real WASAPI device) | `<console exe> --path godot --script res://tools/audio_suspend_probe.gd` | 0 | `{"late_effect_dropped":true,"live_players":2,"ok":true,"paused_in_background":[true,true],"replayed_on_resume":false,"resumed":[true,true]}`, clean exit |
| PixiJS tests | `npm test` | 0 | 30 files, **248 tests passed** |
| PixiJS build | `npm run build` | 0 | TypeScript + Vite build OK |
| Working tree | `git status --porcelain` | 0 | empty |
| Diff check | `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | 0 | clean (whole port; this commit) |
| Source-tree guard | `bash godot/tools/source_tree_guard.sh` (Git Bash) | 0 | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |

Not re-run for this commit: Linux (no Linux-specific code changed), the rendered interpolation
probe and the captures (nothing visual changed).

### Deviations

| ID | Status |
|---|---|
| D-11 | Campaign: the pure v1→v2 rules are ported (SAV-013–017); the format-3 converter and SaveService integration are M4; the Android legacy-store acquisition and the signed-upgrade/MIG proof are M9 |
| D-13 | Mostly closed (title, synthesized audio, profiles, cast); what remains is the Android legacy-store acquisition and MIG proof, which are M9, not M1/M2 evidence |
| D-05, D-14, D-15 | As in progress report 5 |
| D-01–D-04, D-06–D-10 | As in correction report 1 |

### Still required before requesting M1/M2 completion review

- **Manual desktop play (M2):** five minutes with keyboard/controller; occlusion at every approach
  angle; camera bounds at map edges; crisp rendering at two window sizes and one non-integer aspect.
- **Manual touch play (M2):** five minutes on a portrait Android device or touch surface (move,
  simultaneous RUN, PEE, pointer ownership, left/right edges); touch video/capture.
- **Manual M1 checks:** editor preview of every playable animation/direction; listening to the
  recorded and synthesized audio; approval of the title images (`captures/title_m1/`).

### Architect review result

Pending.

---

## Historical — progress report 5: remaining M1/M2 work (`5a4a486`; M1 Partial, M2 Partial)

> Historical record of `5a4a486`, superseded by correction reports 6 and 7. **Errata** (text below
> kept as submitted): "legacy import into the container stays M9" should read as the approved
> three-stage plan (correction report 7): M1 — the migration-plugin feasibility spike on a
> controlled old→new APK lineage, still open as an M1 blocker (the "Android (M1 spike)" item below
> was right to list it); M4 — the format-3 converter and SaveService integration; M9 — the
> production lineage/certificate, two WebView/device versions and end-to-end MIG-001–010 proof.
> The audio behaviour then recorded, a new effect requested in the background "starts paused"
> (also in `windows_evidence/d12bedd/`), was not source parity: the source drops it (F-18).

Scope: the architect's instruction after the fourth review ("continue only the remaining documented
M1/M2 work"). No M3 content. The accepted foundations are not rewritten: IsoGrid,
GridKinematicSolver, movement, camera, depth sorting, the TileMap renderer, SaveService candidate
handling, the audio lifecycle (suspend/resume, track continuity), interaction geometry, the test
runner and the PCK test are unchanged. The asset pipeline is extended (new outputs and fixtures);
every earlier output is byte-identical (`--check` on Windows and Linux).

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (nothing accepted; see "Still required") |
| Base | `c320000` (correction report 4) |
| Code commits | `53493e2` audio, `392207d` playable dogs, `5745c99` cast/banks/frozen art, `16b5619` title/font/coverage, `ead5918` campaign migration, `acdfce3` story maps, `401e8e4` RNG-002, `d12bedd` probe exit + README |
| Hosts | **Windows 11 25H2** (RTX 3090, WASAPI audio) and **Linux: Ubuntu 26.04 in WSL 2** on the same PC |
| Godot / toolchain | Godot 4.7.2.stable.official.ed1daf0bf (win64 console and linux.x86_64); Node v24.15.0; Playwright 1.63.0; Chromium 153.0.8010.12 (revision 1243, pinned) |
| Not available | an Android device, SDK, export templates or signing identity; a human tester |

### What changed

1. **Audio (AUD-001–008).** The extractor copies the remaining recorded music (levels 2–4) and
   effects (meow, coin, ball, alarm, siren, laser) and executes `src/fx/audioFiles.ts` for the
   cue tables (`?url` imports now resolve to repository paths). It renders the fourteen `SOUNDS`
   cues and the medieval loop with the source's own `synth.ts`/`sounds.ts` at the source rate to
   mono 22,050 Hz signed 16-bit PCM WAV (`round(clamp(x, -1, 1) * 32767)`), records recipe/input
   hashes, sample counts, peaks and probe samples, and Chromium decode references for every
   recorded file. WAVs import as plain PCM; the medieval loop loops over its whole buffer.
   AudioService plays all five recorded tracks (per-track `MUSIC_FILE_GAIN`), `medieval`
   (`MUSIC_VOLUME`, restarts from 0 like the source's new buffer source), twelve recorded and
   fourteen synthesized effects, and delayed cues in audio time. The Green Zone gains the source's
   marking star (+0.12 s), tired and cleaned-poop cues. D-05 closed.
2. **Playable dogs (AST-002–009).** Copies of the knight, Sbrimbrulòn (plain/knight) and Bagnaskiz
   (plain/armoured) sheets; one layout per `PLAYABLE_CHARACTER_KEYS` skin (`zampanoCross` detected
   as an alias of the knight art); the source `costumeFor()` table. SpriteFrames for all six skins
   and a `PlayableCharacterProfile` per `PLAY_AS` dog (normal/cross/armoured slots; Zampanò's frames
   byte-identical). The world applies the `--as` profile (it was parsed but not applied before).
3. **Cast, banks, frozen art (AST-011–018).** The 23 delivered pixel-cast sheets and the professor
   portrait; the 14 remaining Color Ink banks; the 17 procedural cast roles frozen with the source
   recipe (`CAST_SPECS` + `poseFor` + `drawCritter`); the remaining palette-independent procedural
   sprites (items, FX, story specials). The native level-frame contract is taken from the executed
   source generators: every bank delivers all 104 native frames with exact geometry, every
   `floorArt_` frame is a native tile, all 19 compositions are valid. SpriteFrames for every cast
   role.
4. **Title (AST-010).** `src/ui/titleAnim.ts` runs unchanged in Chromium (three imports replaced;
   the page and the WebP share one intercepted offline origin): 99 frames at the canonical
   125 px width, one 2000×1176 page, 8,316,000 bytes; the WebP's delays (checked against the
   file's own ANMF chunks); `TitlePortrait` is the only linear-sampled node (alpha-cut shader).
   `docs/porting/captures/title_m1/` has first/middle/last frames at three widths for approval.
5. **Font (AST-020).** Fallback-glyph map and 128 wrapping cases from the source (`layoutLines`
   executed); `PixelText.wrap` no longer wraps every word at width 0 (source: 0 = no wrap).
6. **Coverage (AST-001).** Every runtime-authoritative source file is a verified copy; the WebP and
   WOFF2 converter inputs are hash-recorded.
7. **Campaign migration (SAV-013–017).** `CampaignMigration` (pure): `migrateV1`, `loadCampaign`
   (v1 migrated once with its untouched payload kept aside; v2 normalized) and the one-time notice
   of `storyFlow.showNotice`, against fixtures produced by the executed source over an in-memory
   localStorage. Legacy import into the container stays M9 (D-11).
8. **Story maps (MAP-003, AST-015, COLL-005).** The twenty story maps parse like the source cell for
   cell; TileMapLayer cell centres equal IsoGrid tile centres over every extent. The grid solver
   reaches every marker and exit the source can reach; the four markers the source cannot reach
   are actor spawn points (ship 5/6, neighborhood 0/9). The four map keys without a composition
   resolve to delivered theme/fallback banks; none of them is staged by the current chapters.
9. **RNG-002.** The same seed reproduces the source World: treat route, spawn spots, all 692 static
   props (map props, forest trees, wall blocks) and all 9,216 ground cells (`mapRenderer.makeTile`
   executed with texture-token stubs), and a second build is identical.
10. **Probes.** `audio_suspend_probe.gd` waits for the audio server before quitting (clean exit on a
    real device); `title_capture.gd` added. README updated.

Findings for the architect:

- **F-15:** AST-007's "arms attachment alignment" has no separate source counterpart: the armoured
  sheets draw sword and shield inside each frame. The case checks the armoured frames on the shared
  40×40 frame and foot anchor (standing frames end 1–2 rows above the anchor in all 8 directions),
  the art differing from the plain costume, and the arms capability flag. Architect to accept or
  redefine.
- **F-16:** the source cannot load a v1 save whose `book.shards` is not an array (`filter` throws);
  the fixtures only use shapes the source accepts. The port tolerates the malformed shape.
- **F-17:** on a 60 Hz display with VSync, the rendered probe cannot reach 90/120 FPS and its
  interpolation-off control may show no repeated frames (exit 1, inconclusive); the 30/60/90/120
  evidence is the `--disable-vsync` run.

### Acceptance IDs

Newly satisfied by full suite cases (33): RNG-002; MAP-003; AST-001–013, AST-015–018, AST-020;
AUD-001–008; SAV-013–017. Total: **90** (FEATURE_MATRIX status section). Every automated M1 ID
(ISO-001–003, RNG-001–003, AST-001–020, AUD-001–008, SAV-013–017) is now satisfied, AST-019 by
command evidence on both hosts. Still partial: ARCH-001 (M5 story scene), VIEW-004 and CAM-004
(rendered checks by probe, now also on a real GPU), DOG-005 (M3 fetch), DOG-008 (M5 stage change),
COLL-005 (story pickups/spots/marvels at literal coordinates arrive with the M5 scripts), and the
M3 IDs GZ-001/002/021/025, UI-001–006, FLOW-005, SAV-021.

### Commands executed and results

Fresh clones of `d12bedd`, every step exit 0 unless stated; reports and logs:
`docs/porting/windows_evidence/d12bedd/REPORT.md`, `docs/porting/linux_evidence/d12bedd/REPORT.md`.

| Check | Windows 11 (`core.autocrlf=true`) | Linux (Ubuntu 26.04, WSL 2) |
|---|---|---|
| Asset check (`build_assets.ps1 -Check` / `build_assets.sh --check`) | 206 outputs identical (72 copies); 55 resources identical | identical result, same bytes |
| Clean import | no errors or warnings | no errors or warnings |
| Suite `--suite all` | **128 passed, 0 failed** | **128 passed, 0 failed** |
| Main scene, 600 frames | banner only | banner only |
| `git status --porcelain` | empty | empty |
| Source-tree guard | OK | OK |
| `git diff --check 95b69c0 HEAD` | clean | — |
| Rendered probe, real GPU, `--disable-vsync` | 30.0/60.0/90.4/120.6 FPS, 0 repeated frames, teleport resets, no static shimmer; control shows the expected repeats | not run (no display) |
| Audio probe, real device | pause/resume of music and effects, clean exit | not run |
| PixiJS baseline `npm test`, `npm run build` | 30 files, 248 tests passed; build OK | not run |

### Deviations

| ID | Status |
|---|---|
| D-05 | **Closed**: synthesized cues and the medieval loop are rendered source WAVs |
| D-13 | **Mostly closed**: title, synthesized audio, Sbrimbrulòn/Bagnaskiz profiles and the cast are done; the Android migration spike remains (no device/SDK/signing lineage here) |
| D-14 | Rendered 30/60/90/120 checks now also on a real desktop GPU; device rates unverified |
| D-15 | Still proposed (Windows CI); Windows and Linux evidence now come from real host runs |
| D-01–D-04, D-06–D-11 | As in correction report 1 |

### Still required before requesting M1/M2 completion review

Cannot be produced on this host without a person or a device:

- **Manual desktop play (M2):** five minutes with keyboard/controller; occlusion at every approach
  angle; camera bounds at map edges; crisp rendering at two window sizes and one non-integer
  aspect.
- **Manual touch play (M2):** five minutes on a portrait Android device or touch surface (move,
  simultaneous RUN, PEE, pointer ownership, left/right edges); touch video/capture.
- **Manual M1 checks:** editor preview of every playable animation/direction; listening to the
  recorded and synthesized audio; approval of the title images (`captures/title_m1/`).
- **Android (M1 spike, device evidence):** export templates, SDK, a controlled signed old APK and
  a device, for the migration spike and any device-only row (B-04).

### Architect review result

Pending.

---

## Historical — correction report 4: fourth M1/M2 review (`c320000`; M1 Partial, M2 Partial)

> Historical record of `c320000`, superseded by progress report 5.

Scope: the architect's three items on `e2768cf` (`a0e3b8d` plus its Windows evidence), in one
commit. No M3 content. The asset pipeline, SaveService candidate selection, IsoGrid,
GridKinematicSolver, movement, camera, depth sorting, the TileMap renderer, the audio lifecycle
and the PCK export test are unchanged.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (nothing accepted) |
| Base | `e2768cf` (`a0e3b8d` + `docs/porting/windows_evidence/a0e3b8d/`) |
| Host | **Windows 11 Pro N for Workstations 25H2, build 26200.8037**: a real Windows PC (the project owner's), not a simulation |
| Godot / toolchain | Godot 4.7.2.stable.official.ed1daf0bf, `Godot_v4.7.2-stable_win64_console.exe`; PowerShell 7.7.0 (official portable zip, SHA-256 verified); Git 2.54.0.windows.1, `core.autocrlf=true`; Node v24.15.0, npm 11.12.1; Playwright 1.63.0; **Chromium 153.0.8010.12 (revision 1243, pinned)** |
| Hosts not available | Android (no SDK, templates or device). Linux was not used for this report |

### Windows evidence: obtained on a real Windows host

A fresh `git clone` of `a0e3b8d` with Git for Windows' default line endings
(`core.autocrlf=true`), `npm ci`, `npx playwright install chromium`, then from the clone root in
PowerShell 7.7.0. Report and every step's merged stdout/stderr:
`docs/porting/windows_evidence/a0e3b8d/REPORT.md`.

| Step | Exit | Result |
|---|---|---|
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` | 0 | `asset check OK: 33 outputs identical (15 copies), Node v24.15.0, Playwright 1.63.0, Chromium 153.0.8010.12 (revision 1243, pinned; host browser reported 153.0.8010.12)`; `build_resources check (all): OK, 7 outputs identical` |
| `<console exe> --headless --path godot --import` | 0 | no errors or warnings |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all` | 0 | **110 passed, 0 failed** |
| `<console exe> --headless --path godot --quit-after 600` | 0 | engine banner only, no errors or warnings |
| `git status --porcelain` | 0 | empty: the checks modified no tracked file |

This produces, for `a0e3b8d`, the two Windows items earlier reports could not: the Windows
PowerShell asset check exits 0, and the Godot Windows console suite passes (110/110). The asset
check regenerates every output on the host and compares bytes, so Windows Chromium's font
rasterization and WebAudio decoding yield the committed bytes. This commit is re-verified the same
way below.

### Changes per review item

1. **Interaction broad phase covers the target radius (finding F-14).** The source measures prop
   interactions to the prop's **edge** (`WorldMapModel.nearest_prop`:
   `hypot(prop − player) − radius ≤ distance`; marking 1.05 to any vertical prop, drinking 1.0 to
   a fountain), so an accepted prop's centre can lie distance + radius away: tree 1.37, pole 1.21,
   fountain 1.41 (marking) and 1.36 (drinking) tiles. The previous probe (`PROBE_RADIUS` = 1.05,
   the bare rule distance) would have missed every such target registered at its centre. The
   probe is now conservatively inflated: `GridShapes.PROBE_RADIUS` = the largest prop rule
   distance 1.05 + `MAX_TARGET_RADIUS` 0.5 (the widest catalog prop: house, gate) +
   `SNAP_MARGIN` 0.1 (probe and target nodes both sit on whole pixels; a half-pixel diagonal is
   0.0494 tiles) = **1.65 tiles**; `GridShapes.reach(rule, radius)` names the reach. The exact
   source edge-distance logic (`nearest_prop`, as used by `try_pee` and `_check_drink`) is
   unchanged and stays authoritative; no rule reads the probe before M3.
   `test_SLICE_interaction_broad_phase_covers_prop_edge_reach`: the widest-prop and snap-margin
   contract for every catalog prop; tree, pole and fountain (marking) and fountain (drinking) at
   reach ± 1e-9 tiles in 16 grid directions (8 compass points and the 8 edge midpoints of the
   probe polygon, its tightest directions); the exact decision accepts every inside point and
   rejects every outside point; the old bare-distance polygon misses every inside point; and a
   real physics-server overlap with a point-like target on the whole-pixel prop centre reports all
   128 placements. Mutation check: with the old 1.05 probe this case fails all 128 broad-phase
   assertions while the exact decisions still pass.
   `test_SLICE_probe_and_hurtbox_are_projected_grid_ellipses_broad_phase_only` now uses the new
   radius (a target at the probe radius overlaps; one 0.05 tile beyond the polygon vertex does
   not). ARCHITECTURE §7.2 describes the reach.
2. **Current evidence status.** This section carries the real Windows evidence. FEATURE_MATRIX:
   CORE-001 and AST-019 command evidence name the Windows clean clone, a Windows verification note
   was added, the Windows-host item was removed from "Not verified", and the isolated-project and
   contact-shape rows were updated. Older reports are marked historical.
3. **Windows evidence logs normalized.** Trailing spaces (23 Godot progress lines in step a) and
   final blank lines (steps b and d) removed in `docs/porting/windows_evidence/a0e3b8d/`;
   `git diff -w --ignore-blank-lines` shows no other change, and REPORT.md records it.

### Commands executed and results (Windows 11)

A fresh `git clone` of this commit's code (taken before this table was written; the tested tree
differs from this commit only in this table) with Git for Windows' defaults
(`core.autocrlf=true`), `npm ci` (exit 0) and `npx playwright install chromium` (exit 0), then
from the clone root in PowerShell 7.7.0:

| Command | Exit | Result |
|---|---|---|
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` | 0 | `asset check OK: 33 outputs identical (15 copies), Node v24.15.0, Playwright 1.63.0, Chromium 153.0.8010.12 (revision 1243, pinned; host browser reported 153.0.8010.12)`; `build_resources check (all): OK, 7 outputs identical` |
| `<console exe> --headless --path godot --import` | 0 | no errors or warnings |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all` | 0 | **111 passed, 0 failed** (the 110 earlier cases + `test_SLICE_interaction_broad_phase_covers_prop_edge_reach`) |
| `<console exe> --headless --path godot --quit-after 600` | 0 | engine banner only, no errors or warnings |
| `git status --porcelain` | 0 | empty: the checks modified no tracked file |
| `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | 0 | clean (whole port against the audited source; this commit) |
| `bash godot/tools/source_tree_guard.sh` (Git Bash) | 0 | guard OK: only `/godot` and `docs/porting` differ from `95b69c0` |

Not re-run for this commit: the PixiJS source checks (no source file changed), the captures and
the rendered interpolation probe (nothing visual changed), and Linux.

### Deviations

| ID | Status |
|---|---|
| D-15 | Still proposed only (Windows CI outside the gate-5 paths); no longer the only route to Windows evidence, which now comes from a real host run |
| D-01–D-14 | As in correction report 1 |

### Architect review result

Pending.

---

## Historical — correction report 3: third M1/M2 review (`a0e3b8d`; M1 Partial, M2 Partial)

> Historical record of `a0e3b8d`, superseded by correction report 4. Its "Windows evidence: still
> not obtained" was true when written; real Windows evidence for `a0e3b8d` is in correction report 4.

Scope: the architect's four items on `9f458f8`, in one commit. No M3 content. IsoGrid,
GridKinematicSolver, movement, camera, depth sorting, TileMap rendering, Green Zone rules, the
audio lifecycle, the PCK export test and SaveService candidate selection are unchanged.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (nothing accepted) |
| Base | `9f458f8` |
| Godot / toolchain | 4.7.2.stable.official.ed1daf0bf Linux x86_64; Node v24.15.0; Playwright/playwright-core 1.63.0; **Chromium 153.0.8010.12 (revision 1243), the build pinned by playwright-core** |
| Hosts not available | **Windows** (still none attached; see "Windows evidence"); Android (no SDK, templates or device) |

### Finding F-13: the committed metadata was generated under a non-pinned Chromium

`playwright-core@1.63.0/browsers.json` pins Chromium **153.0.8010.12** (revision 1243), but every
earlier output recorded **157.0.8103.78**. This container installs its own headless shell in
the revision-1243 slot (`chromium_headless_shell-1243` wraps a 157 binary), and Playwright's
default headless launch uses that shell. A Windows host with `npx playwright install chromium`
gets the genuine 153 build, so its `--check` saw different `chromium` values in
`sfx_leading_silence.json`, `source_font_glyphs.json` and the manifest: the likely cause of the
reported Windows failure. Regenerated under the genuine 153 build (the full Chromium of the same
revision, present here as `chromium-1243/chrome-linux64/chrome`), only those version strings
changed: the font atlas, the 95 glyph hashes and every leading-silence offset are byte-identical
under 157 and 153, so those outputs do not depend on the Chromium build.

### Changes per review item

1. **Deterministic Chromium provenance.** The extractor derives the expected build from the
   installed `playwright-core/browsers.json` (after checking playwright and playwright-core both
   equal the lockfile), launches the full `chromium` channel (what `npx playwright install
   chromium` installs on every platform; hosts may substitute the default headless shell), and
   exits 6 unless `browser.version()` equals the pinned version. Generated files record only the
   pinned values (`toolchain.chromium`, `chromium_revision`, `chromium_channel`,
   `chromium_pinned_by`); the host browser's own report is printed (host evidence) and never
   written. Verified: a revision-1243 slot that actually holds the 157 shell is refused with
   exit 6. `test_SLICE_chromium_provenance_is_the_pinned_build` asserts every recorded Chromium
   value is the same pinned version and equals the installed `browsers.json` when present.
2. **Future-copy failures reported.** `_preserve_future()` returns `""` or
   `future_copy_failed:<file>` (`<file>` = `save_v3.json`, `save_v3.tmp` or `save_v3.bak`); it
   reads the copy back and removes a short or failed copy of its own. Failures are listed in
   `future_copy_errors`, put in `last_error` and emitted through `save_failed`; writes stay blocked
   and the originals stay untouched. Injections: a directory occupying the copy path (a real
   I/O failure) and `fault_future_copy` (a short write caught by the read-back), for each of
   main, temp and backup, plus two simultaneous failures and recovery on the next launch:
   `test_SLICE_future_copy_failures_are_reported_and_writes_stay_blocked`. The runner resets
   `fault_future_copy` per case.
3. **Viewport documentation.** ARCHITECTURE §8 and the base matrix row now describe the source
   `computeViewport` as authoritative, step by step, with its below-192 bands (areas narrower than
   192 px at scale 1; areas 271–383 px at scale 2, width 135–191).
4. **InteractionProbe/Hurtbox.** Both are now projected grid circles (`GridShapes.ellipse_polygon`,
   circumscribed 16-gon, on the foot point) instead of screen circles (probe radius 12 px, hurtbox
   6 px at (0, −8)), and are documented (ARCHITECTURE §7.2) and tested as **broad phase only**:
   the probe gates the largest Green Zone interaction distance (`GridShapes.PROBE_RADIUS` = 1.05
   tiles), the hurtbox is the player's 0.26-tile radius, and rules decide with
   `GridShapes.distance` (the source's hypot). `test_SLICE_probe_and_hurtbox_are_projected_grid_ellipses_broad_phase_only`:
   every vertex lies on the projected grid circle, 2,000 grid points within the radius project
   inside (no missed contact), a corner point is inside but farther (so the shape never decides),
   and a real Area2D overlap in the physics server accepts a target at 1.0 tile and rejects one at
   1.3 tiles.

### Commands executed and results (Linux)

| Command | Result |
|---|---|
| `NODE=/opt/node24150/bin/node godot/tools/build_assets.sh --check godot` | `asset check OK: 33 outputs identical (15 copies), Node v24.15.0, Playwright 1.63.0, Chromium 153.0.8010.12 (revision 1243, pinned; host browser reported 153.0.8010.12)`; `build_resources check (all): OK, 7 outputs identical`; exit 0 |
| the extractor with a revision-1243 slot holding the 157 headless shell | `Chromium 157.0.8103.78 is not the build pinned by playwright-core 1.63.0 (153.0.8010.12, revision 1243); run npx playwright install chromium.`, exit 6 |
| `rm -rf godot/.godot && godot --headless --path godot --import` | exit 0, 0 errors, 0 warnings |
| `godot --headless --path godot --script res://tests/test_runner.gd -- --suite all` | **110 passed, 0 failed** (unit 60, content 15, integration 35), exit 0; the Android-preset PCK case: 5,185,812 bytes, 83 runtime resources loaded from the pack (171 packed files), clean 600-frame packed startup |
| `godot --headless --path godot --quit-after 600` | exit 0, 0 errors, 0 warnings |
| PixiJS under Node v24.15.0: `npm test`, `npm run build`, `npm run smoke`, `npm run playtest -- --skill 0.7 --ending knight --choice first` | 30 files / **248 tests passed**; build OK; smoke **36/36 sub-levels ok**; playtest 36 sub-levels, 0 unfinished, 0 flagged, 0 page errors, ending KNIGHT; all exit 0 |
| `godot/tools/source_tree_guard.sh`; `git diff --check` | guard OK (only `/godot` and `docs/porting` differ from `95b69c0`); diff clean |

### Windows evidence: still not obtained (historical; obtained since, see correction report 4)

"Windows PowerShell asset check exits 0" and "Godot Windows suite remains 107/107 or better" were
**not** run: no Windows machine is attached to this session and none is reachable from this
environment; the CI route needs the D-15 gate-5 exception (still proposed only, updated in
`docs/porting/proposals/godot-port-windows.yml`, which already runs `npx playwright install
chromium`). What changed for the Windows check: with F-13 fixed, the committed outputs now
carry the same pinned Chromium that a Windows `npx playwright install chromium` provides, and
the font/audio outputs proved independent of the Chromium build (157 vs 153). Rasterization and
WebAudio decoding on Windows itself remain unverified.

Simulated Windows checkout (not Windows evidence): `git clone -c core.autocrlf=true` of this commit
(CRLF in 111 source `.ts` files), `npm ci`, then the same asset check (**exit 0**, 33 + 7 outputs
identical, pinned Chromium 153.0.8010.12), the full suite (**110 passed, 0 failed**) and the
600-frame run (exit 0, 0 errors, 0 warnings); `git status` stayed clean.

### Architect review result

Pending.

---

## Historical — correction report 2: second M1/M2 review (`9f458f8`; M1 Partial, M2 Partial)

> Historical record of `9f458f8`, superseded by later reports; current status is correction report 4.

Scope: the architect's nine items on `7b67122`, in one commit. No M3 content. IsoGrid,
GridKinematicSolver, movement, camera, depth sorting, Green Zone rules, safe-area routing, the
audio lifecycle and the three-layer pollution renderer are unchanged (the renderer layers and
AudioService only gained the debug-only bounds of item 5).

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (nothing accepted) |
| Base | `7b67122` |
| Godot / toolchain | 4.7.2.stable.official.ed1daf0bf Linux x86_64; Node v24.15.0, Playwright 1.63.0, Chromium 157.0.8103.78 |
| Hosts not available | **Windows** (none reachable from this environment; see "Windows evidence"); Android (no SDK, templates or device) |

### Changes per review item

1. **Windows dynamic imports.** All 22 dynamic imports of audited source modules in
   `extract.mjs` go through `importSource(rel)` = `import(pathToFileURL(path.join(SRC, rel)).href)`
   (a bare `C:\…` path is rejected by the ESM loader as an unsupported URL scheme). The TS resolve
   hooks already used `pathToFileURL`. Verified on Linux (regeneration and `--check`); **not run on
   Windows** (see below).
2. **Export-safe leading silence.** `tools/build_resources.gd` builds
   `data/audio/sfx_leading_silence.tres` (`SfxLeadingSilence`: audited commit, runtime rate 48000,
   trim level, cue → seconds) from the extractor's JSON; `build_resources --check` now verifies 7
   outputs. `AudioService` preloads the Resource and reads no JSON; the JSON stays a non-exported
   build input (`data/*.json, data/*/*.json` exclusions unchanged). `assets/environment/manifest.json`
   is excluded from the release package. New integration case
   `test_SLICE_android_pck_has_runtime_data_and_starts_clean`: `--export-pack "Android"` with the
   running binary (no export templates needed), then the pack as the only `res://` (`--main-pack`):
   every runtime resource of the project (82, derived from the project tree, minus the font page
   PNG that the `.fnt` import consumes) loads from the pack, OFL.txt is present, nothing under
   `tests/`/`tools/` and no `.json`/`.md` is packed, AudioService has the 6 offsets from the pack,
   the real main scene starts the Green Zone with Zampanò's SpriteFrames, and a 600-frame packed
   startup exits 0 with no engine error or warning. Packed runs get their own user-data directory
   (`XDG_DATA_HOME`/`APPDATA`), so they never touch a real save.
3. **Future format in main, temp and backup.** `load_from_disk` validates all three files first.
   Any future-format file is copied byte-for-byte (`save_v3.future.json`,
   `save_v3.tmp.future.json`, `save_v3.bak.future.json`; an identical copy is not rewritten, a
   different earlier copy is kept), `future_files` lists the locations, no save file is touched
   again (no temp deletion, no promotion, no rotation) and every write is refused
   (`write_blocked_future_version`). A future main loads defaults; otherwise the valid
   current-format file is shown read-only. `test_SAV_022_…` covers each location with a payload
   containing CRLF, non-ASCII characters and trailing spaces: status, blocked writes, every file
   byte-identical after two refused writes, the copy byte-identical, and a second launch.
4. **No corrupt copy of a valid older main.** Only an INVALID main is written to
   `save_v3.corrupt.json`; on temp recovery a valid older main is rotated to the backup by the
   normal write. `test_SLICE_temp_recovery_keeps_a_valid_older_main_as_backup` (plus the invalid
   main case, still preserved).
5. **Bounded, debug-only diagnostics.** `AudioService.started` records only when
   `diagnostics` (default `OS.is_debug_build()`) and keeps the last 64 entries; the Ground and
   overlay TileMap layers record `applied` only in debug builds and for at most 256 distinct cells
   (the integer `callback_calls` counter stays). `test_SLICE_diagnostics_are_bounded_and_debug_only`.
6. **MAP-007** is one aggregator, `test_MAP_007_green_zone_topology_route_and_treats_match_source`:
   96×96 rows (and SHA-256), size, start/exit, playable tiles, every prop, every ground count,
   the exit-distance field, the canonical start→exit route length (the source's `startDist` that
   `placeTreats` walks) and the 30 treat placements (twice, same seed). The separate `MAP_007b`
   case is gone.
7. **Profile isolation.** `AppState.reload()` resets `selected_profile` to the validated default on
   every call; `--as=<id>` is accepted only for profiles in `AppState.PROFILES` (Zampanò in this
   build), otherwise rejected with a warning and recorded in `rejected_profile`. The isolation pair
   dirties both fields; `test_SLICE_profile_override_is_validated` covers the pure resolver.
8. **AUTO-001 label removed** from the slice driver, the slice run case and its output line.
9. **VIEW-002 resolved for the original algorithm.** No new clamp. The extractor executes the
   source `computeViewport` over a dense grid (5 DPRs × 26 widths × 22 heights = 2,860 cases,
   device px 100–2,525 × 160–2,911) and stores the outputs; `test_VIEW_002_…` requires the Godot
   result to equal the source in every case, an integer scale, and width 192–270 / aspect
   0.42–0.62 wherever the source gives them, the only exceptions being the source's own (narrow
   areas: scale 1 at their width, 360 cases; constrained areas 271–383 px: scale 2 at 135–191 px,
   210 cases; 2,290 in range). TEST_PLAN VIEW-002 now states this resolution.

### Commands executed and results (Linux)

| Command | Result |
|---|---|
| `NODE=/opt/node24150/bin/node godot/tools/build_assets.sh --check godot` | `asset check OK: 33 outputs identical (15 copies), Node v24.15.0, Playwright 1.63.0, Chromium 157.0.8103.78`; `build_resources check (all): OK, 7 outputs identical`; exit 0 |
| `rm -rf godot/.godot && godot --headless --path godot --import` | exit 0, 0 errors, 0 warnings |
| `godot --headless --path godot --script res://tests/test_runner.gd -- --suite all` | **107 passed, 0 failed** (unit 59, content 14, integration 34), exit 0; VIEW-002 compared 2,860 source cases; the PCK case exported 5,183,640 bytes, checked 82 runtime resources against 169 packed files |
| `godot --headless --path godot --quit-after 600` | exit 0, 0 errors, 0 warnings |
| PixiJS under Node v24.15.0: `npm test`, `npm run build`, `npm run smoke`, `npm run playtest -- --skill 0.7 --ending knight --choice first` | 30 files / **248 tests passed**; build OK; smoke **36/36 sub-levels ok**; playtest 36 sub-levels, 0 unfinished, 0 flagged, 0 page errors, ending KNIGHT; all exit 0 |
| `godot/tools/source_tree_guard.sh`; `git diff --check` | guard OK (only `/godot` and `docs/porting` differ from `95b69c0`); diff clean |

Captures and the rendered probes were not re-run: nothing visual or in the interpolation path
changed (the 18 captures of correction report 1 stand).

### Windows evidence: not obtained (blocked) (historical; obtained since, see correction report 4)

The two Windows items of the required evidence were **not** produced:

- "Windows PowerShell asset check exits 0" — not run.
- "Godot Windows console suite remains 104/104 or better" — not run.

No Windows machine is reachable from this cloud environment (no attached computer). Two ways to get
it were attempted and stopped by this environment's permission policy, deliberately not worked
around:

- A GitHub Actions workflow on a `windows-2025` runner (the repository is public, so the runner
  is free) needs a file in `.github/workflows/`, outside the paths MILESTONES gate 5 allows, and an
  exception in `godot/tools/source_tree_guard.sh`. Widening the guard was refused as an oversight
  change that is the architect's to approve. The ready workflow is kept, **inactive**, at
  `docs/porting/proposals/godot-port-windows.yml` (D-15): it verifies the official Godot 4.7.2
  win64 zip against `SHA512-SUMS.txt`, uses the pinned Node, runs `npm ci` and the lockfile's
  Chromium, then exactly `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check`, the
  console import + suite, the 600-frame run, and fails if the checks modified tracked files.
- Installing PowerShell 7 for Linux to at least execute `build_assets.ps1` here was refused too.

The simulated Windows checkout below (`core.autocrlf=true`) is repeated for this commit; it is
not Windows evidence.

`git clone -c core.autocrlf=true` of this commit, then (pinned Node 24.15.0):

| Step in the clone | Result |
|---|---|
| checkout | CRLF in 111 source `.ts` files; LF in every Godot text file (the only CRLF file under `godot/` is the verbatim `assets/environment/manifest.json`, binary by design); `git status` clean |
| `npm ci` | exit 0 |
| `NODE=… godot/tools/build_assets.sh --check godot` (includes a clean `--import`) | `asset check OK: 33 outputs identical (15 copies) …`; `build_resources check (all): OK, 7 outputs identical`; exit 0 |
| full suite | **107 passed, 0 failed**, exit 0 (includes the PCK export/packed-runtime case) |
| `--quit-after 600` | exit 0, 0 errors, 0 warnings; `git status` still clean |

### Deviations

| ID | Status |
|---|---|
| D-15 | **New, needs approval:** Windows CI workflow outside `/godot` and `docs/porting` (gate 5 exception) to produce the Windows evidence; proposed only, not active |
| F-09 / VIEW-002 | Closed by the review resolution: the source algorithm is authoritative |
| D-01–D-14 | As in correction report 1 |

### Architect review result

Pending.

---

## Historical — correction report 1: M1/M2 review fixes (`7b67122`; M1 Partial, M2 Partial)

> Historical record of `7b67122`, superseded by later reports; current status is correction report 4.

Scope: the architect's ten correction items on `5858dc7`, in one commit. No M3 content. IsoGrid,
GridKinematicSolver, movement, depth sorting, camera, needs, pollution and scoring logic are
unchanged (only presentation rounding, diagnostics counters and test hooks were added around them).

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (neither complete; nothing accepted) |
| Base | `5858dc7` |
| Godot | 4.7.2.stable.official.ed1daf0bf, Linux x86_64 |
| Asset toolchain | Node **v24.15.0** (official linux-x64 build, = `godot/tools/.node-version`), Playwright 1.63.0 (= `package-lock.json`), Chromium 157.0.8103.78 |
| Renderer for captures/probes | Xvfb + Mesa llvmpipe, GL Compatibility |
| Hosts not available | Windows (no Windows host or Wine here); Android (no SDK, templates or device) |

### Changes per review item

1. **Platform-independent asset pipeline.** The extractor reads every source input as the audited Git
   blob (`git cat-file blob 95b69c0:<path>`), so working-tree line endings (autocrlf) cannot change
   a hash or an output. Generated text (FNT, JSON, `.tres`, `.import`) is LF and refused if it
   contains CR; `godot/.gitattributes` pins LF for every generated/edited text type and marks
   binary inputs (`assets/environment/manifest.json` is a CRLF blob in the source and is copied
   byte-for-byte; PNG/MP3/WAV/WOFF2/OFL.txt). `--check` now verifies every generated output
   (33 outputs incl. 15 copies, SHA-256 in `data/source_asset_manifest.json`) and
   `build_resources.gd --check` verifies the 6 Godot-built outputs. Guards: refuses to run if
   `src/`, `public/`, `assets/`, `package.json` or `package-lock.json` differ from the audit
   (exit 3), if Node is not exactly v24.15.0 (exit 4), or if the installed Playwright differs from
   the lockfile (exit 5). Everything was regenerated under 24.15.0. Windows commands:
   `godot/tools/build_assets.ps1 -Godot <Godot_v4.7.2-stable_win64_console.exe> -Check` and the
   `_console.exe` test command (README, TEST_PLAN §2).
2. `application/config/quit_on_go_back=false`; `test_SLICE_android_back_pauses_and_never_quits`
   asserts the setting and that Back pauses (Android Back itself unverified on device).
3. **Evidence corrected.** Case naming (TEST_PLAN): `test_<ID>_…` only when every clause is
   exercised, `test_P_<ID>_…` partial, `test_SLICE_…` no plan ID. 104 cases were renamed or
   classified accordingly; M1 and M2 marked Partial; capture count corrected (below); AUTO-001 is
   not claimed and stays reserved for the M3 run with an attack. Errata for the first report are
   listed in that report.
4. **Missing M2 tests added:** VIEW-003 (safe-area override + real `Input.parse_input_event`
   routing through the SubViewportContainer, ≤0.5 logical px), P_VIEW_004, MOVE-005, COLL-003
   (segment-through-obstacle tunnelling at run speed and worst delta), P_COLL_005, DEPTH-003,
   CAM-003, MAP-006, DOG-004, P_DOG_005, DOG-006, CORE-002 at 30/60/90/120 FPS caps, real SubViewport
   multi-touch routing, test-state isolation (`_isolate()` per case: InputService, AudioService,
   SaveService per-case `user://test_runs/<pid>/case_NNN/`, AppState reload, renderable IDs,
   `Engine.max_fps`, time scale; proven by the `SLICE_isolation_1/2` pair), and the rendered
   multi-rate probe (below).
5. **Deep water and walls:** DEEP (phase-rotated `deep_phase0/1` by `hash2(i,j,74)`), WALL
   (`wallBase_0` + depth-sorted `wallBlock` props by `hash2(i,j,5)`) and the story grounds render
   through the shared IsoWorld; COLL-004 covers blocked/walkable grounds including deep water and
   walls; `test_SLICE_deep_water_and_wall_diagnostic_rendering` + capture 20.
6. **SaveService:** `load_status` (new / loaded / recovered_from_temp / recovered_from_backup /
   future_version / corrupt) and `last_error`; the newest valid of main/temp/backup wins; a corrupt
   main is preserved as `save_v3.corrupt.json`; a future-format main is copied byte-for-byte to
   `save_v3.future.json` and writing is blocked; `save_failed` is emitted on any write failure and
   callers report `saved`. SAV-020 injects a crash at all four write stages; SAV-022 replaces the
   vacuous test with real assertions (file untouched, writes blocked, status reported).
7. **Audio:** the briefing and the result card play `intro`, the walk plays `greenzone`, each track
   resumes from its own position; background (`APPLICATION_PAUSED`/focus out) suspends music and
   every effect player, and effects started while suspended start paused; effects start after the
   source's leading silence (computed by executing the source `leadingSilence` in Chromium at 48 kHz:
   bark 0.0947 s, treat 0.0404 s, pee 0.0075 s, drink 0.2799 s, poop/splash 0); the drink WAV is
   imported lossless (`compress/mode=0`).
8. In-viewport `#0c3a10` underlay (canvas layer −100, logical size) under the world; the outer
   pillar/letterbox stays black (`test_SLICE_viewport_underlay_and_black_letterbox`, capture 20).
9. ARCHITECTURE §7 and TEST_PLAN now state the measured `TILE_LAYER_OFFSET = Vector2(-16, 0)` and
   approve the three-layer pollution renderer (Ground tint, Pollution, Fresh); WORLD-005 asserts
   the TileData the engine itself passes to `_tile_data_runtime_update`.
10. `assets/fonts/OFL.txt` is in the export `include_filter`; the Android label is restored to
    `SUPERVILLAINED: CRUSADER` (`test_SLICE_export_ships_ofl_and_the_app_label`).

### Commands executed and results (Linux)

| Command | Result |
|---|---|
| `NODE=/opt/node24150/bin/node godot/tools/build_assets.sh --check godot` | `asset check OK: 33 outputs identical (15 copies), Node v24.15.0, Playwright 1.63.0, Chromium 157.0.8103.78`; `build_resources check (all): OK, 6 outputs identical`; exit 0 |
| the extractor under Node v24.22.3 | `Node v24.22.3 is not the pinned v24.15.0 … refusing to run.`, exit 4 |
| simulated Windows checkout: `git clone -c core.autocrlf=true`, `npm ci`, `--check`, suite, 600-frame run in the clone | all exit 0, see "Simulated CRLF clone" below |
| `rm -rf godot/.godot && godot --headless --path godot --import` | exit 0, 0 errors, 0 warnings |
| `godot --headless --path godot --script res://tests/test_runner.gd -- --suite all` | **104 passed, 0 failed** (unit 58, content 14, integration 32), exit 0, no leaks or orphans |
| `godot --headless --path godot --quit-after 600` | exit 0, 0 errors, 0 warnings |
| `xvfb-run … tools/interpolation_probe.gd` | exit 0 (results below) |
| `godot --headless --path godot --script res://tools/audio_suspend_probe.gd` (forces playback on the Dummy driver so playbacks are live; outside the suite because they are never mixed) | `{"late_effect_paused":true,"live_players":2,"ok":true,"paused_in_background":[true,true],"resumed":[true,true]}`, exit 0; the engine then reports the never-mixed playbacks as leaked at exit (6 objects, 3 resources), the reason this probe is outside the suite |
| `xvfb-run … capture_suite.gd` (tour, `--mode run`, `--mode diagnostic`, two viewport sizes) | 18 PNGs (below); the real-time run reached the exit with total 5660 at 45.17 s |
| PixiJS under Node v24.15.0: `npm test`, `npm run build`, `npm run smoke`, `npm run playtest -- --skill 0.7 --ending knight --choice first` | 30 files / **248 tests passed**; build OK; smoke **36/36 sub-levels ok**; playtest 36 sub-levels, 0 unfinished, 0 flagged, 0 page errors, ending KNIGHT; all exit 0 (also green under v24.22.3) |
| `godot/tools/source_tree_guard.sh`; `git diff --check` | guard OK (only `/godot` and `docs/porting` differ from `95b69c0`); diff clean |

### Rendered multi-rate interpolation probe (`tools/interpolation_probe.gd`, 432×432, llvmpipe)

The real PlayableDog runs east at RUN speed under a static camera; each rendered frame is read
back. Interpolated runs: no repeated frame while moving, no jump beyond two frames' worth, teleport
shown at once. A control run with interpolation off must stutter (it does), proving the metric.
A last pass follows the dog with the real CameraRig: two static markers 40 px apart stay exactly
40 px apart on every frame (no static shimmer).

| FPS cap | achieved | expected px/frame | repeated frames | max px/frame | teleport error px |
|---|---|---|---|---|---|
| 30 | 30.0 | 5.65 | 0 | 6.5 | 3.5 |
| 60 | 60.1 | 2.82 | 0 | 3.5 | 0.5 |
| 90 | 90.0 | 1.88 | 0 | 2.5 | 1.0 |
| 120 | 119.9 | 1.42 | 0 | 2.0 | 1.0 |
| 120, interpolation **off** (control) | 120.4 | 1.41 | **21** | 3.0 | 1.0 |

Camera-follow pass: 90 and 120 FPS, 48/48 frames measured, marker gap always 40 px. This is
renderer evidence for VIEW-004/DOG-008/CAM-004 but runs outside the headless suite and on llvmpipe
only, so those IDs stay partial.

### Captures (18 PNGs in `docs/porting/captures/m2_green_zone_slice/`)

- Tour, 432×864 (logical 216×432 at scale 2), 8: `01_briefing` … `08_touch_joystick`.
- Real-input run, 5: `10_poop_dirt`, `11_pee_cleans_poop`, `12_occlusion_fade`,
  `13_level_end_reveal`, `14_level_end_final`.
- Diagnostic, 800×600, 1: `20_diagnostic_deep_water_walls_story_grounds` (deep water, walls and
  wall blocks, story grounds, void on the green underlay, black pillarbox outside the viewport).
- Viewport extremes, 4: `view_192x457/{02_start,03_walk_north}`, `view_270x435/{02_start,03_walk_north}`.

### Simulated CRLF clone

Closest available stand-in for a Windows clean clone (Linux, not a Windows host):
`git clone -c core.autocrlf=true --branch claude/gallant-keller-rbvtvy` of this commit's tree.
The checkout had CRLF line endings in 111 source text files (e.g. `src/core/audio.ts`,
`package.json`) and LF in every Godot text file (`godot/.gitattributes`); `git status` clean.

| Step in the clone | Result |
|---|---|
| `npm ci` (Node v24.15.0) | exit 0 |
| `NODE=… godot/tools/build_assets.sh --check godot` (includes a clean `--import`) | `asset check OK: 33 outputs identical (15 copies), Node v24.15.0, Playwright 1.63.0, Chromium 157.0.8103.78`; `build_resources check (all): OK, 6 outputs identical`; exit 0; `git status` still clean |
| `godot --headless --path godot --script res://tests/test_runner.gd -- --suite all` | **104 passed, 0 failed**, exit 0 |
| `godot --headless --path godot --quit-after 600` | exit 0, 0 errors, 0 warnings; `git status` still clean |

### Not verified

- **Windows host:** the clean-clone asset `--check` and the Godot 4.7.2 Windows console suite were
  not executed on Windows (no Windows host here). The simulated `core.autocrlf=true` clone above is
  the closest available evidence; the PowerShell script and `_console.exe` commands are untested.
- **Android/device:** export, install, Back, immersive mode, keep-awake, display-cutout safe area,
  touch hardware, audio focus/background on a real app lifecycle, performance. Configuration only.

### Findings added by this correction

- **F-09 (VIEW-002):** the source `computeViewport` yields logical widths 135–191 px for constrained
  areas 271–383 device px wide (scale 2), outside the plan's 192–270. The port keeps source parity
  (`test_P_VIEW_002` asserts the band); the owner decides whether the plan or the source is right.
- **F-10:** `get_cell_tile_data()` returns the shared TileSet data; only the TileData the engine
  passes to `_tile_data_runtime_update` shows the runtime tint, so WORLD-005 records it inside the
  callback.
- **F-11:** `AudioStreamPlayer.stream_paused` is kept only by a live playback and a paused playback
  reports `playing == false`; with the Dummy driver no playback is live, so the suite checks the
  suspension mapping and the probe checks live playbacks under a real driver.
- **F-12:** the test runner previously skipped a test file that failed to parse (0 cases, no
  failure); it now fails the run.

### Deviations status after this correction

| ID | Status |
|---|---|
| D-02 | Closed: three runtime layers approved in ARCHITECTURE §7 |
| D-05 | Partly closed: recorded intro/greenzone music, six effects, leading-silence offsets, background suspension; synthesized cues still silent (M1 audio pipeline) |
| D-12 | Closed: Node v24.15.0 pinned, enforced and used for all generated outputs |
| D-14 | Partly closed: logic at 30/60/90/120 FPS in the suite; rendered presentation by probe (llvmpipe); device rates unverified |
| D-01, D-03, D-04, D-06–D-11, D-13 | Unchanged |
| B-03, B-05 | Closed (ARCHITECTURE §7 offset; TEST_PLAN import step) |
| B-01, B-02, B-04 | Unchanged |

### Architect review result

Pending.

---

## Historical — milestone report: M1 foundation (partial) + M2 Green Zone vertical slice (first submission, `5858dc7`)

> Historical record of `5858dc7`, superseded by later reports; current status is correction report 4.

**Errata (corrected by the report above; this report is kept as submitted otherwise):**
- The "Automated cases" list below used plan IDs for partial checks. Of those, AUTO-001, CFG-001,
  FLOW-004, FLOW-005, GZ-001, GZ-002, GZ-005, GZ-018, GZ-021, GZ-029, AST-001–005/012/016–018/020,
  AUD-001, ARCH-001, MAP-003b, CAM-004, COLL-005, SAV-021, UI-001 and RNG-002 were not satisfied in
  full; the current classification is the correction report's and the matrix status section's.
- AUTO-001 is not claimed: it requires an attack (M3).
- Captures: 13 scripted/run captures + 4 viewport captures = 17, not "14 + 4".
- Tooling: the outputs of this submission were generated under Node v24.22.3; they were
  regenerated under the pinned v24.15.0 by the correction (D-12 closed).

| Field | Value |
|---|---|
| Milestone | First playable milestone requested by the owner: M1 core foundation and content pipeline (partial) + M2 vertical slice, extended with the Green Zone needs/pollution loop, HUD, basic save and start/finish flow from M3/M4 |
| Branch | `claude/gallant-keller-rbvtvy` (session-mandated dedicated porting branch; see B-02) |
| Base | `fb9daa8` = merge of audited source `95b69c0` into the planning-docs commit `576cbdb` (tree = source + 4 planning docs, no other change) |
| Godot | 4.7.2.stable.official.ed1daf0bf, Linux x86_64, from the official GitHub release; SHA-512 `9aa00f7a…ed54c65` matches `SHA512-SUMS.txt` |
| Source reference commit | `95b69c04c5c3b9626e49719f8f916a44659cd265` |
| Tooling | Node v24.22.3 (pin 24.15.0 unavailable, D-12), Playwright 1.63.0, Chromium 157.0.8103.78, Mesa 25.2.8 llvmpipe (captures) |
| Device | No Android device, SDK or export templates in this environment: Android not built or installed |

### Commands executed and results

| Command | Result |
|---|---|
| `godot/tools/build_assets.sh godot` (twice) | first run generated outputs; second run: `extract done … 0 file(s) changed`, `build_resources (images): OK, 0 file(s) changed`, `build_resources (resources): OK, 0 file(s) changed`; SHA-256 of every `.tres/.png/.import` identical across runs (AST-019) |
| `node … extract.mjs --check` | `asset check OK (14 copies, 4 inputs)` |
| `rm -rf godot/.godot && godot --headless --path godot --import` | exit 0, 0 errors, 0 warnings (CORE-001 clean cache) |
| `godot --headless --path godot --script res://tests/test_runner.gd -- --suite all` | **73 passed, 0 failed** (unit 46, content 11, integration 16), exit 0, no leaked objects at exit |
| `godot --headless --path godot --quit-after 600` (real Main scene, real main loop) | exit 0, 0 errors, 0 warnings |
| `xvfb-run … capture_suite.gd` (tour) and `--mode run` | 14 captures + 4 viewport captures in `docs/porting/captures/m2_green_zone_slice/`; real-time full run reached the exit with total 5660 at 45.2 s, identical to the deterministic headless run |
| `godot/tools/source_tree_guard.sh` | `OK: only /godot and docs/porting differ from 95b69c0` |
| `npm ci && npm test && npm run build` (source baseline, Node 24.22.3) | 30/30 files, **248/248 tests passed**; TypeScript + Vite build passed |
| `git diff --check` | clean |

### Automated cases (all executed, all passed)

- Unit: CFG-001, CORE-002, RNG-001/002/003, ISO-001/002/003/004, MOVE-001/002/003/004, VIEW-001/002,
  DEPTH-001/002, CAM-001, MAP-001/002 (incl. MAP-004), MAP-007 (rows, topology, props, BFS = MAP-005,
  reachability = COLL-005), GZ-001 (spot RNG), GZ-002 (needs script), GZ-005 (full scripted rules
  run: treats → warning → poop → pee-clean → drink → starvation → game over, every checkpoint and the
  complete event sequence equal to the source), GZ-008, GZ-018/019/020/021 (scoring), GZ-024,
  GZ-029, COLL-002/004, DOG-001/002/003/007, AST-005, FLOW-004 (exit), SAV-001/002/003/004/018/019/020/021/022.
- Content: AST-001/002/003/004/012/014/016/017/018/020, AUD-001.
- Integration: ARCH-001 and ARCH-001b (dummy story map through the same IsoWorld), MAP-003b,
  WORLD-004, WORLD-005, CAM-002/004, COLL-001/006, COLL-002 decision experiment, DEPTH-004, UI-001,
  MOVE-001 (keyboard + joystick + simultaneous RUN), FLOW-001/002/005, **AUTO-001**.

AUTO-001 (real input only — InputService movement and PEE, no teleport, no rule calls): start
(90,90) → exit (4,4) in 45.1 s game time, 30 treats, 7 poops, 6 pees (poops cleaned), 2 lives,
final health 0.9359, 3 stars, total score 5660, record saved, level-end overlay shown.

Source-parity precision achieved: grid solver identical to `GameMap.moveCircle` on 48 trajectories
(0.0 tile); Zampanò movement/animation traces (8 directions × walk/analog/run, exhaustion, idle
phases, scripted run, three terrains, action lock, knockback) within 1e-9 tile of the source class;
Green Zone rows, BFS field, 94 props and 30 treat positions identical; pollution field equal to
float32 precision.

### Captures (432×864 = logical 216×432 at integer scale 2; Mesa llvmpipe, GL Compatibility)

`01_briefing`, `02_start`, `03_walk_north`, `04_walk_east`, `05_run_northwest`, `06_pee_clean`,
`07_pause`, `08_touch_joystick`, `10_poop_dirt`, `11_pee_cleans_poop`, `12_occlusion_fade`,
`13_level_end_reveal`, `14_level_end_final`; viewport extremes `view_192x457/` and `view_270x435/`
(both scale 2). Manual review: tiles tessellate, path edge masks, prop anchors, 8-way sprite facing,
dirt overlay + dead-grass tint, fresh highlight, tree fade over the dog, HUD/touch layout inside the
view at all three widths.

### M2 collision decision (recorded once)

The 48 source trajectories were replayed through native `CharacterBody2D.move_and_slide()`
(floating, safe_margin 0.08, max_slides 4, wall_min_slide_angle 0.261799) against 1,194 projected
blocked-tile diamonds and prop ellipses: **21/48 trajectories exceed 0.10 tile (max 9.18 tile);
excluding starts that overlap an obstacle, 15/40 exceed (max 6.92 tile)**. Godot projects the
motion onto the wall tangent in screen space, which is not equivalent under the 2:1 projection to
the source's per-axis grid-space slide (for a grid-x wall the slide speed becomes vx − 0.6·vy).
**Selected: the approved GridKinematicSolver** (`WorldMapModel.move_circle`, exact port), 0.0 tile
deviation. `PlayableDog` stays a `CharacterBody2D` on PlayerBody (layer 2) with mask 0 (no
WorldSolid); no native slide is applied to static geometry. The test asserts native remains out of
tolerance so a future engine change forces a re-review.

### Findings for the architect

- **F-01 (contract error):** ARCHITECTURE.md §7 states `map_to_local(i,j) + Vector2(0,8)` equals
  `IsoGrid.grid_to_screen(i+0.5, j+0.5)`. Measured on 4.7.2 with ISOMETRIC + DIAMOND_DOWN +
  horizontal offset axis: `map_to_local(i,j) = tile centre + (16, 0)`. Every TileMapLayer therefore
  sits at `IsoGrid.TILE_LAYER_OFFSET = (-16, 0)`; MAP-003b proves alignment on six cells.
- **F-02:** Godot 4.7.2's decimal→double conversion (JSON, `String.to_float`, GDScript literals) is
  not correctly rounded (up to 18 ulps measured). Fixture floats are compared within 64 ulps
  (~1.4e-14 relative); RNG outputs are compared bit-exactly through their integer numerators.
- **F-03:** `Vector2` is 32-bit in official builds. Authoritative grid state (positions,
  velocities, distances, dirt) is kept in 64-bit floats; `Vector2` is presentation-only.
- **F-04:** V8's `Math.hypot` (normalised Kahan) is not bit-identical to `sqrt(x²+y²)`; it is
  ported as `JsMath.hypot` so distances and pollution stamps match the source bit-for-bit.
- **F-05:** An entry `--script` cannot statically reference classes that use autoload globals; the
  runner and capture tool access them dynamically.
- **F-06:** `JSON.parse_string` logs an engine error on corrupt input; SaveService uses
  `JSON.new().parse()` so corruption recovery is silent and testable.
- **F-07:** With the Dummy audio driver (headless/no sound card) playbacks are never mixed and leak
  at exit; AudioService records requested cues but does not play on Dummy.
- **F-08:** Camera2D under physics interpolation must be declared physics-process
  (`process_callback = 0`), otherwise the engine warns and overrides it.

### Known deviations in this milestone (to close or approve)

| ID | Deviation | Closes in |
|---|---|---|
| D-01 | Tuning is typed GDScript constants (`core/game_config.gd`) verified value-by-value against the source export (CFG-001), not `.tres` balance Resources | architect decision; trivial to convert |
| D-02 | Three runtime-updated TileMapLayers (ground tint, dirt, fresh) instead of two: in the source a cell can show dirt and the fresh highlight at once | architect decision |
| D-03 | The source's threat RNG is shared by cats/balls and pollution waves; with cats/balls not yet ported, wave placement matches the source only until the first cat spawn (16 s) | M3 |
| D-04 | Camera shake noise and treat bob phase use seeded/hashed values instead of `Math.random` (CAM-003 determinism; cosmetic) | approve |
| D-05 | Synthesized cues (warning, empty, hurt, jingle, gameover, star, …) are silent; requests are counted in `AudioService.missing_cues`. Recorded music/effects play | M1 audio pipeline (AUD-005–008) |
| D-06 | Text glow/outline-glow and the briefing's justified layout are simplified (shadow + centred wrap) | M8 |
| D-07 | Popups are text-only; the poop warning is a blinking "!" instead of the thought sprite; no particles | M8 |
| D-08 | No title/campaign yet: TITLE on the result card returns to the briefing; no CONTINUE handoff to 1.1; no Supervillained snap | M3–M5 |
| D-09 | Gesture bindings, action switcher and RUN-toggle UI are not wired (InputService supports toggle) | M3/M5 |
| D-10 | Cats, coins, magnet balls, Bagnaskiz and Under Attack are not ported | M3 |
| D-11 | Save: campaign subtree preserved as an opaque v2 object; `CampaignFlagSchema`, v1→v2 migration and legacy import not implemented | M4/M9 |
| D-12 | Node 24.22.3 used; the pinned 24.15.0 is not installed here (Playwright pinned version matches) | tooling |
| D-13 | Not done from M1: title WebP extraction (AST-010), synthesized audio WAVs, Sbrimbrulòn/Bagnaskiz profiles (AST-008/009), cast sheets, Android migration spike | M1 completion / M8 / M9 |
| D-14 | DOG-008/VIEW-004 multi-rate (30/90/120 FPS) presentation checks not executed; physics interpolation is enabled and resets on spawn/teleport/camera snap | M2 follow-up |

### Blockers and architecture conflicts

- **B-01:** The planning branch `codex/godot-port-architecture` does not exist on the remote; the four
  planning documents were taken from `main@576cbdb` (they are identical to what the milestone
  references).
- **B-02:** MILESTONES.md says "Claude Code creates `godot/vg1-port`"; this session may only push to
  `claude/gallant-keller-rbvtvy`, which is used as the dedicated porting branch.
- **B-03:** F-01 (TileMap offset contract) needs an architecture correction.
- **B-04:** Android: no export templates, SDK, signing identity, old APK or device here. The preset
  (`export_presets.cfg`: `com.zampano.supervillained`, versionCode 2, min SDK 24, portrait,
  immersive, no Internet permission) is configuration only; target SDK 36 applies only with a
  Gradle build. No APK/AAB was built and the WebView migration spike was not attempted.
- **B-05:** A clean clone must run `godot --headless --import` once before the test runner (global
  class registration); the documented TEST_PLAN command should include it.

### Android compatibility assessment (static, not device-verified)

GL Compatibility renderer; portrait orientation; keep-screen-on; ETC2/ASTC import enabled for
export validation; all pixel art imported lossless without mipmaps; touch via
`InputEventScreenTouch/Drag` with per-index pointer ownership; Back (`NOTIFICATION_WM_GO_BACK_REQUEST`)
and background (`NOTIFICATION_APPLICATION_PAUSED`/focus out) pause the run; no network API is used.

### Source-tree guard

Only `/godot` and `docs/porting/` (this log, the matrix status section, captures) differ from the
audited source commit.

### Architect review result

Pending.
