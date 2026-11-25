class_name StoryCatalog
extends Resource
## The campaign's scene catalog as data: level numbers and titles, sub-level ids and titles, and
## which sub-level is the Green Zone walk. Generated from the source catalog
## (src/campaign/chapters CHAPTERS) by tools/source_extract and tools/build_resources.gd; no story
## scripts or prose. A later story rewrite replaces this resource, not the save or title code.

## [{"number": int, "title": String, "menu_title": String,
##   "sub_levels": [{"id": String, "title": String, "green_zone": int (0 = a story scene)}]}]
@export var chapters: Array = []


func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for ch: Dictionary in chapters:
		for s: Dictionary in ch["sub_levels"]:
			out.append(String(s["id"]))
	return out


func has_id(id: String) -> bool:
	return ids().has(id)


func chapter(number: int) -> Dictionary:
	for ch: Dictionary in chapters:
		if int(ch["number"]) == number:
			return ch
	return {}


## {"chapter": Dictionary, "index": int, "sub": Dictionary} or {} (source findSubLevel).
func find(id: String) -> Dictionary:
	for ch: Dictionary in chapters:
		var subs: Array = ch["sub_levels"]
		for k in subs.size():
			if subs[k]["id"] == id:
				return {"chapter": ch, "index": k, "sub": subs[k]}
	return {}


## The first unfinished sub-level in story order: {"level", "id", "title"}, or {} when finished.
func next_unfinished(completed: Array) -> Dictionary:
	for ch: Dictionary in chapters:
		for s: Dictionary in ch["sub_levels"]:
			if not completed.has(s["id"]):
				return {"level": int(ch["number"]), "id": String(s["id"]), "title": String(s["title"])}
	return {}


## Where CONTINUE goes (source StoryFlow.nextLabel): "LEVEL 1: 1.0 THE GREEN ZONE", or "".
func continue_label(completed: Array) -> String:
	var n := next_unfinished(completed)
	if n.is_empty():
		return ""
	return "LEVEL %d: %s %s" % [n["level"], n["id"], String(n["title"]).to_upper()]


## The sub-level is playable in this build: the Green Zone walk, or a story scene whose rewritten
## Resource exists (data/story/scenes/<id>.tres, M5R); the others show the "not in this build" card.
func playable_in_build(id: String) -> bool:
	var f := find(id)
	if f.is_empty():
		return false
	return int(f["sub"]["green_zone"]) > 0 or ResourceLoader.exists(scene_path(id))


## Where a story scene's Resource lives.
static func scene_path(id: String) -> String:
	return "res://data/story/scenes/%s.tres" % id.replace(".", "_")
