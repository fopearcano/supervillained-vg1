class_name StorySceneData
extends Resource
## One scripted catalog entry (1.1–8.4): the rewrite's content authority for that scene
## (docs/porting/STORY_REWRITE_SPEC.md §5.1). Every line the player reads is in `steps`; no
## execution script holds narrative text. Validated by StoryValidator.

## Stable catalog ID ("1.3"); save data (campaign.completed), never renamed.
@export var id := ""
## Raised whenever the scene's player-visible content changes.
@export var content_version := 1
@export var title := ""
## The PixiJS draft title (tools only).
@export var old_title := ""
## Chapter number.
@export var level := 0
## The scene card text (what happens).
@export_multiline var summary := ""
## StoryMapData id of the first stage.
@export var map := ""
## AudioService music key.
@export var music := ""
## Speaker ids the scene uses (each must be in the StoryCast).
@export var cast: PackedStringArray = []
## The ordered StoryStep Resources.
@export var steps: Array = []
## {"requires_completed": [ids], "requires_abilities": [ids]}.
@export var entry_conditions: Dictionary = {}
## Declared effect keys the scene may write: "meter.<name>", "flags.<name>", "book.<key>",
## "unlock.<ability>", "coins".
@export var persistent_effects: PackedStringArray = []
## {"boundary": "scene"|"sleep"|"chapter_end", "requires_flags": [names], "requires_abilities": [ids]}.
@export var completion: Dictionary = {}
## Reality scene (Levels 1 and 8): plain skin, no armour, no dream capability.
@export var reality := false
## Event/place tags and short source references (docs/STORY-SOURCES.md); tools only.
@export var historical_tags: PackedStringArray = []
@export var source_refs: PackedStringArray = []
## "draft_reference" | "draft_implemented_review_pending" | "narrative_approved".
@export var review_status := ""
## Every REVIEW REQUIRED item and review remark.
@export var review_notes: PackedStringArray = []
## Technical status (STORY_REWRITE_SPEC.md §4).
@export var technical_status := ""


## Why the scene cannot start from `state` ("" = it can): every `entry_conditions.requires_completed`
## id completed and every `requires_abilities` ability held. Reality scenes need no ability rule
## here: `reality` alone keeps them plain (spec §2.4).
func entry_failure(state: Dictionary) -> String:
	var done: Array = state.get("completed", [])
	for req: String in entry_conditions.get("requires_completed", []):
		if not done.has(req):
			return "entry condition: %s is not completed" % req
	var held: Array = state.get("abilities", [])
	for a: String in entry_conditions.get("requires_abilities", []):
		if not held.has(a):
			return "entry condition: the ability '%s' is not held" % a
	return ""
