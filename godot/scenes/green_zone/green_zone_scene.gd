class_name GreenZoneScene
extends Node2D
## Level 1 — the Green Zone (port of src/scenes/gameScene.ts and the Green Zone part of
## src/scenes/flow.ts). Owns the rules/threat models and orchestrates one logic tick in the
## source order; visuals, audio and overlays react to the models' local signals.
##   briefing → play ⇄ pause → [Supervillained snap → level end (CONTINUE: campaign handoff)]
##   | game over; RESTART/RETRY replay at once, QUIT/TITLE return to the title stand-in.

## RESTART (pause) and RETRY (level end, game over): a new run straight into play.
signal restart_requested
## QUIT (pause), TITLE (level end outside the story) and QUIT TO TITLE (game over).
signal title_requested
signal finished(result: Dictionary)
## CONTINUE on the level end: CampaignHandoff data (result, time, coins) for the stub receiver.
signal campaign_handoff(data: Dictionary)

const BRIEFING := preload("res://scenes/overlays/briefing_overlay.gd")
const PAUSE := preload("res://scenes/overlays/pause_overlay.gd")
const LEVEL_END := preload("res://scenes/overlays/level_end_overlay.gd")
const GAME_OVER := preload("res://scenes/overlays/game_over_overlay.gd")
const SUPERVILLAINED := preload("res://scenes/overlays/supervillained_overlay.gd")
const MAGNET_COLOR := Color8(0xdc, 0xf2, 0x3a)

## When false, the briefing is skipped (restart/retry, automation and tests start playing at once).
@export var show_briefing := true
## Tests and automation advance the logic themselves with tick(1/60) (no real-time ticks).
@export var manual_ticks := false
## True when the walk is played as the story's 1.0 (the shipped game): the level end offers
## CONTINUE (campaign handoff) instead of TITLE, like source Flow.playGreenZone.
@export var as_story_scene := true

var level: LevelDefinition
var rules: GreenZoneRules
var threats: GreenZoneThreats
## Gameplay runs (false while the briefing is shown).
var active := false
var paused := false
var result: Dictionary = {}
var main: Node = null
var ticks := 0
## Smoothed visual strength of the "under attack" look (0..1) and the current glitch burst.
var attack_fx := 0.0
var burst := 0.0
## Terminal presentation (Supervillained snap, result card, game over): the level below is frozen
## like the source's overlay scenes with `pausesBelow` — no logic tick, no rule/map timer, no
## camera motion, no attack look update, no world animation; the overlays keep running.
var terminal_frozen := false

var _treat_views: Dictionary = {}
var _poop_views: Dictionary = {}
var _critter_views: Dictionary = {}
var _exit_ring: Sprite2D
var _exit_label: WorldText
var _warning_mark: WorldText
var _magnet: Node2D
var _attack_rect: GlitchRect
var _time := 0.0
var _end_notified := false
var _view := Vector2i(216, 432)
var _overlay: Control = null

@onready var world: IsoWorld = $IsoWorld
@onready var hud: GreenZoneHud = $GreenZoneCanvas/Hud
@onready var controls: TouchControls = $GreenZoneCanvas/TouchControls
@onready var banner: AttackBanner = $GreenZoneCanvas/AttackBanner
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
	# The "under attack" look sits under the HUD and the touch controls, over the world.
	_attack_rect = GlitchRect.new()
	$GreenZoneCanvas.add_child(_attack_rect)
	$GreenZoneCanvas.move_child(_attack_rect, 0)
	_connect_rules()
	_connect_threats()
	hud.catalog = world.catalog
	controls.catalog = world.catalog
	InputService.set_context(&"green_zone")
	# A new run never inherits the previous run's siren (source Flow.newGameScene).
	AudioService.stop_all_loops()
	resize(_view)
	world.snap_camera()
	if show_briefing:
		_set_controls(false)
		_reading()
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
	# The Green Zone music starts with the walk (source flow.startPlaying).
	AudioService.play_music(&"greenzone")
	AudioService.set_duck(1.0)


## Intro music while the player reads (briefing, result card): source flow.reading().
func _reading() -> void:
	AudioService.play_music(&"intro")
	AudioService.set_duck(1.0)


func resize(logical: Vector2i) -> void:
	_view = logical
	if not is_node_ready():
		return
	world.camera_rig.set_view_size(Vector2(logical))
	controls.layout(logical, 60)
	hud.layout(logical)
	banner.layout(logical)
	_attack_rect.size = Vector2(logical)
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
	_magnet = Node2D.new()
	_magnet.draw.connect(_draw_magnet_fields)
	world.decal_layer.add_child(_magnet)
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
	# src/fx/gameAudio.ts: a marking pee adds the star 0.12 s later; tired and a cleaned poop reuse
	# the empty and coin cues with the source's rate/volume.
	rules.pee_started.connect(func(_x: float, _y: float, marking: bool, _r: float, _s: int) -> void:
		AudioService.play(&"pee")
		if marking:
			AudioService.play(&"star", 1.0, 1.0, 0.12))
	rules.pee_empty.connect(func(_x: float, _y: float) -> void: AudioService.play(&"empty"))
	rules.tired.connect(func(_x: float, _y: float) -> void: AudioService.play(&"empty", 1.0, 0.8))
	rules.poop_cleaned.connect(func(_x: float, _y: float, _s: int) -> void: AudioService.play(&"coin", 0.5, 1.5))
	rules.drank.connect(func(_x: float, _y: float) -> void: AudioService.play(&"drink"))
	rules.splashed.connect(func(_x: float, _y: float) -> void: AudioService.play(&"splash", 0.7))
	rules.digest_warning.connect(func(_x: float, _y: float) -> void: AudioService.play(&"warning"))
	rules.life_lost.connect(func(_x: float, _y: float, _l: int) -> void:
		AudioService.play(&"hurt")
		world.camera_rig.model.shake(GameConfig.Fx.SHAKE_HURT))
	rules.score_added.connect(_popup)
	rules.level_complete.connect(func(_x: float, _y: float) -> void:
		_set_controls(false)
		AudioService.stop_loop(&"siren")
		AudioService.play(&"jingle")
		AudioService.set_duck(0.35))
	rules.game_over.connect(func(_x: float, _y: float) -> void:
		_set_controls(false)
		AudioService.stop_loop(&"siren")
		AudioService.stop_music()
		AudioService.play(&"gameover"))


func _connect_threats() -> void:
	threats.barked.connect(func(_x: float, _y: float, _d: String) -> void:
		AudioService.play(&"bark", 1.0, 0.95 + randf() * 0.1)
		world.camera_rig.model.shake(GameConfig.Fx.SHAKE_BARK))
	threats.pollution_surge.connect(func(_x: float, _y: float, _r: float, _t: int) -> void:
		AudioService.play(&"warning", 0.75, 0.82)
		world.camera_rig.model.shake(GameConfig.Fx.SHAKE_POOP))
	threats.cat_added.connect(func(cat: CritterControllers.CatController) -> void:
		_add_critter(cat, CritterView.new().setup_cat(world.catalog, cat)))
	threats.cat_removed.connect(_remove_critter)
	threats.ball_added.connect(func(ball: CritterControllers.BallController) -> void:
		_add_critter(ball, CritterView.new().setup_ball(world.catalog, ball))
		AudioService.play(&"ball"))
	threats.ball_removed.connect(_remove_critter)
	threats.pug_added.connect(func(pug: CritterControllers.BagnaskizController) -> void:
		_add_critter(pug, CritterView.new().setup_bagnaskiz(world.catalog, pug)))
	threats.pug_removed.connect(_remove_critter)
	threats.cat_caught.connect(func(_x: float, _y: float, _c: int, _s: int) -> void:
		AudioService.play(&"meow")
		AudioService.play(&"coin", 1.0, 1.0, GameConfig.Audio.CASH_DELAY))
	threats.fetched.connect(func(_x: float, _y: float, _p: float) -> void: AudioService.play(&"fetch"))
	threats.bumped.connect(func(_x: float, _y: float) -> void:
		AudioService.play(&"laser")
		world.camera_rig.model.shake(GameConfig.Fx.SHAKE_HURT))
	threats.bark_hit.connect(func(_x: float, _y: float, _h: int) -> void:
		AudioService.play(&"hit")
		world.camera_rig.model.shake(GameConfig.Fx.SHAKE_HIT)
		burst = maxf(burst, 0.15))
	threats.bagnaskiz_fled.connect(func(_x: float, _y: float, _s: int) -> void: AudioService.play(&"flee"))
	threats.attack_started.connect(func(_i: float) -> void:
		banner.start()
		burst = 0.6
		world.camera_rig.model.shake(GameConfig.Fx.SHAKE_HURT)
		AudioService.play(&"alarm")
		AudioService.loop(&"siren", GameConfig.Audio.SIREN_VOLUME, GameConfig.Audio.SIREN_DELAY)
		AudioService.set_duck(0.45))
	threats.attack_ended.connect(func() -> void:
		banner.end()
		AudioService.stop_loop(&"siren")
		AudioService.play(&"saved")
		AudioService.set_duck(1.0))


func _add_critter(model: RefCounted, view: CritterView) -> void:
	_critter_views[model] = view
	world.add_dynamic_node(view, view.iso)


func _remove_critter(model: RefCounted) -> void:
	if _critter_views.has(model):
		world.remove_dynamic((_critter_views[model] as CritterView).iso)
		_critter_views.erase(model)


func _popup(x: float, y: float, amount: int, label: String) -> void:
	var p := WorldText.new()
	p.text = label if label != "" else "+%d" % amount
	p.color = PixelText.YELLOW if label == "" else PixelText.GREEN
	p.life = GameConfig.Fx.SCORE_POPUP_TIME
	p.rise = 14.0
	var at := IsoGrid.grid_to_screen_xy(x, y)
	p.position = Vector2(JsMath.round(at[0]), JsMath.round(at[1] - 26.0))
	world.fx_layer.add_child(p)


func _set_controls(on: bool) -> void:
	controls.set_enabled(on)
	hud.set_menu_enabled(on)


func _physics_process(delta: float) -> void:
	if paused or manual_ticks:
		return
	tick(delta)


## One logic tick in source order (GameScene.update): rules, threats, world end step, end check.
## Nothing runs once the terminal presentation has frozen the level.
func tick(dt: float) -> void:
	if terminal_frozen:
		return
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
	for v: CritterView in _critter_views.values():
		v.sync()
	world.end_step(dt)
	_update_attack_fx(dt)
	var lp := IsoGrid.grid_to_screen(world.map.exit.x, world.map.exit.y)
	_exit_label.position = Vector2(JsMath.round(lp.x), JsMath.round(lp.y - 44 + sin(_time * 3.0) * 2.0) + 8)
	var dog := world.player
	var dp := IsoGrid.grid_to_screen_xy(dog.gx, dog.gy)
	_warning_mark.position = Vector2(JsMath.round(dp[0]), JsMath.round(dp[1] - 38.0))
	if not _end_notified and rules.state != "playing" and rules.ended_for() > 1.1:
		_end_notified = true
		if rules.state == "complete":
			_on_complete()
		else:
			_on_game_over()


## Sepia palette shift + glitch bursts while the zone is under attack (GameScene.updateAttackFx);
## the banner shows its hint. The bursts' timing is cosmetic randomness, as in the source.
func _update_attack_fx(dt: float) -> void:
	var health := world.map.health()
	var target := threats.director.intensity(health)
	var rate := 2.5 if target > attack_fx else 0.8
	attack_fx += (target - attack_fx) * minf(1.0, rate * dt)
	if attack_fx < 0.005 and target == 0.0:
		attack_fx = 0.0
	if burst > 0.0:
		burst -= dt
	elif attack_fx > 0.0 and randf() < 0.006 + 0.02 * attack_fx:
		burst = 0.08 + randf() * 0.15
	_attack_rect.fx_time = _time
	_attack_rect.sepia = minf(0.9, attack_fx * 0.95)
	_attack_rect.scanlines = attack_fx * 0.35
	_attack_rect.glitch = 0.35 + attack_fx * 0.5 if burst > 0.0 else 0.0
	_attack_rect.rgb = 2.0 + attack_fx * 2.0 if burst > 0.0 else (1.0 if attack_fx > 0.5 else 0.0)
	_attack_rect.flash = 0.0
	if not active:
		return
	if attack_fx <= 0.0:
		_attack_rect.glitch = 0.0
		_attack_rect.rgb = 0.0
	_attack_rect.apply()
	banner.update_banner(dt, attack_hint())


## The banner's hint (GameScene.updateAttackFx): bark at Bagnaskiz while he is active, otherwise
## pee to heal the zone while it is below the attack threshold.
func attack_hint() -> String:
	var pug := threats.pug
	if pug != null and pug.is_active():
		return "BARK AT BAGNASKIZ!" if InputService.using_touch else "BARK (J) AT BAGNASKIZ!"
	if world.map.health() < threats.director.threshold:
		return "PEE TO HEAL THE ZONE!"
	return ""


func _process(delta: float) -> void:
	if terminal_frozen:
		return
	world.render(delta)
	_exit_ring.modulate.a = 0.5 + 0.5 * sin(_time * 5.0)
	var warn := rules.poop_warning()
	_warning_mark.visible = warn >= 0.0 and int(floor(_time * 6.0)) % 2 == 0
	_magnet.queue_redraw()
	controls.charges = rules.bladder.charges
	controls.max_charges = rules.bladder.max_charges
	controls.regen_fraction = rules.bladder.regen_fraction()
	controls.bark_ready = threats.bark_readiness()
	controls.energy = world.player.energy.fraction()
	controls.can_run = world.player.can_run
	hud.update_state(hud_state(), delta)


## Pulsing rings converging on nearby balls: the magnet pull area (GameScene.drawMagnetFields).
func _draw_magnet_fields() -> void:
	const B := GameConfig.Ball
	var p := world.player
	for b in threats.balls:
		if JsMath.hypot(b.gx - p.gx, b.gy - p.gy) > B.MAGNET_RADIUS * 1.8 or b.age > B.LIFETIME:
			continue
		var c := IsoGrid.grid_to_screen_xy(b.gx, b.gy)
		var center := Vector2(JsMath.round(c[0]), JsMath.round(c[1]))
		for k in 2:
			var u := 1.0 - fmod(_time * 0.8 + k * 0.5, 1.0)
			var r := B.MAGNET_RADIUS * u
			var points := PackedVector2Array()
			for s in 33:
				var a := TAU * s / 32.0
				points.append(center + Vector2(cos(a) * r * 16.0 * sqrt(2.0), sin(a) * r * 8.0 * sqrt(2.0)))
			_magnet.draw_polyline(points, Color(MAGNET_COLOR, 0.55 * (1.0 - u) + 0.1), 1.0)


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
	for c in threats.cats:
		radar.append({"d": IsoGrid.grid_vec_to_screen(c.gx - p.gx, c.gy - p.gy), "color": Color("#3ff0ff"), "size": 3})
	for b in threats.balls:
		radar.append({"d": IsoGrid.grid_vec_to_screen(b.gx - p.gx, b.gy - p.gy), "color": Color("#ffe23a"), "size": 2})
	if threats.pug != null:
		radar.append({"d": IsoGrid.grid_vec_to_screen(threats.pug.gx - p.gx, threats.pug.gy - p.gy), "color": Color("#ff7a1f"), "size": 4, "blink": true})
	return {
		"pees": st["pees"], "poops": st["poops"], "treats": st["treats"], "stars": rules.stars(),
		"lives": st["lives"], "hunger": rules.hunger.fraction(), "score": st["score"], "time": st["time"],
		"zone_name": level.zone_name, "level": level.number, "radar": radar,
		"exit": IsoGrid.grid_vec_to_screen(world.map.exit.x - p.gx, world.map.exit.y - p.gy),
	}


## Debug/test summary (source GameScene.debugState) plus the live threats.
func debug_state() -> Dictionary:
	var st := rules.stats.duplicate()
	var p := world.player
	return {
		"player": [p.gx, p.gy, p.facing, p.state], "health": world.map.health(), "stars": rules.stars(),
		"hunger": rules.hunger.value, "charges": rules.bladder.charges, "progress": world.map.progress_at(p.gx, p.gy),
		"state": rules.state, "stats": st, "treats_left": rules.treats.size(), "attack": threats.director.state,
		"threats": threats.summary(),
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
	AudioService.play(&"click")
	AudioService.set_duck(0.4)
	AudioService.stop_loop(&"siren")
	var p: PauseOverlay = PAUSE.new()
	p.resume_requested.connect(resume)
	p.restart_requested.connect(func() -> void: restart_requested.emit())
	p.quit_requested.connect(func() -> void: title_requested.emit())
	_open_overlay(p)


## Source Flow.resume: the siren and the attack duck come back if the zone is still under attack.
func resume() -> void:
	_close_overlay()
	paused = false
	world.process_mode = Node.PROCESS_MODE_INHERIT
	_set_controls(true)
	InputService.clear_pending()
	AudioService.play(&"click")
	var attack := threats.director.state == "attack"
	AudioService.set_duck(0.45 if attack else 1.0)
	if attack:
		AudioService.loop(&"siren", GameConfig.Audio.SIREN_VOLUME)


## Freezes the level under the terminal overlays (source SupervillainedScene, LevelEndScene and
## GameOverScene pause the scene below): logic ticks, rule and map timers, the camera, the attack
## look and every world node (dog, critters, popups, animated sprites) stop; the scene's own
## overlay canvas and Main's overlay host keep processing, so the overlays still take input.
func _freeze_terminal() -> void:
	if terminal_frozen:
		return
	terminal_frozen = true
	_set_controls(false)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.reset_physics_interpolation()


## Level end: final health with the pee deficit, stars, bonuses; the independent record is saved
## at once (SAV-004/SAV-008) — not during a replay, which changes no persistent byte. The campaign
## (time, coins, 1.0) is handed over only by CONTINUE. "You've been supervillained" snaps in first,
## then the result card.
func _on_complete() -> void:
	_freeze_terminal()
	var st := rules.stats
	var health := ScoringRules.final_health(world.map.health(), st["pees"], st["poops"])
	var stars := ScoringRules.stars_from_health(health)
	var tb := ScoringRules.time_bonus(st["time"], level.par_time)
	var sb := ScoringRules.star_bonus(stars)
	var total: int = st["score"] + tb + sb
	var replay := not AppState.persists()
	var saved: Dictionary = {"new_best": false, "saved": false}
	if not replay:
		saved = SaveService.save_record(level.id, {"score": total, "stars": stars, "time": st["time"]})
	var campaign_coins := int(AppState.campaign()["coins"])
	result = {"state": "complete", "level": level.number, "stats": st.duplicate(), "health": health, "stars": stars,
		"time_bonus": tb, "star_bonus": sb, "total": total, "new_best": saved["new_best"],
		"record_saved": saved["saved"], "coins_total": campaign_coins + int(st["coins"]), "has_next": as_story_scene,
		"next_label": "CONTINUE", "replay": replay}
	finished.emit(result)
	_set_controls(false)
	_reading()
	var sv: SupervillainedOverlay = SUPERVILLAINED.new()
	sv.catalog = world.catalog
	sv.done.connect(func() -> void:
		_close_overlay()
		_open_level_end())
	_open_overlay(sv)


func _open_level_end() -> void:
	var o: LevelEndOverlay = LEVEL_END.new()
	o.result = result
	o.catalog = world.catalog
	o.continue_requested.connect(func() -> void: campaign_handoff.emit(CampaignHandoff.from_result(result)))
	o.retry_requested.connect(func() -> void: restart_requested.emit())
	o.title_requested.connect(func() -> void: title_requested.emit())
	_open_overlay(o)


func _on_game_over() -> void:
	_freeze_terminal()
	result = {"state": "gameover", "stats": rules.stats.duplicate()}
	finished.emit(result)
	_set_controls(false)
	var o: GameOverOverlay = GAME_OVER.new()
	o.score = rules.stats["score"]
	o.retry_requested.connect(func() -> void: restart_requested.emit())
	o.title_requested.connect(func() -> void: title_requested.emit())
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
