class_name StoryMapData
extends Resource
## A story stage map: ASCII rows in the shared legend (TileCatalog.LEGEND; digits are named
## markers used by the scene steps, `S` the player's start), the base ground symbol, and the
## environment bank the world draws it with. Maps are established data: ported verbatim from
## src/story/maps.ts STORY_MAPS (the test compares them with the executed-source fixture).

@export var id := ""
@export var rows: PackedStringArray = []
@export var base := "."
## Source theme key (src/story/maps.ts THEMES).
@export var theme := ""
## Environment bank (tile set and sprite catalogue) the stage is drawn with.
@export var environment := "ch01_greenzone"


## Parses the rows (no exit required). {"ok", "level" | "error"}.
func parse() -> Dictionary:
	return AsciiMapLoader.parse(rows, base, false)


## Marker ids ("0"–"9" and "S") of the map.
func marker_ids() -> PackedStringArray:
	var p := parse()
	var out := PackedStringArray(["S"])
	if p["ok"]:
		for k: String in (p["level"] as Dictionary).get("markers", {}):
			out.append(k)
	return out
