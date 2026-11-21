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
**M1 is Partial and M2 is Partial**: neither milestone is complete or accepted.
Evidence: `docs/porting/IMPLEMENTATION_LOG.md`, `godot/tests/`, `docs/porting/captures/m2_green_zone_slice/` (18 PNGs).
Row status: **Slice** = the row's listed IDs are satisfied by full suite cases for the current
slice; **Partial** = implemented with a listed gap or only partial cases; **Config** = configured,
not executed; **—** = not started.

Acceptance IDs are claimed only through a `test_<ID>_…` suite case that exercises every clause of the
ID (TEST_PLAN.md case naming). `test_P_<ID>_…` cases are partial evidence and satisfy nothing;
`test_SLICE_…` cases check port behaviour that has no plan ID.

**Acceptance IDs satisfied by a full suite case (57), Linux headless, Godot 4.7.2:**
CORE-002; RNG-001, RNG-003; VIEW-001, VIEW-002 (source algorithm, M2 review resolution), VIEW-003; ISO-001–004; MOVE-001–005; COLL-001–004, COLL-006;
DEPTH-001–004; WORLD-004, WORLD-005; CAM-001–003; MAP-001, MAP-002, MAP-004, MAP-005, MAP-006, MAP-007;
DOG-001–004, DOG-006, DOG-007; GZ-008, GZ-009, GZ-019, GZ-020, GZ-024; AST-014; FLOW-001, FLOW-002;
SAV-001–004, SAV-018, SAV-019, SAV-020, SAV-022 (main, temp and backup).
MAP-007 is one aggregator case (rows/topology, canonical route length, treat placements).

**Partial evidence only (not satisfied):** ARCH-001 (no real story scene yet), RNG-002, VIEW-004 and CAM-004 (headless whole-pixel checks; the rendered
30/60/90/120 FPS and static-shimmer checks pass in `tools/interpolation_probe.gd`, outside the
suite), DOG-005 (fetch needs M3 balls), DOG-008 (spawn/teleport/camera-snap resets in the suite and
the rendered probe; stage change does not exist before M5), MAP-003 (Green Zone + diagnostic maps
only), COLL-005 (Green Zone only), GZ-001, GZ-002, GZ-021, GZ-025, AST-001–005, AST-012, AST-016,
AST-017, AST-018, AST-020, AUD-001, SAV-021 (no user-visible notice yet), UI-001–006, FLOW-005.

**Command-level evidence (no suite case, architect to judge):** CORE-001 (clean-cache import and
600-frame Main run, Linux); AST-019 (`build_assets.sh --check`: every generated output
byte-identical under the Chromium build pinned by the locked playwright-core, 153.0.8010.12;
Linux and a simulated CRLF checkout, not a Windows host).

**Export evidence (SLICE, no plan ID):** the Android preset exports as a PCK with the test binary and
runs as a packed runtime: every runtime resource loads from the pack, no JSON/tests/tools/
environment manifest is packed, the exported leading-silence Resource reaches AudioService, and a
600-frame packed startup logs no engine error or warning. Not an APK and not device evidence.

**Not claimed:** AUTO-001 is reserved for the M3 run that includes an attack
(`test_SLICE_real_input_run_reaches_exit` is the current real-input run); FLOW-003/004, GZ-005 and
every other ID not listed above.

**Not verified (no device or host here):** everything on Android hardware (export, install, Back,
immersive, keep-awake, display cutout safe area, touch hardware, audio focus, performance) and
every Windows-host command (asset `--check` via `build_assets.ps1` and the `_console.exe` suite are
documented but were not executed on Windows: no Windows host is reachable from this environment;
a Windows CI workflow is proposed in `docs/porting/proposals/` pending approval, D-15).

| Matrix row | Godot status | Evidence (suite case IDs; P = partial case) | Gap / note |
|---|---|---|---|
| Godot project isolated under `/godot` | Partial | CORE-001 command evidence; source-tree guard | Windows host unverified |
| Fixed 60 Hz game rules | Slice | CORE-002 (30/60/90/120 FPS caps, logic identical to the 60 Hz reference) | — |
| Adaptive pixel-perfect viewport | Partial | VIEW-001, VIEW-002, VIEW-003; P: VIEW-004; underlay/letterbox SLICE case; 4 viewport captures | VIEW-004 rendered checks outside the suite; device safe area unverified |
| Portrait / Back / immersive / keep-awake | Config | project settings (`quit_on_go_back=false`, keep_screen_on), SLICE Back case | no device (B-04) |
| Native Android build | — | SLICE: Android-preset PCK export + packed-runtime startup | no APK: no templates/SDK/device here (B-04) |
| 2:1 projection | Slice | ISO-001–004 | 64-bit math (F-03) |
| Screen-space movement semantics | Slice | ISO-004, MOVE-001 | — |
| Eight-direction facing | Slice | MOVE-002, MOVE-003 | — |
| Walk/run/terrain speed | Slice | MOVE-003, MOVE-004, MOVE-005 | — |
| Collision and sliding | Slice | COLL-001–004, COLL-006; P: COLL-005; SLICE solver decision | GridKinematicSolver (native slide rejected) |
| Shared Green Zone/story world | Partial | P: ARCH-001 (dummy story map) | real story scene M5 |
| Camera lag/look-ahead/sway/shake/clamp | Slice | CAM-001–003; CAM-004 partial (see above) | shake noise seeded (D-04) |
| Stable depth sorting | Slice | DEPTH-001–003 | — |
| Tall-object occlusion | Slice | DEPTH-004, capture 12 | — |
| Animated terrain and pollution presentation | Slice | WORLD-004, WORLD-005 (engine TileData), captures 10/11/20 | three layers, approved in ARCHITECTURE §7 |
| ASCII maps and markers | Partial | MAP-001, MAP-002, MAP-004–007; P: MAP-003 | story maps M5 |
| Deep water and walls | Slice | COLL-004; SLICE diagnostic rendering case; capture 20 | — |
| Contact shapes (InteractionProbe/Hurtbox) | Partial (pre-M3 contract) | SLICE: projected grid ellipses on the foot point, broad phase only, exact grid distance decides; real Area2D overlap | consumers arrive with M3 |
| Zampanò state controller | Partial | DOG-001–004, DOG-006, DOG-007; P: DOG-005, DOG-008 | fetch (M3), stage change (M5) |
| Zampanò normal art | Partial | P: AST-002–005 | other playable dogs M1 completion |
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
| Press Start 2P pixel font | Partial | P: AST-020; OFL exported | wrapping fixtures, glow (D-06) |
| Recorded music/effects | Partial | P: AUD-001; intro/greenzone tracks; 6 effects; leading-silence offsets (exported Resource); lossless drink WAV; background suspension | other tracks/effects later milestones |
| Synthesized audio | — | — | D-05 |
| Settings / records persistence, atomic save | Partial | SAV-001–004, SAV-018–020, SAV-022 (future main/temp/backup); P: SAV-021; SLICE: a valid older main becomes the backup on temp recovery; SLICE: failed future copies reported as `future_copy_failed:<file>` with writes still blocked | user-visible notice, campaign schema, v1 migration (D-11) |
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
| [ ] | Collision and sliding | Implemented: grid circle vs blocked squares/circular props | Projected CharacterBody2D collision or approved compatibility solver within tolerance | M2 / COLL-001–006 |
| [ ] | Shared Green Zone/story world | Implemented: `world/world.ts` | One `IsoWorld` scene used by both modes | M2, M5 / ARCH-001 |
| [ ] | Camera lag/look-ahead/sway/shake/clamp | Implemented: `iso/camera.ts` | Manual CameraRig parity and whole-pixel snapping | M2 / CAM-001–004 |
| [ ] | Stable depth sorting | Implemented: depth, bias, grid-x, stable ID | Explicit visible-object sort and sequential z-index | M2 / DEPTH-001–003 |
| [ ] | Tall-object occlusion | Implemented; player-only AABB fade to 0.42 | Preserve exact player-only behavior | M2 / DEPTH-004 |
| [ ] | Animated terrain and pollution presentation | Implemented in `mapRenderer.ts` | Phase-rotated TileMap animation; notify only on model changes and correctly reapply active/reset runtime modulation | M3 / WORLD-004–005 |
| [ ] | ASCII maps and markers | Implemented and validated | Port parser/topology; generate TileMapLayers and marker nodes | M1–M2 / MAP-001–006 |
| [ ] | Tiled import | Planned-only; source branch throws | Excluded; do not implement for parity | Excluded |

## 3. Playable character and actor systems

| Target | Feature | Source status and evidence | Godot parity requirement | Milestone / tests |
|---|---|---|---|---|
| [ ] | Zampanò state controller | Implemented: free/pee/poop/bark/eat/fetch/hurt/drink/exit, idle/tired | Generic `PlayableDog` state machine with source timing | M2–M3 / DOG-001–008 |
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
| [ ] | Legacy Capacitor import | Not implemented; architectural limitation | Native bridge spike; raw payload backup; deterministic conversion | M1, M9 / MIG-001–010 |
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
