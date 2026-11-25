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
		_need(errors, opt.locked_text == "" or (opt.effects.is_empty() and opt.then_steps.is_empty()), "choice %s: option %s is permanently locked but has effects or steps (unreachable branch)" % [id, opt.id])
		if opt.locked_text != "" or opt.cost > 0:
			lockable += 1
	_need(errors, options.is_empty() or lockable < options.size(), "choice %s: every option can be locked at once (all-locked dead end)" % id)
