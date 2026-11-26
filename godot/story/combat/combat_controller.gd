class_name CombatController
extends RefCounted
## BARK, the SWORD and the SHIELD in a story walk (port of src/story/combat.ts), over the rules of
## CombatRules. They work in every walk (a bark is a bark, a swing at nothing is a swing); with a
## fight definition the named actors take the blows, chase Zampanò and swing back (a ring fills under
## them: time to raise the shield) and he has hearts. Non-lethal: routed foes run off; at no hearts
## he is knocked down (`knocked` turns true) and the walk calls reset(): everyone back where they
## stood, hearts full, nothing persistent touched. The sword and the shield need the knight's
## capability (StoryContext.armed(): a dream scene with `knight` held); without it they only show
## a one-time notice. Presentation state (the swing's arc, the bark's ring, the raised shield) is
## read by StoryFxView. Every player-visible word comes from the fight definition (the step's
## Resource) or ShellText.

const C := GameConfig.Combat

## The scene's context, held weakly (the context holds this controller: no reference cycle when a
## scene is freed mid-walk).
var ctx: StoryContext:
	get:
		return _ctx_ref.get_ref() if _ctx_ref else null
var _ctx_ref: WeakRef = null
## The fight ({} = none): "foes" (handles), "hp", "speed", "radius", "leash", "health", "parry",
## "rout" (how many to rout; absent = all; 0 = none: only get through), "rout_lines",
## "sword_cost" (effects of each swing that lands, 5.3's Grace) and "sword_cost_text" (shown once).
var def: Dictionary = {}
var foes: Array[StoryActor] = []
var health := 0
var max_health := 0
var routed := 0
## The shield is up this tick.
var guarding := false
## True once he has no hearts left (the walk shows the card and calls reset()).
var knocked := false
## Every combat event this run, in order ("bark", "bark_hit", "strike", "hit", "parried",
## "routed", "blocked", "hurt", "knocked", "no_arms", "shield_up"): tests and the reports.
var events: Array[String] = []
var strike_cd := 0.0
var bark_cd := 0.0
var guard_pulse := 0.0
var swing := 0.0
var swing_dir := Vector2.ZERO
var bark_ring := 0.0
var invuln := 0.0
var _snapshots: Array = []
var _was_guarding := false
var _told: Dictionary = {}


func active() -> bool:
	return not def.is_empty()


## How many routed foes finish the fight.
func need() -> int:
	if not active():
		return 0
	if not def.has("rout"):
		return foes.size()
	return clampi(int(def["rout"]), 0, foes.size())


func won() -> bool:
	return not active() or routed >= need()


func start(p_ctx: StoryContext, p_def: Dictionary) -> void:
	_ctx_ref = weakref(p_ctx)
	def = p_def
	if not active():
		return
	max_health = int(def.get("health", C.HEALTH))
	health = max_health
	for h: String in def.get("foes", []):
		var a := ctx.actor(h)
		if a == null:
			return
		foes.append(a)
		_snapshots.append({"actor": a, "at": Vector2(a.gx, a.gy)})
	_arm()


## Every foe at full HP, hostile, coming for him.
func _arm() -> void:
	for s: Dictionary in _snapshots:
		var a: StoryActor = s["actor"]
		a.foe = CombatRules.new_foe(float(def.get("hp", C.FOE_HP)))
		a.hostile = true
		a.knock(0.0, 0.0)
		a.chase(float(def.get("speed", C.FOE_CHASE_SPEED)), float(def.get("radius", C.FOE_CHASE_RADIUS)), s["at"], float(def.get("leash", 0.0)), C.FOE_STOP_AT)
	routed = 0
	_show_health()


## Knocked down: everyone back where they started, hearts full (the walk puts him back too).
func reset() -> void:
	if not active():
		return
	for s: Dictionary in _snapshots:
		var a: StoryActor = s["actor"]
		var at: Vector2 = s["at"]
		a.set_grid_position(at.x, at.y)
	health = max_health
	invuln = 0.0
	knocked = false
	guard_pulse = 0.0
	_arm()


func _show_health() -> void:
	if not active():
		return
	var label := ctx.ui_text("story_fight_routed") % [routed, need()] if need() > 0 else ctx.ui_text("story_fight_health")
	ctx.hud.set_mode(label, float(health) / float(max_health), Color("#ff4a4a"))


## The sword and the shield only for a knight (a dream scene with `knight` held): otherwise a
## one-time notice, and nothing happens.
func _armed(what: String) -> bool:
	if ctx.armed():
		return true
	events.append("no_arms")
	if not _told.has(what):
		_told[what] = true
		ctx.notice(ctx.ui_text("story_no_arms") % ctx.ui_text("story_mode_" + what), Color("#9aa4c0"))
	return false


## Turns him toward the nearest fighting foe within `range_` (aim help for thumbs).
func _face_nearest(range_: float) -> StoryActor:
	var p := ctx.player
	var best: StoryActor = null
	var bd := range_
	for a: StoryActor in foes:
		if a.foe == null or a.foe.routed:
			continue
		var d := JsMath.hypot(a.gx - p.gx, a.gy - p.gy)
		if d < bd:
			bd = d
			best = a
	if best:
		p.face(IsoGrid.dir_from_grid_vector(best.gx - p.gx, best.gy - p.gy, p.facing))
	return best


func _facing_vec() -> Vector2:
	var g := IsoGrid.dir_to_grid_xy(ctx.player.facing)
	return Vector2(g[0], g[1])


## BARK: a woof everywhere; in a fight it staggers and pushes back everyone near (never parried).
## False while a fight's bark cools down (nothing happens).
func bark() -> bool:
	var p := ctx.player
	if active() and bark_cd > 0.0:
		return false
	p.start_action("bark", GameConfig.Story.BARK_ANIM)
	ctx.play_sound("bark")
	ctx.say_float(ctx.ui_text("story_bark_text"), ctx.player_pos(), Color.WHITE)
	events.append("bark")
	if not active():
		return true
	bark_cd = C.BARK_COOLDOWN
	bark_ring = 1.0
	for a: StoryActor in foes:
		if a.foe == null or a.foe.routed:
			continue
		var dx := a.gx - p.gx
		var dy := a.gy - p.gy
		var d := JsMath.hypot(dx, dy)
		if d > C.BARK_RADIUS:
			continue
		var l := d if d > 0.0 else 1.0
		a.knock(dx / l * C.BARK_KNOCK, dy / l * C.BARK_KNOCK)
		events.append("bark_hit")
		_land(a, CombatRules.damage_foe(a.foe, C.BARK_DAMAGE, C.BARK_STUN, false))
	return true


## SWORD: a swing in front of him (knights only). Foes in the arc are hit and pushed back; a foe
## who parries and is not open takes nothing (both step back).
func strike() -> void:
	if not _armed("sword") or strike_cd > 0.0:
		return
	var p := ctx.player
	strike_cd = C.SWORD_COOLDOWN
	_face_nearest(C.SWORD_RANGE + 0.6)
	p.start_action("bark", C.SWORD_ACTION_TIME)
	p.bump(0.25)
	ctx.play_sound("swish")
	var f := _facing_vec()
	swing_dir = IsoGrid.grid_vec_to_screen(f.x, f.y)
	swing = 1.0
	events.append("strike")
	if not active():
		return
	var landed := false
	for a: StoryActor in foes:
		if a.foe == null or a.foe.routed:
			continue
		if not CombatRules.in_arc(p.gx, p.gy, f.x, f.y, a.gx, a.gy, C.SWORD_RANGE, C.SWORD_HALF_ARC):
			continue
		var dx := a.gx - p.gx
		var dy := a.gy - p.gy
		var d := JsMath.hypot(dx, dy)
		if d == 0.0:
			d = 1.0
		if bool(def.get("parry", false)) and not CombatRules.is_open(a.foe):
			a.knock(dx / d * C.SWORD_PARRY_KNOCK, dy / d * C.SWORD_PARRY_KNOCK)
			p.knockback(-dx, -dy, C.SWORD_PARRY_KNOCK)
			ctx.play_sound("clang")
			ctx.say_float(ctx.ui_text("story_parried"), Vector2(a.gx, a.gy), Color("#9aa4c0"))
			events.append("parried")
			if not _told.has("parry"):
				_told["parry"] = true
				ctx.notice(ctx.ui_text("story_parry_hint"), Color("#9ad8ff"))
			continue
		a.knock(dx / d * C.SWORD_KNOCK, dy / d * C.SWORD_KNOCK)
		events.append("hit")
		landed = true
		_land(a, CombatRules.damage_foe(a.foe, C.SWORD_DAMAGE, C.SWORD_STUN))
	# A swing that lands (on one foe or several) costs its price once (5.3: Grace, the forbidden
	# thing); a miss, a parried blow, a bark or a block costs nothing.
	var cost: Dictionary = def.get("sword_cost", {})
	if landed and not cost.is_empty():
		events.append("sword_cost")
		ctx.apply(cost)
		if not _told.has("cost") and String(def.get("sword_cost_text", "")) != "":
			_told["cost"] = true
			ctx.notice(String(def["sword_cost_text"]), Color("#ff9a1f"))


## SHIELD: up for a moment (held: as long as it is held); raising it shoves whoever is in front.
func raise_shield() -> void:
	if not _armed("shield"):
		return
	guard_pulse = C.SHIELD_PULSE


func _land(a: StoryActor, result: String) -> void:
	if result == "none":
		return
	a.flash_hit()
	a.play_action("hurt", 0.3)
	ctx.play_sound("hit")
	if result != "routed":
		return
	routed += 1
	a.hostile = false
	a.flee(C.ROUT_SPEED, 99.0)
	var lines: Array = def.get("rout_lines", [])
	if not lines.is_empty():
		ctx.say_float(String(lines[(routed - 1) % lines.size()]), Vector2(a.gx, a.gy), Color("#ff9a1f"))
	ctx.play_sound("flee")
	events.append("routed")
	_show_health()


## One logic tick: the shield, the foes' swings, the hearts, the presentation timers.
func update(dt: float, guard_held: bool) -> void:
	var p := ctx.player
	strike_cd = maxf(0.0, strike_cd - dt)
	bark_cd = maxf(0.0, bark_cd - dt)
	guard_pulse = maxf(0.0, guard_pulse - dt)
	invuln = maxf(0.0, invuln - dt)
	swing = maxf(0.0, swing - dt / (C.SWORD_ACTION_TIME * 1.6))
	bark_ring = maxf(0.0, bark_ring - dt * 2.5)
	guarding = ctx.armed() and (guard_held or guard_pulse > 0.0)
	p.guarding = guarding
	if guarding:
		# Behind the shield he turns to the nearest threat (the shield faces it).
		_face_nearest(2.6)
		if not _was_guarding:
			ctx.play_sound("click")
			events.append("shield_up")
			# The bash: whoever stands right in front is shoved back (room, not an opening: the
			# opening is a blow taken on the shield).
			var f := _facing_vec()
			for a: StoryActor in foes:
				if a.foe == null or a.foe.routed:
					continue
				if not CombatRules.in_arc(p.gx, p.gy, f.x, f.y, a.gx, a.gy, C.SHIELD_BASH_RANGE, C.SHIELD_HALF_ARC):
					continue
				var dx := a.gx - p.gx
				var dy := a.gy - p.gy
				var d := JsMath.hypot(dx, dy)
				if d == 0.0:
					d = 1.0
				a.knock(dx / d * C.SHIELD_BASH_KNOCK, dy / d * C.SHIELD_BASH_KNOCK)
	_was_guarding = guarding
	if active() and not knocked:
		_update_foes(dt)


func _update_foes(dt: float) -> void:
	var p := ctx.player
	for a: StoryActor in foes:
		var f := a.foe
		if f == null or f.routed:
			continue
		var d := JsMath.hypot(a.gx - p.gx, a.gy - p.gy)
		var ev := CombatRules.step_foe(f, dt, d)
		if ev == "windup":
			a.play_action("bark", C.FOE_WINDUP)
		if ev != "strike" or d > C.FOE_REACH:
			continue
		var face := _facing_vec()
		if guarding and CombatRules.shield_blocks(p.gx, p.gy, face.x, face.y, a.gx, a.gy):
			ctx.play_sound("clang")
			CombatRules.stagger_foe(f, C.SHIELD_BLOCK_STUN)
			var l := d if d > 0.0 else 1.0
			a.knock((a.gx - p.gx) / l * C.SHIELD_BLOCK_KNOCK, (a.gy - p.gy) / l * C.SHIELD_BLOCK_KNOCK)
			ctx.say_float(ctx.ui_text("story_clang"), ctx.player_pos(), Color("#ffe23a"))
			events.append("blocked")
			continue
		if invuln > 0.0:
			continue
		health = maxi(0, health - 1)
		invuln = C.HURT_INVULN
		p.knockback(p.gx - a.gx, p.gy - a.gy, C.HURT_KNOCK)
		p.start_action("hurt", C.HURT_TIME)
		ctx.play_sound("hurt")
		ctx.shake(2.0)
		events.append("hurt")
		_show_health()
		if health <= 0:
			knocked = true
			events.append("knocked")
			return


## The fight is over (or abandoned): nobody stays a fighter; who was not routed stands idle.
func stop() -> void:
	if ctx == null:
		return
	if ctx.scene.world:
		ctx.player.guarding = false
	for a: StoryActor in foes:
		if not is_instance_valid(a):
			continue
		var was_routed := a.foe != null and a.foe.routed
		a.foe = null
		a.hostile = false
		a.knock(0.0, 0.0)
		if not was_routed:
			a.set_idle(true)
	if active():
		ctx.hud.clear_mode()
	guarding = false
