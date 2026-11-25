class_name CampaignSummary
extends RefCounted
## What the COUCH card shows about a saved story (port of src/campaign/summary.ts), pure.

const MONTHS := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]


## Source progressSummary(state, CHAPTERS).
static func progress(state: Dictionary, catalog: StoryCatalog) -> Dictionary:
	var done_ids: Array = state["completed"]
	var levels: Array = []
	var done := 0
	var total := 0
	var next: Variant = null
	for ch: Dictionary in catalog.chapters:
		var subs: Array = ch["sub_levels"]
		var d := 0
		for s: Dictionary in subs:
			if done_ids.has(s["id"]):
				d += 1
			elif next == null:
				next = {"level": int(ch["number"]), "id": String(s["id"]), "title": String(s["title"])}
		levels.append({"number": int(ch["number"]), "done": d, "total": subs.size()})
		done += d
		total += subs.size()
	var abilities: Array = state["abilities"]
	var book: Dictionary = state["book"]
	return {
		"started": done > 0, "done": done, "total": total, "levels": levels, "next": next,
		"ending": null if next != null else CampaignFlow.ending(state),
		"meters": (state["meters"] as Dictionary).duplicate(),
		"values": (book["values"] as Array).size(), "marvels": (book["marvels"] as Array).size(),
		"items": (book["items"] as Array).size(), "shards": (book["shards"] as Array).size(),
		"coins": state["coins"],
		"costume": "knight" if abilities.has("knight") else ("cross" if abilities.has("cross") else null),
		"abilities": abilities.duplicate(), "playTime": state["playTime"], "savedAt": state["savedAt"],
	}


## "1H 05M", "12M", "45S" (source formatPlayTime).
static func format_play_time(seconds: float) -> String:
	var s := maxi(0, int(floor(seconds)))
	var h := s / 3600
	var m := (s % 3600) / 60
	if h > 0:
		return "%dH %02dM" % [h, m]
	if m > 0:
		return "%dM" % m
	return "%dS" % s


## "17 NOV 18:52" this year, "17 NOV 2025" before, or "NEVER" (source formatSavedAt), in the local
## time given by `offset_minutes` (the device's time zone in the game; 0 in the UTC fixture).
static func format_saved_at(ms: Variant, now_ms: int, offset_minutes: int) -> String:
	if ms == null:
		return "NEVER"
	var d := Time.get_datetime_dict_from_unix_time(int(floor(float(ms) / 1000.0)) + offset_minutes * 60)
	var n := Time.get_datetime_dict_from_unix_time(int(floor(float(now_ms) / 1000.0)) + offset_minutes * 60)
	var day := "%d %s" % [d["day"], MONTHS[int(d["month"]) - 1]]
	if d["year"] != n["year"]:
		return "%s %d" % [day, d["year"]]
	return "%s %02d:%02d" % [day, d["hour"], d["minute"]]


## The device's offset from UTC in minutes (Time.get_time_zone_from_system()).
static func local_offset_minutes() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0))
