class_name StoryChapterData
extends Resource
## One level of the campaign (STORY_REWRITE_SPEC.md §5.2): its metadata, the level card, the
## Professor's level-end aside and its scripted scenes in catalog order (1.0, the Green Zone walk,
## is not a story scene and is not listed).

@export var number := 0
@export var title := ""
@export var menu_title := ""
## The level card text.
@export_multiline var intro := ""
## Who plays whom (tools only, never on a player card).
@export var cast_note := ""
@export var music := ""
## The Professor's aside shown after the level's last scene.
@export_multiline var professor_aside := ""
## The ordered StorySceneData Resources.
@export var scenes: Array = []
@export var content_version := 1
@export var review_status := ""
@export var review_notes: PackedStringArray = []


func scene(id: String) -> StorySceneData:
	for s: StorySceneData in scenes:
		if s.id == id:
			return s
	return null
