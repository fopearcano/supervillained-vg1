class_name StoryActionRouter
extends RefCounted
## What each action input does during a story walk (port of src/story/walk.ts `perform` and
## StoryScene.actionMode). The router only decides which mode to perform; the objective performs it.
##
## Modes: "scene" (the objective's own action: SNIFF, LOOK, VOW, or a scene's own BARK with its
## rule), "bark" (a plain bark), and "sword" and "shield" (M6 combat), offered only while the
## campaign's capability permits (StoryContext.armed(): a dream scene with `knight` held, from the
## authored point of 2.3). A walk with its own action offers ["scene", "bark"] (+ the arms); a walk
## without one offers ["bark"] (+ the arms). The switcher cycles only these valid modes.
##
## Inputs, every tick of a walk (source order):
##   switch  (Q/Tab, the switcher button, a gesture bound to SWITCH) -> the next mode;
##   action  (J/X, the round touch button, a gesture bound to ACTION) -> the selected mode;
##   pee     (Space)                                                  -> "scene", always;
##   bark    (B, a gesture bound to BARK, the default double tap)     -> "bark", directly;
##   strike / guard (U / I, the default swipes up / down)             -> "sword" / "shield",
##                                                                      directly (without the
##                                                                      capability the walk only
##                                                                      shows that he has no arms).

## Modes combat adds (knights in the dream); never offered in reality.
const COMBAT_MODES := ["sword", "shield"]

var modes: PackedStringArray = PackedStringArray(["bark"])
var mode := "bark"
## The objective's own action label ("" = none) and the plain bark's label (ShellText).
var scene_label := ""
var bark_label := ""
var sword_label := ""
var shield_label := ""


## Sets the modes for a walk: its own action first (when it has one), then the plain bark, then
## (`combat`: the knight's capability) the sword and the shield.
func configure(p_scene_label: String, p_bark_label: String, combat: bool = false, p_sword_label: String = "", p_shield_label: String = "") -> void:
	scene_label = p_scene_label
	bark_label = p_bark_label
	sword_label = p_sword_label
	shield_label = p_shield_label
	modes = PackedStringArray()
	if scene_label != "":
		modes.append("scene")
	modes.append("bark")
	if combat:
		modes.append_array(PackedStringArray(COMBAT_MODES))
	mode = modes[0]


## The action button's label in the selected mode.
func label() -> String:
	match mode:
		"scene":
			return scene_label
		"sword":
			return sword_label
		"shield":
			return shield_label
	return bark_label


func index() -> int:
	return modes.find(mode)


## The action button's next mode; false when there is only one.
func cycle() -> bool:
	if modes.size() < 2:
		return false
	mode = modes[(modes.find(mode) + 1) % modes.size()]
	return true


## Reads this tick's action inputs: {"switched": bool, "perform": [mode, ...]} in the source's order.
func poll() -> Dictionary:
	var out: Array[String] = []
	var switched := false
	if InputService.consume(&"switch"):
		switched = cycle()
	if InputService.consume(&"action"):
		out.append(mode)
	if InputService.consume(&"pee"):
		out.append("scene" if modes.has("scene") else "bark")
	if InputService.consume(&"bark"):
		out.append("bark")
	if InputService.consume(&"strike"):
		out.append("sword")
	if InputService.consume(&"guard"):
		out.append("shield")
	return {"switched": switched, "perform": out}
