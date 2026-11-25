class_name ObjectiveRule
extends RefCounted
## A scene rule an ObjectiveStep runs (STORY_REWRITE_SPEC.md §5.3): real-time behaviour a generic
## objective cannot express, parameterised by the step's `rule_params` (numbers, places) and
## `rule_lines` (every line it shows). One instance per objective run; its state lives in the
## step's run dictionary `st`.

## Lines spoken by characters on the lawn (src/campaign/chapters/ch1.ts colours).
const JACK_COLOR := Color("#f0b060")
const WINDOW_COLOR := Color("#f0d8a0")


func begin(_ctx: StoryContext, _step: ObjectiveStep, _st: Dictionary) -> void:
	pass


## True when the rule completes the objective.
func tick(_ctx: StoryContext, _step: ObjectiveStep, _st: Dictionary, _dt: float) -> bool:
	return false


## The objective's action button was pressed.
func on_action(_ctx: StoryContext, _step: ObjectiveStep, _st: Dictionary) -> void:
	pass


func end(_ctx: StoryContext, _step: ObjectiveStep, _st: Dictionary) -> void:
	pass


## Keeps the player out of a grid rectangle (someone standing in a gap): pushes him back to the
## side he came from. True when he was pushed this tick.
static func keep_out(ctx: StoryContext, gap: Rect2) -> bool:
	var dog := ctx.player
	var r := GameConfig.Player.RADIUS
	var hit := dog.gx + r > gap.position.x and dog.gx - r < gap.end.x and dog.gy + r > gap.position.y and dog.gy - r < gap.end.y
	if not hit:
		return false
	var x := gap.position.x - r - 0.01 if dog.gx < gap.get_center().x else gap.end.x + r + 0.01
	dog.gx = x
	dog.vx = 0.0
	dog.set_grid_position(x, dog.gy)
	return true
