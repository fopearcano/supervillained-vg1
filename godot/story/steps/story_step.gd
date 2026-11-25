class_name StoryStep
extends Resource
## Base of every story step (docs/porting/STORY_REWRITE_SPEC.md §5.3). A step is data: its
## Resource holds every player-visible string; its script holds execution logic only.
##
## Execution contract (StoryRunner): begin(ctx, st) once, then tick(ctx, st, dt) every logic tick
## until it returns true, then end(ctx, st). Per-run state lives in the Dictionary `st` the runner
## owns, never on the Resource, so one loaded Resource can run any number of times (restart,
## replay) without leaking state. A step may queue follow-up steps through ctx.insert().
##
## Schema contract (StoryValidator): the introspection methods below describe what the step
## references and writes; check() reports field errors.

## Stable within its scene (unique; restart, metrics and the drivers refer to it).
@export var id := ""


func kind() -> String:
	return "step"


# --- Schema (StoryValidator) --------------------------------------------------------------------

## Player-visible strings.
func texts() -> PackedStringArray:
	return PackedStringArray()


func speakers() -> PackedStringArray:
	return PackedStringArray()


## Map markers the step refers to on the current stage.
func marker_refs() -> PackedStringArray:
	return PackedStringArray()


## Effect dictionaries the step may apply.
func effect_sets() -> Array:
	return []


## Nested step lists (a choice's branches).
func branches() -> Array:
	return []


func sounds() -> PackedStringArray:
	return PackedStringArray()


## Sprite catalogue keys.
func sprites() -> PackedStringArray:
	return PackedStringArray()


## Cast roles (SpriteFrames) the step instantiates.
func roles() -> PackedStringArray:
	return PackedStringArray()


## Actor handles the step defines (spawns) and uses.
func actor_defs() -> PackedStringArray:
	return PackedStringArray()


func actor_refs() -> PackedStringArray:
	return PackedStringArray()


## The map a stage step loads ("" for every other step).
func stage_map() -> String:
	return ""


## Field checks; appends readable errors.
func check(_errors: PackedStringArray) -> void:
	pass


static func _need(errors: PackedStringArray, ok: bool, what: String) -> void:
	if not ok:
		errors.append(what)
