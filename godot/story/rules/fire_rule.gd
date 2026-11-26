class_name FireRule
extends ObjectiveRule
## 7.5: a fire that spreads through the streets (port of src/story/walk.ts updateFire). After
## `start_after` seconds of the walk the fire starts at the marker `from` (its card shows for two
## seconds without stopping the walk); every `spread_every` seconds `per_tick` burning tiles each set a
## neighbour alight, drawn from the scene's seeded generator (a run and its restart are the same). A
## blocked tile, the goal, the walk's start and every checkpoint (ObjectiveStep.checkpoints) never
## burn: they are safe. Stepping into a burning tile pushes him back toward the restart point (the
## last checkpoint passed, else the start) with HOT!; `breaths` burns and the smoke takes him: the
## card, then he is back at the last checkpoint with the `escort` beside him and the fire back at
## its start. The fire applies nothing: the walk's state persists only when the scene completes.
## Lines (rule_lines): fire_big, fire_small (the start card), hot, label (the breath gauge),
## out_big, out_small (the smoke's restart card).

const S := GameConfig.Story
const GAUGE := Color("#ff7a1f")
const CARD := Color("#ff9a1f")


func begin(ctx: StoryContext, step: ObjectiveStep, st: Dictionary) -> void:
	_reset(ctx, st)
	st["fire_restarts"] = 0
	st["safe"] = _safe(ctx, step, st)


func _reset(ctx: StoryContext, st: Dictionary) -> void:
	for k: Vector2i in st.get("fire", {}):
		ctx.scene.remove_prop(_handle(k))
	st["fire"] = {}
	st["fire_order"] = []
	st["fire_on"] = false
	st["fire_wait"] = 0.0
	st["spread_t"] = 0.0
	st["anim_t"] = 0.0
	st["hot_t"] = 0.0
	st["burns"] = 0
	st["card_t"] = 0.0


func _safe(ctx: StoryContext, step: ObjectiveStep, st: Dictionary) -> Dictionary:
	var out := {}
	var pts: Array = [st["start"]]
	if st.get("goal") != null:
		pts.append(st["goal"])
	for c: String in step.checkpoints:
		pts.append(ctx.marker(c))
	for p: Vector2 in pts:
		out[Vector2i(floori(p.x), floori(p.y))] = true
	return out


static func _handle(k: Vector2i) -> String:
	return "fire_%d_%d" % [k.x, k.y]


## True when the tile is burning (the driver and the tests read it).
static func burning(st: Dictionary, p: Vector2) -> bool:
	return (st.get("fire", {}) as Dictionary).has(Vector2i(floori(p.x), floori(p.y)))


func _ignite(ctx: StoryContext, st: Dictionary, k: Vector2i) -> void:
	var map := ctx.world.map
	if k.x < 0 or k.y < 0 or k.x >= map.width or k.y >= map.height or map.is_blocked_tile(k.x, k.y):
		return
	var pr := map.prop_at(k.x, k.y)
	if pr != null and pr.solid:
		return
	if (st["safe"] as Dictionary).has(k) or (st["fire"] as Dictionary).has(k):
		return
	st["fire"][k] = true
	(st["fire_order"] as Array).append(k)
	ctx.scene.place_prop(_handle(k), "flame_%d" % ((k.x + k.y) % 3), Vector2(k.x + 0.5, k.y + 0.5), Color.WHITE)


func tick(ctx: StoryContext, step: ObjectiveStep, st: Dictionary, dt: float) -> bool:
	if float(st["card_t"]) > 0.0:
		st["card_t"] = float(st["card_t"]) - dt
		if float(st["card_t"]) <= 0.0:
			ctx.hud.hide_card()
	if not st["fire_on"]:
		st["fire_wait"] = float(st["fire_wait"]) + dt
		if float(st["fire_wait"]) < float(step.rule_params["start_after"]):
			return false
		st["fire_on"] = true
		var at := ctx.marker(String(step.rule_params["from"]))
		_ignite(ctx, st, Vector2i(floori(at.x), floori(at.y)))
		ctx.hud.show_card(String(step.rule_lines["fire_big"]), String(step.rule_lines["fire_small"]), CARD, 0.2, false)
		st["card_t"] = 2.0
		ctx.play_sound("siren")
		(ctx.metrics.get_or_add("fire", []) as Array).append(step.id)
		return false
	st["spread_t"] = float(st["spread_t"]) - dt
	if float(st["spread_t"]) <= 0.0:
		st["spread_t"] = float(step.rule_params["spread_every"])
		var order: Array = st["fire_order"]
		var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		for n in int(step.rule_params["per_tick"]):
			if order.is_empty():
				break
			var k: Vector2i = order[ctx.rng.randi() % order.size()]
			_ignite(ctx, st, k + (dirs[ctx.rng.randi() % 4] as Vector2i))
	# The flames flicker (three frames).
	st["anim_t"] = float(st["anim_t"]) + dt
	if float(st["anim_t"]) >= 0.125:
		st["anim_t"] = 0.0
		var f := int(floor(float(st["t"]) * 8.0))
		for k: Vector2i in st["fire"]:
			var pr: StoryProp = ctx.scene.props.get(_handle(k))
			if pr:
				pr.set_key(ctx.world.catalog, "flame_%d" % ((f + k.x) % 3))
	ctx.hud.set_mode(String(step.rule_lines["label"]), 1.0 - float(st["burns"]) / float(step.rule_params["breaths"]), GAUGE)
	st["hot_t"] = float(st["hot_t"]) - dt
	var p := ctx.player_pos()
	if float(st["hot_t"]) <= 0.0 and burning(st, p):
		st["hot_t"] = S.FIRE_HURT_TIME
		var back: Vector2 = st["start"]
		ctx.player.knockback(back.x - p.x, back.y - p.y, S.FIRE_KNOCKBACK)
		ctx.player.start_action("hurt", S.FIRE_HURT_TIME)
		ctx.notice(String(step.rule_lines["hot"]), Color("#ff3b3b"))
		ctx.play_sound("hurt")
		st["burns"] = int(st["burns"]) + 1
		(ctx.metrics.get_or_add("burns", []) as Array).append(step.id)
		if int(st["burns"]) >= int(step.rule_params["breaths"]):
			st["rule_restart"] = {"big": String(step.rule_lines["out_big"]), "small": String(step.rule_lines["out_small"])}
			(ctx.metrics.get_or_add("smoke", []) as Array).append(step.id)
	return false


## The smoke took him: back at the last checkpoint (ObjectiveStep already put him at st.start), the
## escort beside him, the fire out and starting again from its origin.
func restart(ctx: StoryContext, step: ObjectiveStep, st: Dictionary) -> void:
	_reset(ctx, st)
	st["fire_restarts"] = int(st["fire_restarts"]) + 1
	var e := ctx.actor(String(step.rule_params.get("escort", "")))
	if e:
		var p := ctx.player_pos()
		e.set_grid_position(p.x + 0.8, p.y + 0.4)


func end(ctx: StoryContext, _step: ObjectiveStep, st: Dictionary) -> void:
	_reset(ctx, st)
	ctx.hud.clear_mode()
