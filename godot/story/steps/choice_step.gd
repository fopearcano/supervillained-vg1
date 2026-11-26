class_name ChoiceStep
extends StoryStep
## A choice: the speaker's prompt, then the options (StoryChoiceOption). Costly options lock when
## Commozione is short; if every option is locked they are all offered unlocked (no dead end).
## `once_each`: after an option's follow-up the choice is asked again (`prompt_again`) with the
## options not yet taken, until none remains.

@export var speaker := ""
@export_multiline var prompt := ""
@export_multiline var prompt_again := ""
## StoryChoiceOption Resources.
@export var options: Array = []
@export var once_each := false


func kind() -> String:
	return "choice"


func texts() -> PackedStringArray:
	var out := PackedStringArray([prompt])
	if prompt_again != "":
		out.append(prompt_again)
	for o: StoryChoiceOption in options:
		out.append(o.label)
		if o.said != "":
			out.append(o.said)
		if o.locked_text != "":
			out.append(o.locked_text)
	return out


func speakers() -> PackedStringArray:
	return PackedStringArray([speaker, "zampano"])


func effect_sets() -> Array:
	var out: Array = []
	for o: StoryChoiceOption in options:
		if not o.effects.is_empty():
			out.append(o.effects)
	return out


func branches() -> Array:
	var out: Array = []
	for o: StoryChoiceOption in options:
		out.append(o.then_steps)
	return out


func check(errors: PackedStringArray) -> void:
	_need(errors, speaker != "", "choice without a speaker")
	_need(errors, prompt.strip_edges() != "", "choice without a prompt")
	_need(errors, options.size() >= 2, "choice %s needs at least two options" % id)
	_need(errors, not once_each or prompt_again.strip_edges() != "", "once_each choice %s without prompt_again" % id)
	var ids: Array = []
	var lockable := 0
	for o: Variant in options:
		if not o is StoryChoiceOption:
			errors.append("choice %s: an option is not a StoryChoiceOption" % id)
			continue
		var opt: StoryChoiceOption = o
		_need(errors, opt.id != "" and not ids.has(opt.id), "choice %s: option ids must be set and unique" % id)
		ids.append(opt.id)
		_need(errors, opt.label.strip_edges() != "", "choice %s: option %s without a label" % [id, opt.id])
		_need(errors, opt.cost >= 0, "choice %s: option %s has a negative cost" % [id, opt.id])
		_need(errors, opt.locked_text == "" or not opt.requires.is_empty() or (opt.effects.is_empty() and opt.then_steps.is_empty()), "choice %s: option %s is permanently locked but has effects or steps (unreachable branch)" % [id, opt.id])
		if not opt.requires.is_empty():
			var why := StoryConditions.check(opt.requires)
			_need(errors, why == "", "choice %s: option %s: %s" % [id, opt.id, why])
			_need(errors, opt.locked_text != "", "choice %s: option %s with a condition needs its locked_text" % [id, opt.id])
		if opt.locked_text != "" or opt.cost > 0:
			lockable += 1
	_need(errors, options.is_empty() or lockable < options.size(), "choice %s: every option can be locked at once (all-locked dead end)" % id)


## Options still offered (once_each: the ones not taken yet in this run).
func open_options(ctx: StoryContext) -> Array:
	var taken: Array = ctx.choices_taken.get(id, [])
	return options.filter(func(o: StoryChoiceOption) -> bool: return not (once_each and taken.has(o.id)))


## What the player sees for each open option: its label (with the cost) or its lock. If every
## option is locked they are all offered unlocked (no dead end; source optionView/AskStep).
func views(ctx: StoryContext, open: Array) -> Array:
	var out: Array = []
	var commozione := float((ctx.state["meters"] as Dictionary)["commozione"])
	for o: StoryChoiceOption in open:
		if not o.requires.is_empty():
			out.append({"label": o.label, "locked": "" if StoryConditions.holds(ctx.state, o.requires) else o.locked_text})
		elif o.locked_text != "":
			out.append({"label": o.label, "locked": o.locked_text})
		elif o.cost > 0 and commozione < o.cost:
			out.append({"label": o.label, "locked": ctx.ui_text("story_too_unmoved") % o.cost})
		elif o.cost > 0:
			out.append({"label": o.label + ctx.ui_text("story_cost_suffix") % o.cost, "locked": ""})
		else:
			out.append({"label": o.label, "locked": ""})
	if out.all(func(v: Dictionary) -> bool: return String(v["locked"]) != ""):
		out = open.map(func(o: StoryChoiceOption) -> Dictionary: return {"label": o.label, "locked": o.locked_text})
	return out


func begin(ctx: StoryContext, st: Dictionary) -> void:
	st["t"] = 0.0
	st["phase"] = "typing"
	st["open"] = open_options(ctx)
	var again: bool = (ctx.choices_taken.get(id, []) as Array).size() > 0
	ctx.hud.show_line(ctx.cast.display_name(speaker), ctx.cast.color(speaker), ctx.portrait_of(speaker), prompt_again if again and prompt_again != "" else prompt)
	ctx.speaking_gesture(speaker)


func tick(ctx: StoryContext, st: Dictionary, dt: float) -> bool:
	st["t"] = float(st["t"]) + dt
	if st["phase"] == "typing":
		if ctx.hud.typing and ctx.tapped(st, GameConfig.Story.LINE_GUARD):
			ctx.hud.finish_typing()
		if not ctx.hud.typing and float(st["t"]) > GameConfig.Story.CHOICE_DELAY:
			st["phase"] = "choosing"
			st["views"] = views(ctx, st["open"])
			ctx.hud.set_choices(st["views"])
		return false
	var pick := ctx.hud.read_choice()
	if pick < 0:
		return false
	AudioService.play(&"click")
	var lock := String((st["views"][pick] as Dictionary)["locked"])
	if lock != "":
		ctx.notice(lock, PixelText.RED)
		return false
	var o: StoryChoiceOption = (st["open"] as Array)[pick]
	# The cost is spent only when he has it (source spend(): an all-locked fallback pick is free).
	if o.cost > 0 and float((ctx.state["meters"] as Dictionary)["commozione"]) >= o.cost:
		ctx.apply({"commozione": -o.cost})
	(ctx.metrics["choices"] as Array).append("%s:%s" % [id, o.id])
	var taken: Array = ctx.choices_taken.get(id, [])
	taken.append(o.id)
	ctx.choices_taken[id] = taken
	if not o.effects.is_empty():
		ctx.apply(o.effects)
	var follow: Array = []
	if not o.silent:
		var line := DialogueStep.new()
		line.id = "%s.%s.said" % [id, o.id]
		line.speaker = "zampano"
		line.text = o.said if o.said != "" else o.label
		follow.append(line)
	follow.append_array(o.then_steps)
	if once_each and open_options(ctx).size() > 0:
		follow.append(self)
	ctx.insert(follow)
	return true


func end(ctx: StoryContext, _st: Dictionary) -> void:
	ctx.hud.hide_line()
