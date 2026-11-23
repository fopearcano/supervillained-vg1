# SUPERVILLAINED VG1 — feature parity matrix

This is the living parity checklist for the Godot port. All Godot boxes are intentionally unchecked at planning time.

## Status legend

- **Implemented** — present in executable source and covered by code/tests or direct inspection.
- **Partial** — usable source capability with a product, coverage, or integration limitation.
- **Planned-only** — declared by old documents but not implemented; not automatically a port requirement.
- **Retired** — deliberately removed by the canonical Fourth Crusade rewrite.
- **Unverified on device** — code/config exists but this audit did not execute it on Android hardware.

Canonical evidence precedence is code/tests, `docs/STORY.md`, `docs/STORY-SOURCES.md`, then current decision-log sections. Target acceptance IDs are defined in `TEST_PLAN.md`; milestone IDs are defined in `MILESTONES.md`.

## Godot implementation status — M1 Partial, M2 Partial, awaiting architect review

Boxes below stay unchecked until the architect accepts the evidence (MILESTONES.md common gate 7).
**M1 is Partial and M2 is Partial**: neither milestone is complete or accepted. Open M1 blocker:
the Android migration-plugin feasibility spike (see "Legacy-save plan" below).
Evidence: `docs/porting/IMPLEMENTATION_LOG.md`, `godot/tests/`, `docs/porting/captures/m2_green_zone_slice/` (18 PNGs),
`docs/porting/captures/title_m1/` (title frames for approval), `docs/porting/windows_evidence/` and
`docs/porting/linux_evidence/` (real host runs).
Row status: **Slice** = the row's listed IDs are satisfied by full suite cases (or on combined
evidence, TEST_PLAN.md) for the current slice; **Partial** = implemented with a listed gap or only partial cases; **Config** = configured,
not executed; **—** = not started.

Acceptance IDs are claimed through a `test_<ID>_…` suite case that exercises every clause of the
ID (TEST_PLAN.md case naming) or, for an ID with rendered clauses, on combined evidence (TEST_PLAN.md):
named suite cases for every other clause plus the architect-accepted rendered probe for the rendered
clauses. `test_P_<ID>_…` cases alone are partial evidence and satisfy nothing; `test_SLICE_…` cases
check port behaviour that has no plan ID.

**Acceptance IDs satisfied by a full suite case (93, counting split-ID parts), Godot 4.7.2; current tree verified on the Windows console build (`godot/` tree `a06b1df`, 138 passed), Linux (Ubuntu 26.04, WSL 2) on the prior tree `d12bedd` (128 passed):**
CORE-002; RNG-001–003; ARCH-001a; VIEW-001, VIEW-002 (source algorithm, M2 review resolution), VIEW-003; ISO-001–004; MOVE-001–005; COLL-001–004, COLL-005a, COLL-006;
DEPTH-001–004; WORLD-004, WORLD-005; CAM-001–003; MAP-001–007;
DOG-001–004, DOG-005a, DOG-006, DOG-007; GZ-008, GZ-009, GZ-019, GZ-020, GZ-024; AST-001–018, AST-020; AUD-001–008;
FLOW-001, FLOW-002; SAV-001–004, SAV-013–020, SAV-022 (main, temp and backup).
MAP-007 is one aggregator case (rows/topology, canonical route length, treat placements).
Every automated M1 ID (ISO-001–003, RNG-001–003, AST-001–020, AUD-001–008, SAV-013–017) is
satisfied, AST-019 by command evidence. **AST-007 / finding F-15 accepted by the architect**
(review of `6b91fd3`): the sword and shield are baked into the armoured frames, so shared frame and
foot-anchor alignment is the applicable "arms attachment" contract.

**Satisfied on combined evidence (3; TEST_PLAN.md; rendered clauses accepted by the architect on the
review of `6b91fd3`):** VIEW-004 (suite: `test_P_VIEW_004_whole_pixel_world_and_nearest_filtering`,
nearest filtering and whole-pixel sprite, camera and UI transforms; rendered: the probe's 30/60/90/120
FPS runs with no streak or double interpolation and its static-shimmer pass); CAM-004 (suite:
whole-pixel camera origin in `test_CAM_002_camera_clamps_small_and_large_maps` and
`test_P_VIEW_004_…`; rendered: the probe's static-shimmer pass under the moving `CameraRig`);
DOG-008a (suite: `test_CORE_002_logic_independent_of_render_rate` for the spawn, teleport and
camera-snap resets and the shipped test-hook defaults, `test_P_DOG_008a_main_restart_resets_interpolation_and_run_state`
for the restart through the real Main flow; rendered: the probe's presentation and teleport-reset
clauses). The rendered clauses did not run in the headless suite: they are the probe's command-level
evidence (below). Total satisfied: 96 (93 + 3).

**Split IDs (TEST_PLAN.md; a parent is satisfied only when both parts are):** ARCH-001 =
ARCH-001a (M2, satisfied) + ARCH-001b (M5, production story scene); COLL-005 = COLL-005a (M2,
satisfied) + COLL-005b (M5–M7: scripted-position objectives; `test_P_COLL_005b` evidence in
M5/M6, the full aggregate in M7). COLL-005 covers static and scripted-position reachability only;
dynamic goals (moving or runtime-placed targets) are owned by WALK/NPC/MINI and each scene's STY
real-input completion. DOG-005 = DOG-005a (M2,
satisfied) + DOG-005b (M3, forced fetch); DOG-008 = DOG-008a (M2, satisfied on combined evidence) + DOG-008b (M5,
stage change).

**Automated M2 acceptance IDs (MILESTONES.md M2):** all satisfied, by full suite cases or, for
VIEW-004, CAM-004 and DOG-008a, on combined evidence (above). M2 stays **Partial**: its manual
desktop and touch play checks are not done (below).

**Partial evidence only (not satisfied, later milestones):** GZ-001, GZ-002, GZ-021, GZ-025,
SAV-021 (no user-visible notice yet), UI-001–006, FLOW-005.

**Command-level evidence (no suite case, architect to judge):** CORE-001 (clean-cache import and
600-frame Main run on a clean Windows 11 clone of the current tree (`godot/` `1532143`), and on a clean
Ubuntu 26.04 clone of the prior tree `d12bedd`); **rendered interpolation probe** (accepted by the
architect as command-level rendered evidence for VIEW-004, CAM-004 and DOG-008a's rendered
presentation and teleport-reset clauses): `tools/interpolation_probe.gd` with
`--rendering-driver opengl3 --disable-vsync` on the RTX 3090 for the current tree `a06b1df`:
30.0 / 60.0 / 90.2 / 120.0 FPS achieved, 0 repeated frames, no streak or double interpolation, the teleport shown at once; the interpolation-off control showed 21 repeated frames at 120 FPS; static markers stayed 40 px apart under the moving camera at 90 and 120 FPS (`windows_evidence/correction-11-godot-tree-a06b1df/`); the architect's
independent run on `1532143` passed at 30/60/90/120 FPS; AST-019 (all 206 generated outputs byte-identical
under the Chromium build pinned by the locked playwright-core, 153.0.8010.12:
`pwsh godot/tools/build_assets.ps1 -Check` on Windows 11 with `core.autocrlf=true` for the current tree,
and `build_assets.sh --check` on Ubuntu 26.04 for `d12bedd`, the same bytes; the generated outputs
did not change between the two trees).

**Host verification.** *Current tree* (`godot/` tree `a06b1df5e3db91f0fc7690785d94932fdf6bca24`, correction report 11: the
`1532143` tree without the ARCH-001a source-parser gate and with the real restart case, test files
only): a fresh Windows 11 25H2 clone (PowerShell 7.7.0, Godot 4.7.2 console exe, Node 24.15.0,
pinned Chromium, WASAPI audio) passed the asset check (206 + 55 outputs identical), the clean import,
the suite **138 passed, 0 failed**, the 600-frame Main run, the PCK smoke, the rendered
interpolation probe with VSync off, the live audio probe,
the PixiJS baseline (248 tests, build OK), `git diff --check` and the source-tree guard
(`windows_evidence/correction-11-godot-tree-a06b1df/`). *Previous Windows trees*: `1532143`
(correction report 10, **137 passed**, `windows_evidence/correction-10-godot-tree-1532143/`), `6a3c53b`
(correction report 9, **137 passed**, `windows_evidence/correction-9-godot-tree-6a3c53b/`), `b1c3595`
(correction report 8, **137 passed**, `windows_evidence/correction-8-godot-tree-b1c3595/`),
`b8535ab` (correction report 7 addendum, **137 passed**,
`windows_evidence/correction-7-godot-tree-b8535ab/`) and `81906cd` /
`fd20ac1f3c8ac95fb197fd7bcca6a5d4c2c95876` (correction report 6, **134 passed**,
`windows_evidence/correction-6-godot-tree-fd20ac1/`). **Correction 6 was not rerun on Linux, and
neither were correction 7's addendum and corrections 8, 9, 10 and 11.** *Prior tree* (`d12bedd`, progress report 5): a fresh Ubuntu 26.04 (WSL 2) clone passed the
asset check, clean import, suite **128 passed, 0 failed**, 600-frame run and empty `git status`
(`linux_evidence/d12bedd/`), and Windows additionally ran the rendered probe at 30/60/90/120 FPS
with VSync off (`windows_evidence/d12bedd/`). Earlier Windows evidence for `a0e3b8d` is kept in
`windows_evidence/a0e3b8d/`. Windows is a development host only; the D-15 Windows CI workflow stays
a proposal.

**Export evidence (SLICE, no plan ID):** the Android preset exports as a PCK with the test binary and
runs as a packed runtime: every runtime resource loads from the pack, no JSON/tests/tools/
environment manifest is packed, the exported leading-silence Resource reaches AudioService, and a
600-frame packed startup logs no engine error or warning. Not an APK and not device evidence.

**Not claimed:** AUTO-001 is reserved for the M3 run that includes an attack
(`test_SLICE_real_input_run_reaches_exit` is the current real-input run); FLOW-003/004, GZ-005 and
every other ID not listed above.

**Not verified (no physical device or tester here; the emulator below has not run the game yet):**
everything on Android hardware or the emulator (export, install, Back, immersive, keep-awake,
display cutout safe area, touch hardware, audio focus, performance);
the M1 migration-plugin spike (open M1 blocker, below); the manual M1/M2 checks (desktop and touch
play sessions, occlusion and camera-edge inspection, crisp rendering at two sizes and one
non-integer aspect, animation preview, listening to the audio, approval of the title images).

**Legacy-save plan (approved: MILESTONES.md M1/M4/M9, ARCHITECTURE.md §17.2–17.3):**
1. **M1 — feasibility spike, open M1 blocker.** A throwaway native migration plugin under
   `/godot/platform/android/`, tested on a controlled same-package/same-signature old→new APK
   lineage: it either reads the five legacy `supervillained:` keys without mutating them, or a
   reproducible failure is documented, and the native-bridge versus staged-Capacitor decision is
   written. Not started. Available on this Windows host (correction report 8): the Android SDK
   (platform-tools/adb 37.0.3, build-tools 36.1.0, platform 36), Godot's 4.7.2 Android export
   templates, JDK 21, and the emulator device `sv_m1_api36` (adb serial `emulator-5554`, Android 16 /
   API 36, Google WebView 133.0.6943.137). Remaining blocker: the migration plugin itself and a
   controlled signed old→new APK lineage. M1 cannot be complete without it.
2. **M4 — deterministic format-3 converter and SaveService integration**, plus the fixture/simulated
   MIG-005 (the raw five-key payload written exactly with timestamp and SHA-256 before any parsing;
   backup, write and read-back failure tests). The pure v1→v2 rules, SAV-013–017, are ported now.
3. **M9 — production proof:** the actual installed lineage and signing certificate, two WebView/device
   versions, and end-to-end MIG-001–010.

| Matrix row | Godot status | Evidence (suite case IDs; P = partial case) | Gap / note |
|---|---|---|---|
| Godot project isolated under `/godot` | Partial | CORE-001 command evidence: Windows 11 clean clone of the current tree (correction report 11, `godot/` `a06b1df`; before it correction report 10, `1532143`); Ubuntu 26.04 clean clone of the prior tree `d12bedd`; source-tree guard on the current tree | command evidence only, architect to judge |
| Fixed 60 Hz game rules | Slice | CORE-002 (30/60/90/120 FPS caps, logic identical to the 60 Hz reference) | — |
| Adaptive pixel-perfect viewport | Partial | VIEW-001, VIEW-002, VIEW-003; VIEW-004 on combined evidence (`test_P_VIEW_004` + the architect-accepted rendered probe); underlay/letterbox SLICE case; 4 viewport captures; rendered probe on llvmpipe and a real RTX 3090 | device safe area unverified |
| Portrait / Back / immersive / keep-awake | Config | project settings (`quit_on_go_back=false`, keep_screen_on), SLICE Back case | not run on a device or the emulator yet |
| Native Android build | — | SLICE: Android-preset PCK export + packed-runtime startup | no APK built yet; the Android SDK, export templates and the emulator `sv_m1_api36` are now available |
| 2:1 projection | Slice | ISO-001–004 | 64-bit math (F-03) |
| Screen-space movement semantics | Slice | ISO-004, MOVE-001 | — |
| Eight-direction facing | Slice | MOVE-002, MOVE-003 | — |
| Walk/run/terrain speed | Slice | MOVE-003, MOVE-004, MOVE-005 | — |
| Collision and sliding | Slice | COLL-001–004, COLL-005a (one continuous drive to every treat's exact position within its pickup radius and on to the exit; every reachable story-map marker), COLL-006; SLICE solver decision | GridKinematicSolver (native slide rejected); COLL-005b scripted-position story objectives (M5–M7) |
| Shared Green Zone/story world | Slice | ARCH-001a (dummy Story host scene: same classes and public interfaces, its own environment resources, lifecycle, movement, camera, sorting, recursive cleanup); no duplicate playable/input controller: a static code-review requirement (ActorBody controllers on the shared solver allowed) | ARCH-001b production story scene (M5) |
| Camera lag/look-ahead/sway/shake/clamp | Slice | CAM-001–003; CAM-004 on combined evidence (whole-pixel origin in the suite + the architect-accepted rendered probe's static-shimmer pass) | shake noise seeded (D-04) |
| Stable depth sorting | Slice | DEPTH-001–003 | — |
| Tall-object occlusion | Slice | DEPTH-004, capture 12 | — |
| Animated terrain and pollution presentation | Slice | WORLD-004, WORLD-005 (engine TileData), captures 10/11/20 | three layers, approved in ARCHITECTURE §7 |
| ASCII maps and markers | Slice | MAP-001–007 (all twenty story maps parse like the source) | story scenes M5 |
| Deep water and walls | Slice | COLL-004; SLICE diagnostic rendering case; capture 20 | — |
| Contact shapes (InteractionProbe/Hurtbox) | Partial (pre-M3 contract) | SLICE: projected grid ellipses on the foot point, broad phase only, exact grid distance decides; real Area2D overlap; SLICE: probe reaches prop centres at rule distance + prop radius (tree/pole/fountain ±1e-9 boundaries, 16 directions, exact edge-distance decision authoritative) | consumers arrive with M3 |
| Zampanò state controller | Slice | DOG-001–004, DOG-005a, DOG-006, DOG-007; DOG-008a on combined evidence (`test_CORE_002` spawn/teleport/camera-snap resets and test-hook defaults, `test_P_DOG_008a` restart through the real Main flow, the architect-accepted rendered probe) | DOG-005b forced fetch (M3); DOG-008b stage change (M5) |
| Zampanò normal art | Slice | AST-002–005 (every playable skin) | — |
| Playable profiles (cross, armour, Sbrimbrulòn, Bagnaskiz) | Slice | AST-006–009; SLICE: the dog scene references no profile, the world injects the `--as` choice before `add_child()` (all three), lazy Zampanò fallback only for an unconfigured dog | arms capability DOG-009 (M6); ALT-001–003 (M8) |
| Story cast art | Slice | AST-011 (23 delivered, 17 frozen procedural roles + cat) | actors M5 |
| Color Ink environments | Partial | AST-012, AST-013, AST-014, AST-015, AST-016 | story TileSets per bank with the story scenes (M5) |
| Procedural art frozen, no fallback | Slice | AST-017, AST-018; AST-019 command evidence | — |
| Title animation conversion | Slice | AST-010; 3 review images | title scene M4; image approval pending |
| Redesigned 96×96 park/topology | Slice | MAP-007 | — |
| Hunger | Partial | P: GZ-002; SLICE scripted rules run | — |
| Digestion and poop warning | Partial | DOG-004; SLICE scripted rules run | warning bubble simplified (D-07) |
| Surface-dependent pollution | Slice | GZ-008, GZ-009 | — |
| Bladder and pee | Partial | DOG-003; SLICE scripted rules run; captures 06/11 | — |
| Marking | Partial | ported rule | MARK paths not fixture-covered |
| Zone health and half-stars | Slice | GZ-019, GZ-020 | — |
| Score/time/records | Partial | SAV-004; P: GZ-021 | cat/mark components need M3 |
| Lives for speed | Partial | GZ-024; P: GZ-025 | title counter UI is M4 |
| Run energy | Slice | DOG-007; HUD energy ring | — |
| Treats | Partial | SLICE real-input run; MAP-007 placements | — |
| Cats and coins / Magnet balls / Under Attack / Bagnaskiz | — | — | M3 (D-10) |
| Pollution waves | Partial | director + placement ported | RNG sharing with cats (D-03) |
| HUD/radar/touch controls | Partial | VIEW-003; P: UI-001–006; SLICE multi-touch routing; captures | gestures/switcher (D-09) |
| Briefing/level end/game over | Partial | FLOW-001, FLOW-002; P: FLOW-005; captures 01/07/13/14 | Supervillained snap, CONTINUE handoff (D-08) |
| Green Zone automated full-play coverage | Partial | SLICE real-input run (no teleports) | AUTO-001 needs the M3 attack |
| Press Start 2P pixel font | Slice | AST-020 (glyphs, metrics, wrapping, fallback, IPA, schwa); OFL exported | glow (D-06) |
| Recorded music/effects | Slice | AUD-001–004 (5 tracks, 12 effects); leading-silence offsets (exported Resource); lossless drink WAV; background suspension of playing/scheduled sounds; SLICE source `play()` parity: requests while muted or suspended dropped, same cue within 45 ms dropped, volume 0 is silence; live probe on a real device | routing/duck/volume AUD-009–013 (M8) |
| Synthesized audio | Slice | AUD-005–008 (14 cues + medieval loop as source-rendered PCM WAV) | chapter routing (M5–M8) |
| Settings / records persistence, atomic save | Partial | SAV-001–004, SAV-018–020, SAV-022 (future main/temp/backup); P: SAV-021; SLICE: a valid older main becomes the backup on temp recovery; SLICE: failed future copies reported as `future_copy_failed:<file>` with writes still blocked | user-visible notice, campaign schema (D-11) |
| Campaign v1→v2 migration | Partial | SAV-013–017 (pure `CampaignMigration`, source fixtures) | M1 migration-plugin spike open (M1 blocker); format-3 converter, SaveService integration and fixture/simulated MIG-005 M4; production lineage, two WebView/device versions and MIG-001–010 proof M9 |
| Everything else in this matrix | — | — | later milestones |

## 1. Platform and runtime

| Target | Feature | Source status and evidence | Godot parity requirement | Milestone / tests |
|---|---|---|---|---|
| [ ] | Godot 4.7.2 project isolated under `/godot` | N/A; source is Vite/PixiJS | Standard GDScript project; no source replacement; reproducible headless launch | M1 / CORE-001 |
| [ ] | Fixed 60 Hz game rules | Implemented: `core/loop.ts`, `config.ts` | `_physics_process` at 60 Hz; fixed-seed tests | M1–M2 / CORE-002 |
| [ ] | Adaptive pixel-perfect viewport | Implemented: `core/display.ts` `computeViewport`; target width 216, integer scale, width 192–270 and aspect 0.42–0.62 where the area allows, with the source's below-192 bands (areas < 192 px: scale 1 at their own width; areas 271–383 px: scale 2, width 135–191) | Port the exact source algorithm (authoritative, no extra clamp) into the SubViewport/safe-area container | M2 / VIEW-001–004 |
| [ ] | Portrait orientation | Implemented in Android manifest; unverified in this audit on device | Portrait only, rotation ignored without layout break | M9 / AND-003 |
| [ ] | Offline operation | Implemented: bundled assets; publisher link is explicit external action | Cold start and full play in airplane mode; no runtime fetch | M9 / AND-008 |
| [ ] | Background pause/resume | Implemented in web scene/audio flow | Freeze rules, save if dirty, suspend/resume audio safely | M3, M9 / LIFE-001–003 |
| [ ] | Android Back behavior | Implemented by `MainActivity.java`; unverified on device | Pause/unpause gameplay; navigate overlays; title behavior matches source | M9 / AND-004 |
| [ ] | Android immersive/keep-awake/safe area | Configured in native Java/CSS; unverified on device | Fullscreen transient bars, keep screen on, HUD outside cutouts | M9 / AND-005–007 |
| [ ] | Native Android build | Capacitor APK configuration exists; this audit did not build/install it | Godot APK and AAB export with pinned package/version/signing | M9 / AND-001–002 |
| [ ] | Android automated coverage | Source Java tests are boilerplate; instrumented example asserts wrong package; no Android CI | Real export/install/upgrade/lifecycle/device suite and CI or reproducible device script | M9 / AND-001–013 |
| [ ] | Android 60 FPS frame pacing | Source targets 60 Hz logic but has no audited native pacing test | 60 FPS cap + VSync + Swappy `pipeline_forced_on`; work-time and presented-interval/jank gates on 60/90/120 Hz panels | M9–M10 / PERF-001–004 |
| [ ] | iOS build | Implemented in source Capacitor project | Out of current Godot scope; existing iOS tree remains functional | Not ported |

## 2. Isometric world, movement, and presentation

| Target | Feature | Source status and evidence | Godot parity requirement | Milestone / tests |
|---|---|---|---|---|
| [ ] | 2:1 projection | Implemented: `iso/projection.ts`; 32×16 tiles | Exact forward/inverse formulas and tile-center convention | M1–M2 / ISO-001–003 |
| [ ] | Screen-space movement semantics | Implemented: input is inverse-projected to grid | Up on stick is up on screen; analog magnitude walks only | M2 / ISO-004, MOVE-001 |
| [ ] | Eight-direction facing | Implemented and asset-tested | N/NE/E/SE/S/SW/W/NW after 2:1 compensation | M2 / MOVE-002, AST-004 |
| [ ] | Walk/run/terrain speed | Implemented: 4.4/7.5 tiles/s and surface multipliers | Copy current values; RUN is explicit, never joystick threshold | M2 / MOVE-003–005 |
| [ ] | Collision and sliding | Implemented: grid circle vs blocked squares/circular props | Projected CharacterBody2D collision or approved compatibility solver within tolerance | M2 / COLL-001–004, COLL-005a, COLL-006; M5–M7 / COLL-005b |
| [ ] | Shared Green Zone/story world | Implemented: `world/world.ts` | One `IsoWorld` scene used by both modes | M2 / ARCH-001a, M5 / ARCH-001b |
| [ ] | Camera lag/look-ahead/sway/shake/clamp | Implemented: `iso/camera.ts` | Manual CameraRig parity and whole-pixel snapping | M2 / CAM-001–004 |
| [ ] | Stable depth sorting | Implemented: depth, bias, grid-x, stable ID | Explicit visible-object sort and sequential z-index | M2 / DEPTH-001–003 |
| [ ] | Tall-object occlusion | Implemented; player-only AABB fade to 0.42 | Preserve exact player-only behavior | M2 / DEPTH-004 |
| [ ] | Animated terrain and pollution presentation | Implemented in `mapRenderer.ts` | Phase-rotated TileMap animation; notify only on model changes and correctly reapply active/reset runtime modulation | M3 / WORLD-004–005 |
| [ ] | ASCII maps and markers | Implemented and validated | Port parser/topology; generate TileMapLayers and marker nodes | M1–M2 / MAP-001–006 |
| [ ] | Tiled import | Planned-only; source branch throws | Excluded; do not implement for parity | Excluded |

## 3. Playable character and actor systems

| Target | Feature | Source status and evidence | Godot parity requirement | Milestone / tests |
|---|---|---|---|---|
| [ ] | Zampanò state controller | Implemented: free/pee/poop/bark/eat/fetch/hurt/drink/exit, idle/tired | Generic `PlayableDog` state machine with source timing | M2 / DOG-001–004, DOG-005a, DOG-006, DOG-007, DOG-008a; M3 / DOG-005b; M5 / DOG-008b |
| [ ] | Zampanò normal art | Implemented; current delivered 8-way sheet plus tired | Complete SpriteFrames with timing/anchor validation | M2 / AST-001–005 |
| [ ] | Zampanò cross appearance | Implemented alias to knight art; rag carried only in reality | Alias same Godot resource; do not restore retired rag-cross sprite | M5 / AST-006 |
| [ ] | Zampanò armoured art/actions | Implemented, 12 actions × 8 directions | Full SpriteFrames; arms capability starts at 2.3 | M6 / DOG-009, AST-007 |
| [ ] | Sbrimbrulòn normal/armoured playable profile | Partial product feature: works through `?as=`, no alternate story | Resource/costume mapping and developer override; no new narrative | M8 / ALT-001–003 |
| [ ] | Bagnaskiz normal/armoured playable profile | Partial product feature: works through `?as=`, no alternate story | Resource/costume mapping and developer override; no new narrative | M8 / ALT-001–003 |
| [ ] | Generic actor behaviors | Implemented: idle, patrol, chase, flee, follow, wander, flail, goto, fly | Explicit small state controller; no behavior tree | M5–M7 / NPC-001–006 |
| [ ] | Speaking gestures | Implemented for delivered human actors | Dialogue signal triggers one-shot gesture where available | M5 / NPC-007 |
| [ ] | NPC pathfinding | Not implemented; source uses straight paths/local steering | Do not add as a parity dependency | Excluded |

## 4. Green Zone gameplay

| Target | Feature | Source status and evidence | Godot parity requirement | Milestone / tests |
|---|---|---|---|---|
| [ ] | Redesigned 96×96 park/topology | Implemented: `levels/level1.ts`; topology tests | Deterministic identical ground/props/start/exit/treat route | M3 / GZ-001, MAP-007 |
| [ ] | Hunger | Implemented: activity-sensitive drain, starvation/life loss/refill | Exact rates, invulnerability and HUD behavior | M3 / GZ-002–004 |
| [ ] | Digestion and poop warning | Implemented: overflow, warning, delayed action when busy | Exact timer/overflow/action lock semantics | M3 / GZ-005–007 |
| [ ] | Surface-dependent pollution | Implemented: bush/tall grass/grass/path footprints, spread | Same field math, changed cells and visual feedback | M3 / GZ-008–011 |
| [ ] | Bladder and pee | Implemented: charges, regeneration, water refill, expanding clean | Exact charge/radius/timing semantics | M3 / GZ-012–015 |
| [ ] | Marking | Implemented: vertical-object bonus, larger radius, once per object | Area detection plus persistent marked IDs per run | M3 / GZ-016–017 |
| [ ] | Zone health and half-stars | Implemented: clean playable tiles and end penalty | Exact thresholds, half-star floor, pees<poops penalty | M3 / GZ-018–020 |
| [ ] | Score/time/records | Implemented: treats/cats/marking/time/stars; independent bests | Exact values; separate score/stars/time records | M3–M4 / GZ-021–023, SAV-008 |
| [ ] | Lives for speed | Implemented: 2–9 lives, speed cost above 2 | Title setting and Green Zone-only effect | M3–M4 / GZ-024–025 |
| [ ] | Run energy | Implemented: drain, recovery, tired threshold, hold/toggle | HUD ring, tired state, story exclusions | M3 / GZ-026–028 |
| [ ] | Treats | Implemented: deterministic placement, hunger/digestion/score | Same route placement and pickup effects | M3 / GZ-029–030 |
| [ ] | Cats and coins | Implemented: flee/obstacle steering, bark stun, coin/score | Same timings/steering and two-step audio | M3 / GZ-031–033 |
| [ ] | Magnet balls/fetch | Implemented: attraction, escape by run, forced fetch/penalties | Same force field, duration and penalties | M3 / GZ-034–036 |
| [ ] | Pollution waves | Implemented: three progress-triggered deterministic outbreaks | Exact triggers/count/radius/strength and cue | M3 / GZ-037 |
| [ ] | Under Attack event | Implemented: health/script triggers, hysteresis, banners/effects | Same director state machine and recovery rule | M3 / GZ-038–041 |
| [ ] | Bagnaskiz threat | Implemented: seeks green, trails dirt, bumps, 3 bark hits/flee | CharacterBody2D behavior and bark cone parity | M3 / GZ-042–045 |
| [ ] | HUD/radar/touch controls | Implemented | Native Controls match data and safe-area layout | M3 / UI-001–006 |
| [ ] | Briefing/level end/game over | Implemented | Native overlays and transitions, exact handoff to 1.1 | M3 / FLOW-001–005 |
| [ ] | Green Zone automated full-play coverage | Partial: pure/balance tests; story autopilot skips 1.0 | Add deterministic Godot gameplay driver and on-device manual run | M3, M10 / AUTO-001, MAN-GZ |

## 5. Campaign content checklist

All source entries below are implemented. “Ported” means script, map, actors, dialogue, effects, state changes, audio/theme, failure/retry rules, and remembered/book output all pass their scene test—not merely that a scene opens.

| Ported | ID | Canonical title | Essential interaction/parity point | Milestone / test |
|---|---:|---|---|---|
| [ ] | 1.0 | The Green Zone | Full Green Zone; coins/time into campaign at level-end handoff | M3 / STY-100 |
| [ ] | 1.1 | A bucket on his head | Slipping visor, hedge gap, Confusione slap; reality | M5 / STY-101 |
| [ ] | 1.2 | Under the Professor's desk | Follow, three lecture scraps, Jack gate/bark puzzle | M5 / STY-102 |
| [ ] | 1.3 | The toll at the bowl | Paw/direct path, flags and Supervillain effect | M5 / STY-103 |
| [ ] | 1.4 | Santina wants her ball back | Performance/ball flag; setup for 8.4 | M5 / STY-104 |
| [ ] | 1.5 | A cross of rag | Carry rag, cross unlock, exact sleep boundary | M5 / STY-105 |
| [ ] | 2.1 | One step from Jerusalem | Receding goal/door; armour appearance begins | M6 / STY-201 |
| [ ] | 2.2 | Names on a list | Lull vow, Grace/flag/sermon unlock, ranked list | M6 / STY-202 |
| [ ] | 2.3 | A coat of mail too big | Bark fight, arms pickups, knight unlock, parry tutorial, follow Pierre | M6 / STY-203 |
| [ ] | 3.1 | Look at those ships | Follow/LOOK marvels, empty berths, Meraviglia opens | M6 / STY-301 |
| [ ] | 3.2 | The price of passage | Bowl rounds, both 34,000/36,000 accounts, shortfall flag | M6 / STY-302 |
| [ ] | 3.3 | The art of weeping | Timed kneel/wait/weep recollection | M6 / STY-303 |
| [ ] | 3.4 | Nobody leaves the Lido | Stealth follow, eavesdrop, Zara deal, Doge cross | M6 / STY-304 |
| [ ] | 4.1 | Veni Creator | Deck walk and shield rhythm; fleet marvel | M6 / STY-401 |
| [ ] | 4.2 | Horses below deck | Boat alignment, feed three horses, bucket moved | M6 / STY-402 |
| [ ] | 4.3 | Rumours on deck | Four rumours, Zara reveal, rowing rhythm | M6 / STY-403 |
| [ ] | 5.1 | A small favor for Venice | Message carry; costly dissent vs host choice and meter effects | M7 / STY-501 |
| [ ] | 5.2 | A cross above the wall | Ladders, steady ladder, cloth route flag | M7 / STY-502 |
| [ ] | 5.3 | Whose orders? | Three duties, `zaraOwe`, non-lethal brawl, sword Grace cost | M7 / STY-503 |
| [ ] | 5.4 | A letter for Rome | Letter assembly; two absolution versions | M7 / STY-504 |
| [ ] | 5.5 | Winter at Zara | Carry sail, 36,000 board, Jerusalem heading | M7 / STY-505 |
| [ ] | 6.1 | Short rations | Half-loaf route; costly share vs dice; comradeship setup | M7 / STY-601 |
| [ ] | 6.2 | A prince on credit | Rumour ordering of four promises; only twelve swear | M7 / STY-602 |
| [ ] | 6.3 | On their knees at Corfu | Follow, kneeling leaders, stay/Syria choice and flag | M7 / STY-603 |
| [ ] | 7.1 | Looking both ways | Three marvels, Niketas, intentionally lost rowing/tug | M7 / STY-701 |
| [ ] | 7.2 | The Doge's banner | Banner follow, 18-second shield stand, carry word | M7 / STY-702 |
| [ ] | 7.3 | Stay beside Pierre | Bespoke shoulder pace, companions, no blow, Physical courage | M7 / STY-703 |
| [ ] | 7.4 | A city to visit | Four marvels including column/Hercules/lamp courtyard | M7 / STY-704 |
| [ ] | 7.5 | Unpaid promises | Lighter chests, mosque/fire, checkpointed escort home | M7 / STY-705 |
| [ ] | 7.6 | A third Alexios | Equal-pace embassy, fire-ships, coup/deaths | M7 / STY-706 |
| [ ] | 7.7 | The hole in the wall | Oath, Friday/Sunday, intentionally lost tug, comradeship voice/rattle | M7 / STY-707 |
| [ ] | 7.8 | Whose street was it? | Clari/Choniates accounts, lull oath action/silence, ending flag | M7 / STY-708A/B |
| [ ] | 7.9 | The common pile | Declare/hide lamp, empty pedestal, column, coarse silver, failed Jerusalem | M7 / STY-709 |
| [ ] | 8.1 | Falling to pieces | Scrambled controls, sound/smell goal, waking body | M7 / STY-801 |
| [ ] | 8.2 | What he can tell | No returned object, conditional study marvels/drawing, Grace telling tier | M7 / STY-802 |
| [ ] | 8.3 | The vanguard of the lawn | Bespoke walk/flinch companions, Bagnaskiz steps aside, accessible bowl | M7 / STY-803 |
| [ ] | 8.4 | At Santina's gate, again | Tell day, unanswered question, push ball, thanks | M7 / STY-804 |

## 6. Story systems, endings, and content integrity

| Target | Feature | Source status and evidence | Godot parity requirement | Milestone / tests |
|---|---|---|---|---|
| [ ] | Canonical Fourth Crusade narrative | Implemented: `docs/STORY.md`, chapter code | Exact English text, sources metadata, scene order and boundaries | M5–M7 / CONTENT-001–004 |
| [ ] | Dialogue/typewriter/cards/choices | Implemented | Native UI, text speeds, costly locks, no dead-end choices | M5 / DLG-001–007 |
| [ ] | Names and period-word colors | Implemented and tested | Same lists/spans/colors while typing and after completion | M5 / DLG-008–009 |
| [ ] | Four campaign meters | Implemented | Exact starts, clamps, effects, fades, costs and display | M5–M7 / CAMP-001–006 |
| [ ] | Meraviglia/book/home mapping | Implemented | Exact marvel/item/value/remembered/shard collections and 8.2 mapping | M5–M7 / CAMP-007–011 |
| [ ] | Costumes/abilities | Implemented | Reality rag carry, dream armour from 2.1, arms ability at 2.3 | M5–M6 / CAMP-012–014 |
| [ ] | Progression/autosave | Implemented | Sequential chapter unlock, per-effect/per-scene saves | M4–M7 / FLOW-006–009 |
| [ ] | Replay | Implemented on copied state | Finished-scene replay changes no persistent campaign data | M4–M5 / FLOW-010–011 |
| [ ] | Story pause `SKIP SCENE` | Implemented; marks scene complete | Preserve as current parity behavior | M5 / FLOW-012 |
| [ ] | THE KNIGHT ending | Implemented through 7.8 oath call | Exact flag, cards, notes and final flow | M7 / END-001 |
| [ ] | THE WITNESS ending | Implemented; internal key `alpha` | Exact silence/Niketas path, cards, notes and final flow | M7 / END-002 |
| [ ] | Grace/Standing ending notes | Implemented | Exact tier thresholds and text | M7 / END-003–004 |
| [ ] | Source/invention metadata | Implemented in chapter definitions/docs | Preserve metadata for review; do not show SOURCE/CAST on player cards | M5–M7 / CONTENT-005 |

## 7. Story movement, combat, NPCs, and minigames

| Target | Feature | Source status and evidence | Godot parity requirement | Milestone / tests |
|---|---|---|---|---|
| [ ] | Reach/collect/action/survive walks | Implemented | Typed StoryWalk objectives, failure/retry and feedback | M5–M7 / WALK-001–006 |
| [ ] | Pickups/carry/visible spot rings | Implemented | Visible required items, carry attachment, action objectives | M5–M7 / WALK-007–009 |
| [ ] | Stealth/sight/bush hiding | Implemented | Same cone/range/LOS/contact/restart rules | M6 / WALK-010–013 |
| [ ] | Follow leader and lull windows | Implemented | Same wait/catch-up and audible/action windows | M5–M7 / WALK-014–017 |
| [ ] | Scrambled controls | Implemented and used in 8.1 | Same rotation/settling and test-driver compensation | M7 / WALK-018 |
| [ ] | Spreading fire/checkpoints | Implemented and used in 7.5 | Same spread/push/restart checkpoints | M7 / WALK-019–021 |
| [ ] | Generic pace/thirst hooks | Engine capability exists but unused by current chapters | Not required; bespoke 7.3/8.3 logic is required | Excluded unless reused |
| [ ] | BARK/SWORD/SHIELD combat | Implemented | Exact pure rules and presentation timing | M6–M7 / COM-001–012 |
| [ ] | Non-lethal routing/knockdown | Implemented | Reset fight state; no deaths | M6 / COM-013–014 |
| [ ] | Companions | Implemented as real following actors | Exact current scene behavior, not just dialogue flags | M7 / NPC-008–011 |
| [ ] | Rhythm: parade/rowing | Implemented in current campaign at 4.1 and 4.3 | Current timing, win/loss effects and continuation; scene restart is the retry path; unused `weeping()` factory is not ported | M6 / MINI-001–004 |
| [ ] | Boat | Implemented | Alignment/control/objective parity | M6 / MINI-005 |
| [ ] | Ladders | Implemented in current campaign at 5.2 only | 16 rungs, normal stone warning/hit/slide behavior, input cap, palette and authored walk frames; omit dormant hard-assault branch | M7 / MINI-006–008 |
| [ ] | Tug | Implemented; intended losses in 7.1/7.7 | Result semantics and story continuation | M7 / MINI-009–010 |
| [ ] | Letter | Implemented | Correct assembly and two account branches | M7 / MINI-011 |
| [ ] | Rumour ordering | Implemented | Ordering, feedback, completion | M7 / MINI-012 |
| [ ] | Calm rescue/catapult | Retired by canonical rewrite | Do not port | Excluded |

## 8. UI, art, audio, and effects

| Target | Feature | Source status and evidence | Godot parity requirement | Milestone / tests |
|---|---|---|---|---|
| [ ] | Title menu and animated portrait | Implemented; 99-frame WebP with source-specific shared crop/high-quality resize/alpha cut | Pinned extraction, bounded atlas memory, exact delays, title-only smooth scaling, film/glitch/shine | M4, M8 / UI-007–011, AST-010 |
| [ ] | COUCH | Implemented | Exact summary/progress/meters/book/record/play-time/save-date | M4 / UI-012–014 |
| [ ] | OPTIONS and CONTROLS | Implemented | Sound, volume, text speed, lives, gestures, run, switcher, hand | M4 / UI-015–021 |
| [ ] | GLOSSARY | Implemented | Exact text, circled definition and close behavior | M4 / UI-022 |
| [ ] | Story menus/book/pause | Implemented | Native Controls with identical availability/side effects | M5 / UI-023–030 |
| [ ] | Supervillained snap | Implemented after Green Zone and each story level | Timing, skip window, FX/audio, correct exclusions | M3–M7 / FX-001–003 |
| [ ] | Delivered playable/cast art | Integrated, with procedural roles remaining | Copy only runtime-authoritative files; freeze fallbacks | M1, M8 / AST-001–009, AST-011 |
| [ ] | Color Ink environments | Integrated; 15 banks, 19 compositions, current exceptions | Editor-time TileSet/atlas conversion; topology remains authoritative | M1–M8 / AST-012–016 |
| [ ] | Procedural fallback visuals | Implemented at runtime and can mask missing files | Freeze current outputs; Godot validator fails on missing required assets | M1 / AST-017–019 |
| [ ] | Press Start 2P pixel font | Implemented through a custom 8 px thresholded bitmap atlas; WOFF2 is source input and OFL licensed | Export the exact bitmap glyphs/metrics/IPA substitutions to a Godot bitmap Font; preserve OFL | M1 / AST-020 |
| [ ] | Recorded music/effects | Implemented: 5 music, 12 SFX | Copy current compressed runtime files; validate decode/playback | M1, M8 / AUD-001–004 |
| [ ] | Synthesized medieval/UI/combat audio | Implemented at runtime: medieval loop, 14 cues | Deterministically render to mono 22,050 Hz signed-16-bit PCM WAV | M1, M8 / AUD-005–008 |
| [ ] | Track resume/duck/mute/volume | Implemented | Same continuity, gains, settings and background behavior | M8 / AUD-009–013 |
| [ ] | Glitches/particles/popups/shake | Implemented | Godot shaders/particles/tweens with approved captures | M8 / FX-004–012 |
| [ ] | Asset licensing/provenance | Only font license is documented | Owner must record rights before public release | M10 / REL-001 |

## 9. Persistence and Android upgrade

| Target | Feature | Source status and evidence | Godot parity requirement | Milestone / tests |
|---|---|---|---|---|
| [ ] | Settings persistence | Implemented in localStorage | Validated fields in atomic format-3 save | M4 / SAV-001–003 |
| [ ] | Records persistence | Implemented, independent best score/stars/time | Preserve `level1` record and semantics | M4 / SAV-004 |
| [ ] | Legacy standalone coin key | API exists but is unused by current executable flow; campaign has separate coins | Import/preserve present/value only; current Godot gameplay must not mutate it | M4 / SAV-005 |
| [ ] | Campaign v2 save | Implemented | Preserve all fields and exact replay/save triggers | M4–M7 / SAV-006–012 |
| [ ] | Campaign v1→v2 migration | Implemented/tested | Pure port, raw backup, one-time notice | M4 / SAV-013–017 |
| [ ] | Atomic Godot save/backup | Source localStorage is guarded but not atomic | temp-validate-rotate-rename; recover from corruption | M4 / SAV-018–022 |
| [ ] | Legacy Capacitor import | Not implemented; architectural limitation | Native bridge spike; raw payload backup; deterministic conversion | M1 spike, M4 converter + simulated MIG-005, M9 proof / MIG-001–010 |
| [ ] | Same-package Android upgrade | Source package is `com.zampano.supervillained`, repository versionCode 1, release uses debug key | Same ID, code higher than installed artifact, exact certificate, no uninstall | M9 / AND-009–013 |
| [ ] | Browser-save import | Not available automatically | Explicitly unsupported unless a future manual export is authorized | Document limitation |

## 10. Planned-only, retired, and out-of-scope inventory

| Item | Source status | Port decision |
|---|---|---|
| Shop | Planned-only; coins exist, shop does not | Excluded |
| Accounts/cloud save | Not implemented; game is offline | Excluded |
| Multiplayer/analytics | Not implemented | Excluded |
| Tiled importer | Reserved type throws | Excluded |
| Alternate-character campaigns | No authored story branches | Excluded; keep debug skin override |
| Old 42/43-scene anthology | Superseded/retired | Do not port; only v1 save migration data remains |
| Black-hole story cuts | Retired | Do not port |
| Calm rescue/catapult | Retired | Do not port |
| Unused `weeping()` RhythmGame factory | Dormant legacy code; current 3.3 is a lull walk with WEEP actions | Do not port; test 3.3 under `STY-303` and lull-walk cases |
| Hard-assault Ladders branch | Dormant legacy code; current 7.2 is combat, not ladders | Do not port; only current 5.2 ladder configuration is required |
| Art archive and delivery ZIP internals | Reference/superseded/unintegrated | Do not bundle wholesale |
| Godot iOS export | Not requested | Excluded; do not break source iOS project |

## 11. Definition of parity complete

The port is not feature-complete until every required checkbox above is checked with evidence, all 37 campaign entries pass both scripted smoke and real-input playthroughs, both endings are reached, Green Zone 1.0 is played rather than skipped, asset validation has no fallback/missing-key warning, save migration has a proven or explicitly accepted limitation, and the signed Android upgrade/on-device matrix passes.
