class_name GreenZoneScene
extends Node2D
## The complete prototype: one endless Green Zone sandbox with Zampano.
## Move, collect treats, wait for digestion, poop, and use pee to clean the pollution.

signal restart_requested

const PAUSE := preload("res://scenes/overlays/pause_overlay.gd")

## Tests may advance the logic explicitly with tick().
@export var manual_ticks := false

var level: LevelDefinition
var rules: GreenZoneRules
var active := false
var paused := false
var main: Node = null
var ticks := 0

var _treat_views: Dictionary = {}
var _poop_views: Dictionary = {}
var _warning_mark: WorldText
var _time := 0.0
var _view := Vector2i(216, 432)
var _overlay: Control = null

@onready var world: IsoWorld = $IsoWorld
@onready var hud: GreenZoneHud = $GreenZoneCanvas/Hud
@onready var controls: TouchControls = $GreenZoneCanvas/TouchControls
@onready var overlay_canvas: CanvasLayer = $OverlayCanvas


func bind_main(m: Node) -> void:
	main = m


func _ready() -> void:
	level = GreenZoneLevel.definition()
	var map := GreenZoneLevel.load_model(level)
	world.setup(map)
	rules = GreenZoneRules.new(map, world.player, level)
	for t: Array in rules.treats:
		var view := TreatView.new().setup(world.catalog, int(t[2]), t[0], t[1])
		_treat_views[int(t[2])] = view
		world.add_dynamic_node(view, view.iso)
	_warning_mark = WorldText.new()
	_warning_mark.text = "!"
	_warning_mark.color = PixelText.ORANGE
	_warning_mark.visible = false
	world.fx_layer.add_child(_warning_mark)
	_connect_rules()
	controls.catalog = world.catalog
	InputService.set_context(&"green_zone")
	resize(_view)
	world.snap_camera()
	start_play()


func start_play() -> void:
	active = true
	_set_controls(true)
	InputService.set_context(&"green_zone")
	AudioService.play_music(&"greenzone")
	AudioService.set_duck(1.0)


func resize(logical: Vector2i) -> void:
	_view = logical
	if not is_node_ready():
		return
	world.camera_rig.set_view_size(Vector2(logical))
	controls.layout(logical, 104)
	hud.layout(logical)
	if _overlay:
		_overlay.size = Vector2(logical)


func _connect_rules() -> void:
	rules.treat_eaten.connect(func(index: int, _x: float, _y: float, _s: int) -> void:
		if _treat_views.has(index):
			world.remove_dynamic((_treat_views[index] as TreatView).iso)
			_treat_views.erase(index)
		AudioService.play(&"treat"))
	rules.poop_dropped.connect(func(pile: PoopPileModel) -> void:
		var view := PoopView.new().setup(world.catalog, pile)
		_poop_views[pile] = view
		world.add_dynamic_node(view, view.iso)
		AudioService.play(&"poop")
		world.camera_rig.model.shake(GameConfig.Fx.SHAKE_POOP))
	rules.poop_removed.connect(func(pile: PoopPileModel) -> void:
		if _poop_views.has(pile):
			world.remove_dynamic((_poop_views[pile] as PoopView).iso)
			_poop_views.erase(pile))
	rules.pee_started.connect(func(_x: float, _y: float, marking: bool, _r: float, _s: int) -> void:
		AudioService.play(&"pee")
		if marking:
			AudioService.play(&"star", 1.0, 1.0, 0.12))
	rules.pee_empty.connect(func(_x: float, _y: float) -> void: AudioService.play(&"empty"))
	rules.tired.connect(func(_x: float, _y: float) -> void: AudioService.play(&"empty", 1.0, 0.8))
	rules.hunger_depleted.connect(func(_x: float, _y: float) -> void:
		AudioService.play(&"hurt")
		world.camera_rig.model.shake(GameConfig.Fx.SHAKE_HURT))
	rules.poop_cleaned.connect(func(_x: float, _y: float, _s: int) -> void: AudioService.play(&"coin", 0.5, 1.5))
	rules.drank.connect(func(_x: float, _y: float) -> void: AudioService.play(&"drink"))
	rules.splashed.connect(func(_x: float, _y: float) -> void: AudioService.play(&"splash", 0.7))
	rules.digest_warning.connect(func(_x: float, _y: float) -> void: AudioService.play(&"warning"))
	rules.score_added.connect(_popup)


func _popup(x: float, y: float, amount: int, label: String) -> void:
	var popup := WorldText.new()
	popup.text = label if label != "" else "+%d" % amount
	popup.color = PixelText.YELLOW if label == "" else PixelText.GREEN
	popup.life = GameConfig.Fx.SCORE_POPUP_TIME
	popup.rise = 14.0
	var at := IsoGrid.grid_to_screen_xy(x, y)
	popup.position = Vector2(JsMath.round(at[0]), JsMath.round(at[1] - 26.0))
	world.fx_layer.add_child(popup)


func _set_controls(on: bool) -> void:
	controls.set_enabled(on)
	hud.set_menu_enabled(on)


func _physics_process(delta: float) -> void:
	if paused or manual_ticks:
		return
	tick(delta)


func tick(dt: float) -> void:
	if paused or not active:
		return
	if InputService.consume(&"menu"):
		open_pause()
		return
	_time += dt
	ticks += 1
	rules.update(dt, InputService)
	for view: TreatView in _treat_views.values():
		view.step(dt)
	for view: PoopView in _poop_views.values():
		view.step(dt)
	world.end_step(dt)
	var dog := world.player
	var dog_screen := IsoGrid.grid_to_screen_xy(dog.gx, dog.gy)
	_warning_mark.position = Vector2(JsMath.round(dog_screen[0]), JsMath.round(dog_screen[1] - 38.0))


func _process(delta: float) -> void:
	if not is_instance_valid(rules):
		return
	world.render(0.0 if paused else delta)
	var warning := rules.poop_warning()
	_warning_mark.visible = warning >= 0.0 and int(floor(_time * 6.0)) % 2 == 0
	controls.charges = rules.bladder.charges
	controls.max_charges = rules.bladder.max_charges
	controls.regen_fraction = rules.bladder.regen_fraction()
	controls.energy = world.player.energy.fraction()
	controls.can_run = world.player.can_run
	hud.update_state(hud_state(), delta)


func hud_state() -> Dictionary:
	var stats := rules.stats
	return {
		"pees": stats["pees"],
		"poops": stats["poops"],
		"treats": stats["treats"],
		"hunger": rules.hunger.fraction(),
		"digestion": clampf(rules.digestion.meter / GameConfig.Digestion.MAX, 0.0, 1.0),
		"poop_warning": rules.poop_warning(),
		"health": rules.health(),
		"score": stats["score"],
	}


func _open_overlay(overlay: Control) -> void:
	_overlay = overlay
	if main:
		main.push_overlay(overlay)
	else:
		overlay_canvas.add_child(overlay)
	overlay.size = Vector2(_view)


func _close_overlay() -> void:
	if _overlay == null:
		return
	if main:
		main.pop_overlay(_overlay)
	else:
		_overlay.queue_free()
	_overlay = null


func open_pause() -> void:
	if paused:
		return
	paused = true
	world.process_mode = Node.PROCESS_MODE_DISABLED
	_set_controls(false)
	AudioService.set_duck(0.4)
	var pause: PauseOverlay = PAUSE.new()
	pause.resume_requested.connect(resume)
	pause.restart_requested.connect(func() -> void: restart_requested.emit())
	_open_overlay(pause)


func resume() -> void:
	_close_overlay()
	paused = false
	world.process_mode = Node.PROCESS_MODE_INHERIT
	_set_controls(true)
	InputService.clear_pending()
	AudioService.set_duck(1.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if active and not paused and rules:
			open_pause()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if paused:
			resume()
		elif active and rules:
			open_pause()
