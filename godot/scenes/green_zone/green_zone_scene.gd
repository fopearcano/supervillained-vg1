class_name GreenZoneScene
extends Node2D
## Level 1 — the Green Zone (port of src/scenes/gameScene.ts and the Green Zone part of
## src/scenes/flow.ts). Owns the rules/threat models and orchestrates one logic tick in the
## source order; visuals, audio and overlays react to the rules' local signals.
##   briefing (start) → play → [pause] → level end (finish, record saved) | game over → retry

signal restart_requested
signal finished(result: Dictionary)

const BRIEFING := preload("res://scenes/overlays/briefing_overlay.gd")
const PAUSE := preload("res://scenes/overlays/pause_overlay.gd")
const LEVEL_END := preload("res://scenes/overlays/level_end_overlay.gd")
const GAME_OVER := preload("res://scenes/overlays/game_over_overlay.gd")

## When false, the briefing is skipped (automation/tests start playing at once).
@export var show_briefing := true
## Tests and automation advance the logic themselves with tick(1/60) (no real-time ticks).
@export var manual_ticks := false

var level: LevelDefinition
var rules: GreenZoneRules
var threats: GreenZoneThreats
## Gameplay runs (false while the briefing is shown).
var active := false
var paused := false
var result: Dictionary = {}
var main: Node = null
var ticks := 0

var _treat_views: Dictionary = {}
var _poop_views: Dictionary = {}
var _exit_ring: Sprite2D
var _exit_label: WorldText
var _warning_mark: WorldText
var _time := 0.0
var _end_notified := false
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
	_build_exit()
	var lives := AppState.lives()
	rules = GreenZoneRules.new(map, world.player, level, lives)
	world.player.speed_mul = LivesRules.lives_speed(lives)
	threats = GreenZoneThreats.new(rules)
	for t: Array in rules.treats:
		var view := TreatView.new().setup(world.catalog, int(t[2]), t[0], t[1])
		_treat_views[int(t[2])] = view
		world.add_dynamic_node(view, view.iso)
	_connect_rules()
	hud.catalog = world.catalog
	controls.catalog = world.catalog
	InputService.set_context(&"green_zone")
	resize(_view)
	world.snap_camera()
	if show_briefing:
		_set_controls(false)
		var b: BriefingOverlay = BRIEFING.new()
		b.go.connect(func() -> void:
			_close_overlay()
			start_play())
		_open_overlay(b)
	else:
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
	controls.layout(logical, 60)
	hud.layout(logical)
	if _overlay:
		_overlay.size = Vector2(logical)


func _build_exit() -> void:
	var map := world.map
	_exit_ring = Sprite2D.new()
	_exit_ring.texture = world.catalog.texture("exitRing_0")
	_exit_ring.centered = false
	_exit_ring.offset = -Vector2(world.catalog.anchor("exitRing_0"))
	_exit_ring.position = IsoGrid.grid_to_screen(map.exit_tile.x, map.exit_tile.y)
	world.decal_layer.add_child(_exit_ring)
	var flag := IsoProp.new().setup(world.catalog, "exitFlag_0", map.exit.x + 0.25, map.exit.y - 0.25, null, true)
	world.add_static(flag, flag.iso)
	_exit_label = WorldText.new()
	_exit_label.text = "EXIT"
	_exit_label.color = Color("#fff36a")
	world.fx_layer.add_child(_exit_label)
	_warning_mark = WorldText.new()
	_warning_mark.text = "!"
	_warning_mark.color = PixelText.ORANGE
	_warning_mark.visible = false
	world.fx_layer.add_child(_warning_mark)


func _connect_rules() -> void:
	rules.treat_eaten.connect(func(index: int, _x: float, _y: float, _s: int) -> void:
		if _treat_views.has(index):
			world.remove_dynamic((_treat_views[index] as TreatView).iso)
			_treat_views.erase(index)
		AudioService.play(&"treat"))
	rules.poop_dropped.connect(func(pile: PoopPileModel) -> void:
		var v := PoopView.new().setup(world.catalog, pile)
		_poop_views[pile] = v
		world.add_dynamic_node(v, v.iso)
		AudioService.play(&"poop")
		world.camera_rig.model.shake(GameConfig.Fx.SHAKE_POOP))
	rules.poop_removed.connect(func(pile: PoopPileModel) -> void:
		if _poop_views.has(pile):
			world.remove_dynamic((_poop_views[pile] as PoopView).iso)
			_poop_views.erase(pile))
	rules.pee_started.connect(func(_x: float, _y: float, _m: bool, _r: float, _s: int) -> void: AudioService.play(&"pee"))
	rules.pee_empty.connect(func(_x: float, _y: float) -> void: AudioService.play(&"empty"))
	rules.drank.connect(func(_x: float, _y: float) -> void: AudioService.play(&"drink"))
	rules.splashed.connect(func(_x: float, _y: float) -> void: AudioService.play(&"splash", 0.7))
	rules.digest_warning.connect(func(_x: float, _y: float) -> void: AudioService.play(&"warning"))
	rules.life_lost.connect(func(_x: float, _y: float, _l: int) -> void:
		AudioService.play(&"hurt")
		world.camera_rig.model.shake(GameConfig.Fx.SHAKE_HURT))
	rules.score_added.connect(_popup)
	rules.level_complete.connect(func(_x: float, _y: float) -> void:
		_set_controls(false)
		AudioService.play(&"jingle")
		AudioService.set_duck(0.35))
	rules.game_over.connect(func(_x: float, _y: float) -> void:
		_set_controls(false)
		AudioService.stop_music()
		AudioService.play(&"gameover"))
	threats.barked.connect(func(_x: float, _y: float, _d: String) -> void:
		AudioService.play(&"bark", 1.0, 0.95 + randf() * 0.1)
		world.camera_rig.model.shake(GameConfig.Fx.SHAKE_BARK))
	threats.pollution_surge.connect(func(_x: float, _y: float, _r: float, _t: int) -> void: AudioService.play(&"warning", 0.75, 0.82))


func _popup(x: float, y: float, amount: int, label: String) -> void:
	var p := WorldText.new()
	p.text = label if label != "" else "+%d" % amount
	p.color = PixelText.YELLOW if label == "" else PixelText.GREEN
	p.life = GameConfig.Fx.SCORE_POPUP_TIME
	p.rise = 14.0
	p.position = IsoGrid.grid_to_screen(x, y) + Vector2(0, -26)
	world.fx_layer.add_child(p)


func _set_controls(on: bool) -> void:
	controls.set_enabled(on)
	hud.set_menu_enabled(on)


func _physics_process(delta: float) -> void:
	if paused or manual_ticks:
		return
	tick(delta)


## One logic tick in source order (GameScene.update): rules, threats, world end step, end check.
func tick(dt: float) -> void:
	_time += dt
	ticks += 1
	if active:
		if InputService.consume(&"menu") and rules.state == "playing":
			open_pause()
		rules.update(dt, InputService)
		if rules.state == "playing":
			threats.update(dt, InputService)
	else:
		world.player.set_intent(0.0, 0.0)
	for v: TreatView in _treat_views.values():
		v.step(dt)
	for v: PoopView in _poop_views.values():
		v.step(dt)
	world.end_step(dt)
	var lp := IsoGrid.grid_to_screen(world.map.exit.x, world.map.exit.y)
	_exit_label.position = Vector2(JsMath.round(lp.x), JsMath.round(lp.y - 44 + sin(_time * 3.0) * 2.0) + 8)
	var dog := world.player
	_warning_mark.position = IsoGrid.grid_to_screen(dog.gx, dog.gy) + Vector2(0, -38)
	if not _end_notified and rules.state != "playing" and rules.ended_for() > 1.1:
		_end_notified = true
		if rules.state == "complete":
			_on_complete()
		else:
			_on_game_over()


func _process(delta: float) -> void:
	world.render(delta)
	_exit_ring.modulate.a = 0.5 + 0.5 * sin(_time * 5.0)
	var warn := rules.poop_warning()
	_warning_mark.visible = warn >= 0.0 and int(floor(_time * 6.0)) % 2 == 0
	controls.charges = rules.bladder.charges
	controls.max_charges = rules.bladder.max_charges
	controls.regen_fraction = rules.bladder.regen_fraction()
	controls.bark_ready = threats.bark_readiness()
	controls.energy = world.player.energy.fraction()
	controls.can_run = world.player.can_run
	hud.update_state(hud_state(), delta)


func hud_state() -> Dictionary:
	var st := rules.stats
	var p := world.player
	var radar: Array = []
	for t: Array in rules.treats:
		var d := IsoGrid.grid_vec_to_screen(t[0] - p.gx, t[1] - p.gy)
		if absf(d.x) < 260 and absf(d.y) < 260:
			radar.append({"d": d, "color": Color("#ff3b6b")})
	for poop in rules.poops:
		if not poop.cleaned:
			radar.append({"d": IsoGrid.grid_vec_to_screen(poop.gx - p.gx, poop.gy - p.gy), "color": Color("#8a5422")})
	return {
		"pees": st["pees"], "poops": st["poops"], "treats": st["treats"], "stars": rules.stars(),
		"lives": st["lives"], "hunger": rules.hunger.fraction(), "score": st["score"], "time": st["time"],
		"zone_name": level.zone_name, "level": level.number, "radar": radar,
		"exit": IsoGrid.grid_vec_to_screen(world.map.exit.x - p.gx, world.map.exit.y - p.gy),
	}


# --- Flow ---------------------------------------------------------------------------------------

func _open_overlay(o: Control) -> void:
	_overlay = o
	if main:
		main.push_overlay(o)
	else:
		overlay_canvas.add_child(o)
	o.size = Vector2(_view)


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
	var p: PauseOverlay = PAUSE.new()
	p.resume_requested.connect(resume)
	p.restart_requested.connect(func() -> void: restart_requested.emit())
	p.quit_requested.connect(func() -> void: restart_requested.emit())
	_open_overlay(p)


func resume() -> void:
	_close_overlay()
	paused = false
	world.process_mode = Node.PROCESS_MODE_INHERIT
	_set_controls(true)
	InputService.clear_pending()
	AudioService.set_duck(1.0)


## Level end: final health with the pee deficit, stars, bonuses; the record is saved at once.
func _on_complete() -> void:
	var st := rules.stats
	var health := ScoringRules.final_health(world.map.health(), st["pees"], st["poops"])
	var stars := ScoringRules.stars_from_health(health)
	var tb := ScoringRules.time_bonus(st["time"], level.par_time)
	var sb := ScoringRules.star_bonus(stars)
	var total: int = st["score"] + tb + sb
	var new_best: bool = SaveService.save_record(level.id, {"score": total, "stars": stars, "time": st["time"]})
	result = {"state": "complete", "level": level.number, "stats": st.duplicate(), "health": health, "stars": stars,
		"time_bonus": tb, "star_bonus": sb, "total": total, "new_best": new_best, "coins_total": st["coins"]}
	finished.emit(result)
	var o: LevelEndOverlay = LEVEL_END.new()
	o.result = result
	o.catalog = world.catalog
	o.retry_requested.connect(func() -> void: restart_requested.emit())
	o.title_requested.connect(func() -> void: restart_requested.emit())
	_open_overlay(o)


func _on_game_over() -> void:
	result = {"state": "gameover", "stats": rules.stats.duplicate()}
	finished.emit(result)
	var o: GameOverOverlay = GAME_OVER.new()
	o.score = rules.stats["score"]
	o.retry_requested.connect(func() -> void: restart_requested.emit())
	o.title_requested.connect(func() -> void: restart_requested.emit())
	_open_overlay(o)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if active and not paused and rules and rules.state == "playing":
			open_pause()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if paused:
			resume()
		elif active and rules.state == "playing":
			open_pause()
