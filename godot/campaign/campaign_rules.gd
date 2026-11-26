class_name CampaignRules
extends RefCounted
## The campaign's persistent-effect rules (port of src/campaign/state.ts applyEffects and
## markComplete), pure: meters clamp to 0..METER_MAX, book entries and abilities are added once
## (first occurrence kept), coins never drop below zero, flags merge; returns the change labels
## the story shows as popups. The story scenes that apply effects arrive with M5.

const METER_LABEL := {"commozione": "COMMOZIONE", "supervillain": "SUPERVILLAIN", "grace": "GRACE", "standing": "STANDING"}


static func _add_unique(list: Array, v: String) -> bool:
	if list.has(v):
		return false
	list.append(v)
	return true


## Applies `fx` to `state` in place; returns [{"label", "positive"}, ...] like the source.
static func apply_effects(state: Dictionary, fx: Dictionary) -> Array:
	var out: Array = []
	var meters: Dictionary = state["meters"]
	for key: String in CampaignSchema.METER_KEYS:
		var d: Variant = fx.get(key)
		if d == null or float(d) == 0.0:
			continue
		var before := float(meters[key])
		meters[key] = CampaignSchema.clean_number(clampf(before + float(d), 0.0, CampaignSchema.METER_MAX))
		var real := float(meters[key]) - before
		if real != 0.0:
			out.append({"label": "%s%s %s" % ["+" if real > 0 else "", CampaignSchema.clean_number(real), METER_LABEL[key]], "positive": real > 0})
	if fx.get("flags") is Dictionary:
		(state["flags"] as Dictionary).merge(fx["flags"], true)
	var book: Dictionary = state["book"]
	var marvels: Variant = fx.get("marvel")
	for m: String in (marvels if marvels is Array else ([] if marvels == null else [marvels])):
		if _add_unique(book["marvels"], m):
			out.append({"label": "MARVEL: %s" % m.to_upper(), "positive": true})
	if fx.get("item") and _add_unique(book["items"], fx["item"]):
		out.append({"label": "GOT: %s" % String(fx["item"]).to_upper(), "positive": true})
	if fx.get("value") and _add_unique(book["values"], fx["value"]):
		out.append({"label": "VALUE: %s" % String(fx["value"]).to_upper(), "positive": true})
	if fx.get("remembered"):
		_add_unique(book["remembered"], fx["remembered"])
	if fx.get("shard") and _add_unique(book["shards"], fx["shard"]):
		out.append({"label": "SCRAP: %s" % String(fx["shard"]).to_upper(), "positive": true})
	var unlock: Variant = fx.get("unlock")
	if unlock and not (state["abilities"] as Array).has(unlock):
		(state["abilities"] as Array).append(unlock)
		out.append({"label": "UNLOCKED: %s" % String(unlock).to_upper(), "positive": true})
	var coins: Variant = fx.get("coins")
	if coins != null and float(coins) != 0.0:
		state["coins"] = maxi(0, int(state["coins"]) + int(coins))
		out.append({"label": "%s%d COINS" % ["+" if float(coins) > 0 else "", int(coins)], "positive": float(coins) > 0})
	return out


## The feeling fades (source fadeCommozione, RD-05): a dream scene of Levels 2-7 starts with
## COMMOZIONE_FADE less Commozione (never below 0), so wonder and weeping must keep filling it.
## Returns the amount lost (0 outside Levels 2-7).
static func fade_commozione(state: Dictionary, level: int) -> float:
	if level < 2 or level > 7:
		return 0.0
	var m: Dictionary = state["meters"]
	var before := float(m["commozione"])
	m["commozione"] = maxf(0.0, before - GameConfig.Story.COMMOZIONE_FADE)
	return before - float(m["commozione"])


## Supervillain full (source unshakeable): he cannot be pushed off the lawn. The book shows it
## ("(FULL)"); the draft's other use, softening the generic pace walk's nerve loss, has no scene in
## the current campaign (FEATURE_MATRIX: excluded unless reused; RD-53).
static func unshakeable(state: Dictionary) -> bool:
	return float((state.get("meters", {}) as Dictionary).get("supervillain", 0.0)) >= CampaignSchema.METER_MAX


static func mark_complete(state: Dictionary, id: String) -> void:
	if not (state["completed"] as Array).has(id):
		(state["completed"] as Array).append(id)
