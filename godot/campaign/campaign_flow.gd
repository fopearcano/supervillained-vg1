class_name CampaignFlow
extends RefCounted
## The campaign's flow policy over catalog metadata (source src/story/storyFlow.ts and
## src/story/screens.ts), pure: which levels and scenes are open, where CONTINUE goes, what a
## finished scene saves, when replays run on a deep copy without saving, where the
## "You've been supervillained" snap belongs. Story scenes themselves arrive with M5; this build can
## play only the catalog's Green Zone walk (StoryCatalog.playable_in_build).


## Level 1 is always open; a later level opens when the previous one is complete (StoryFlow.unlocked).
static func level_unlocked(state: Dictionary, catalog: StoryCatalog, number: int) -> bool:
	if number <= 1:
		return true
	var prev := catalog.chapter(number - 1)
	if prev.is_empty():
		return false
	for s: Dictionary in prev["sub_levels"]:
		if not (state["completed"] as Array).has(s["id"]):
			return false
	return true


## A scene is selectable in its level's list when finished (replay) or the level's first unfinished
## one (StoryChapterScene), inside an unlocked level.
static func scene_open(state: Dictionary, catalog: StoryCatalog, id: String) -> bool:
	var f := catalog.find(id)
	if f.is_empty() or not level_unlocked(state, catalog, int(f["chapter"]["number"])):
		return false
	var done: Array = state["completed"]
	if done.has(id):
		return true
	for s: Dictionary in f["chapter"]["sub_levels"]:
		if not done.has(s["id"]):
			return s["id"] == id
	return false


## Starting a scene from the level list: {"mode": "replay"|"play"|"locked", "state": Dictionary,
## "persist": bool, "playable": bool}. A finished scene replays on a deep copy with persistence off.
static func start(state: Dictionary, catalog: StoryCatalog, id: String) -> Dictionary:
	if not scene_open(state, catalog, id):
		return {"mode": "locked", "state": state, "persist": false, "playable": false}
	var replay := (state["completed"] as Array).has(id)
	return {"mode": "replay" if replay else "play", "state": CampaignSchema.deep_copy(state) if replay else state,
		"persist": not replay, "playable": catalog.playable_in_build(id)}


## A finished scene (StoryFlow.finishSub): outside a replay it is marked complete and the campaign
## is saved (after its effects); a replay changes and saves nothing. Returns {"save": bool}.
static func finish(state: Dictionary, id: String, replaying: bool) -> Dictionary:
	if replaying:
		return {"save": false}
	if not (state["completed"] as Array).has(id):
		(state["completed"] as Array).append(id)
	return {"save": true}


## Where CONTINUE goes: {"id", "level", "title", "playable"} for the next unfinished scene, or {}
## when everything is finished (the level list opens instead).
static func continue_target(state: Dictionary, catalog: StoryCatalog) -> Dictionary:
	var n := catalog.next_unfinished(state["completed"])
	if n.is_empty():
		return {}
	n["playable"] = catalog.playable_in_build(n["id"])
	return n


## "You've been supervillained": after the Green Zone walk (before its score card), and after the
## last scene of every level (before the Professor's aside or the ending), never after a replay of a
## story scene. Source detail kept: the walk's snap is shown by the walk's own flow, replay or not.
static func supervillained_after(catalog: StoryCatalog, id: String, replaying: bool) -> bool:
	var f := catalog.find(id)
	if f.is_empty():
		return false
	if int(f["sub"]["green_zone"]) > 0:
		return true
	if replaying:
		return false
	return int(f["index"]) == (f["chapter"]["sub_levels"] as Array).size() - 1


## Grace tier (source graceTier): "high" from GRACE_HIGH, "mid" from GRACE_LOW, else "low".
static func grace_tier(state: Dictionary) -> String:
	var g := float((state["meters"] as Dictionary)["grace"])
	return "high" if g >= GameConfig.Story.GRACE_HIGH else ("mid" if g >= GameConfig.Story.GRACE_LOW else "low")


## Standing tier for the ending: "fond" from STANDING_FOND, "fair" from STANDING_FAIR, else "low".
static func standing_tier(state: Dictionary) -> String:
	var s := float((state["meters"] as Dictionary)["standing"])
	return "fond" if s >= GameConfig.Story.STANDING_FOND else ("fair" if s >= GameConfig.Story.STANDING_FAIR else "low")


## The ending's two extra lines (source endingNotes): the Grace line, then the Standing line.
static func ending_notes(state: Dictionary, text: ShellText) -> PackedStringArray:
	return PackedStringArray([text.get_text("ending_grace_" + grace_tier(state)), text.get_text("ending_standing_" + standing_tier(state))])


## THE KNIGHT ("knight") when he enforced the oath, otherwise THE WITNESS ("alpha", the source key).
static func ending(state: Dictionary) -> String:
	return "knight" if (state["flags"] as Dictionary).get("oath") == "enforced" else "alpha"
