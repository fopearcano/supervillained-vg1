class_name StoryScene
extends Node2D
## The production story scene (ARCHITECTURE.md §6 and §13; port of src/story/storyScene.ts):
## instantiates the shared IsoWorld for each stage (like GreenZoneScene), owns a StoryRunner over
## the scene Resource's steps, the StoryContext the steps use, the story HUD and touch controls,
## and ticks at the fixed 60 Hz logic rate (tests tick by hand). The campaign is a working copy
## of the entry state: effects apply to it at once and the scene reports it with `completed`;
## Main commits it in one save (RD-05). Restart starts again from the entry state, so nothing is
## applied twice; a replay's copy is never committed.

signal completed(result: Dictionary)
signal failed(message: String)
signal quit_requested

const WORLD_SCENE := preload("res://world/world_2d.tscn")
const TEXT: ShellText = preload("res://data/shell/shell_text.tres")

## Tests tick by hand; the game ticks in _physics_process.
@export var manual_ticks := false

var data: StorySceneData
var cast: StoryCast
## map id -> StoryMapData
var maps: Dictionary = {}
## The campaign the scene was entered with (deep copy); restart returns to it.
var entry_state: Dictionary = {}
## False in a replay: nothing is ever committed.
var persist := true
var world: IsoWorld
var ctx: StoryContext
var runner: StoryRunner
## handle -> StoryActor / StoryProp / ObjectiveMarker on the current stage.
var actors: Dictionary = {}
var props: Dictionary = {}
var markers: Array = []
## Story play time (outside replays), kept across restarts in the session (RD-05).
var play_time := 0.0
var restarts := 0
var stage_changes := 0
var paused := false
var finished := false
var ticks := 0
var main: Node = null
var _view := Vector2i(216, 432)
var _carry_sprite: Sprite2D = null
var _pause: Control = null

@onready var hud: StoryHud = $StoryCanvas/StoryHud
## The visor bars and the flash, beneath the touch controls and the HUD (source draw order).
@onready var shade: StoryShade = $StoryCanvas/StoryShade
@onready var controls: StoryTouchControls = $StoryCanvas/StoryTouchControls
@onready var overlay_canvas: CanvasLayer = $OverlayCanvas


## Configures the scene before it enters the tree.
func setup(p_data: StorySceneData, p_entry_state: Dictionary, p_persist: bool) -> StoryScene:
	data = p_data
	entry_state = p_entry_state.duplicate(true)
	persist = p_persist
	return self


func bind_main(m: Node) -> void:
	main = m


func _ready() -> void:
	cast = load("res://data/story/cast.tres")
	for f in DirAccess.get_files_at("res://data/story/maps"):
		if f.ends_with(".tres"):
			var m: StoryMapData = load("res://data/story/maps/" + f)
			maps[m.id] = m
	shade.hud = hud
	runner = StoryRunner.new()
	runner.finished.connect(_on_runner_finished)
	AppState.settings_changed.connect(func(_s: Dictionary) -> void: _apply_text_speed())
	resize(_view)
	_start_run()


## The typewriter follows the OPTIONS text speed (RD-17).
func _apply_text_speed() -> void:
	hud.cps = GameConfig.Story.TEXT_CPS.get(String(AppState.settings.get("textSpeed", "normal")), GameConfig.Story.TEXT_CPS["normal"])


func _start_run() -> void:
	finished = false
	paused = false
	ctx = StoryContext.new()
	ctx.scene = self
	ctx.data = data
	ctx.cast = cast
	ctx.state = entry_state.duplicate(true)
	ctx.persist = persist
	# The scene's own seeded randomness (a lull's pauses): every run and restart draws the same.
	ctx.rng.seed = hash("story:" + data.id)
	ctx.runner = runner
	ctx.hud = hud
	hud.hide_line()
	hud.hide_card()
	hud.objective = ""
	hud.carry_label = ""
	hud.visor = 0.0
	_apply_text_speed()
	InputService.set_context(&"story_walk")
	AudioService.play_music(StringName(data.music))
	AudioService.set_duck(1.0)
	_clear_stage()
	set_controls(false)
	# Entry conditions hold before anything runs; else an explicit story error (deferred so the
	# owner's failed handler, connected after the scene enters the tree, receives it).
	var why := data.entry_failure(entry_state)
	if why != "":
		finished = true
		ctx.error = "story %s: %s" % [data.id, why]
		push_error(ctx.error)
		var message := ctx.error
		(func() -> void: failed.emit(message)).call_deferred()
		return
	# The feeling fades (RD-05): a dream scene of Levels 2-7 starts with a little less Commozione, on
	# the working copy only; a restart starts again from the entry state, so it fades once per
	# committed scene.
	var lost := CampaignRules.fade_commozione(ctx.state, 0 if data.reality else data.level)
	if lost > 0.0:
		ctx.metrics["faded"] = lost
		ctx.notice(ctx.ui_text("story_fade_notice") % int(lost), Color("#9aa4c0"))
	# The first step is the scene's StageStep (validated): it builds the first stage.
	runner.start(data.steps)


func resize(logical: Vector2i) -> void:
	_view = logical
	if not is_node_ready():
		return
	hud.layout(logical)
	shade.size = Vector2(logical)
	controls.layout(logical, 60)
	if world:
		world.camera_rig.set_view_size(Vector2(logical))


# --- Stage --------------------------------------------------------------------------------------

## Loads a map as a new IsoWorld (the old one, its actors, props and markers are freed), places the
## player in the scene's costume (plain in reality, the coat of mail in the dream) and snaps the camera; the new player's physics interpolation is
## reset (DOG-008b). False (and an explicit failure) when the map or its marker is missing.
func build_stage(map_id: String, at: String, point: Vector2, face: String) -> bool:
	var m: StoryMapData = maps.get(map_id)
	if m == null:
		ctx.fail("missing map '%s'" % map_id)
		return false
	var parsed := m.parse()
	if not parsed["ok"]:
		ctx.fail("map '%s' does not parse: %s" % [map_id, parsed.get("error", "")])
		return false
	_clear_stage()
	world = WORLD_SCENE.instantiate()
	world.environment = m.environment
	add_child(world)
	move_child(world, 0)
	world.setup(WorldMapModel.new(parsed["level"]))
	ctx.map_id = map_id
	hud.world = world
	world.camera_rig.set_view_size(Vector2(_view))
	var p := ctx.place(at, point)
	if ctx.error != "":
		return false
	world.player.set_grid_position(p.x, p.y)
	world.player.face(face)
	world.player.no_run = false
	# The costume follows the scene's `reality` (StorySceneData.costume), never the abilities held.
	world.player.set_costume(data.costume())
	world.decal_layer.add_child(StoryFxView.new().setup(self, true))
	world.fx_layer.add_child(StoryFxView.new().setup(self, false))
	ctx.hides = []
	world.snap_camera()
	stage_changes += 1
	return true


func _clear_stage() -> void:
	actors.clear()
	props.clear()
	markers.clear()
	_carry_sprite = null
	if world:
		remove_child(world)
		world.queue_free()
		world = null


func spawn_actor(handle: String, role: String, p: Vector2, face: String) -> StoryActor:
	if actors.has(handle):
		despawn_actor(handle)
	if role != "legs" and StoryCast.frames_path(role) == "":
		ctx.fail("missing SpriteFrames for cast role '%s'" % role)
		return null
	var a := StoryActor.new().setup(handle, role, world.catalog)
	a.set_grid_position(p.x, p.y)
	a.face(face)
	world.add_dynamic_node(a, a.iso)
	actors[handle] = a
	return a


func despawn_actor(handle: String) -> void:
	var a: StoryActor = actors.get(handle)
	if a == null:
		return
	actors.erase(handle)
	world.remove_dynamic(a.iso)
	a.queue_free()


func place_prop(handle: String, key: String, p: Vector2, tint: Color) -> StoryProp:
	if not world.catalog.has_key(key):
		ctx.fail("missing sprite '%s'" % key)
		return null
	remove_prop(handle)
	var pr := StoryProp.new().setup(handle, world.catalog, key, tint)
	pr.set_grid_position(p.x, p.y)
	world.add_dynamic_node(pr, pr.iso)
	props[handle] = pr
	return pr


func remove_prop(handle: String) -> void:
	var pr: StoryProp = props.get(handle)
	if pr == null:
		return
	props.erase(handle)
	world.remove_dynamic(pr.iso)
	pr.queue_free()


func add_marker(p: Vector2, radius: float, color: Color) -> ObjectiveMarker:
	var mk := ObjectiveMarker.new().setup(p.x, p.y, radius, color)
	world.object_layer.add_child(mk)
	markers.append(mk)
	return mk


## Removes a spot ring (one already freed, e.g. with its stage, is ignored).
func remove_marker(mk: Variant) -> void:
	if mk == null or not is_instance_valid(mk):
		return
	markers.erase(mk)
	(mk as ObjectiveMarker).queue_free()


func set_controls(on: bool) -> void:
	if not is_node_ready() or ctx == null:
		return
	controls.configure(on, ctx.actions.label() if on else "", on and not ctx.no_run, ctx.actions.modes.size() if on else 0, ctx.actions.index())
	if not on and world:
		world.player.set_intent(0.0, 0.0)


## The logical view size (the minigames' tap band).
func view_size() -> Vector2i:
	return _view


## A minigame's view over the stage, beneath the HUD (MiniGameStep); removed with hide_minigame.
func show_minigame(v: Control) -> void:
	var canvas := hud.get_parent()
	canvas.add_child(v)
	canvas.move_child(v, hud.get_index())
	v.size = Vector2(_view)


func hide_minigame(v: Control) -> void:
	if is_instance_valid(v):
		v.get_parent().remove_child(v)
		v.queue_free()


## The thing he carries: its label on the HUD and its sprite on his back ("" = drop).
func set_carried(label: String, sprite: String) -> void:
	hud.carry_label = label
	if _carry_sprite and is_instance_valid(_carry_sprite):
		_carry_sprite.queue_free()
	_carry_sprite = null
	if label != "" and sprite != "" and world.catalog.has_key(sprite):
		_carry_sprite = Sprite2D.new()
		_carry_sprite.texture = world.catalog.texture(sprite)
		_carry_sprite.position = Vector2(0, -18)
		world.player.add_child(_carry_sprite)


# --- Ticks --------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not manual_ticks:
		tick(delta)


## One logic tick: the menu, the runner (the current step), the player (joystick or a scripted
## walk), the actors, the world's end step and the HUD.
func tick(dt: float) -> void:
	if paused or finished or ctx == null or ctx.error != "":
		return
	ticks += 1
	if persist:
		play_time += dt
	if InputService.consume(&"menu"):
		open_pause()
		return
	runner.tick(ctx, dt)
	if finished or ctx.error != "" or world == null:
		return
	var dog := world.player
	# A walk's speed modifier applies to walking, never to a charge (2.3's heavy armour).
	dog.speed_mul = 1.0 if dog.running else ctx.walk_speed_mul
	if ctx.controls:
		dog.no_run = ctx.no_run
		# 8.1's scrambled legs turn the joystick (in doubles: no float32 Vector2 on the parity path).
		var mx := InputService.move_x
		var my := InputService.move_y
		if ctx.scramble_angle != 0.0:
			var c := cos(ctx.scramble_angle)
			var sn := sin(ctx.scramble_angle)
			var rx := mx * c - my * sn
			my = mx * sn + my * c
			mx = rx
		dog.set_intent(mx, my, InputService.run_held and not ctx.no_run)
	elif ctx.move_target == null:
		dog.set_intent(0.0, 0.0)
	dog.update_movement(dt, world.map)
	var pp := Vector2(dog.gx, dog.gy)
	for a: StoryActor in actors.values():
		a.tick(dt, world.map, pp)
	world.end_step(dt)
	hud.visor = ctx.visor
	hud.tick(dt)


func _process(delta: float) -> void:
	if world:
		world.render(delta)


func _on_runner_finished() -> void:
	finished = true
	set_controls(false)
	completed.emit({"id": data.id, "state": ctx.state.duplicate(true), "play_time": play_time, "persist": persist,
		"trace": runner.trace, "metrics": ctx.metrics.duplicate(true), "restarts": restarts})


func on_failed(message: String) -> void:
	finished = true
	set_controls(false)
	failed.emit(message)


# --- Pause, restart, quit -----------------------------------------------------------------------

## The story pause (RESUME, RESTART SCENE, QUIT TO TITLE); the scene is frozen meanwhile.
func open_pause() -> void:
	if paused or finished:
		return
	paused = true
	set_controls(false)
	AudioService.play(&"click")
	AudioService.set_duck(0.4)
	var o := StoryPauseOverlay.new()
	o.setup(TEXT, {"resume": resume, "restart": restart, "quit": quit})
	_pause = o
	if main:
		main.push_overlay(o)
	else:
		overlay_canvas.add_child(o)
		o.size = Vector2(_view)


func _close_pause() -> void:
	if _pause and is_instance_valid(_pause):
		if main:
			main.pop_overlay(_pause)
		else:
			_pause.queue_free()
	_pause = null
	AudioService.set_duck(1.0)


func resume() -> void:
	_close_pause()
	paused = false
	InputService.clear_pending()
	set_controls(ctx.controls)


## Starts the scene again from its entry state: no effect, meter change or reward is kept from the
## abandoned attempt, so none is applied twice (play time is kept).
func restart() -> void:
	_close_pause()
	runner.stop(ctx)
	restarts += 1
	_start_run()


func quit() -> void:
	_close_pause()
	runner.stop(ctx)
	finished = true
	quit_requested.emit()
