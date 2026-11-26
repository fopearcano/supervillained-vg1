class_name ShoulderRule
extends ObjectiveRule
## 7.3: stay level with Pierre's shoulder (port of the 7.3 walk, STORY.SHOULDER). Progress is measured
## along the march from `from` to `to`; he is level when his progress is within `band` of Pierre's and
## he is within `side` tiles of the line through Pierre. Nerve (the gauge) gains `gain` per second while
## level and loses `lose` while not, with a notice every 2.4 s saying why (ahead, behind, aside); at no
## nerve the walk is OUT OF STEP: the card, then both back at the start (restart()). Along the way: the
## grooms and cooks join (a notice at `pots_at` of the march), Flanders rejoins (`rejoin_actor` falls in
## beside Pierre at `rejoin_at`), and the woman at the window speaks (her words float, from
## `window_from`). Complete at 95 % of the march while level. Every line is in rule_lines.

const GAUGE := Color("#ff7a1f")


func begin(ctx: StoryContext, step: ObjectiveStep, st: Dictionary) -> void:
	st["nerve"] = 1.0
	st["warn_t"] = 0.0
	st["pots"] = false
	st["rejoined"] = false
	st["window_t"] = 1.5
	st["restarts"] = 0


func _axis(ctx: StoryContext, step: ObjectiveStep) -> Array:
	var s0 := ctx.marker(String(step.rule_params["from"]))
	var g := ctx.marker(String(step.rule_params["to"]))
	var length := s0.distance_to(g)
	return [s0, (g - s0) / maxf(length, 0.001), length]


func tick(ctx: StoryContext, step: ObjectiveStep, st: Dictionary, dt: float) -> bool:
	var lead := ctx.actor(String(step.rule_params["leader"]))
	if lead == null:
		return true
	var ax := _axis(ctx, step)
	var s0: Vector2 = ax[0]
	var f: Vector2 = ax[1]
	var length: float = ax[2]
	var p := ctx.player_pos()
	var l := Vector2(lead.gx, lead.gy)
	var diff := (p - s0).dot(f) - (l - s0).dot(f)
	var side := absf((p.x - l.x) * f.y - (p.y - l.y) * f.x)
	var level := absf(diff) < float(step.rule_params["band"]) and side < float(step.rule_params["side"])
	st["level"] = level
	st["nerve"] = clampf(float(st["nerve"]) + (float(step.rule_params["gain"]) if level else -float(step.rule_params["lose"])) * dt, 0.0, 1.0)
	st["warn_t"] = float(st["warn_t"]) - dt
	if not level and float(st["warn_t"]) <= 0.0:
		st["warn_t"] = 2.4
		var why := "ahead" if diff > 0.0 else ("side" if side >= float(step.rule_params["side"]) else "behind")
		ctx.notice(String(step.rule_lines[why]), Color("#ff9a1f"))
		(ctx.metrics.get_or_add("pace", []) as Array).append(why)
	ctx.hud.set_mode(String(step.rule_lines["label"]), float(st["nerve"]), GAUGE)
	var done := (l - s0).dot(f) / length
	if not st["pots"] and done > float(step.rule_params["pots_at"]):
		st["pots"] = true
		ctx.notice(String(step.rule_lines["pots"]), Color("#ffe23a"))
	if not st["rejoined"] and done > float(step.rule_params["rejoin_at"]):
		st["rejoined"] = true
		var r := ctx.actor(String(step.rule_params["rejoin_actor"]))
		if r:
			r.follow_actor = lead
			r.follow_gap = 2.4
			r.follow(3.0, -1.2)
		ctx.notice(String(step.rule_lines["rejoin"]), Color("#3ff0ff"))
	st["window_t"] = float(st["window_t"]) - dt
	if float(st["window_t"]) <= 0.0 and done > float(step.rule_params["window_from"]):
		st["window_t"] = 2.2
		var w := ctx.actor(String(step.rule_params["window_actor"]))
		if w:
			ctx.say_float(String(step.rule_lines["window"]), Vector2(w.gx, w.gy), Color("#c8a0ff"))
	if float(st["nerve"]) <= 0.0:
		st["rule_restart"] = {"big": String(step.rule_lines["out_big"]), "small": String(step.rule_lines["out_small"])}
		(ctx.metrics.get_or_add("nerve_broken", []) as Array).append(step.id)
		return false
	return done > 0.95 and level


## Out of step: both back at the start, nerve full; Pierre marches again.
func restart(ctx: StoryContext, step: ObjectiveStep, st: Dictionary) -> void:
	var s0 := ctx.marker(String(step.rule_params["from"]))
	var g := ctx.marker(String(step.rule_params["to"]))
	ctx.player.set_grid_position(s0.x, s0.y)
	var lead := ctx.actor(String(step.rule_params["leader"]))
	if lead:
		lead.set_grid_position(s0.x - 1.0, s0.y)
		lead.go_to(Vector2(g.x - 1.0, g.y), float(step.rule_params["speed"]))
	ctx.world.snap_camera()
	st["nerve"] = 1.0
	st["restarts"] = int(st["restarts"]) + 1


func end(ctx: StoryContext, _step: ObjectiveStep, _st: Dictionary) -> void:
	ctx.hud.clear_mode()
