# SUPERVILLAINED VG1 — Godot validation and acceptance plan

## 1. Test objective

The test program proves behavioral and content parity, Android viability, and safe save migration. It is not enough to show that the Godot project launches or looks similar. Evidence must cover pure rules, real scene execution, real input paths, every campaign entry, both endings, Green Zone 1.0, native lifecycle/touch behavior, and a signed in-place Android upgrade.

The PixiJS branch is the reference implementation at commit `95b69c0`. Reference fixtures must record that commit and may not be silently regenerated after a Godot mismatch.

## 2. Test layers

| Layer | Purpose | Runs where | Blocks milestone |
|---|---|---|---|
| Static/content validation | resource paths, hashes, counts, maps, scene IDs, source-tree guard | headless/editor import | yes |
| Pure unit tests | projection, RNG, map model, rules, campaign/save transforms | Godot headless | yes |
| Scene integration | node wiring, input, physics, signals, pause/restart, UI state | Godot headless or offscreen | yes |
| Script smoke | instantiate and advance every story step; fail on missing data/resources | Godot headless/offscreen | yes |
| Real-input automation | drive `InputService`, never call rules directly | Godot process | yes for content milestones |
| Capture regression | layout/visual state at deterministic checkpoints | compatibility renderer | yes after golden approval |
| Manual gameplay | game feel, readability, audio, branch intent | desktop + device | yes |
| Android instrumentation/ADB | install/upgrade, lifecycle, package/signature, performance | physical Android | yes for M9/M10 |

## 3. Test harness contract

Create a small first-party GDScript runner, not a third-party framework:

```powershell
# A clean clone imports once first (registers the global script classes)
godot --headless --path godot --import

# All headless-safe suites (runner options follow `--`)
godot --headless --path godot --script res://tests/test_runner.gd -- --suite all

# Focused suites
godot --headless --path godot --script res://tests/test_runner.gd -- --suite unit
godot --headless --path godot --script res://tests/test_runner.gd -- --suite integration
godot --headless --path godot --script res://tests/test_runner.gd -- --suite content

# Visual capture run; requires a renderer/display or approved offscreen configuration
godot --path godot --rendering-driver opengl3 --script res://tools/capture_suite.gd -- --out <dir> [--mode run|diagnostic]
```

On Windows use the **console** binary so the exit code reaches the shell (the GUI binary detaches):

The asset check needs the pinned Node 24.15.0 on `PATH`, `npm ci` and the pinned Chromium
(`npx playwright install chromium`) first:

```powershell
& 'C:\Program Files\Godot472\Godot_v4.7.2-stable_win64_console.exe' --headless --path godot --import
& 'C:\Program Files\Godot472\Godot_v4.7.2-stable_win64_console.exe' --headless --path godot --script res://tests/test_runner.gd -- --suite all
pwsh godot/tools/build_assets.ps1 -Godot 'C:\Program Files\Godot472\Godot_v4.7.2-stable_win64_console.exe' -Check
```

The integration suite also exports the Android preset as a PCK with the running binary (`--export-pack`, no export templates needed) and runs it as the only `res://` (`--main-pack`): every runtime resource must load from the pack, excluded content must be absent, and a 600-frame packed startup must log no engine error or warning. The packed runs use their own user-data directory. This is not Android device evidence (AND-001…013).

Case naming: `test_<ID>_…` only when every clause of that acceptance ID is exercised; `test_P_<ID>_…` is partial evidence toward the ID and never satisfies it by itself; `test_SLICE_…` checks port behaviour that has no plan ID. The matrix and log claim only `test_<ID>` cases, combined evidence as defined below, or architect-accepted command evidence (an executed command whose output is recorded for a named `godot/` tree; currently CORE-001 and AST-019).

Split IDs: an ID whose clauses belong to two milestones is split into `<ID>a` (the earlier milestone's clauses) and `<ID>b` (the later clauses, which keep their own milestone). Each part is claimed only by its own `test_<ID>a_…` / `test_<ID>b_…` case; the parent ID is satisfied only when both parts are. Splitting never removes a clause: every clause of the parent belongs to exactly one part.

Combined evidence: an ID may be satisfied by named suite cases (`test_P_<ID>_…` or other cases) for every clause they exercise plus, for the clauses no suite case can exercise, one of the following, once the architect accepts it for that ID: (a) a **named architect static review** for a static code-review requirement (no source-parser test stands in for it); (b) a **renderer-backed probe** for a clause that can only be observed under a real renderer (rendered-FPS presentation, streaks, double interpolation, on-screen shimmer): an executed command whose exact output is recorded under `docs/porting/*_evidence/` for a named `godot/` tree. The matrix and log name every part and never present a static review or a rendered clause as a suite result; a probe is rerun whenever rendering, the camera, physics interpolation or the dog's presentation changes. Current: ARCH-001a is satisfied on combined evidence (`test_ARCH_001a_dummy_story_host_shares_the_green_zone_world` plus the named static review, which is the architect's review of `f580fa4`, confirmed by the architect on review of `46d7ad9`: no duplicate playable/input movement controller). No renderer-backed probe is accepted: on review of `f580fa4` the architect withdrew the acceptance of `tools/interpolation_probe.gd`, whose runs stay supplemental command evidence. To satisfy the rendered clauses of VIEW-004, CAM-004 and DOG-008a, a probe must, at 30/60/90/120 FPS under a real renderer: require exactly one connected dog component per frame; track the dog's bounding-box dimensions, shape and pixel intensity so that a trail is rejected; compare total displacement over elapsed time with the expected speed tightly enough to reject sustained double interpolation; track each static marker's absolute centroid, bounding box and pixel pattern; include an intentional fractional-camera negative control that proves shimmer detection; and inspect the first rendered frame after spawn, camera snap and restart where the clause requires it.

The runner must:

- discover an explicit registry of test scripts/cases;
- isolate mutable globals and temporary `user://` directories per case;
- provide exact, approximate, signal, error, and image assertions;
- seed every random source;
- fail on engine errors, orphan nodes, missing resources, unexpected warnings, or timeout;
- print concise console results and write JSON plus JUnit-compatible XML to ignored `godot/test-results/`;
- exit nonzero on failure;
- accept `--case`, `--suite`, `--seed`, `--repeat`, and `--update-goldens` (golden update requires explicit use and review).

Production automation uses `InputService` injection. It may set movement vectors and press/release actions, but may not teleport, mutate rule state, call completion methods, or skip a step. A separate script-smoke mode may use deliberate debug-skip hooks solely to validate construction/resource coverage.

One-time reference fixture generators may use Node/Playwright under `/godot/tools`; they are development-only, must not alter the source tree, and must write the source commit/hash into each fixture.

## 4. Baseline reference suite

Before comparing Godot behavior, run and record:

```powershell
npm ci
npm test
npm run build
npm run smoke
npm run playtest -- --skill 0.7 --ending knight --choice first
```

The planning audit result was 30/30 Vitest files and 248/248 tests passed; build passed; 36/36 scripted scenes smoke-passed; the Knight autopilot reached the ending with no failures/page errors. This is historical evidence for the planning commit, not permission to skip rerunning the source baseline at release.

Android coverage is a source gap, not a passing baseline: the Java unit and instrumentation files are untouched Capacitor examples, the instrumented example asserts the wrong package (`com.getcapacitor.app`), and there is no Android CI workflow. The only workflow is the iOS build and it does not run Vitest. M9 must therefore establish Android evidence from scratch.

## 5. Static architecture and content tests

| ID | Acceptance |
|---|---|
| CORE-001 | Clean clone imports and headless-launches in Godot 4.7.2 with no missing Resource/script error. |
| CORE-002 | Project physics rate is 60 Hz; time is derived from integer ticks or a 600-tick accumulator is within `1e-9` of 10 game seconds independent of render rate. |
| ARCH-001 | Green Zone and Story scenes both instantiate the same `IsoWorld`, `PlayableDog`, `IsoGrid`, sorter and camera classes with the same public interfaces; environment resources (tile set, sprite catalogue, bank) may be chapter-specific. No duplicate playable/input movement controller: only `PlayableDog` turns player input into movement; actors (ActorBody, cats, Bagnaskiz, companions) may move with approved behaviour controllers on the shared `WorldMapModel` solver, including their own `update_movement`/`set_intent` (a static code-review requirement, not a source-parser test). Split: |
| ARCH-001a | **M2.** A dummy Story host scene (not shipped; the M5 story scene replaces it) instantiates the shared `IsoWorld` scene as its child like `GreenZoneScene`, supplies its own chapter-specific environment resources (tile set, sprite catalogue, bank id) through the world's public properties, configures a story-style map (no exit, markers, water, props) through `IsoWorld.setup()`, and runs its lifecycle: ready, logic ticks driven by `InputService`, rendered frames, cleanup that frees the world, dog, camera and every other descendant. Its `IsoWorld`, `PlayableDog` and `CameraRig` classes and public interfaces are `GreenZoneScene`'s; `IsoGrid` places and `IsoDepthSorter` ranks both worlds; its movement equals the shared controller and grid solver tick for tick; the camera follows on whole pixels. No duplicate playable/input movement controller is a **static code-review requirement**, checked when each change is reviewed, not by a handwritten source-parser test: only `PlayableDog` turns player input into movement; `ActorBody` controllers (NPCs, cats, Bagnaskiz, companions, combat actors) may use approved behaviour controllers with the shared `WorldMapModel` solver. ARCH-001a is claimed on combined evidence: this automated dummy-host case plus a named architect static review that confirms the requirement. |
| ARCH-001b | **M5.** The production story scene (story runner, real chapter maps) satisfies the same contract. |
| RNG-001 | Deterministic RNG first-N outputs match source fixture for multiple seeds including 0 and max 32-bit. |
| RNG-002 | Same seed reproduces treat/decor/spawn choices byte-for-byte. |
| RNG-003 | Different seeds produce different sequences without global RNG leakage. |
| CONTENT-001 | Catalog contains exactly eight chapters and 37 entries with exact IDs/counts/order. |
| CONTENT-002 | Every non-Green-Zone sublevel builds a fresh nonempty step list; 1.0 has the exact Green Zone dispatch and an intentionally empty story script; no retired scene ID is registered. |
| CONTENT-003 | Every source/reference metadata field is present and canonical titles match `docs/STORY.md`. |
| CONTENT-004 | All dialogue/card text snapshots match approved source exports, including punctuation/case. |
| CONTENT-005 | CAST/SOURCE metadata is available to tools but absent from player-facing cards. |
| REL-001 | Runtime asset manifest has an owner-provided provenance/license disposition for every distributable non-code asset before public release. |

## 6. Viewport, isometry, movement, collision, depth, and camera

### Viewport

| ID | Acceptance |
|---|---|
| VIEW-001 | Ported viewport calculation matches source fixtures for common CSS/device sizes and DPRs. |
| VIEW-002 | Logical size and the integer scale equal the source `computeViewport`, executed by the extractor over a dense grid of device sizes and DPRs (M2 review resolution: the original executable algorithm is authoritative; no new clamp without the owner's explicit authorization). Consequently the logical width is 192–270 and the aspect 0.42–0.62 (within one pixel of flooring) wherever the source gives them; the source's own exceptions are kept: constrained areas narrower than 192 device px use scale 1 at their own width, and constrained areas 271–383 px use scale 2 at 135–191 px (finding F-09). |
| VIEW-003 | Safe-area rectangle is honored; touch mapping round-trips physical→logical coordinates within 0.5 logical pixel. |
| VIEW-004 | Nearest filtering and integer placement produce no fractional sprite/control transforms at capture checkpoints; physics-interpolated motion at 30/60/90/120 render FPS has no streak, double interpolation or static shimmer. |

### Isometry and movement

| ID | Acceptance |
|---|---|
| ISO-001 | `grid_to_screen` matches source for origin, axes, negative, fractional and large coordinates within `1e-6`. |
| ISO-002 | `screen_to_grid(grid_to_screen(p)) == p` within `1e-6` for at least 1,000 seeded points. |
| ISO-003 | Tile centers and map row/column conventions match source fixtures. |
| ISO-004 | Eight screen input vectors project to expected normalized grid vectors; screen motion stays parallel to input. |
| MOVE-001 | Analog magnitudes below full deflection scale walking but never activate RUN. |
| MOVE-002 | Facing classification matches all boundary vectors and the eight source direction names. |
| MOVE-003 | Walk/run traces match 4.4/7.5 tiles/s after source acceleration/deceleration within 0.05 tile. |
| MOVE-004 | Bush/water/tall-grass multipliers are 0.7/0.8/0.85 and transition on the same footprint rule. |
| MOVE-005 | Action locks, external push and knockback decay match source trace checkpoints. |

### Collision

| ID | Acceptance |
|---|---|
| COLL-001 | Player circle/ellipse cannot cross blocked tile diamonds at all eight approach directions. |
| COLL-002 | Sliding along horizontal/vertical/diagonal obstacle boundaries reaches source checkpoints within 0.10 tile. |
| COLL-003 | Circular props push out without tunneling at walk/run maximum speed and worst fixed delta. |
| COLL-004 | Bush is walkable; void, forest, wall and deep water are not; water/tall grass remain walkable. |
| COLL-005 | Spawn/start/exit and every statically placed or scripted-position objective of the current maps and chapters remain reachable under the selected solver. Dynamic goals (moving or runtime-placed targets and action zones) are not part of COLL-005: they are owned by WALK, NPC, MINI and each scene's STY real-input completion. Split: |
| COLL-005a | **M2.** One dog, driven continuously through its own controller and the selected solver from the Green Zone start, reaches each treat's exact coordinate within the rule's pickup radius (each leg starting where the previous really ended), then the exit within its rule distance; and the start, exit and every map marker of each current story map that the source can reach are reached by the selected solver; markers the source cannot reach are listed as actor-only spawn points. |
| COLL-005b | **M5–M7.** Every remaining scripted spatial objective of the current chapters that has a scripted position (reach goals by marker or literal coordinate, pickups, spots, marvels, and action zones placed at a fixed point when their walk starts) is reachable under the selected solver from where the scene places Zampanò. Runtime-placed and moving targets are assigned elsewhere, not to COLL-005b: follow leaders and companions (WALK-014–017, NPC-008–011), actor goto/chase/flee/follow targets (NPC-001–006), pickups and spot rings that appear, move or attach during a walk (WALK-007–009), fire and checkpoints (WALK-019–021), minigame targets (MINI-001–012); each scene's real-input completion (STY-101–804) proves them reachable in play. Evidence: `test_P_COLL_005b_…` per level in M5 (Level 1) and M6 (Levels 2–4); the full `test_COLL_005b_…` aggregate over every chapter is reserved for M7. |
| COLL-006 | Repeated collision test is deterministic and stable without jitter/energy gain. |

### Depth, world, camera

| ID | Acceptance |
|---|---|
| DEPTH-001 | Sort key/order matches source for depth, bias, grid-x tie and stable-ID tie. |
| DEPTH-002 | Sort order is stable across 1,000 stationary frames and after remove/re-add operations with defined IDs. |
| DEPTH-003 | Only visible candidates receive object-band ranks; ground/decal/FX/UI bands never interleave incorrectly. |
| DEPTH-004 | A tall prop uses the source first-order fade (rate constant 10/s) toward 0.42 only when in front of/overlapping the player, then toward 1.0 when clear; intermediate checkpoints match source. |
| WORLD-004 | Water/deep-water/tall-grass phase-rotated alternatives are selected by the source cell hash, remain deterministic and do not animate all cells in lockstep. |
| WORLD-005 | (Three layers: Ground, Pollution, Fresh — ARCHITECTURE §7.) A nonempty model change triggers one notification per affected layer, active cells are reapplied, reset-pending cells receive default modulation before removal, an empty change set triggers none, and dirt base tint/overlay alpha/fresh fade/clean removal match source. |
| CAM-001 | Snap/follow/look-ahead checkpoints match source within 1 logical pixel. |
| CAM-002 | Bounds clamp keeps view inside approved margin for small and large maps. |
| CAM-003 | Sway/shake decay is deterministic under seeded noise or test override and returns to zero. |
| CAM-004 | Camera origin is whole-pixel at render checkpoints; no static shimmer. |

## 7. Map and asset contract tests

### Maps

| ID | Acceptance |
|---|---|
| MAP-001 | Empty map, unknown symbol, missing/duplicate start and required missing exit fail with useful errors. |
| MAP-002 | Short rows pad with void and digit markers land on the configured base ground. |
| MAP-003 | Every current arcade/story map parses; dimensions, ground counts, props, markers/start/exit match source fixtures; `map_to_local(cell) + IsoGrid.TILE_LAYER_OFFSET` (measured `Vector2(-16, 0)` on 4.7.2) matches the source tile center from `IsoGrid`. |
| MAP-004 | Story maps allowed without exit use start as exit without altering markers. |
| MAP-005 | BFS distance fields and selected reference paths match source. |
| MAP-006 | Visual floor compositions never change topology, collision or markers. |
| MAP-007 | Green Zone 96×96 topology, canonical route length and deterministic treat placements match source fixtures. |

### Assets

| ID | Acceptance |
|---|---|
| AST-001 | Every required source asset path exists and SHA-256 matches the approved source manifest. |
| AST-002 | Playable main/tired sheets have exact dimensions and complete 40×40 frame regions. |
| AST-003 | Playable foot anchor is `(20,36)` and renders on the world foot point. |
| AST-004 | Every required playable action has eight real direction entries; no blank/duplicate-diagonal regression. |
| AST-005 | Authored per-frame timing and loop/one-shot behavior match source duration fixtures. |
| AST-006 | `zampanoCross` aliases knight visuals and does not duplicate/restore retired rag-cross art. |
| AST-007 | Armoured Zampanò exposes all required actions and arms attachment alignment. |
| AST-008 | Sbrimbrulòn normal/armoured profiles validate completely. |
| AST-009 | Bagnaskiz normal/armoured profiles validate completely and preserve full-color signature pixels. |
| AST-010 | Title conversion has 99 frames, exact delay list, frame-0 256 px probe, alpha cutoff 110, one shared `DOG_CROP_MARGIN` crop, source 2× resize/second alpha cut, canonical max width 125, atlas page dimensions ≤2048×2048, <12 MB uncompressed frame memory, and approved smooth title-only scaling/first-middle-last images. |
| AST-011 | Integrated cast files/roles match manifest; all procedural-only roles have frozen explicit outputs. |
| AST-012 | All 15 environment art banks and native frame dimensions/anchors validate. |
| AST-013 | Authored floor composition keys/counts match approved manifest. |
| AST-014 | Green Zone deliberately ignores obsolete `1:arcade` composition. |
| AST-015 | `lawn`, `darkwood`, `interior`, `desert` exceptions use approved theme/fallback visuals without topology changes. |
| AST-016 | Environment resources import losslessly with nearest filtering and mipmaps off. |
| AST-017 | Missing required art causes validator/test failure; no runtime silent procedural fallback. |
| AST-018 | Runtime export excludes ZIPs, art archive, originals, prompts/source grids, screenshots and unused title files. |
| AST-019 | Asset sync is deterministic and produces no diff on a second run. |
| AST-020 | Generated bitmap font matches source glyph-image hashes, 8 px advance/union metrics, wrapping fixtures, ASCII fallback, borrowed IPA marks and rotated-e schwa; WOFF2 source and OFL are retained. |

## 8. Player, Green Zone, and flow tests

### Playable dog

| ID | Acceptance |
|---|---|
| DOG-001 | Free movement selects idle/walk/run and preserves facing on zero input. |
| DOG-002 | Standing→sit→sniff rest sequence and reset after action match source timing. |
| DOG-003 | Pee state locks/permits movement and animation for exact rule duration. |
| DOG-004 | Poop state/warning handoff and busy-action delay match source. |
| DOG-005 | Bark, eat/drink, fetch, hurt and exit state transitions cannot overlap illegally. Split: |
| DOG-005a | **M2.** Bark, eat/drink, hurt and exit transitions (action lock and state machine) cannot overlap illegally: per-tick state, durations, counters and event order equal the source in its overlap scenarios. |
| DOG-005b | **M3** (with the magnet balls, GZ-034–036). The forced fetch cannot overlap illegally with bark, eat/drink, hurt or exit. |
| DOG-006 | Invulnerability blink/squash presentation never changes rule state. |
| DOG-007 | Energy exhaustion selects tired and blocks run until recovery threshold. |
| DOG-008 | Spawn/teleport/restart/stage change/camera snap reset physics interpolation; 30/60/90/120 FPS presentation leaves no streak and test hooks do not leak into release input. Split: |
| DOG-008a | **M2.** Spawn, teleport, restart and camera snap reset physics interpolation; 30/60/90/120 FPS presentation leaves no streak; test hooks do not leak into release input. |
| DOG-008b | **M5.** A story stage change resets physics interpolation. |
| DOG-009 | Armour appearance and sword/shield capability are independently gated at 2.1/2.3. |

### Green Zone

| ID range | Acceptance cases |
|---|---|
| GZ-001 | Full map/data/spawn director loads deterministically. |
| GZ-002–004 | Hunger drain by idle/walk/run, starvation life/refill/invulnerability, no-treat route balance. |
| GZ-005–007 | Digestion gain/overflow, three-second warning, busy-action postponement/automatic poop. |
| GZ-008–011 | Surface footprints, max-blended stamp, timed spread, clean/fade of poop piles. |
| GZ-012–015 | Bladder charge use, empty feedback, time regeneration, puddle/fountain refill/drink cooldown. |
| GZ-016–017 | Marking detection/radius/points and once-per-object rule. |
| GZ-018–020 | Clean-tile health, half-star floor/thresholds, pees<poops final penalty. |
| GZ-021–023 | Treat/cat/mark/time/star score components, timer penalty, independent best records. |
| GZ-024–025 | Lives clamp 2–9 and exact speed-for-lives factor only in Green Zone. |
| GZ-026–028 | Run drain, conditional recovery, tired lock/re-enable at 35%. |
| GZ-029–030 | Treat pickup affects hunger/digestion/count/score once and produces cue/FX. |
| GZ-031–033 | Cat idle/flee steering, bark stun/catch, coin/score/audio. |
| GZ-034–036 | Ball attraction curve, run escape, fetch lock/hunger/time penalty. |
| GZ-037 | Three route-progress pollution waves trigger once with seeded placement and cue. |
| GZ-038–041 | Under-attack health/script triggers, cooldown, intensity, flee+health hysteresis/end. |
| GZ-042–045 | Bagnaskiz targeting/trail, bump/hunger, bark cone/hit count, flee/award. |

### Flow and Green Zone manual case

| ID | Acceptance |
|---|---|
| FLOW-001 | Briefing→play starts only after confirmation and correct music transition. |
| FLOW-002 | Pause freezes timers/rules and resumes with cleared queued input. |
| FLOW-003 | Restart creates a clean run with retained settings only. |
| FLOW-004 | Level end calculates/animates correct summary and can skip animation safely. |
| FLOW-005 | Game over/retry and 1.0→1.1 campaign handoff match source. |
| AUTO-001 | Real-input Green Zone driver completes a seeded run including treat, poop, pee, one attack and exit without direct rule calls. |
| MAN-GZ | Human completes healthy, polluted and game-over runs on desktop and portrait touch device. |

## 9. UI and input tests

| ID range | Acceptance cases |
|---|---|
| UI-001–006 | HUD values/stars/radar, touch joystick, simultaneous pointers, handed mirror, action labels/safe margins. |
| UI-007–011 | Title layout/actions, animated portrait, film/glitch/shine, Insert Brain/lives, short/tall screens. |
| UI-012–014 | Couch next scene/progress, meters/book/records, play/save time and finished-ending state. |
| UI-015–021 | mute/volume/text speed/lives, gesture bindings, run hold/toggle, switcher and handedness persistence. |
| UI-022 | Glossary content, red ring animation and all close/back paths. |
| UI-023–030 | Story menu/chapter list, Meraviglia pagination, pause/restart/skip/quit, dialogue/choices/cards, controller focus/back. |

Additional input assertions:

- keyboard mappings match README controls;
- each touch pointer is owned by exactly one control until release/cancel;
- swipes fire once as soon as qualified; double tap fires on second press; buttons remain immediate;
- context changes clear queued edges so a confirm cannot trigger pee/action in the next scene;
- Android Back is equivalent to context-appropriate cancel/pause, not a process exit during a run.

## 10. Dialogue, campaign, walk, NPC, combat, and minigame tests

### Dialogue and campaign

| ID range | Acceptance cases |
|---|---|
| DLG-001–007 | typewriter speeds/instant, confirm behavior, wrapping/growing box, choices, locked/costly policy, no all-locked dead end, replay text. |
| DLG-008–009 | names remain yellow and every approved period word is amber during typing and after completion. |
| CAMP-001–006 | initial meters, clamped effects, costs, Commozione fade, Grace tiers, Standing/Grace notes. |
| CAMP-007–011 | unique book awards, remembered/shards/items/values, marvel→home mapping and conditional 8.2 data. |
| CAMP-012–014 | cross/sermon/knight unlocks, dream skin logic, full-Supervillain/unshakeable behavior. |

### Walk and actors

| ID range | Acceptance cases |
|---|---|
| WALK-001–006 | reach/collect/action/survive objectives, progress, success, failure/restart. |
| WALK-007–009 | visible spot rings/sprites, pickups/effects, carry attachment/clear. |
| WALK-010–013 | sight cone/range/LOS, bush hiding, hostile contact and checkpoint restart. |
| WALK-014–017 | leader waits/catches up, lull opens/closes, hidden sound goal, no-run/speed modifiers. |
| WALK-018 | scrambled input rotation and settling match 8.1 fixture. |
| WALK-019–021 | fire spread/push, safe checkpoints, restart state. |
| NPC-001–006 | idle/patrol/chase/flee/follow/wander/flail/goto/fly state transitions and collision. |
| NPC-007 | on-stage idle human performs one speaking gesture then resumes behavior. |
| NPC-008–011 | 7.3 and 8.3 exact companion fall-in/wait/rejoin/pace effects. |

### Combat

| ID range | Acceptance cases |
|---|---|
| COM-001–004 | bark area/range/cone/push, never parried, small stagger. |
| COM-005–008 | sword cooldown/hit, foe wind-up/ring, parry/opening consumption, stagger duration. |
| COM-009–012 | shield front arc/turn/block, blocked attacker stagger, rear hit, controls/modes. |
| COM-013–014 | foe routing and player knockdown fully reset a fight without death/state leakage. |

### Minigames

| ID | Acceptance |
|---|---|
| MINI-001 | Rhythm timing windows, errors and real-input test-driver behavior; a loss applies its exact loss effect and advances once without automatic retry. |
| MINI-002 | 4.1 parade shield rhythm and campaign effects. |
| MINI-003 | 4.3 rowing rhythm and campaign effects. |
| MINI-004 | Rhythm animation/audio/result cleanup is stable across win/loss continuation; whole-scene restart is the only retry path and unused `weeping()` factory is absent. |
| MINI-005 | 4.2 boat alignment/objective/result. |
| MINI-006 | Current 5.2 uses exactly 16 rungs, the input cap and correct result effects. |
| MINI-007 | Current 5.2 stone warning→hit→slide behavior works and the climb continues until victory; there is no lost result/automatic retry and the dormant pitch/axe/hard-assault branch is absent. |
| MINI-008 | 5.2 palette and ladder hero animation use the actual authored walk frame count/timing. |
| MINI-009 | 7.1 tug/rowing result semantics. |
| MINI-010 | 7.7 tug is intentionally lost and story continues correctly. |
| MINI-011 | Letter assembly and both absolution accounts. |
| MINI-012 | Rumour ordering, feedback and completion effects. |

## 11. Scene-by-scene campaign acceptance

Each `STY-*` case has three layers:

1. **Build smoke:** load map/theme/resources, construct every step, advance with debug skip, and fail on any error/warning/missing key.
2. **Real-input completion:** test driver uses the same InputService path as a player and reaches completion inside a time budget.
3. **State snapshot:** compare completed ID, meters, flags, book, abilities, coins, play time policy, ending data and next scene to the approved branch fixture.

IDs and essential assertions:

| IDs | Coverage |
|---|---|
| STY-100 | Full Green Zone 1.0 handoff, time/coins and completion. |
| STY-101–105 | Level 1 reality, flags/scraps/cross, exact sleep boundary. |
| STY-201–203 | Receding Jerusalem, vow/list, bark fight/arms/parry/follow. |
| STY-301–304 | Venice marvels/debt disagreement/weeping/stealth deal. |
| STY-401–403 | Fleet rhythm, horses/boat, rumours/rowing. |
| STY-501–505 | Zara prohibition/dissent, ladders/cloth, duty choice/brawl, letter, winter balance. |
| STY-601–603 | Rations/comradeship, prince promises, Corfu advice. |
| STY-701–707 | City arrival through breach: marvels, banner fight, bespoke pace, city visit, fire escort, coup, oath/breach. |
| STY-708A | 7.8 player calls oath: enforced flag, costs/rewards, girl released, Knight route. |
| STY-708B | 7.8 player stays silent: Niketas calls oath, girl released, Witness/`alpha` route. |
| STY-709 | Lamp declare/hide, empty pedestal, column, pile, Jerusalem never loads. |
| STY-801–804 | Scramble/wake, conditional telling/drawing, lawn companions/bowl, Santina/ball/final line. |

Full-campaign policies:

- Knight + first choices + skill 0.7;
- Witness + last choices + skill 0.7;
- mixed/random + lower skill (target 0.4), which may retry but may not skip;
- one clean human Knight campaign and one clean human Witness campaign before M10.

## 12. Endings and flow tests

| ID | Acceptance |
|---|---|
| END-001 | `oath=enforced` yields THE KNIGHT and exact own-words account. |
| END-002 | absent/silent oath yields THE WITNESS while internal compatibility value remains `alpha`. |
| END-003 | Grace tier produces exact approved line at both boundaries and near-boundary values. |
| END-004 | Standing tier produces exact approved line at both boundaries and near-boundary values. |
| FLOW-006 | Sequential completion unlocks next scene/chapter only as source does. |
| FLOW-007 | Save occurs after persistent effects and scene completion. |
| FLOW-008 | Restart does not double-fade Commozione or duplicate awards. |
| FLOW-009 | Supervillained boundaries are exact: after 1.0 before its score card; again after 1.5 before the Level 1 Professor aside; after the final sublevel of Levels 2–8 before the aside/ending flow; never after a completed-scene replay. |
| FLOW-010 | Finished-scene replay starts from a deep copy. |
| FLOW-011 | Replay completion/restart/choice changes no persistent save field. |
| FLOW-012 | `SKIP SCENE` completes/saves exactly as current source and is unavailable where inappropriate. |

## 13. Save and migration tests

### Native save

| ID | Acceptance |
|---|---|
| SAV-001 | Default settings exactly match source defaults. |
| SAV-002 | Every settings field validates/clamps; bad/unknown fields cannot poison runtime. |
| SAV-003 | Settings round-trip and signal only real changes. |
| SAV-004 | Records keep best score, best stars and lowest time independently. |
| SAV-005 | Legacy standalone `coins` is losslessly imported as present/value preservation data and never mutated by current gameplay; campaign coins remain distinct. |
| SAV-006 | New campaign exact default snapshot. |
| SAV-007 | Campaign effects deduplicate book/ability arrays and clamp meters. |
| SAV-008 | Exact Green Zone order: record saves at level completion; campaign time/coins and 1.0 completion save only on CONTINUE; retry, result-screen quit and game over do not hand them off. |
| SAV-009 | Per-effect/per-scene autosave points match source; settings/container writes do not change nested campaign `savedAt`. |
| SAV-010 | Play time excludes replays and save time uses Unix milliseconds. |
| SAV-011 | Replay state is a deep independent copy. |
| SAV-012 | Known flags obey `CampaignFlagSchema`; unknown v2 scalar flags pass through, invalid known values/unknown composites are omitted after raw backup, and v1 `santinaBall` compatibility values survive. |
| SAV-013 | Valid v1 fixture preserves only 1.0/1.2/1.3/1.4 and approved fields. |
| SAV-014 | Old 1.1-without-1.0 fixture counts 1.0 complete. |
| SAV-015 | Rewritten scenes reset meters/book/abilities/ending as source. |
| SAV-016 | Untouched v1 payload is backed up once; second load is idempotent. |
| SAV-017 | Dream-rewritten notice is set/shown/cleared exactly once. |
| SAV-018 | Format-3 round-trip is semantically identical after normalization. |
| SAV-019 | Temp write validates before replacing current save. |
| SAV-020 | Failure before/after backup rotation recovers newest valid file. |
| SAV-021 | Corrupt current + valid backup restores with user-visible notice and no data loss. |
| SAV-022 | Unknown future format is preserved and reported; it is never overwritten by defaults. Applies to the main, temp and backup files alike: each future payload is preserved byte-for-byte and every write is blocked. |

### Capacitor acquisition and Android upgrade

| ID | Acceptance |
|---|---|
| MIG-001 | Old APK fixture contains known values in all five `supervillained:` keys. |
| MIG-002 | Upgrade uses same package ID, a versionCode greater than the actually installed artifact, and its exact signing certificate. |
| MIG-003 | Installation is `adb install -r`/store update; no uninstall or clear-data step. |
| MIG-004 | Native bridge reads only the verified old origin/default WebView store and does not mutate it. |
| MIG-005 | Raw payload is written with timestamp/hash before conversion. **M4 (fixture/simulated):** the raw five-key payload is written exactly, byte for byte, with its timestamp and SHA-256 before any parsing, and is read back and verified; backup, write and read-back failures are tested (nothing is parsed and no success is claimed after any of them). **M9:** proven through real WebView acquisition on the installed lineage. |
| MIG-006 | Settings/records and passive legacy standalone-coin present/value data convert exactly. |
| MIG-007 | v2 campaign converts exactly to format 3. |
| MIG-008 | v1 campaign performs v1→v2 semantics before format-3 conversion. |
| MIG-009 | `not_attempted/imported/imported_partial/not_found/retryable_error/blocked` transitions, per-key results and retry/idempotence rules match the schema. |
| MIG-010 | Missing/unreadable legacy store shows approved limitation/recovery copy and never fabricates success. |

Mandatory negative cases: different signing key cannot update; different package cannot see sandbox; fresh install has no legacy payload; malformed JSON is backed up but not trusted; browser storage is not claimed as importable.

## 14. Audio and FX tests

| ID range | Acceptance cases |
|---|---|
| AUD-001–004 | Five recorded tracks and twelve recorded effects exist, decode, are non-silent, and map to correct cues. |
| AUD-005–008 | Medieval loop and fourteen synth cues are deterministic mono 22,050 Hz signed-16-bit little-endian PCM WAV; recipe hashes, sample counts, output hashes, duration/amplitude and loop/cue behavior match fixtures. |
| AUD-009–013 | Chapter routing, track-position resume, gain trims, mute/volume, duck/background suspend/resume. |
| FX-001–003 | Supervillained snap timing, skip window, placement after correct level boundaries/exclusions. |
| FX-004–012 | Title/transition/text glitch bounds, particles/popups, bark arcs, shake/flash, cleanup and no rule dependency. |

Audio manual review uses headphones and device speaker at safe volume. Listen for clipping, doubled cues, loop gaps, resume jumps, and missing audio after backgrounding. Automated audio assertions do not replace listening.

## 15. Alternate playable profiles

| ID | Acceptance |
|---|---|
| ALT-001 | Developer launch option selects Zampanò/Sbrimbrulòn/Bagnaskiz without changing campaign text/state. |
| ALT-002 | Plain/cross-equivalent/armoured costume mapping is exact; only armoured profiles gain arms when campaign ability allows. |
| ALT-003 | Each profile completes movement, one action-heavy scene and one fight with valid frames/anchors; no public character selector exists by default. |

## 16. Android and lifecycle matrix

| ID | Acceptance |
|---|---|
| AND-001 | Headless export creates debug APK; release process creates signed APK and AAB. |
| AND-002 | APK metadata: exact package, min SDK 24, approved target/compile, versionCode greater than the actually installed artifact (repository baseline 1), expected certificate. |
| AND-003 | App launches/locks portrait; rotation attempt does not corrupt viewport/input. |
| AND-004 | Back pauses/resumes gameplay and navigates overlays/title as specified. |
| AND-005 | Immersive bars hide and transient swipe bars do not permanently offset UI. |
| AND-006 | Keep-screen-on is active during play and released when app exits/background policy requires. |
| AND-007 | Safe-area/cutout/home-gesture regions do not cover HUD/buttons. |
| AND-008 | Airplane-mode cold start, title, Green Zone, representative chapters, audio and saves work. |
| AND-009 | Signed source APK upgrades in place to Godot artifact. |
| AND-010 | Migrated Couch/settings/records/coins/campaign match source fixture. |
| AND-011 | QUIT closes task from title; it cannot accidentally close an active run via Back. |
| AND-012 | Publisher link opens external browser and return restores paused game safely. |
| AND-013 | APK/AAB contains no keystore/password/source ZIP/archive/unexpected Internet-loaded resource. |
| LIFE-001 | App switch/home pauses simulation/audio; return resumes without input edge/stuck pointer. |
| LIFE-002 | Screen lock/unlock and focus loss during dialogue, fight and minigame preserve valid state. |
| LIFE-003 | Background flushes only already-dirty persistent domains (approved native hardening), never transient mid-scene/run state and never advances campaign `savedAt` without a source-defined campaign save; forced death restarts from the last defined point. |

Device report must record model, SoC/GPU, RAM, Android version, WebView version, refresh rate, display resolution/DPR, build hash/type, battery/thermal condition and input method.

## 17. Performance tests

Use a named mid-range Android device and a release-like signed build with max FPS 60, VSync, Android frame pacing enabled and Swappy `pipeline_forced_on`. On 90/120 Hz panels record the selected display mode and prove Swappy does not downgrade the target. Distinguish CPU/GPU work time from presented-frame intervals. Warm up for two minutes, then record:

| ID | Scenario and gate |
|---|---|
| PERF-001 | Ten-minute worst-case Green Zone: three pollution waves, active attack, maximum visible items/FX. Presented average ≥58 FPS; CPU/GPU work p95 ≤16.7 ms and p99 ≤25 ms; missed 60 Hz slots <2%; no post-warmup stall >100 ms. |
| PERF-002 | Dense Constantinople story/fight/minigame sequence meets the same work/presentation gates and does not trigger a 45/30 FPS Swappy downgrade. |
| PERF-003 | Peak proportional-set memory remains <256 MB; no monotonic leak across five scene/restart cycles. |
| PERF-004 | Cold-start to interactive title, scene transition and save-write times are recorded; no blocking operation causes >100 ms gameplay stall after warmup. |

Collect Godot profiler captures plus `adb shell dumpsys gfxinfo`, `adb shell dumpsys meminfo`, SurfaceFlinger/frame-timestamp evidence and relevant logcat. Include a 90 Hz device or forced 90 Hz mode in the pacing report, even if the designated performance device is 60/120 Hz. Do not profile an editor/debug build as release evidence. Thermal throttling is reported, not discarded.

## 18. Visual capture and review

Required logical viewport cases:

- 192×457 (narrow/tall boundary, approximately 0.42);
- 200×430 (the existing Playwright reference geometry from 400×860 CSS at DPR 2);
- 216×432 (target portrait);
- 270×435 (wide portrait boundary, approximately 0.62);
- simulated top/bottom/side safe-area insets;
- right- and left-hand controls.

Required capture families include title/options/controls/Couch/Glossary, Green Zone movement/occlusion/HUD/poop/pee/attack/cat-ball/result/game-over, representative card/dialogue/choice/book/pause, every minigame, all playable profiles/costumes/directions, fights 2.3/5.3/7.2, scenes 7.3/7.5/7.8/8.1/8.2/8.3, Supervillained snap, and both endings.

Source and Godot images are reviewed side by side for hierarchy, content, crop, anchor, readability and state. Exact cross-engine pixel equality is not required. After a Godot capture is approved, subsequent same-version regression uses dimensions plus a documented pixel/perceptual tolerance. Updating a golden requires an explicit flag, committed image diff and architect approval.

## 19. Manual full-game checklist

Before M10 acceptance:

1. Clean-save Green Zone run into Level 1.
2. Complete campaign to Knight without skips.
3. Clean-save campaign to Witness without skips.
4. Exercise all meaningful choices/branches not covered by those two runs through replay or a third save.
5. Deliberately fail/retry every fight and failure-capable walk; exercise each minigame win/loss or hit/slide outcome and its whole-scene restart path without inventing automatic retries.
6. Verify every menu, Back path, text speed, control setting and handed layout.
7. Verify replay does not alter Couch or save hashes.
8. Verify migrated v1 and v2 saves on device.
9. Complete at least one long offline session with background/lock interruptions.
10. Review final capture set and audio cue checklist.

Record tester, date, branch/SHA, artifact checksum, platform/device, start fixture, ending, observed defects and result. “Looks fine” is not acceptable evidence.

## 20. Release-blocking failures

Any of these blocks release:

- a required campaign entry cannot be completed by real input;
- either ending is unreachable or state/text differs materially;
- Green Zone automation/human play cannot reach a valid result;
- save/replay corrupts or mutates unintended state;
- legacy migration claims success with missing/different data;
- signed in-place upgrade is not demonstrated or save-loss limitation is undisclosed;
- a missing asset is hidden by fallback;
- required content depends on network access;
- Android Back/lifecycle loses an active run outside defined save semantics;
- required source baseline no longer builds/tests;
- performance gate is missed without an approved scope/target change;
- unreviewed or unlicensed material is included in a public release.

## 21. Milestone evidence template

```text
Milestone:
Branch / commit:
Godot version:
Source reference commit:
Commands executed and exact summaries:
Automated case IDs passed/failed/skipped:
Manual scenarios and device/environment:
Captures / reports:
Save fixtures and hashes:
Android package/version/certificate (if applicable):
Known deviations / open decisions:
Source-tree guard result:
Architect review result:
```

No test is reported as passed unless it was executed against the identified commit/artifact.
