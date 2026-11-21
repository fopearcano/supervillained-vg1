class_name CampaignMigration
extends RefCounted
## Campaign save rules of src/campaign/state.ts that a legacy (Capacitor) save needs before it
## becomes part of the format-3 container: the version-1 -> version-2 migration (migrateV1), the
## load rule (loadCampaign: v1 is migrated once and its untouched payload kept aside, v2 is
## normalized) and the one-time "dream rewritten" notice (src/story/storyFlow.ts showNotice).
## Pure: callers own storage. Campaign dictionaries use the source's JSON field names.

const STORY_VERSION := 2
const NOTICE_REWRITTEN := "dream-rewritten"
## Where the source keeps an untouched version-1 save (localStorage `story-v1-backup`).
const V1_BACKUP_KEY := "story-v1-backup"
## Version-1 scenes whose meaning the rewrite keeps (docs/STORY-SOURCES.md, "Save migration").
const V1_KEPT_SCENES: Array[String] = ["1.0", "1.2", "1.3", "1.4"]
## Flags only the kept scenes set.
const V1_KEPT_FLAGS: Array[String] = ["pawOffered", "longWay", "santinaBall"]
## The lecture scraps of 1.2 (same names in both versions).
const V1_KEPT_SHARDS: Array[String] = ["A FLEET BOUGHT ON CREDIT", "A KNIGHT WHO KEPT WALKING", "A CITY SEEN FROM ITS WALLS"]
## The remembered lines of the kept scenes.
const V1_KEPT_REMEMBERED: Array[String] = ["AND A DOG DREAMS LECTURES.", "THERE WAS A GATE, AND IT WAS A CHIHUAHUA.",
	"THERE WAS A BOWL, AND IT WAS ALWAYS ONE STEP AWAY.", "THERE WAS A GATE, AND I WAS MAGNIFICENT AT IT."]


## Source newCampaign().
static func new_campaign() -> Dictionary:
	return {
		"version": 2,
		"completed": [],
		"meters": {"commozione": 20, "supervillain": 10, "grace": 70, "standing": 50},
		"flags": {},
		"book": {"marvels": [], "items": [], "values": [], "remembered": [], "shards": []},
		"abilities": [],
		"coins": 0,
		"playTime": 0,
		"savedAt": null,
		"notice": null,
	}


## JavaScript `typeof v === 'number' && Number.isFinite(v)`.
static func _finite(v: Variant) -> bool:
	return (v is float or v is int) and is_finite(float(v))


static func _strings(v: Variant) -> Array:
	var out: Array = []
	if v is Array:
		for x: Variant in v:
			if x is String:
				out.append(x)
	return out


## Source migrateV1(): the Green Zone and the unchanged neighbourhood scenes (1.0, 1.2-1.4) with
## their flags, scraps and remembered lines, coins and play time are kept; the dream starts again
## at 1.1 with fresh meters, book and costume; the notice is set when a played scene is replayed.
static func migrate_v1(raw: Dictionary) -> Dictionary:
	var s := new_campaign()
	var old := _strings(raw.get("completed"))
	# Saves from before the Green Zone walk became 1.0: whoever reached 1.1 has walked it.
	if old.has("1.1") and not old.has("1.0"):
		old.push_front("1.0")
	var completed: Array = []
	for id in V1_KEPT_SCENES:
		if old.has(id):
			completed.append(id)
	s["completed"] = completed
	var flags: Variant = raw.get("flags")
	if not flags is Dictionary:
		flags = {}
	for f in V1_KEPT_FLAGS:
		if (flags as Dictionary).has(f) and not completed.is_empty():
			s["flags"][f] = flags[f]
	# The kept scenes' own meter change: offering the paw at the bowl (1.3).
	if typeof(s["flags"].get("pawOffered")) == TYPE_BOOL and s["flags"]["pawOffered"] == true:
		s["meters"]["supervillain"] = maxi(0, int(s["meters"]["supervillain"]) - 3)
	var book: Variant = raw.get("book")
	if not book is Dictionary:
		book = {}
	s["book"]["shards"] = _strings((book as Dictionary).get("shards", [])).filter(func(x: String) -> bool: return V1_KEPT_SHARDS.has(x))
	s["book"]["remembered"] = _strings((book as Dictionary).get("remembered", [])).filter(func(x: String) -> bool: return V1_KEPT_REMEMBERED.has(x))
	s["coins"] = maxf(0.0, float(raw["coins"])) if _finite(raw.get("coins")) else 0
	s["playTime"] = maxf(0.0, float(raw["playTime"])) if _finite(raw.get("playTime")) else 0
	s["savedAt"] = float(raw["savedAt"]) if _finite(raw.get("savedAt")) else null
	# Tell the player only when something they played is being played again.
	var replayed := false
	for id: String in old:
		replayed = replayed or not V1_KEPT_SCENES.has(id)
	s["notice"] = NOTICE_REWRITTEN if replayed else null
	return s


## Source loadCampaign() over a key/value store: {"story": payload or null, V1_BACKUP_KEY: ...}.
## Returns {"campaign": Dictionary, "store": the store after the load}. A version-1 payload is
## migrated and written back; its untouched original is kept under V1_BACKUP_KEY unless a backup
## already exists. A version-2 payload is normalized; any other version yields a new campaign.
static func load_campaign(store: Dictionary) -> Dictionary:
	var out_store := store.duplicate(true)
	var raw: Variant = store.get("story")
	var base := new_campaign()
	if not raw is Dictionary:
		return {"campaign": base, "store": out_store}
	var version: Variant = (raw as Dictionary).get("version")
	if _finite(version) and float(version) == 1.0:
		if out_store.get(V1_BACKUP_KEY) == null:
			out_store[V1_BACKUP_KEY] = (raw as Dictionary).duplicate(true)
		var migrated := migrate_v1(raw)
		out_store["story"] = migrated.duplicate(true)
		return {"campaign": migrated, "store": out_store}
	if not (_finite(version) and float(version) == float(STORY_VERSION)):
		return {"campaign": base, "store": out_store}
	return {"campaign": normalize_v2(raw), "store": out_store}


## loadCampaign()'s version-2 branch: unknown fields pass through; meters/book merged over the
## defaults; arrays, play time, save time and notice validated.
static func normalize_v2(raw: Dictionary) -> Dictionary:
	var base := new_campaign()
	var out := base.duplicate(true)
	for k: Variant in raw:
		var v: Variant = raw[k]
		if v is Dictionary:
			out[k] = (v as Dictionary).duplicate(true)
		elif v is Array:
			out[k] = (v as Array).duplicate(true)
		else:
			out[k] = v
	out["version"] = STORY_VERSION
	var meters: Dictionary = base["meters"].duplicate()
	if raw.get("meters") is Dictionary:
		meters.merge(raw["meters"], true)
	out["meters"] = meters
	out["flags"] = (raw["flags"] as Dictionary).duplicate(true) if raw.get("flags") is Dictionary else {}
	var book: Dictionary = base["book"].duplicate(true)
	if raw.get("book") is Dictionary:
		book.merge((raw["book"] as Dictionary).duplicate(true), true)
	out["book"] = book
	out["abilities"] = (raw["abilities"] as Array).duplicate(true) if raw.get("abilities") is Array else []
	out["completed"] = (raw["completed"] as Array).duplicate() if raw.get("completed") is Array else []
	out["playTime"] = maxf(0.0, float(raw["playTime"])) if _finite(raw.get("playTime")) else 0
	out["savedAt"] = float(raw["savedAt"]) if _finite(raw.get("savedAt")) else null
	out["notice"] = NOTICE_REWRITTEN if raw.get("notice") == NOTICE_REWRITTEN else null
	return out


## Source storyFlow showNotice(): true exactly once for a migrated save; clears the notice (the
## caller saves the campaign, source saveCampaign()).
static func consume_notice(state: Dictionary) -> bool:
	if state.get("notice") != NOTICE_REWRITTEN:
		return false
	state["notice"] = null
	return true
