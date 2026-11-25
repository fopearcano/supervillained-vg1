class_name JackGateRule
extends ObjectiveRule
## 1.2: Jack stands in the gap between two garden gates (`rule_params.gap`, grid rectangle) and lets
## every dog through but Zampanò (RD-19).
## Success: bark near him (`range`) — he echoes each bark (`rule_lines.echo`); at `heads_at` echoes
## heads pop up along the fences (`heads`); at `echo_open` the Professor's window creaks
## (`rule_lines.creak` at `creak_point`) and the gap opens.
## Failure and recovery: pushing into him is one bump per GameConfig.Story.BUMP_EVERY ("NOPE!",
## `rule_lines.nope`); at the counts in `hint_bumps` a hint (`rule_lines.hint`); at `recover_bumps`
## the window creaks anyway — nobody stays stuck.

const S := GameConfig.Story


func begin(_ctx: StoryContext, _step: ObjectiveStep, st: Dictionary) -> void:
	st["echoes"] = 0
	st["bumps"] = 0
	st["open"] = false
	st["cool"] = 0.0
	st["heads"] = false


func on_action(ctx: StoryContext, step: ObjectiveStep, st: Dictionary) -> void:
	if st["open"]:
		return
	var jack := ctx.actor(String(step.rule_params["blocker"]))
	if jack == null:
		return
	if Vector2(jack.gx, jack.gy).distance_to(ctx.player_pos()) > float(step.rule_params["range"]):
		return
	st["echoes"] = int(st["echoes"]) + 1
	ctx.metrics["echoes"] = st["echoes"]
	var lines: Array = step.rule_lines["echo"]
	ctx.say_float(String(lines[mini(int(st["echoes"]) - 1, lines.size() - 1)]), Vector2(jack.gx, jack.gy), JACK_COLOR)
	jack.play_action("bark", 0.5)
	if int(st["echoes"]) == int(step.rule_params["heads_at"]) and not st["heads"]:
		_heads(ctx, step, st)
	if int(st["echoes"]) >= int(step.rule_params["echo_open"]):
		_open(ctx, step, st)


func tick(ctx: StoryContext, step: ObjectiveStep, st: Dictionary, dt: float) -> bool:
	if st["open"]:
		return true
	st["cool"] = maxf(0.0, float(st["cool"]) - dt)
	if not keep_out(ctx, step.rule_params["gap"]):
		return false
	if float(st["cool"]) > 0.0:
		return false
	st["cool"] = S.BUMP_EVERY
	st["bumps"] = int(st["bumps"]) + 1
	ctx.metrics["bumps"] = st["bumps"]
	var jack := ctx.actor(String(step.rule_params["blocker"]))
	if jack:
		ctx.say_float(String(step.rule_lines["nope"]), Vector2(jack.gx, jack.gy), JACK_COLOR)
		jack.play_action("bark", 0.4)
	if (step.rule_params["hint_bumps"] as Array).has(int(st["bumps"])):
		ctx.notice(String(step.rule_lines["hint"]), PixelText.ORANGE)
	if int(st["bumps"]) >= int(step.rule_params["recover_bumps"]):
		_open(ctx, step, st)
	return false


func _heads(ctx: StoryContext, step: ObjectiveStep, st: Dictionary) -> void:
	st["heads"] = true
	for h: Dictionary in step.rule_params.get("heads", []):
		var a := ctx.scene.spawn_actor(String(h["name"]), String(h["role"]), ctx.marker(String(h["at"])), "S")
		if a:
			a.face_point(ctx.player_pos())
			a.play_action("bark", 0.6)


func _open(ctx: StoryContext, step: ObjectiveStep, st: Dictionary) -> void:
	st["open"] = true
	ctx.say_float(String(step.rule_lines["creak"]), step.rule_params["creak_point"], WINDOW_COLOR)
