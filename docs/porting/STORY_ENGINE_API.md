# SUPERVILLAINED VG1 — Story engine API (M5R)

The native story engine that plays the rewritten story Resources. Content rules, schema and status
vocabulary: [`STORY_REWRITE_SPEC.md`](STORY_REWRITE_SPEC.md); decisions: [`STORY_REWRITE_DECISIONS.md`](STORY_REWRITE_DECISIONS.md);
architecture context: [`ARCHITECTURE.md`](ARCHITECTURE.md) §13. Paths below are relative to `godot/`.

Engine rules (checked by tests):

- **Text is data.** Every line a player reads is in a `.tres` Resource (`data/story/`) or, for
  interface chrome (pause labels, the lock reason, error titles), in `data/shell/shell_text.tres`.
  Step, rule, scene and HUD scripts hold execution logic only; `StoryValidator.scan_scripts()`
  fails on a sentence or an uppercase multi-word literal in `story/`, `scenes/story/` or `ui/story/`
  (CONTENT-004).
- **No dialogue framework and no global event bus.** Steps talk to the scene only through
  `StoryContext`; the runner and the scene emit local signals.
- **Deterministic.** One logic tick per `_physics_process` at the fixed 60 Hz rate; tests set
  `manual_ticks` and call `tick(dt)` themselves.
- **A scene is one save transaction** (RD-05): effects apply to a working copy at once; Main
  commits it once at the completion boundary.

## 1. Flow from Main

```text
TITLE / CONTINUE / level list
  └─ Main._play_scene(id)
       ├─ 1.0 → Green Zone walk (M3/M4)
       ├─ StoryLibrary.has_scene(id) → Main.show_story_card(id)   LEVEL n · "1.3 THE TOLL AT THE BOWL" · summary
       │      tap → Main.start_story(id) → StoryScene.setup(data, AppState.story_entry_state(), AppState.persists())
       │             completed(result) → Main._on_story_completed(result)
       │                 replay  → AppState.end_replay(), back to the level's scene list (nothing saved)
       │                 else    → AppState.commit_scene(id, result.state, result.play_time)
       │                              failed save → save-error card: TRY AGAIN (re-commits the same result) or TITLE
       │                                            (abandons the scene); no BACK, Android Back keeps the card
       │                              saved       → next scene's card, or Main._level_end(id)
       │             quit_requested → Main.quit_to_title() (the attempt is discarded)
       │             failed(message) → title with the "story error" card (explicit, never silent)
       └─ no Resources → Main.show_boundary(id)   "not in this build" (2.1 after Level 1)

Main._level_end(id) → Supervillained snap → Main._professor_aside(n) → the next level's first scene
```

`Main.start_story(id)` first checks the scene's entry conditions (`StorySceneData.entry_failure`):
a failure shows the story error card and nothing starts (RD-30).

`StoryCatalog.playable_in_build(id)` is true for the Green Zone and for every ID with a scene
Resource (`StoryCatalog.scene_path(id)` = `res://data/story/scenes/<id with "." → "_">.tres`).
`StoryLibrary` loads scenes and chapters (`scene(id)`, `chapter(n)`, `chapters()`, `has_scene(id)`).
The runtime catalog is generated (RD-29): `StoryCatalog.overlay(compat, StoryCatalog.rewrite_titles())`
lays the Resources' titles over the frozen compatibility catalog; `tools/build_resources.gd --check`
fails when the shipped catalog is not that output.

`AppState.commit_scene(id, working, play_time) -> {saved, replay, applied, error}`: in a replay it
returns `saved: false, replay: true` and writes nothing; for a scene already completed it returns
`saved: true, applied: false` (never committed twice); otherwise it adds the play time, marks the
scene complete and calls `SaveService.save_campaign(state, now)` once (atomic, M4 correction 28).

## 2. `StoryScene` (`scenes/story/story_scene.gd`, `.tscn`)

A `Node2D` that builds the shared `IsoWorld` (`world/world_2d.tscn`) for each stage, like
`GreenZoneScene`. Children: `StoryCanvas` (`StoryTouchControls`, `StoryHud`) and `OverlayCanvas`.

| Member | Meaning |
|---|---|
| `signal completed(result)` | the runner finished; `result` = `{id, state, play_time, persist, trace, metrics, restarts}` (`state` is the working copy, deep-copied) |
| `signal failed(message)` | content could not run (missing marker/actor/resource, a scripted move timing out) |
| `signal quit_requested` | QUIT TO TITLE from the story pause |
| `setup(data, entry_state, persist) -> StoryScene` | before it enters the tree; `entry_state` is deep-copied; `persist` false in a replay |
| `bind_main(main)` | lets the pause use Main's overlay stack (Android Back opens the story pause) |
| `tick(dt)` | one logic tick: MENU → `runner.tick` → player intent (joystick or scripted walk) → movement → actors → `world.end_step` → HUD |
| `build_stage(map_id, at, point, face) -> bool` | a fresh `IsoWorld` on a story map, Zampanò placed in his plain skin (reality, RD-12), the camera snapped; `stage_changes` counts it |
| `spawn_actor(handle, role, p, face)` / `despawn_actor(handle)` | `StoryActor`s by handle |
| `place_prop(handle, key, p, tint)` / `remove_prop(handle)` | `StoryProp`s (sprite-catalogue keys) |
| `add_marker(p, radius, color)` / `remove_marker(marker)` | `ObjectiveMarker` rings (removing a freed one is a no-op) |
| `set_controls(on)` / `set_carried(label, sprite)` | touch controls and the carried thing on his back |
| `open_pause()` / `resume()` / `restart()` / `quit()` | the story pause: RESUME, RESTART SCENE, QUIT TO TITLE (no SKIP SCENE, RD-23) |
| `play_time`, `restarts`, `ticks`, `stage_changes`, `finished`, `paused` | read by Main and the tests |

`restart()` stops the running step, then starts again from `entry_state` (a fresh `StoryContext`
and working copy): nothing from the abandoned attempt is kept except the session's play time.
Before the first step runs, the entry conditions are checked against `entry_state`; a failure stops
the scene with an explicit error (emitted deferred, so the owner's handler receives it).
Every scene's first step is a `StageStep` (RD-26); the scene builds no stage of its own.

## 3. `StoryRunner` (`story/story_runner.gd`)

| Member | Meaning |
|---|---|
| `start(steps)` | queue a scene's top-level steps |
| `tick(ctx, dt)` | `begin(ctx, st)` the next step, `tick(ctx, st, dt)` it until it returns true, then `end(ctx, st)`; steps that finish at once chain in the same tick with `dt = 0` |
| `insert(steps)` | queue steps right after the current one (a choice's branch, a repeated `once_each` choice) |
| `stop(ctx)` | `end` the current step and drop the queue (restart, quit) |
| `current`, `st`, `trace` | the running step, its per-run state, every step id begun (tests, reports) |
| `signal step_started(step)`, `signal finished` | local signals |

`st` is owned by the runner and replaced for each step: step Resources are shared data and are
never mutated while they run.

## 4. `StoryContext` (`story/story_context.gd`)

The only API a step or rule uses.

| Member | Meaning |
|---|---|
| `scene`, `data`, `cast`, `runner`, `hud`, `world`, `player` | the scene, its Resource, the cast, the runner, the HUD, the current stage |
| `state` | the campaign working copy (the replay's copy in a replay) |
| `persist` | false in a replay |
| `apply(effects) -> Array` | `CampaignRules.apply_effects` on `state`, one notice per change (green/red) |
| `notice(text, color, delay)`, `say_float(text, at, color)`, `flash()`, `shake(n)`, `play_sound(key)` | presentation |
| `marker(id) -> Vector2`, `place(at, point)` | a marker's grid centre ("S" = start) — a missing marker **fails** the scene |
| `actor(handle)`, `has_actor(handle)` | a missing actor **fails** the scene |
| `fail(message)` | stops the scene with an explicit error (Main shows it) |
| `set_controls(on)`, `controls`, `no_run`, `move_target` | who drives the player |
| `actions` | the walk's `StoryActionRouter` (§6a) |
| `carry(label, sprite)`, `carrying` | the carried thing |
| `visor` | 0..1, the 1.1 bucket bars |
| `ui_text(key)` | interface chrome from `ShellText` |
| `portrait_of(speaker)`, `speaking_gesture(speaker)` | the dialogue portrait; a human speaker's on-stage actor gestures |
| `tapped(st, guard) -> bool` | a confirm/action key or a tap after `guard` seconds (a held key never skips) |
| `choices_taken`, `metrics` | choices made, notices, Jack's echoes/bumps (completion reports) |

## 5. Steps (`story/steps/`)

Every step extends `StoryStep` (a `Resource` with a stable `id`). Validation hooks (used by
`StoryValidator`, spec §6): `kind()`, `texts()`, `speakers()`, `marker_refs()`, `effect_sets()`,
`branches()`, `sounds()`, `sprites()`, `roles()`, `actor_defs()`, `actor_refs()`, `stage_map()`,
`check(errors)`. Execution hooks: `begin(ctx, st)`, `tick(ctx, st, dt) -> bool`, `end(ctx, st)`.

| Step | Fields | Runs |
|---|---|---|
| `StageStep` | `map`, `player_at`/`player_point`, `player_face`, `actors` (`StoryActorSpec`: name, role, at/point, face) | builds the stage and places the cast; instant |
| `ActorStep` | `actor`, `action` (spawn, despawn, goto, follow, idle, face, gesture, place), `role`, `at`/`point`, `near_player`, `face`, `face_player`, `speed`, `run`, `wait_arrival`, `arrival_timeout` | instant, or until arrival (distance ≤ `StoryActor.ARRIVE_DISTANCE`) with `wait_arrival`; past `arrival_timeout` the scene **fails** explicitly (RD-31) |
| `MoveStep` | `to_marker`/`to_point`, `speed`, `face` | walks Zampanò there (controls off); fails explicitly after 12 s |
| `NarrationStep` | `text` | a narrator box; typewriter, then a confirm/tap (guard `LINE_GUARD`) |
| `DialogueStep` | `speaker`, `text`, `remembered`, `effects` | a speaker's box with name colour and portrait; `remembered` adds the line to the book; effects apply on begin |
| `ChoiceStep` | `speaker`, `prompt`, `prompt_again`, `options` (`StoryChoiceOption`), `once_each` | the prompt, then the option rows (keys, confirm or taps); see below |
| `ObjectiveStep` | `objective`, `objective_kind` (reach, collect, follow), goal (`goal_marker`/`goal_point`, `goal_label`, `goal_radius`), `pickups` (`StoryPickup`), `no_run`, `action_label`/`action_text`/`action_sound`, `checkpoints`, follow (`leader`, `path`, `leader_speed`, `leader_lines`, `leader_leg_timeout`), `rule`/`rule_params`/`rule_lines`, `hint`/`hint_after` | the player walks with the joystick until the goal is met; see §6 and §6a |
| `EffectStep` | `effects` | applies them; instant |
| `CardStep` | `big`, `small`, `color`, `seconds` (0 = tap), `dim`, `sound`, `flash` | a centred card (guard `CARD_GUARD`) |
| `WaitStep` | `seconds` | a pause |
| `CueStep` | `sound`, `shake`, `flash`, `visor`, `float_text` at `float_at`/`float_point` in `float_color` | instant |
| `PropStep` | `prop`, `sprite`, `action` (place, move, remove), `at`/`point`, `tint`, `float_text`, `float_color`, `sound` | instant |
| `CarryStep` | `label`, `sprite` ("" drops it) | instant |
| `CompleteStep` | — | checks the scene's `completion` requirements on the working copy (a missing flag or ability **fails** the scene), then the runner finishes |

**Choices.** Each option has `id`, `label`, `said` (Zampanò's line when picked, skipped with
`silent`), `cost` (Commozione), `locked_text`, `effects`, `then_steps`. A costly option shows
`label` plus `ui_text("story_cost_suffix") % cost`; without enough Commozione it is locked with
`ui_text("story_too_unmoved") % cost`; an option with `locked_text` is locked with that line. If
every option is locked, all of them open (never a dead end) and a cost is spent only when
Commozione covers it. On a pick: the cost is spent, the effects apply, the `said` line and the
`then_steps` are inserted; with `once_each` the choice is asked again (`prompt_again`) until every
option has been taken. Choice rows are laid out by the HUD (`choice_rects`) and accept taps.

## 6. Objectives and scene rules

`ObjectiveStep` turns the controls on, shows its `objective` line and ring markers, and checks each
tick: pickups within `GameConfig.Story.PICKUP_RADIUS` (each shows its `text`, plays its `sound` and
applies its `effects`; shards and spots), then the goal within `goal_radius` (default
`GOAL_RADIUS`). `follow` moves the `leader` along `path`, waits while the player lags by more than
`LEAD_WAIT_DISTANCE`, and says `leader_lines[i]` at each stop; a leg longer than
`leader_leg_timeout` of walking **fails** the scene (RD-31). The walk's own action (`action_label`:
SNIFF, or a scene's own BARK) shows `action_text`, plays `action_sound` and calls the rule's
`on_action`; a plain bark shows the ShellText bark line and calls the rule's `on_bark` (§6a).

### 6a. Action routing and gestures (`story/story_action_router.gd`, `InputService`)

`StoryActionRouter` (one per context; the objective configures it) holds the walk's modes —
`["scene", "bark"]` when the walk has its own action, else `["bark"]`; `"sword"` and `"shield"` are
extension points for M6's combat, never offered in M5R — and the selected mode (the first). Each
tick `poll()` reads, in the source's order:

| Input | Physical | Does |
|---|---|---|
| `switch` | Q, Tab, the switcher button, a gesture bound to SWITCH | the next mode (a "J: …" notice when no touch is in use) |
| `action` | J, X, the round ACTION button, a gesture bound to ACTION BUTTON | the selected mode |
| `pee` | Space | the walk's own action, whatever the mode |
| `bark` | B, a gesture bound to BARK (the default double tap) | a plain bark, which the bucket and Jack hear (RD-28) |
| `strike` / `guard` | U / I, the default swipes up / down | SWORD / SHIELD when offered (M6); nothing in M5R |

`InputService` recognises the right-hand gestures while a walk enables them (`gestures_enabled`,
`gesture_zone` = the side opposite the joystick): a double tap (second press within
`DOUBLE_TAP_TIME` and `DOUBLE_TAP_DIST`, fired on press) and vertical swipes (`classify_swipe`),
each queuing the action its CONTROLS binding names (`GESTURE_ACTIONS`; RUN ON/OFF latches RUN). A
pointer is owned by what it first touched: a button or the joystick never becomes a gesture. A plain
tap in the zone is still a tap. The story touch controls remove their buttons and turn the gestures
off when the scene leaves.

A **rule** (`story/rules/`, `ObjectiveRule`: `begin`, `tick -> bool`, `on_action`, `on_bark`, `end`,
plus the static `keep_out(ctx, gap)`) adds real-time behaviour; its numbers are in `rule_params` and every
line it shows is in `rule_lines`:

| Rule | Scene | Params | Lines |
|---|---|---|---|
| `visor` (`VisorRule`) | 1.1 | — (timings in `GameConfig.Story.VISOR_*`) | — (the HUD's bars) |
| `jack_gate` (`JackGateRule`) | 1.2 | `blocker`, `gap` (Rect2), `range`, `heads_at`, `heads`, `echo_open`, `creak_point`, `hint_bumps`, `recover_bumps` | `echo`, `nope`, `hint`, `creak` |
| `cut_off` (`CutOffRule`) | 1.3 | `blocker`, `gap`, `block_point`, `lane_y`, `joke_every`, `joke_y` | `cut`, `notice`, `jokes` |

A new rule is a new `ObjectiveRule` subclass registered in `ObjectiveStep.RULES`/`RULE_SCRIPTS`,
with its parameters validated in `ObjectiveStep.check`.

## 7. Actors, props, markers, HUD

- `StoryActor` (`scenes/story/story_actor.gd`, `CharacterBody2D`): `setup(handle, role, catalog)`,
  `set_grid_position`, `face`, `face_point`, `set_idle`, `go_to(p, speed, run)`, `follow(speed)`,
  `gesture()`, `play_action(clip, seconds)`; moves on the shared `WorldMapModel` circle solver. The
  Professor is drawn as his legs (RD-13).
- `StoryProp` (`Node2D`, a sprite-catalogue frame) and `ObjectiveMarker` (`Area2D` ring;
  `contains_grid(x, y, r)` is the authoritative grid test).
- `StoryHud` (`ui/story/story_hud.gd`): `show_line(name, color, portrait, text)` (typewriter at
  `cps`, set from the OPTIONS text speed, RD-17), `finish_typing`, `hide_line`, `set_choices(views)`,
  `read_choice() -> int`, `show_card`/`hide_card`, `notice`, `float_text`, `flash`, the objective and
  carry lines, the visor bars, and `shown_texts` (every text shown, for the tests). Period words are
  drawn amber in dialogue and names yellow on story cards (`StoryMarkup`, `data/story/markup.tres`).
- `StoryTouchControls`: the joystick, the action button (labelled by its mode), the mode switcher
  (two modes and the CONTROLS setting), RUN and MENU, and the gesture zone; the same `InputService`
  actions as keys.
- `StoryPauseOverlay` (`scenes/shell/`): RESUME, RESTART SCENE, QUIT TO TITLE (`ShellText`).

## 8. Content tools and tests

- `StoryValidator.for_project()` → `validate_chapter(ch)`, `validate_scene(scene)`,
  `check_effects(...)`, static `scan_scripts(dirs)` (spec §6; `tests/unit/test_story_schema.gd`).
- `tests/automation/story_driver.gd` (`StoryDriver.new(scene, policy, gate, scripted)`, `drive(dt)`):
  real-input mode plays through `InputService` (joystick injection, confirm/action edges, pointer
  taps on the choice rows, a breadth-first path over walkable tiles); scripted mode places Zampanò on
  each target (the smoke). `policy` maps a choice id to an option id; `gate` is "bark" or "push".
- `tests/integration/test_story_input.gd` (J, X, Space, B, Q/Tab, the touch ACTION button and switcher,
  the double tap with each binding, pointer ownership and swipe routing — real key events and screen
  touches through Main), `tests/integration/test_story_engine.gd` (DLG, WALK, NPC, missing content at
  run time, arrival, blocked actors, timeouts and restart) and
  `test_story_level1.gd` (STY, FLOW, CONTENT, ARCH-001b, DOG-008b, COLL-005b partial, a failed scene
  save, the story pause through Main).
- `tools/capture_suite.gd --mode story` writes the Level 1 captures (shots 40–51).

- `tools/story_review_export.tscn`: writes every player-visible line of a chapter in play order
  (the owner's narrative-review package).

## 8a. M6: combat, stealth, minigames, the book

- **Costume and capability** (RD-32): `StorySceneData.costume()` → `PlayableDog.set_costume()` at every
  stage; `StoryContext.armed()` gates SWORD/SHIELD (router modes; U/I and swipes route directly; without
  it `CombatController` shows a one-time no-arms notice).
- **Combat** (`story/combat/`): `CombatRules` (pure: `Foe`, `in_arc`, `damage_foe`, `stagger_foe`,
  `step_foe`, `is_open`, `shield_blocks`); `CombatController` (one per walk, `ctx.combat`: `bark()`,
  `strike()`, `raise_shield()`, `update(dt, guard_held)`, `reset()`, `stop()`, `events`); a fight is
  `ObjectiveStep.fight` (`foes`, `hp`, `speed`, `radius`, `leash`, `health`, `parry`, `rout`; lines
  `rule_lines.rout`) with kind `fight`; a knockdown is the walk's interrupt (card, reset).
  `StoryFxView` draws rings, the arc, the bark ring, the shield and HP pips.
- **Actors**: `StoryActor` behaviours idle, goto, follow (with a side), patrol, chase, flee, wander;
  `foe`, `hostile`, `sight_range`/`sight_half_angle`/`alert`, knockback. `ActorStep` actions patrol,
  chase, flee, wander, emote, with `sight_range`, `hostile`.
- **Stealth** (`StorySight`): range, cone, line of sight, bush and hiding-spot cover (`PropStep.hides`);
  `ObjectiveStep.caught = "restart"` with `caught_text`; checkpoints become the restart point.
- **Rules**: `receding` (2.1), `lull` (2.2, 3.3), `listen` (3.4), `sounder` (3.1's bell; `hidden`: a
  goal found by ear). The HUD gauge: `StoryHud.set_mode(label, value, color)`.
- **Minigames** (RD-35): `MiniGameStep` (`game`: parade, rowing, boat; `lines`; `won_effects`,
  `lost_effects`; `params`) over `RhythmGame` / `BoatGame` (pure), drawn by `MiniGameView`.
- **The book**: `MeravigliaOverlay` (Main `open_book()`).

## 8b. M7: Levels 5–8, branches, the endings

- **Branches** (RD-40): `BranchStep` (`cases`: `StoryBranchCase` {id, when, steps}; `otherwise`) runs
  the first case whose `StoryConditions.holds(state, when)`; forms: `{flag, eq}` (`eq` null = absent),
  `{meter, gte|lt}`, `{ability}`, `{book, has|gte}`, `{all: […]}`, `{any: […]}`; `check(when)` names a
  malformed one (the validator runs it). Metrics `branches` ("id:case").
- **Objectives**: `objective_kind = survive` (`survive` seconds; a knockdown restarts the clock);
  `in_order` pickups (only the next spot shows). `StoryPickup.seen_marvel`/`seen_label`/`seen_text`
  (8.2: the dream's version only for a marvel in the book; `shown_text(state)`).
- **Rules**: `steady` (5.2's ladder steadied), `act_at` (the walk's action at the goal: 5.5's board,
  8.3's bowl, 8.4's ball), `shoulder` (7.3), `fire` (7.5: `from`, `start_after`, `spread_every`,
  `per_tick`, `breaths`, `escort`; `FireRule.burning(st, p)`), `no_running` (7.6), `waking` (8.1:
  `every`, `angles`, `settle_at`, the knock, the smell, the receding JERUSALEM;
  `StoryContext.scramble_angle` turns the joystick), `companions` (8.3: `companions` [actor, side],
  `fall_in_x`). `lull` gains `cost` ({meter, amount}: all he has left when short) and
  `silence_after`/`silence_actor`/`silence_effects` (7.8). A rule may set `st.rule_restart` {big,
  small}: the walk's interrupt card, then `ObjectiveRule.restart()`.
- **Actors**: `flail` (5.3's brawlers); `ActorStep.target_actor` / `StoryActor.follow_actor` (follow
  another actor).
- **Minigames**: `MiniGameStep.game` adds ladders, letter, rumour and tug (`NEVER_LOST`: ladders;
  `NEVER_WON`: tug, which needs its `lost_effects`); pure `LaddersGame`, `LetterGame`, `RumourGame`,
  `TugGame`.
- **Choices**: `StoryChoiceOption.requires` (a condition; locked with `locked_text` while it does not
  hold).
- **The fade** (RD-51): `CampaignRules.fade_commozione(state, level)` at a dream scene's start.
- **Full Supervillain** (RD-53): `CampaignRules.unshakeable(state)`; the book shows "(FULL)".
- **The ending** (RD-52): `CampaignFlow.ending`, `grace_tier`, `standing_tier`, `ending_notes`; Main
  `show_ending()` after the last level's aside.

## 9. Adding a scene (all 36 story scenes are Resources since M7)

1. Record the rewrite in the matrix and the decisions log (spec §3) first.
2. Author `data/story/scenes/<id>.tres` (a `StageStep` first, a `CompleteStep` last) and add it to
   its chapter Resource in catalog order; any new map goes in `data/story/maps/`.
3. Run the validator (the schema and content tests); add a fingerprint to the content fixture.
4. Drive it with `StoryDriver` in both modes; add its restart, replay and force-close tests.
