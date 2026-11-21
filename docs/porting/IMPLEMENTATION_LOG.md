# SUPERVILLAINED VG1 — Godot port implementation log

Evidence record per milestone (TEST_PLAN.md §21). Feature-matrix boxes stay unchecked until the
architect accepts the evidence; the matrix carries a pending-review status section instead.

---

## Milestone report: M1 foundation (partial) + M2 Green Zone vertical slice

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
