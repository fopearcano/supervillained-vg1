class_name StoryConditions
extends RefCounted
## Conditions over the campaign state (BranchStep cases): pure. See StoryBranchCase for the forms.


static func holds(state: Dictionary, when: Dictionary) -> bool:
	if when.has("any"):
		for w: Dictionary in when["any"]:
			if holds(state, w):
				return true
		return false
	if when.has("all"):
		for w: Dictionary in when["all"]:
			if not holds(state, w):
				return false
		return true
	if when.has("flag"):
		var flags: Dictionary = state.get("flags", {})
		var v: Variant = when["eq"]
		if v == null:
			return not flags.has(String(when["flag"]))
		return flags.has(String(when["flag"])) and flags[String(when["flag"])] == v
	if when.has("meter"):
		var m := float((state.get("meters", {}) as Dictionary).get(String(when["meter"]), 0.0))
		if when.has("gte") and m < float(when["gte"]):
			return false
		if when.has("lt") and m >= float(when["lt"]):
			return false
		return true
	if when.has("ability"):
		return (state.get("abilities", []) as Array).has(String(when["ability"]))
	if when.has("book"):
		var list: Array = (state.get("book", {}) as Dictionary).get(String(when["book"]), [])
		if when.has("has"):
			return list.has(String(when["has"]))
		return list.size() >= int(when.get("gte", 0))
	return false


## "" when `when` is a well-formed condition, else why not.
static func check(when: Dictionary) -> String:
	for k: String in ["all", "any"]:
		if not when.has(k):
			continue
		if not when[k] is Array or (when[k] as Array).is_empty():
			return "'%s' needs a list of conditions" % k
		for w: Variant in when[k]:
			if not w is Dictionary:
				return "'%s' holds a non-condition" % k
			var why := check(w)
			if why != "":
				return why
		return ""
	if when.has("flag"):
		var f := String(when["flag"])
		var known: bool = CampaignSchema.FLAG_ENUMS.has(f) or CampaignSchema.FLAG_NUMBERS.has(f) or CampaignSchema.FLAG_BOOLEANS.has(f) or CampaignSchema.FLAG_ANY_SCALAR.has(f)
		if not known:
			return "unknown flag '%s'" % f
		return "" if when.has("eq") else "a flag condition needs 'eq'"
	if when.has("meter"):
		if not CampaignSchema.METER_KEYS.has(String(when["meter"])):
			return "unknown meter '%s'" % when["meter"]
		return "" if when.has("gte") or when.has("lt") else "a meter condition needs 'gte' or 'lt'"
	if when.has("ability"):
		return "" if CampaignSchema.ABILITIES.has(String(when["ability"])) else "unknown ability '%s'" % when["ability"]
	if when.has("book"):
		if not ["marvels", "items", "values", "remembered", "shards"].has(String(when["book"])):
			return "unknown book kind '%s'" % when["book"]
		return "" if when.has("has") or when.has("gte") else "a book condition needs 'has' or 'gte'"
	return "an empty or unknown condition"
