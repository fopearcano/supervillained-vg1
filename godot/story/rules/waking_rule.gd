class_name WakingRule
extends ObjectiveRule
## 8.1: waking (port of src/story/walk.ts updateScramble and the 8.1 onUpdate). His legs do not do
## what he tells them: every `every` seconds the joystick turns by one of `angles` (degrees, drawn
## from the scene's seeded generator) with a notice and the glitch; once the goal is within
## `settle_at` of the way from the start, the controls settle for good (StoryContext.scramble_angle
## back to 0, a notice). The knock pops up at `knock_near` while he is below `knock_y` on the map and
## at `knock_far` above it; the smell of his cushion floats at `smell`; JERUSALEM floats at a point
## that moves one step away whenever he comes within 2.2 tiles of it (never reachable). Lines
## (rule_lines): scramble, settle, knock, smell, jerusalem, jerusalem_moves.

const SCRAMBLE_COLOR := Color("#b070ff")
const PINK := Color("#f6c0e0")


func begin(ctx: StoryContext, step: ObjectiveStep, st: Dictionary) -> void:
	st["scramble_t"] = 0.0
	st["settled"] = false
	st["knock_t"] = 0.0
	st["smell_t"] = 0.0
	st["jt"] = 0.0
	st["jerusalem"] = step.rule_params["jerusalem"]
	ctx.scramble_angle = 0.0


func tick(ctx: StoryContext, step: ObjectiveStep, st: Dictionary, dt: float) -> bool:
	var p := ctx.player_pos()
	if not st["settled"]:
		var start: Vector2 = st["start"]
		var goal: Vector2 = st["goal"]
		var total := maxf(start.distance_to(goal), 0.001)
		if p.distance_to(goal) / total < float(step.rule_params["settle_at"]):
			st["settled"] = true
			ctx.scramble_angle = 0.0
			ctx.notice(String(step.rule_lines["settle"]), PixelText.GREEN)
			(ctx.metrics.get_or_add("scramble", []) as Array).append("settled")
		else:
			st["scramble_t"] = float(st["scramble_t"]) - dt
			if float(st["scramble_t"]) <= 0.0:
				st["scramble_t"] = float(step.rule_params["every"])
				var angles: Array = step.rule_params["angles"]
				var deg := float(angles[ctx.rng.randi() % angles.size()])
				ctx.scramble_angle = deg_to_rad(deg)
				ctx.notice(String(step.rule_lines["scramble"]), SCRAMBLE_COLOR)
				ctx.play_sound("glitch")
				(ctx.metrics.get_or_add("scramble", []) as Array).append(deg)
	# The knock: near or far by where he is.
	st["knock_t"] = float(st["knock_t"]) - dt
	if float(st["knock_t"]) <= 0.0:
		st["knock_t"] = float(step.rule_params["knock_every"])
		var m := String(step.rule_params["knock_near"] if p.y > float(step.rule_params["knock_y"]) else step.rule_params["knock_far"])
		ctx.say_float(String(step.rule_lines["knock"]), ctx.marker(m), PixelText.YELLOW)
	st["smell_t"] = float(st["smell_t"]) - dt
	if float(st["smell_t"]) <= 0.0:
		st["smell_t"] = 1.2
		ctx.say_float(String(step.rule_lines["smell"]), ctx.marker(String(step.rule_params["smell"])), Color("#a050e0"))
	# Jerusalem: always one step away.
	var j: Vector2 = st["jerusalem"]
	if p.distance_to(j) < 2.2:
		st["jerusalem"] = Vector2(10.5 if p.x < 8.0 else 5.5, maxf(4.5, p.y - 4.0))
		ctx.notice(String(step.rule_lines["jerusalem_moves"]), PINK)
		(ctx.metrics.get_or_add("jerusalem_moves", []) as Array).append(st["jerusalem"])
	st["jt"] = float(st["jt"]) - dt
	if float(st["jt"]) <= 0.0:
		st["jt"] = 1.6
		ctx.say_float(String(step.rule_lines["jerusalem"]), st["jerusalem"], PINK)
	return false


func end(ctx: StoryContext, _step: ObjectiveStep, _st: Dictionary) -> void:
	ctx.scramble_angle = 0.0
