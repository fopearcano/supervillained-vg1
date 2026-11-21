# SUPERVILLAINED VG1 — Godot port implementation log

Evidence record per milestone (TEST_PLAN.md §21). Feature-matrix boxes stay unchecked until the
architect accepts the evidence; the matrix carries a pending-review status section instead.

---

## Correction report: M1/M2 review fixes (M1 Partial, M2 Partial)

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

## Milestone report: M1 foundation (partial) + M2 Green Zone vertical slice (first submission, `5858dc7`)

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
