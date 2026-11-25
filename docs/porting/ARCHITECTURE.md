# SUPERVILLAINED VG1 — Godot migration architecture

- Status: implementation specification for a new Godot project; no Godot gameplay code exists yet.
- Target: Godot 4.7.2 stable, standard GDScript, native Android.
- Audited source: branch `claude/gallant-pascal-wjy5l2`, commit `95b69c0`.
- Planning branch: `codex/godot-port-architecture`.

## 1. Scope and sources of truth

The port is a rewrite of the runtime, not a redesign of the game. The PixiJS/TypeScript application remains intact and buildable. All Godot implementation must live under `/godot`; generated builds and editor caches must not be committed.

When source materials disagree, use this order:

1. Executable chapter and gameplay code plus passing tests.
2. `docs/STORY.md` for the canonical current narrative and `docs/STORY-SOURCES.md` for sources and save semantics.
3. Current sections of `DECISIONS.md`; its earlier 42/43-scene anthology design is historical and is superseded by the Fourth Crusade rewrite.
4. `README.md` and `CLAUDE.md` for player-facing behavior and current architecture.
5. `SPEC.md` for the Green Zone design only; its engine prohibition and original single-level scope do not apply to this migration.

**Narrative content (M5R architect decision).** For story prose, scene beats and story content the
authority is the Godot-native rewrite: the versioned story Resources under `godot/data/story/`, then
`docs/porting/STORY_REWRITE_SPEC.md`, `STORY_CONTENT_MATRIX.md` and `STORY_REWRITE_DECISIONS.md`.
For narrative text, items 1 and 2 above (the PixiJS chapter code and `docs/STORY.md`) are draft and
reference material; reviews do not require verbatim parity with them. The order above still governs
mechanics, maps, assets and saves, and the rewrite preserves the invariants of
`STORY_REWRITE_SPEC.md` §2 (eight levels, IDs 1.0–8.4 and the 37-entry catalog, both endings, the
reality/dream boundary, meters, abilities, flags, choices and consequences, Green Zone 1.0).

The canonical campaign has **37 entries: 1.0 plus 36 scripted scenes**:

| Level | Entries | Count |
|---|---|---:|
| 1 — The Greenzone | 1.0–1.5 | 6 |
| 2 — On the edge of dreams | 2.1–2.3 | 3 |
| 3 — Venice | 3.1–3.4 | 4 |
| 4 — The sea | 4.1–4.3 | 3 |
| 5 — Zara | 5.1–5.5 | 5 |
| 6 — The long winter | 6.1–6.3 | 3 |
| 7 — Constantinople | 7.1–7.9 | 9 |
| 8 — Back to the Greenzone | 8.1–8.4 | 4 |

Scene 1.0 is the Green Zone `GameScene`; 1.1–8.4 are story scripts. Retired anthology scenes, black-hole cuts, calm rescue, and catapult are not parity requirements.

## 2. Verified source baseline

The repository was inspected rather than inferred from documentation. On 2026-11-21 the following commands were executed on the audited commit:

| Check | Result |
|---|---|
| `npm ci` | completed; 151 packages audited, no reported vulnerabilities |
| `npm test` | 30 files, 248 tests passed |
| `npm run build` | TypeScript and Vite production build passed |
| `npm run smoke` | all 36 scripted scenes passed; no page, texture, marker, actor, or GL errors |
| `npm run playtest -- --skill 0.7 --ending knight --choice first` | reached Knight ending; 36 scripted scenes, 0 unfinished, 0 flagged, 0 page errors |

The story smoke and autopilot intentionally do not play Green Zone 1.0. Green Zone logic has unit and balance coverage, but full Green Zone and Android behavior still require manual/on-device verification.

Android packaging is configured but not validated by meaningful repository tests: the Java unit/instrumentation files are Capacitor boilerplate, the instrumented example asserts `com.getcapacitor.app` rather than the real package, and there is no Android CI workflow. The committed workflow is iOS-only and does not run Vitest. This audit did not build or install an APK.

The locally installed executable reports file product version `4.7.2.stable.official`. No Godot project or Godot test was run because `/godot` does not yet exist.

## 3. Source architecture and current status

The PixiJS implementation is a compact custom engine, not an ECS:

- `src/core/game.ts` owns renderer, input, scene stack, settings, audio, and loop.
- `src/core/loop.ts` runs fixed 60 Hz logic with render interpolation.
- `src/core/scene.ts` implements an overlay-capable scene stack.
- `src/world/world.ts` is shared by Green Zone and story stages.
- `src/config.ts` centralizes global tuning; chapter scripts own per-scene data.
- `src/campaign/chapters/` contains executable story definitions, not passive JSON.
- `src/story/` contains the reusable step runner, walks, combat, dialogue, and minigames.
- `src/systems/` contains mostly pure Green Zone and combat rules.

The requested core game is implemented in the source: Green Zone needs/pollution/scoring/threats, the canonical eight-level campaign, both endings, combat, companions, NPC behaviors, current minigames, dialogue, progression, replay, settings, touch controls, isometric rendering, and Android packaging. Partial or planned-only source items are called out in `FEATURE_MATRIX.md`.

## 4. Architectural decisions

These decisions are binding for the first implementation pass.

1. **One new project under `/godot`.** Do not move, rewrite, or import in place from `src/`, `public/`, `assets/`, `android/`, or `ios/`.
2. **GDScript only for game code.** No C#, GDExtension, ECS, behavior-tree framework, dialogue framework, or third-party runtime package. A narrowly scoped Android Java/Kotlin migration plugin is the only anticipated exception.
3. **Composition over inheritance.** A generic `PlayableDog` supports Zampanò, Sbrimbrulòn, and Bagnaskiz through Resources. NPC behavior stays a small explicit state controller.
4. **Shared world stack.** Green Zone and story stages instantiate the same isometric world, player, camera, depth, collision, and animation components.
5. **Authoritative grid semantics.** Gameplay values remain in continuous grid coordinates and tiles/second. Rendering and Godot physics positions are projections of that model.
6. **Native Godot UI.** All menus, HUD, dialogue, book, virtual joystick, buttons, and overlays use `Control`, `CanvasLayer`, `Theme`, and input events. No embedded web UI.
7. **Typed data for story content, typed code for its execution (amended in M5R).** Each scene is a `StorySceneData` Resource whose ordered steps are typed `StoryStep` Resources holding all player-visible text; step classes and small scene rule classes hold execution logic only and are parameterised by the Resource fields. Every step type and field is validated (`STORY_REWRITE_SPEC.md` §6): this is not an unvalidated JSON DSL. No narrative text in runner, step, rule or scene scripts.
8. **Editor-time asset conversion.** Sprite sheets, environment atlases, title animation, procedural fallbacks, and synthesized audio are converted before shipping. Runtime atlas packing and WebAudio synthesis are eliminated.
9. **Versioned atomic saves.** Godot uses one validated JSON container under `user://`, plus backup and raw legacy-import files.
10. **Parity before cleanup.** Port current behavior, including oddities documented as current, before proposing redesigns. Story prose and scene beats are the exception: they follow the rewrite authority (§1, §13), with every change recorded in `STORY_REWRITE_DECISIONS.md`.
11. **Compatibility renderer first.** Use Godot's `gl_compatibility` renderer for this 2D, min-SDK-24 Android target. A renderer change requires capture and device-performance evidence; it is not a casual project-setting change.

## 5. Proposed project layout

```text
godot/
  project.godot
  export_presets.cfg
  README.md
  main/
    main.tscn
    main.gd
    pixel_viewport_controller.gd
  autoload/
    app_state.gd
    save_service.gd
    input_service.gd
    audio_service.gd
  core/
    game_config.gd
    deterministic_rng.gd
    result.gd
  data/
    balance/
    characters/
    maps/
    palettes/
    campaign/
    audio/
    source_asset_manifest.json
  iso/
    iso_grid.gd
    iso_depth_sorter.gd
    camera_rig.gd
    iso_renderable.gd
  world/
    world_2d.tscn
    world_2d.gd
    level_definition.gd
    ascii_map_loader.gd
    world_map_model.gd
    tile_catalog.tres
  entities/
    playable_dog/
    actor/
    critters/
    items/
    props/
    components/
  systems/
    needs_system.gd
    green_zone_rules.gd
    scoring_rules.gd
    threat_director.gd
    lives_rules.gd
    combat_rules.gd
  campaign/
    campaign_state.gd
    campaign_catalog.gd
    campaign_summary.gd
    home_objects.gd
    chapters/ch1.gd ... ch8.gd
  story/
    story_runner.gd
    story_context.gd
    steps/
    story_walk_controller.gd
    combat_controller.gd
    carry_presenter.gd
    text_markup.gd
  scenes/
    title/
    green_zone/
    story/
    overlays/
    minigames/
    debug/
  ui/
    theme/
    hud/
    touch/
    dialogue/
    menus/
  fx/
    shaders/
    particles/
    popups/
    transitions/
  assets/
    fonts/
    sprites/
    environment/
    audio/recorded/
    audio/generated/
    title/
    branding/
  tools/
    sync_source_assets.gd
    build_sprite_frames.gd
    build_tile_resources.gd
    validate_content.gd
    capture_suite.gd
  tests/
    test_runner.gd
    unit/
    integration/
    fixtures/
    captures/
```

Generated `.godot/`, export output, APK/AAB files, and local keystore paths must be ignored. The root `android/` remains the Capacitor project; any Godot custom Gradle/plugin files live only below `/godot`.

## 6. Persistent runtime and scene hierarchy

Only four autoloads are justified:

| Autoload | Responsibility | Must not own |
|---|---|---|
| `AppState` | current validated campaign, settings, records, selected playable profile, replay/non-persistent session | scene nodes or file I/O |
| `SaveService` | load, validate, migrate, atomically write, back up, legacy import | gameplay rules |
| `InputService` | InputMap state, touch state, gesture mapping, handedness, context, test/autopilot injection | UI drawing |
| `AudioService` | music continuity, buses, cue lookup, mute/volume/ducking, background suspend | gameplay event decisions |

Do not add a global event bus. Controllers expose local typed signals, and scenes connect only to their owned children/services.

`main/main.tscn` is persistent:

```text
Main (Node)
└── SafeAreaRoot (Control)
    └── PixelViewportContainer (SubViewportContainer)
        └── GameViewport (SubViewport)
            ├── SceneHost (Node)
            ├── OverlayCanvas (CanvasLayer)
            │   └── OverlayHost (Control)
            └── TransitionCanvas (CanvasLayer)
                └── TransitionHost (Control)
```

`Main` owns scene replacement and overlay push/pop. A pause overlay freezes the active gameplay root while its own nodes continue processing; it asks `AudioService` to duck rather than relying on incidental AudioStream behavior. Replays receive a deep copy of `CampaignState` with `persist=false`.

Major screens are separate packed scenes:

- `TitleScreen.tscn`: NEW GAME, CONTINUE, COUCH, OPTIONS, GLOSSARY, QUIT, animated portrait, film/glitch presentation.
- `GreenZoneScene.tscn`: shared world plus Green Zone controller and HUD.
- `StoryScene.tscn`: shared world plus `StoryRunner`, dialogue/story HUD, and optional minigame host.
- Overlay scenes: briefing, pause, controls, story menu, chapter list, Meraviglia book, level end, game over, Professor aside, ending, and Supervillained snap.

## 7. Shared isometric world

`world/world_2d.tscn`:

```text
IsoWorld (Node2D)
├── GroundLayer (TileMapLayer)
├── PollutionLayer (TileMapLayer)
├── FreshLayer (TileMapLayer)
├── DecalLayer (Node2D)
├── ObjectLayer (Node2D)
│   ├── static props
│   ├── player
│   ├── actors/critters
│   └── items/pickups
├── FxLayer (Node2D)
├── TriggerLayer (Node2D)
└── CameraRig (Node2D)
    └── Camera2D
```

Ground cells use `TileMapLayer`, which is the non-deprecated Godot 4 node. Floors and pollution are separate layers. Tall props are instanced nodes in `ObjectLayer` so they share the same explicit painter sort as characters and can fade for occlusion. Authored Color Ink floor compositions remain visual-only; ASCII topology, collision, markers, and objectives remain authoritative.

The generated TileSet contract is fixed: `tile_size = Vector2i(32, 16)`, isometric shape, `TILE_LAYOUT_DIAMOND_DOWN`, and horizontal offset axis. Measured on Godot 4.7.2 with this configuration, `map_to_local(Vector2i(i,j)) == IsoGrid.grid_to_screen(i + 0.5, j + 0.5) + Vector2(16, 0)`, so every TileMapLayer is positioned at `IsoGrid.TILE_LAYER_OFFSET = Vector2(-16, 0)` and tests must prove `map_to_local(Vector2i(i,j)) + TILE_LAYER_OFFSET == IsoGrid.grid_to_screen(i + 0.5, j + 0.5)` (MAP-003). *(Corrected after the M2 review: the earlier `Vector2(0, 8)` offset did not match the engine.)* Water, deep water, and tall grass use phase-rotated animated alternatives selected by the same deterministic cell hash as the source; a single lockstep animated tile is not parity.

Continuous dirt/fresh presentation uses three runtime-updated TileMapLayers, not thousands of ad-hoc sprites (approved after the M2 review: in the source a cell can show the dirt overlay and the fresh highlight at the same time, which one layer cannot hold). `GroundLayer` supplies dirt-dependent base modulation; `PollutionLayer` contains only cells whose dirt is above `POLLUTION.VISIBLE` and supplies the overlay alpha; `FreshLayer` contains only freshly cleaned cells and supplies the highlight alpha. A stamp notifies Ground and Pollution; a clean also notifies Fresh; fresh-only timer changes notify only Fresh. The renderer owns `runtime_coords` (all currently modulated cells) and `reset_pending` (cells that just returned to defaults). On a nonempty model changed set it updates those sets/cells, clears the copied model set, then calls layer-wide `notify_runtime_tile_data_update()` once per affected layer. `_use_tile_data_runtime_update(coords)` returns `true` for the union of `runtime_coords` and `reset_pending`; `_tile_data_runtime_update(coords, tile_data)` returns `void` and mutates `tile_data.modulate` from the current model. Thus a layer-wide refresh reapplies every still-active modulation. A reset cell remains eligible until its callback applies the default modulation; the callback marks it applied, and the next process tick removes it from `reset_pending`; overlay cells are erased from their layer when their alpha would be zero. Tests observe the engine-supplied runtime `TileData` inside the callback (`get_cell_tile_data()` returns the shared, unmodified data). No notification is issued when the model changed set is empty. This choice is profiled in M3; replacing it requires architect approval and equivalent tint/alpha/fade tests.

### 7.1 Projection contract

`IsoGrid` is the only implementation of projection:

```text
TILE_W = 32
TILE_H = 16
screen_x = (grid_x - grid_y) * 16
screen_y = (grid_x + grid_y) * 8
grid_x = screen_y / 16 + screen_x / 32
grid_y = screen_y / 16 - screen_x / 32
```

Grid tile `(i, j)` covers `[i,i+1) × [j,j+1)`. Map rows are `grid_y`; columns are `grid_x`. Direction names are screen-space names: `N` means up on the display. Facing classification must undo the 2:1 squash exactly as `src/iso/projection.ts` does.

No gameplay script may call `TileMapLayer.map_to_local()` as its coordinate authority. It may be used only by map-building/presentation code, with regression tests against `IsoGrid`.

### 7.2 Movement and physics

`PlayableDog` and moving actors are `CharacterBody2D` configured for top-down motion: `motion_mode = MOTION_MODE_FLOATING`. The native-solver baseline pins `safe_margin = 0.08`, `max_slides = 4`, and `wall_min_slide_angle = 0.261799` radians in one `PhysicsConfig` Resource; M2 may change them only once, against recorded source trajectories. Each body keeps `grid_position` and `grid_velocity` in tiles and tiles/second. A physics tick performs:

1. Read a screen-space input vector from `InputService`.
2. Inverse-project and normalize it into grid space.
3. Apply analog walk magnitude, RUN state, energy, terrain multiplier, action locks, acceleration/deceleration, external push, and knockback in grid units.
4. Project grid velocity into screen pixels/second.
5. Assign the projected pixels/second directly to `velocity` (do not multiply by delta) and call `move_and_slide()` from `_physics_process()`.
6. Convert the final foot point back to authoritative grid coordinates.

Current values must be copied from `src/config.ts`, including walk 4.4 tiles/s, run 7.5, radius 0.26, acceleration 16, deceleration 20, and terrain multipliers bush 0.7, water 0.8, tall grass 0.85. Full joystick deflection does **not** trigger run; RUN/Shift/K or scripted input does.

A grid-space circle projects to an ellipse. Player and circular prop collision polygons must be generated by projecting sampled circle points; blocked square tiles project to diamonds. `Area2D` is used for pickups, exits, water/marking detection, objectives, sight/contact zones, and combat hit/hurt areas. Every `Area2D` shape that stands for a source radius (the dog's `InteractionProbe` and `Hurtbox` included) is a projected grid circle built by `GridShapes.ellipse_polygon()` (circumscribed, on the foot point), never a screen circle, and is **broad phase only**: an overlap means "maybe", and the rule decides with the exact grid distance (`GridShapes.distance()`, the source's `Math.hypot`) against its own source radius. Prop rules measure to the prop's **edge** (`WorldMapModel.nearest_prop`: hypot − radius ≤ distance, the source logic, authoritative), so interaction targets register at their grid centre and the probe covers the largest prop rule distance plus the largest target radius (`GridShapes.MAX_TARGET_RADIUS`, the widest catalog prop) plus a whole-pixel snap margin for the probe and target nodes (`GridShapes.SNAP_MARGIN`): `GridShapes.PROBE_RADIUS` = 1.05 + 0.5 + 0.1 = 1.65 tiles. The hurtbox is the player's collision radius.

Godot slide response is a migration risk. Milestone 2 has a mandatory trajectory comparison against source fixtures. If projected `move_and_slide()` differs by more than 0.10 tile at any checkpoint or changes reachability, port `GameMap.moveCircle` as `GridKinematicSolver` for static-map resolution. In that mode, remove `WorldSolid` from the body's mask and do not call native slide resolution for the same static displacement; the custom solver moves the body once. Dynamic player/actor contact remains the source-style radius/Area2D rule logic rather than a second blocking solver. This is the approved fallback; do not tune around a mismatch scene by scene.

Enable Godot physics interpolation project-wide. Gameplay bodies and `CameraRig` move only in `_physics_process()`; there is no manual interpolation and Camera2D smoothing stays disabled. Call `reset_physics_interpolation()` on the moved body/visual hierarchy and camera after spawn, teleport, restart, checkpoint restore, stage change, or camera snap, before it becomes visible. Whole-pixel canvas transform snapping happens after interpolation. This avoids double interpolation while retaining the source's fixed-tick/smooth-render contract.

### 7.3 Collision layers

| Layer | Name | Typical bodies | Typical mask |
|---:|---|---|---|
| 1 | WorldSolid | TileMap collision, solid props | player, actors |
| 2 | PlayerBody | `PlayableDog` body | world, actors as required |
| 3 | ActorBody | NPCs, cats, Bagnaskiz, combat foes | world, player as required |
| 4 | Interaction | pickups, water, exit, objectives, marking zones | player |
| 5 | PlayerAttack | bark/sword transient areas | actor hurtboxes |
| 6 | ActorAttack | foe attack areas | player hurtbox |
| 7 | Hurtbox | player/actor hit receivers | attack layers |
| 8 | VisionTrigger | optional broad-phase sight/stealth zones | player |

Collision masks are explicit per scene; decorative nodes have no collision. Vision occlusion itself uses grid/raycast logic, not physics overlap alone.

### 7.4 Depth, occlusion, and camera

Do not rely solely on Godot Y-sort. `IsoDepthSorter` collects visible `IsoRenderable` objects and sorts by:

1. `grid_x + grid_y + depth_bias`;
2. `grid_x`;
3. stable creation ID.

It assigns sequential `z_index` values inside the object band. This preserves the source tie-break and avoids flicker. Ground, pollution, decals, objects, world FX, and UI occupy separate z/canvas bands.

Occlusion parity is intentionally player-only: a tall prop uses the source first-order fade update (rate constant 10/s) toward alpha 0.42 when it sorts in front of the playable dog and their screen-space sprite rectangles overlap. It returns toward 1.0 with the same update when clear. Do not replace this with a general visibility system during parity work.

`CameraRig` manually ports exponential follow, movement look-ahead, vertical bias, handheld sway, shake decay, whole-pixel snapping, and map clamping. Built-in Camera2D smoothing stays disabled so there is one source of truth.

## 8. Pixel viewport and portrait layout

The source uses an adaptive logical width rather than one fixed viewport. `PixelViewportController` ports `computeViewport` exactly; the source algorithm is authoritative (M2 review resolution of VIEW-002, no additional clamp without the owner's explicit authorization):

- device area = floor(css × DPR); the area is constrained to the portrait aspect range 0.42–0.62 (width floored to height × 0.62, or height floored to width / 0.42);
- integer device-pixel scale = max(1, round(area width / 216)), lowered while the logical width would fall below 192 and scale > 1, raised while it would exceed 270;
- logical size = floor(area / scale), so the width is 192–270 and the aspect 0.42–0.62 (within one pixel of flooring) wherever the area allows it, with the source's own below-192 bands kept as they are:
  - constrained areas narrower than 192 device px stay at scale 1 at their own width (below 192);
  - constrained areas 271–383 device px wide get scale 2 and a logical width of 135–191 (scale 1 would exceed 270, scale 2 falls below 192, and the source keeps scale 2);
- centered letterbox/pillarbox outside the safe area;
- nearest filtering, mipmaps off, integer sprite/control positions.

Use `DisplayServer.get_display_safe_area()` to obtain the physical safe rectangle. The root window performs no second content stretch. Size/center `PixelViewportContainer` to `logical_size × integer_scale`, set `stretch=true` and `stretch_shrink=integer_scale`, and let it size the child `GameViewport`; do not also assign the SubViewport size manually. Present the viewport texture with nearest filtering.

`SubViewportContainer` forwards pointer events into the SubViewport. Controls inside it receive logical viewport coordinates and pass those directly to `InputService`; they must not convert them again. Only a root/window event intentionally routed straight to an autoload is transformed once. This prevents duplicate or double-scaled touch delivery.

The WOFF2 and OFL remain source/license inputs, but the runtime UI uses a generated bitmap font for parity. The M1 converter executes the source `src/ui/pixelFont.ts` rasterization contract—8 px design size, alpha threshold 110, fixed advance/cropped union metrics, ASCII fallback, borrowed IPA marks and rotated-e schwa—and emits a BMFont/image-font atlas plus metrics. Godot loads that bitmap Font at integer multiples with nearest CanvasItem/viewport filtering. Do not substitute a directly rasterized dynamic `FontFile`, which changes wrapping and special glyphs.

## 9. Entities and animation resources

### 9.1 Playable dog

```text
PlayableDog (CharacterBody2D)
├── Shadow (Sprite2D)
├── VisualRoot (Node2D)
│   ├── Body (AnimatedSprite2D)
│   ├── CarryAttachment (Node2D)
│   └── ActionFxAttachment (Node2D)
├── BodyShape (CollisionShape2D)
├── InteractionProbe (Area2D)
├── Hurtbox (Area2D)
└── StateMachine (Node)
```

The state machine covers free, pee, poop, bark, eat/drink, fetch, hurt, and exit; guarding and combat actions compose with it. Idle presentation cycles standing, sitting, and sniffing; tired is driven by run-energy recovery. Gameplay timers own action duration; animation completion must not silently change rule timing.

`PlayableCharacterProfile` Resource fields:

- stable ID and display name;
- normal, cross-equivalent, and armoured `SpriteFrames` references;
- foot anchor, collision radius, scale;
- capability tags (`can_bark`, `can_use_arms_when_armoured`);
- portrait/name color;
- costume mapping.

Profiles are required for `zampano`, `sbrimbrulon`, and `bagnaskiz`. The canonical campaign selects Zampanò. Preserve a developer launch override for the other two; do not add a player-facing selector without a separate design decision.

### 9.2 Animation import

Playable sheets use 40×40 frames, foot anchor `(20,36)`, directions `N, NE, E, SE, S, SW, W, NW`, and actions `idle, walk, run, sniff, pee, poop, eat, bark, fetch, hurt, sit, tired`. Generate `SpriteFrames` names such as `walk_n`, `walk_ne`, and so on. Set `AnimatedSprite2D.centered=false` and position it at `(-anchor_x, -anchor_y)` relative to the foot point.

Per-frame holds are authored. For nonuniform cycles, set animation speed to 1 and frame-duration weights to seconds (`hold_ms / 1000.0`); for uniform cycles, the source FPS with duration weight 1 is acceptable. One-shot/loop flags must match the manifest. `zampanoCross` deliberately aliases the knight art.

`ActorBody` uses the same presentation component and an explicit behavior enum: idle, patrol, chase, flee, follow, wander, flail, goto, fly. Do not introduce pathfinding where source scenes use straight authored paths/local steering.

## 10. Map and environment data

Keep current ASCII maps as migration authority. `AsciiMapLoader` ports validation for unknown symbols, missing/duplicate starts and exits, short-row padding, story maps without exits, and numeric markers. `LevelDefinition` Resource contains:

- ID, number, zone name, seed, palette, par time;
- ASCII resource path;
- spawn settings and event settings;
- map theme/environment bank;
- whether an exit is required.

At load, `WorldMapModel` owns ground enums, collision/health masks, props, markers, start/exit, pollution floats, changed cells, fresh-clean highlights, and BFS distance-to-exit. It populates `TileMapLayer` nodes and prop scenes. It remains testable without a scene tree.

Do not implement the source's reserved Tiled branch; it currently throws. A future Tiled importer must target the same `LevelDefinition`/`WorldMapModel` interface and is outside parity scope.

## 11. Input and native UI

InputMap actions:

| Action | Keyboard | Touch/context |
|---|---|---|
| move | WASD/arrows | floating joystick on movement side |
| run | Shift or K | RUN, hold or toggle setting |
| context action | Space and/or J/X by scene | round action button |
| pee | Space in Green Zone | PEE |
| bark | B; J/X in Green Zone compatibility | BARK/mode/double tap |
| sword | U | mode/swipe up by default |
| shield | hold I | mode/swipe down by default |
| switch | Q or Tab | optional small switcher |
| pause/back | Esc / Android Back | MENU |
| confirm | Space/Enter | dialogue/card tap |

`InputService` has contexts (`menu`, `green_zone`, `story_walk`, `dialogue`, `minigame`) so the same physical input produces the source behavior. It exposes consumable edges, held states, a screen-space movement vector, and an injection interface used by tests/autopilot.

The floating joystick claims one pointer ID only on the configured movement side, appears under the thumb, applies the source dead zone/radius, and never steals action-button touches. The action side recognizes swipe up/down and double tap above—not on—the buttons. Controls mirror fully for left-hand mode. RUN hold/toggle, switcher visibility, and gesture bindings are saved.

Use Godot `Control` nodes for every screen. `Theme` resources centralize colors, pixel font, borders, focus/pressed states, and safe margins. `RichTextLabel`/custom text markup handles colored names and period words; a small custom `Control` may be used where source-specific justified pixel text or animated hand-drawn rings cannot be expressed by standard Labels.

## 12. Green Zone architecture

`GreenZoneScene` owns pure rule objects through `GreenZoneController`:

```text
GreenZoneScene (Node)
├── IsoWorld
├── GreenZoneController
│   ├── NeedsSystem
│   ├── GreenZoneRules
│   ├── SpawnDirector
│   ├── ThreatDirector
│   ├── PollutionWaveDirector
│   ├── ScoringRules
│   └── LivesRules
└── GreenZoneCanvas (CanvasLayer)
    ├── Hud
    ├── TouchControls
    ├── AttackBanner
    └── PopupLayer
```

Rules remain separate from presentation and emit local signals. Preserve hunger drain by activity, digestion overflow and warning, delayed automatic poop, surface-dependent pollution, pollution spread, bladder regeneration/refill, expanding pee clean radius, one-time marking bonus per object, water behavior, run energy/exhaustion, health/half-stars, end penalty when pees are fewer than poops, lives, scoring, cats/coins, ball magnet/fetch, deterministic spawns, three pollution waves, under-attack state, Bagnaskiz trail/hits/flee, and bark cone.

The 96×96 redesigned Green Zone and its generated topology/treat placement must be ported deterministically from `src/levels/level1.ts`; do not apply the obsolete `1:arcade` authored floor composition.

## 13. Campaign and story architecture

`CampaignState` is a pure RefCounted model. `CampaignCatalog` exposes eight typed `ChapterDefinition`s and exactly 37 `SubLevelDefinition`s. `ChapterDefinition` owns number, title, theme, music, cast metadata, intro, Professor aside and its ordered sublevels. `SubLevelDefinition` owns only ID, title, happens/summary, source metadata, optional Green Zone dispatch and a fresh script factory. Do not duplicate chapter theme/music/intro data across sublevels.

**Story engine (M5R).** `StoryScene` (`scenes/story/story_scene.tscn`) instantiates the shared
`IsoWorld` like `GreenZoneScene`, owns a `StoryRunner` and the story HUD (dialogue box with
typewriter, portraits and speaker names, choice list with locked/costly options, cards, notices,
objective line, carry line, touch joystick and action button, MENU) and ticks at the fixed 60 Hz
logic rate. `StoryRunner` runs the scene Resource's ordered `StoryStep`s: each step has
`begin(ctx, st)`, `tick(ctx, st, dt) -> bool` (true when done) and `end(ctx, st)`, where `st` is the
per-run state the runner owns (step Resources are never mutated), and may insert follow-up steps (a
choice's branch); the runner emits local signals (`step_started`, `finished`) and the scene emits
`completed`, `failed` and `quit_requested` to Main, never a global bus. The full API is in
[`STORY_ENGINE_API.md`](STORY_ENGINE_API.md). Action inputs in walks are routed by a small
`StoryActionRouter` (the action button's mode, Space the walk's own action, B a plain bark, the
mode switcher; SWORD/SHIELD are M6 extension points) and `InputService` recognises the right-hand
gestures with pointer ownership (correction report 31). Display titles come from the story
Resources, generated over a frozen compatibility catalog of stable IDs (RD-29).
`StoryContext` is the only API steps use: the stage (map, markers, actors, props), the player, the
HUD, the campaign working copy and effects, audio, and the input service. Step families: stage,
actor, scripted move, narration, dialogue, choice, objective (reach/collect/follow with pickups,
no-run, an action button and an optional scene rule), effect, card, wait, cue (sound/shake/flash/
visor/floating line), prop, carry and completion. Scene rules (the 1.1 visor, the 1.2 gate, the 1.3
cut-off) are small classes parameterised by their step's Resource fields. Actors (`StoryActor`, a
`CharacterBody2D` like `PlayableDog`) move on the shared `WorldMapModel` grid solver with explicit
idle/goto/follow behaviours; objective markers are `Area2D` rings whose completion test is the
authoritative grid distance.

Save, restart and replay boundaries (`STORY_REWRITE_SPEC.md` §7, decision RD-05): a scene is one
transaction — effects apply to a working copy at once and the campaign is saved once, atomically,
at the scene's completion; restart and force-close discard the uncommitted copy; replays run on
AppState's deep copy and save nothing. Level 1 is in `godot/data/story/`; Levels 2–8 are rewritten
and implemented the same way in later milestones.

`StoryWalkController` supports the currently used reach/collect/action/survive objectives, pickups, marvels/shards/coins, carry state, sight cones and line of sight, bushes, contact/restart, checkpoints, no-run, scramble, spreading fire, fights, and helper-authored follow/lull sequences. Generic legacy `pace` and `thirst` hooks are not required unless a current scene uses them; current 7.3 and 8.3 bespoke pace logic must be ported directly.

Campaign rules to preserve:

- Commozione, Supervillain, Grace, Standing and their exact clamps/tuning;
- Commozione fading and costly actions;
- book arrays, abilities, flags, play time, save time, notice;
- sequential progression and scene replay on a copy;
- rag cross in reality, armour appearance from dream 2.1, arms ability at 2.3;
- Knight/Witness decision in 7.8, internal `alpha` compatibility key;
- Grace/Standing ending notes;
- no physical dream objects returning to reality.

## 14. Combat, companions, NPCs, and minigames

`CombatRules` is pure; `CombatController` owns scene timing and `Area2D` hit detection. Preserve bark push/unparryable behavior, sword cooldown/opening, shield front arc, foe wind-up ring, stagger, parry, health, routing, knockdown/retry, Zara Grace loss, and 7.2 survival timing. Fights remain non-lethal and occur in 2.3, 5.3, and 7.2.

Companions use `ActorBody` follow/goto states and authored paths. Preserve Pierre/Saint-Pol/Flanders behavior in 7.3 and Sbrimbrulòn/Confusione behavior in 8.3. Do not replace authored wait/fall-in logic with a generic nav agent.

Each current minigame is a separate packed scene with a common contract:

```gdscript
signal finished(result: MiniGameResult)
func start(definition: MiniGameDefinition, context: StoryContext) -> void
```

Required scenes are RhythmGame for the current 4.1 parade and 4.3 rowing uses, Boat, the current 5.2 Ladders configuration, Tug, Letter, and Rumour ordering. Result/effect application lives in the common host. Its optional `retry_on_loss` capability is dormant—no canonical sublevel enables it; a player retries through whole-scene restart. The unused `weeping()` RhythmGame factory and hard-assault Ladders branch are also dormant legacy code, while calm rescue and catapult are retired; none is recreated. Current 3.3 is a lull walk with two WEEP actions, current 5.2 stone hits slide the player down but continue until victory, and current 7.2 is an 18-second combat stand.

## 15. Audio and visual effects

Use audio buses `Master`, `Music`, `SFX`, and optional `UI`. `AudioService` keeps per-track playback positions when switching between reading screens and gameplay, applies current per-file gain trims, ducks for pause/attack/end, and suspends on application background. Recorded effects start after the source's leading silence, read from the generated, exported `data/audio/sfx_leading_silence.tres` (`SfxLeadingSilence`, preloaded); the extractor's JSON is provenance only and is excluded from exports with every other build-input JSON. Runtime diagnostics (effect log, TileData log) exist only in debug builds and are bounded.

Reuse the five recorded music files and twelve recorded effects currently imported by `src/fx/audioFiles.ts` byte-for-byte. Render the synthesized medieval loop and fourteen synthesized cues from `src/core/synth.ts`/`src/fx/sounds.ts` to deterministic mono 22,050 Hz, signed 16-bit little-endian PCM WAV. Quantization is `round(clamp(sample, -1, 1) * 32767)`; record recipe/input hashes, sample counts and output hashes. Do not introduce an OGG encoder or reimplement a WebAudio synthesizer at runtime.

Port title/transition/text glitches as small `canvas_item` shaders. Particle scenes cover treat geometry, dust, leaves, water, sparkles, bark arcs, and popups. Keep effects event-driven and disposable; rules must not depend on particle completion.

## 16. Assets and import policy

Godot cannot import outside `res://`, so required files are copied—not moved—into `/godot/assets`. `data/source_asset_manifest.json` records original repository path, SHA-256, dimensions, intended use, license/provenance note, and import settings. The sync tool fails on a changed hash until the change is reviewed.

Audited availability, not ZIP-name assumptions:

| Asset family | Repository reality |
|---|---|
| Playable dogs | Twelve integrated runtime PNGs: normal/armoured main+tired sheets for Zampanò, Sbrimbrulòn and Bagnaskiz. Main sheets are 320×3520, tired sheets 80×320; cross Zampanò aliases knight art. |
| Pixel cast | 23 integrated 160×1600 actor sheets plus `professorFace.png` (24×24). Several legacy roles, beasts, neighbourhood dogs and the Green Zone cat still use procedural source generators. |
| Props/items | Mostly procedural in the source; they must be frozen by the converter rather than assumed to exist in a delivery ZIP. |
| Environments | Fifteen integrated Color Ink PNG banks and their manifest. Nineteen authored floor compositions exist, including obsolete `1:arcade`; four current map keys (`lawn`, `darkwood`, `interior`, `desert`) have no authored composition and use theme/fallback art. |
| Audio | Five integrated recorded music files, twelve integrated recorded effects, one synthesized medieval loop and fourteen synthesized cues. |
| Title | Current runtime uses the 99-frame lossless WebP; older GIF/still variants remain source/reference material. |
| Delivery ZIPs | Hash comparison confirmed the current integrated playable, cast and environment art comes from the relevant deliveries, but ZIPs also contain source grids, prompts, previews, patches and superseded/quantized alternatives. They are not export inputs. |

Include only runtime-authoritative assets:

- current playable and integrated cast sheets from `public/sprites/`;
- required environment banks and manifest from `public/environment-ink/`;
- current compressed music/effects, not `assets/music/originals/`;
- current title WebP converted to frames/durations;
- logo/launcher assets, generated Press Start 2P bitmap font and OFL; the WOFF2 remains a hashed, non-exported converter input in the untouched source tree;
- frozen outputs for currently procedural characters, props, items, and missing frames.

Do **not** wholesale-import root ZIPs, `art-archive/`, main-character ID reference images, source grids/prompts/previews, obsolete title GIFs, `docs/screens/`, or unreferenced originals. ZIP contents are evidence/delivery sources, not a runtime manifest.

Source-derived assets are generated by development-only Node/Playwright tools under `/godot/tools`, pinned to Node 24.15.0 and the root `package-lock.json` (Playwright 1.63.0 and Vite 8.3.8 in the audited install). The Chromium build is the one the locked `playwright-core` pins in its `browsers.json` (153.0.8010.12, revision 1243 for 1.63.0), launched as the full `chromium` channel that `npx playwright install chromium` installs on every platform (a host may substitute the default headless shell); the launched browser must report exactly that version. Generated files record only these pinned values; the host browser's own report appears only in the console output. The extractor refuses any other Node version (exit 4), a Playwright/playwright-core that differs from the lockfile (exit 5), a non-pinned Chromium (exit 6), and any source/lockfile change against the audited commit (exit 3). It reads every copied or parsed source file from the audited commit's Git blob (never the working tree), and `/godot/.gitattributes` fixes LF for generated text and `binary` for verbatim copies, so a Windows `core.autocrlf=true` checkout yields the same bytes. `--check` regenerates everything in memory and fails on any byte difference; `build_resources.gd -- --phase all --check` does the same for the Godot-built resources. The tool harness loads the audited TypeScript/browser algorithms rather than translating them into GDScript: Chromium `ImageDecoder`/source title code for the portrait, the current placeholder builders for procedural art, `pixelFont.ts` for the bitmap font, and the pure synth recipes for PCM. It writes to a temporary directory, verifies hashes, then replaces generated outputs only when bytes differ. A second run must produce no diff and no network access.

The asset importer must:

1. verify source hashes and dimensions;
2. create AtlasTextures/SpriteFrames/TileSet resources editor-side;
3. disable filtering/mipmaps and use lossless import for pixel art;
4. preserve frame counts, direction rows, anchors, timing, and loop flags;
5. decode the 99-frame current WebP, probe frame 0 at 256 px, alpha-cut at 110, derive one shared crop using `TITLE.DOG_CROP_MARGIN`, resize every frame through the source's 2× high-quality intermediate, alpha-cut again, and preserve the exact delay list;
6. freeze procedural fallbacks into committed images rather than mask missing files at runtime;
7. pack the title at canonical maximum logical width `ceil(270 * TITLE.DOG_WIDTH) = 125` into atlas pages no larger than 2048×2048 and keep its total uncompressed frame memory below 12 MB; present it with a title-only linear sampler plus alpha-cut shader when scaling to the current logical width, while all pixel art remains nearest-filtered;
8. fail validation for a missing required frame or texture key.

Only the font has explicit repository licensing evidence. Character, environment, music, sound, and delivery ZIP rights are an external release gate; migration may proceed locally, but public/commercial distribution requires the owner to record provenance/permission.

## 17. Persistence and legacy migration

### 17.1 Godot save container

Use `user://save_v3.json` with these exact defaults and shapes (a JSON `null` is intentional):

```json
{
  "format_version": 3,
  "written_at_unix_ms": 0,
  "settings": {
    "muted": false,
    "volume": 0.7,
    "textSpeed": "normal",
    "lives": 2,
    "controls": {
      "swipeUp": "sword",
      "swipeDown": "shield",
      "doubleTap": "bark",
      "run": "hold",
      "switcher": true,
      "hand": "right"
    }
  },
  "records": {},
  "legacy_arcade_coins": { "present": false, "value": 0 },
  "campaign": {
    "version": 2,
    "completed": [],
    "meters": {
      "commozione": 20,
      "supervillain": 10,
      "grace": 70,
      "standing": 50
    },
    "flags": {},
    "book": {
      "marvels": [],
      "items": [],
      "values": [],
      "remembered": [],
      "shards": []
    },
    "abilities": [],
    "coins": 0,
    "playTime": 0,
    "savedAt": null,
    "notice": null
  },
  "legacy_import": {
    "status": "not_attempted",
    "source": "capacitor_webview",
    "attempt_count": 0,
    "attempted_at_unix_ms": null,
    "payload_sha256": null,
    "keys_present": [],
    "keys_imported": [],
    "keys_failed": [],
    "error_code": null
  }
}
```

`records` omits `level1` until a record exists; each record value has exact shape `{ "score": nonnegative integer, "stars": 0..5 in half-star steps, "time": nonnegative seconds }`. `legacy_arcade_coins` losslessly preserves whether the unused old key existed and its normalized nonnegative integer, but current gameplay never mutates or spends it. Active Green Zone coins enter `campaign.coins` only through the source-equivalent handoff described below.

Normalize/clamp every typed field and deduplicate arrays by first occurrence. Completed IDs must be current catalog IDs; abilities are `cross`, `knight`, or `sermon`; control values use the enums in `src/core/settings.ts`. `CampaignFlagSchema` is explicit:

- enums: `oath` = `undecided|enforced|silent`; `lamp` = `declared|kept`; `drawing` = `ships|city|pedestal|bowl`; `tellingTier` = `high|mid|low`; `zaraOwe` = `pope|host|debt`; `corfu` = `stay|syria`; `letter` = `named|necessity`; `courtesy84` = `unanswered`;
- number: `shortfall` is finite/nonnegative (current authored value 36000);
- booleans: `pawOffered`, `longWay`, `vow`, `weptWell`, `zaraDeal`, `heardZara`, `clothRoute`, `dissent`, `comradeship`, `vanguard`, `visitedCity`, `sworn`, `followed`, `columnAgain`, `told`, `lawnHeld`, `ballReturned`;
- compatibility: current `santinaBall` is `performed`, but v1 migration preserves any scalar value for this kept flag, including the tested legacy `kept` value.

Invalid known values are omitted after the raw payload is backed up. Unknown v2 flag keys with scalar string/finite-number/boolean values are retained as pass-through data because the source copies the complete flag object; arrays/objects are rejected. Unknown future container versions are backed up and shown as a recoverable error, not silently overwritten. This holds for each of `save_v3.json`, `save_v3.tmp` and `save_v3.bak`: a future payload in any of them is copied byte-for-byte (`save_v3.future.json`, `save_v3.tmp.future.json`, `save_v3.bak.future.json`), no save file is touched again and every write is refused for the session; a future main loads defaults, otherwise the valid current-format file is shown read-only. Only an invalid main is preserved as `save_v3.corrupt.json`; a valid main that is merely older than a recovered temp becomes the backup.

Write to `save_v3.tmp`, flush/close, parse and validate the temporary file, rotate the old valid save to `save_v3.bak`, then rename. `written_at_unix_ms` changes on any container write, but nested `campaign.savedAt` changes only at source-equivalent campaign saves so an option change cannot alter Couch's last-save date.

Persistence points are locked: settings save on confirmed change; story effects and scene completion save as in the source; the Green Zone record saves when the level completes; campaign time/coins and 1.0 completion save only when the player chooses CONTINUE on the result screen. Retry, result-screen quit, and game over do not hand them off, and the legacy standalone coin field is not gameplay state. On background, atomically flush already-dirty persistent domains as a native hardening improvement, but do not serialize transient mid-Green-Zone or mid-story progress and do not advance `campaign.savedAt` unless a source-defined campaign save already occurred.

Legacy import status transitions are deterministic: `not_attempted` → `imported`, `imported_partial`, `not_found`, `retryable_error`, or `blocked`. Each key is parsed independently after the raw payload is saved; valid keys import even if another fails. `retryable_error` retries on the next launch, `blocked` requires user/developer action, `not_found` is terminal for that install unless diagnostics explicitly force a retry, and imported states are idempotent.

### 17.2 Capacitor keys

Legacy prefix: `supervillained:`. Import these independently:

- `settings`;
- `records`;
- `coins` (standalone arcade total);
- `story` (campaign v1 or v2);
- `story-v1-backup`.

Run the existing v1-to-v2 campaign transformation before conversion to format 3. Store the untouched exported payload at `user://legacy/capacitor_local_storage.json` with SHA-256 and import timestamp.

### 17.3 Android upgrade requirements and limitation

Automatic recovery is possible only during a true in-place upgrade:

- keep application ID exactly `com.zampano.supervillained`;
- use a version code greater than the actually installed artifact (the audited repository value is `1`);
- sign with the exact certificate used by the installed Capacitor APK;
- do not uninstall, clear storage, or install a differently named development package.

The repository's current release task signs with the machine debug key. A different debug keystore or future production key cannot update that install. The exact installed signing certificate must be recovered and recorded before the migration release.

Same ID/signature preserves the sandbox but does **not** make WebView localStorage equal to Godot `user://`. The approved first experiment is a minimal Android migration plugin that opens an offscreen WebView in the preserved default WebView data directory, uses the verified old Capacitor origin, reads only the five prefixed keys, returns JSON to GDScript, and never mutates the old store. This must be proven against a signed old APK on at least two WebView versions early in the project. Do not parse Chromium LevelDB/SQLite files directly.

If the plugin cannot reliably recover the old origin, guaranteed migration requires a staged final Capacitor release that exports the keys to Android `filesDir` before the Godot upgrade. That requires separate authorization because it changes the old app, and both that staging APK and the Godot APK still need the same package/signing identity as the installed lineage. Android Auto Backup is not an approved substitute. Without either path, automatic migration is impossible and the release must disclose that saves cannot be carried forward. Browser localStorage is a separate sandbox and cannot be imported automatically by the native app.

## 18. Android target

Preserve the current platform contract:

- package `com.zampano.supervillained`;
- minimum SDK 24; compile/target SDK 36 where supported by the 4.7.2 export templates;
- portrait only, immersive bars, safe area, keep screen on;
- hardware Back toggles pause/returns within menus rather than killing a run;
- title QUIT closes the Android task; publisher link opens an external browser;
- pause and suspend audio/gameplay on background;
- fully offline gameplay with no CDN or runtime asset fetch;
- release-signed APK for direct upgrade testing and AAB for store delivery when signing is resolved.

Use a custom Gradle build only if the legacy migration plugin or exact platform flags require it. Keep all custom native code isolated and removable after the migration window. Do not request Internet permission for game operation; an explicit external publisher link can be handled by Android intent.

## 19. Source-to-target mapping

| Source | Godot target | Treatment |
|---|---|---|
| `src/config.ts` | typed balance Resources loaded by `GameConfig` | copy values; validate; no scattered constants |
| `core/game.ts` | persistent `Main` plus four autoloads | rewrite responsibilities |
| `core/loop.ts` | 60 Hz `_physics_process` | eliminate custom RAF/accumulator |
| `core/scene.ts` | SceneHost plus overlay stack | rewrite semantics |
| `core/input.ts` | InputMap, `InputService`, native touch Controls | rewrite; preserve buffering/gestures/context |
| `core/display.ts` | `PixelViewportController` | port algorithm exactly |
| `core/events.ts` | local Godot signals | replace; no global bus |
| `core/assets.ts` | editor import tools and Godot Resources | eliminate runtime packing |
| `core/audio.ts` | `AudioService`, buses, players | rewrite |
| `core/synth.ts` | editor-generated deterministic PCM WAV | eliminate runtime synthesis |
| `core/settings.ts` | `AppState` settings/records schema | rewrite with validation |
| `core/storage.ts` | `SaveService` under `user://` | replace localStorage |
| `core/native.ts` | Godot OS APIs/export config | eliminate Capacitor plugin except migration bridge |
| `core/rng.ts` | `DeterministicRng` | port algorithm/seed behavior exactly |
| `iso/projection.ts` | `IsoGrid` | direct conceptual port |
| `iso/depth.ts` | `IsoDepthSorter` | direct semantic port |
| `iso/camera.ts` | `CameraRig` + `Camera2D` | port behavior, use native camera node |
| `world/tiles.ts` | tile/prop catalog Resources | convert data |
| `world/level.ts` | `AsciiMapLoader`, `LevelDefinition` | port implemented ASCII branch; drop throwing Tiled stub |
| `world/map.ts` | pure `WorldMapModel` | port logic; optional compatibility collision solver |
| `world/mapRenderer.ts` | TileMapLayers and overlays | replace Pixi chunks |
| `world/world.ts` | `IsoWorld` in `world_2d.tscn` | rewrite composition |
| `levels/level1.ts` | Green Zone map builder/data Resource | port deterministically |
| `entities/entity.ts` | `IsoRenderable` plus Node2D/body bases | replace |
| `entities/zampano.ts` | generic `PlayableDog` | port state/movement faithfully |
| `entities/actor.ts` | `ActorBody` + explicit behavior controller | port; no behavior-tree framework |
| `entities/critters.ts` | Cat/Ball/Bagnaskiz packed scenes | port behavior |
| `entities/items.ts` | Treat/Poop/coin/pickup scenes | port behavior |
| `entities/prop.ts` | `IsoProp` StaticBody/Node2D scenes | port metadata/occlusion |
| `systems/needs.ts` | `NeedsSystem` | direct pure-rule port |
| `systems/rules.ts` | `GreenZoneRules` | direct pure-rule port |
| `systems/scoring.ts` | `ScoringRules` | direct pure-rule port |
| `systems/threats.ts`, `threatLogic.ts` | threat/spawn directors | port pure logic and orchestration |
| `systems/combat.ts` | `CombatRules` | direct pure-rule port |
| `systems/lives.ts` | `LivesRules` | direct pure-rule port |
| `campaign/state.ts` | `CampaignState` + save migration | direct semantic port, stronger validation |
| `campaign/summary.ts`, `home.ts`, `titles.ts` | pure utilities/data | port |
| `campaign/chapters/*.ts` | typed GDScript chapter factories | rewrite scene by scene |
| `story/step.ts`, `steps.ts` | `StoryStep` classes and `StoryRunner` | rewrite with signals/await |
| `story/storyScene.ts` | `StoryScene.tscn` | rewrite orchestration |
| `story/storyFlow.ts`, `scenes/flow.ts` | Main scene director plus campaign flow | rewrite |
| `story/walk.ts` | `StoryWalkController` | port current capabilities |
| `story/combat.ts` | `CombatController` | port presentation/timing |
| `story/minigames/*` | dedicated minigame scenes | rewrite only current games |
| `story/maps.ts` | ASCII map resources plus palettes/markers | convert; preserve topology |
| `story/carry.ts` | carry attachment/presenter | port |
| `story/names.ts` | RichText markup helper | port lists and colors |
| `story/dialogueGestures.ts` | actor action signal from dialogue step | port |
| `story/autopilot.ts` | test driver, not a production framework | reuse concept |
| `scenes/gameScene.ts` | `GreenZoneScene.tscn` | rewrite orchestration |
| `scenes/overlays.ts`, `story/screens.ts` | native Control packed scenes | rewrite UI |
| `scenes/couchScene.ts`, `glossaryScene.ts` | dedicated Control scenes | rewrite |
| `scenes/supervillainedScene.ts` | transition overlay | rewrite |
| `ui/*` | Theme/Control scenes | rewrite; keep visual contract |
| `fx/*` | shaders, particles, audio cues, tweens | rewrite using native systems |
| `src/assets/manifest.ts`, `src/assets/environment.ts` | source manifest + generated Resources | reuse contracts, eliminate runtime fallback |
| root `android/`/Capacitor | Godot Android export under `/godot` | preserve old project; replace only at release artifact level |
| Vitest/Playwright scripts | headless GDScript runner, integration driver, capture suite | port intent, not framework |

## 20. Performance and determinism budgets

- physics tick: 60 Hz; release rendering uses `application/run/max_fps=60` and VSync enabled, while interpolation tests temporarily exercise 30/60/90/120 render rates;
- Android frame pacing uses `display/window/frame_pacing/android/enable_frame_pacing=true` and `swappy_mode=0` (`pipeline_forced_on`) so Swappy tries to honor the 60 FPS cap instead of automatically downgrading it;
- deterministic rule tests use fixed seeds and fixed delta;
- nearest-neighbor pixel rendering; no per-frame texture creation;
- no runtime atlas generation or full-track audio decode for long MP3 music;
- TileMap runtime notifications occur only when pollution/fresh state changes; each layer-wide refresh reapplies the active/reset coordinate set defined in Section 7;
- depth sort only visible object candidates;
- object/minigame/FX nodes are pooled only after profiling shows allocation spikes—do not pre-emptively build a general pool framework.

Provisional Android gate on the designated mid-range device: average at least 58 presented FPS; CPU/GPU work-time p95 at or below 16.7 ms and p99 at or below 25 ms; fewer than 2% missed 60 Hz presentation slots after warmup; no stall above 100 ms during a ten-minute worst-case Green Zone run; and peak proportional-set memory below 256 MB. On 90/120 Hz devices record the selected display mode, presented-frame interval histogram and Android/SurfaceFlinger jank evidence, and prove Swappy did not downgrade the target to 45/30 FPS. Record device model, OS, refresh rate, thermal state, and build type. These thresholds may be tightened, not silently relaxed, after the real test device is named.

## 21. Assumptions, open decisions, and exclusions

### Locked assumptions

- English text and canonical story copy remain unchanged.
- Zampanò is the normal campaign protagonist; alternate dogs remain a developer/debug capability unless separately approved.
- The source's `SKIP SCENE` option is parity behavior and remains available.
- Current straight-line/local-steering NPC behavior is intentional; no navigation framework is required.
- Godot targets Android for this migration. The existing Capacitor iOS application remains untouched and is not part of the Godot delivery.

### Decisions requiring owner evidence

| Decision/gate | Needed evidence | Deadline |
|---|---|---|
| Android signing identity | certificate fingerprint and keystore capable of updating the installed APK | before Android migration spike |
| Old WebView origin/storage behavior | installed source APK and two representative Android/WebView versions | Milestone 1 |
| Release rights | provenance/license for delivered art, music, sounds, logo | before public release candidate |
| Performance device | named mid-range Android model and OS | before full Green Zone performance gate |
| Legacy coin product policy | default is locked to current executable behavior: preserve old standalone key inertly and hand Green Zone coins/time to campaign only on CONTINUE; any revival of the older game-over claim is a later design change | after parity, unless owner explicitly overrides |
| Alternate-character exposure | debug override only or player-facing selector | before UI freeze; default is debug only |

### Explicit exclusions

- shop, accounts, analytics, multiplayer;
- Tiled importer;
- new alternate-character story branches;
- retired anthology scenes/minigames;
- iOS Godot export;
- cloud save;
- editing or deleting the PixiJS implementation.

## 22. Review rules for Claude Code

- Work only on the dedicated implementation branch and under `/godot`, except an explicitly authorized migration-bridge release.
- Submit one milestone at a time with source mapping, test evidence, screenshots/captures, and Android evidence where required.
- Never replace a canonical map/script with a visually similar approximation without documenting the behavioral delta.
- Never accept a missing asset because a fallback made it invisible; the Godot validator must fail.
- Keep pure rules free of Nodes where practical, and test them headlessly.
- Do not change a balance value to compensate for a porting bug.
- Treat any failure of save import, scene reachability, both endings, or Android upgrade as a release blocker.

## 23. Godot 4.7 API anchors

Implementation and review should verify behavior against the installed 4.7.2 API, especially these official references:

- [CharacterBody2D](https://docs.godotengine.org/en/4.7/classes/class_characterbody2d.html) for floating motion and slide properties.
- [Physics interpolation](https://docs.godotengine.org/en/4.7/tutorials/physics/interpolation/using_physics_interpolation.html) for fixed-tick presentation and reset rules.
- [SubViewportContainer](https://docs.godotengine.org/en/4.7/classes/class_subviewportcontainer.html) for stretch/shrink and input propagation.
- [TileSet](https://docs.godotengine.org/en/4.7/classes/class_tileset.html) and [TileMapLayer](https://docs.godotengine.org/en/4.7/classes/class_tilemaplayer.html) for isometric layout and runtime tile data.
- [Fonts](https://docs.godotengine.org/en/4.7/tutorials/ui/gui_using_fonts.html) for bitmap font resources and filtering.
- [`user://` data paths](https://docs.godotengine.org/en/4.7/tutorials/io/data_paths.html) for writable native persistence.
- [Android export](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html) for SDK, package and signing requirements.
- [ProjectSettings](https://docs.godotengine.org/en/4.7/classes/class_projectsettings.html) for Android Swappy frame-pacing modes and the 60 FPS cap.
