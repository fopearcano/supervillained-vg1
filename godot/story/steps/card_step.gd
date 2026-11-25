class_name CardStep
extends StoryStep
## Big centred text over a dimmed stage (src/story/steps.ts card): timed (`seconds`) or until a tap.

@export var big := ""
@export_multiline var small := ""
@export var color := Color("#ffe23a")
## 0 = wait for a tap.
@export var seconds := 0.0
@export var dim := 0.55
@export var sound := ""
@export var flash := false


func kind() -> String:
	return "card"


func texts() -> PackedStringArray:
	var out := PackedStringArray()
	for t in [big, small]:
		if t != "":
			out.append(t)
	return out


func sounds() -> PackedStringArray:
	return PackedStringArray([sound]) if sound != "" else PackedStringArray()


func check(errors: PackedStringArray) -> void:
	_need(errors, big.strip_edges() != "" or small.strip_edges() != "", "card %s without text" % id)
	_need(errors, seconds >= 0.0 and dim >= 0.0 and dim <= 1.0, "card %s: bad seconds or dim" % id)


func begin(ctx: StoryContext, st: Dictionary) -> void:
	st["t"] = 0.0
	ctx.hud.show_card(big, small, color, dim, seconds <= 0.0)
	ctx.play_sound(sound)
	if flash:
		ctx.flash()


func tick(ctx: StoryContext, st: Dictionary, dt: float) -> bool:
	st["t"] = float(st["t"]) + dt
	var tap := ctx.tapped(st, GameConfig.Story.CARD_GUARD)
	if seconds > 0.0:
		return float(st["t"]) >= seconds or tap
	return tap


func end(ctx: StoryContext, _st: Dictionary) -> void:
	ctx.hud.hide_card()
