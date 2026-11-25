class_name StoryLibrary
extends RefCounted
## The rewritten story's Resources (data/story/): which chapters and scenes exist in this build.
## A catalog entry without a scene Resource is shown as this build's boundary.


static func chapter_path(number: int) -> String:
	return "res://data/story/chapters/ch%d.tres" % number


static func has_scene(id: String) -> bool:
	return ResourceLoader.exists(StoryCatalog.scene_path(id))


static func scene(id: String) -> StorySceneData:
	return load(StoryCatalog.scene_path(id)) if has_scene(id) else null


static func chapter(number: int) -> StoryChapterData:
	var path := chapter_path(number)
	return load(path) if ResourceLoader.exists(path) else null


## Every chapter Resource present, by number.
static func chapters() -> Array:
	var out: Array = []
	for n in range(1, 9):
		var ch := chapter(n)
		if ch:
			out.append(ch)
	return out
