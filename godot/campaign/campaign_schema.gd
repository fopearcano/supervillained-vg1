class_name CampaignSchema
extends RefCounted
## Format-3 validation of the campaign v2 object and the legacy-import metadata
## (docs/porting/ARCHITECTURE.md §17.1; source types in src/campaign/state.ts). Pure.
##
## Every typed field is normalized: numbers finite, meters clamped to 0..METER_MAX, counts
## nonnegative, arrays of strings deduplicated by first occurrence, completed ids limited to the
## current catalog, abilities to cross/knight/sermon. Flags follow CampaignFlagSchema: known keys
## keep only valid values; unknown keys keep scalar strings, finite numbers and booleans (the source
## copies the whole flag object) and lose arrays/objects. `dropped` lists what was removed.

const VERSION := 2
const METER_KEYS := ["commozione", "supervillain", "grace", "standing"]
const METER_START := {"commozione": 20, "supervillain": 10, "grace": 70, "standing": 50}
const METER_MAX := 100
const ABILITIES := ["cross", "knight", "sermon"]
const BOOK_KEYS := ["marvels", "items", "values", "remembered", "shards"]
const NOTICES := ["dream-rewritten"]

## CampaignFlagSchema (ARCHITECTURE.md §17.1).
const FLAG_ENUMS := {
	"oath": ["undecided", "enforced", "silent"],
	"lamp": ["declared", "kept"],
	"drawing": ["ships", "city", "pedestal", "bowl"],
	"tellingTier": ["high", "mid", "low"],
	"zaraOwe": ["pope", "host", "debt"],
	"corfu": ["stay", "syria"],
	"letter": ["named", "necessity"],
	"courtesy84": ["unanswered"],
}
const FLAG_NUMBERS := ["shortfall"]
const FLAG_BOOLEANS := ["pawOffered", "longWay", "vow", "weptWell", "zaraDeal", "heardZara", "clothRoute",
	"dissent", "comradeship", "vanguard", "visitedCity", "sworn", "followed", "columnAgain", "told", "lawnHeld", "ballReturned"]
## Kept by the v1 migration with any scalar value (current scenes write "performed"; v1 had "kept").
const FLAG_ANY_SCALAR := ["santinaBall"]

## The five legacy Capacitor keys (supervillained:<key>), ARCHITECTURE.md §17.2.
const LEGACY_KEYS := ["settings", "records", "coins", "story", "story-v1-backup"]
const IMPORT_STATUSES := ["not_attempted", "imported", "imported_partial", "not_found", "retryable_error", "blocked"]


static func new_campaign() -> Dictionary:
	return {
		"version": VERSION, "completed": [], "meters": METER_START.duplicate(), "flags": {},
		"book": {"marvels": [], "items": [], "values": [], "remembered": [], "shards": []},
		"abilities": [], "coins": 0, "playTime": 0, "savedAt": null, "notice": null,
	}


static func default_legacy_import() -> Dictionary:
	return {
		"status": "not_attempted", "source": "capacitor_webview", "attempt_count": 0,
		"attempted_at_unix_ms": null, "payload_sha256": null, "keys_present": [], "keys_imported": [],
		"keys_failed": [], "error_code": null,
	}


static func is_finite_number(v: Variant) -> bool:
	return (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) and is_finite(float(v))


static func is_scalar(v: Variant) -> bool:
	return typeof(v) == TYPE_STRING or typeof(v) == TYPE_BOOL or is_finite_number(v)


## An integral float becomes an int (JSON numbers arrive as floats).
static func clean_number(x: float) -> Variant:
	if x == floor(x) and absf(x) < 9007199254740992.0:
		return int(x)
	return x


## Strings in first-occurrence order, optionally limited to `allowed`; non-strings dropped.
static func unique_strings(raw: Variant, allowed: Array = [], dropped: Array = [], where: String = "") -> Array:
	var out: Array = []
	if not raw is Array:
		if raw != null:
			dropped.append(where)
		return out
	for v: Variant in raw:
		if typeof(v) != TYPE_STRING or (not allowed.is_empty() and not allowed.has(v)):
			dropped.append("%s:%s" % [where, v])
			continue
		if not out.has(v):
			out.append(v)
	return out


static func normalize_flags(raw: Variant, dropped: Array = []) -> Dictionary:
	var out := {}
	if not raw is Dictionary:
		return out
	for key: Variant in raw:
		if typeof(key) != TYPE_STRING:
			continue
		var v: Variant = raw[key]
		var ok := false
		if FLAG_ENUMS.has(key):
			ok = typeof(v) == TYPE_STRING and (FLAG_ENUMS[key] as Array).has(v)
		elif FLAG_NUMBERS.has(key):
			ok = is_finite_number(v) and float(v) >= 0.0
			if ok:
				v = clean_number(float(v))
		elif FLAG_BOOLEANS.has(key):
			ok = typeof(v) == TYPE_BOOL
		elif FLAG_ANY_SCALAR.has(key):
			ok = is_scalar(v)
		else:
			ok = is_scalar(v)
			if ok and typeof(v) != TYPE_STRING and typeof(v) != TYPE_BOOL:
				v = clean_number(float(v))
		if ok:
			out[key] = v
		else:
			dropped.append("flags.%s" % key)
	return out


## True when `raw` is an object whose `version` is a finite number exactly equal to 2 (2.5, 2.1, "2"
## and the like are rejected; no integer cast decides it).
static func is_version(raw: Variant, version: int = VERSION) -> bool:
	return raw is Dictionary and is_finite_number((raw as Dictionary).get("version")) and float(raw["version"]) == float(version)


## Normalizes a campaign v2 object against the catalog ids. Returns {"ok", "data", "dropped"};
## ok is false only when `raw` is not a version-2 object (the caller then keeps defaults or, for a
## saved container, rejects the container).
static func normalize(raw: Variant, catalog_ids: PackedStringArray) -> Dictionary:
	var dropped: Array = []
	if not is_version(raw):
		return {"ok": false, "data": new_campaign(), "dropped": ["campaign"]}
	var r: Dictionary = raw
	var out := new_campaign()
	out["completed"] = unique_strings(r.get("completed"), Array(catalog_ids), dropped, "completed")
	var meters: Dictionary = r["meters"] if r.get("meters") is Dictionary else {}
	for k: String in METER_KEYS:
		if is_finite_number(meters.get(k)):
			out["meters"][k] = clean_number(clampf(float(meters[k]), 0.0, METER_MAX))
		elif meters.has(k):
			dropped.append("meters.%s" % k)
	out["flags"] = normalize_flags(r.get("flags"), dropped)
	var book: Dictionary = r["book"] if r.get("book") is Dictionary else {}
	for k: String in BOOK_KEYS:
		out["book"][k] = unique_strings(book.get(k), [], dropped, "book.%s" % k)
	out["abilities"] = unique_strings(r.get("abilities"), ABILITIES, dropped, "abilities")
	if is_finite_number(r.get("coins")):
		out["coins"] = maxi(0, int(floor(float(r["coins"]))))
	if is_finite_number(r.get("playTime")):
		out["playTime"] = clean_number(maxf(0.0, float(r["playTime"])))
	if is_finite_number(r.get("savedAt")):
		out["savedAt"] = int(floor(float(r["savedAt"])))
	if NOTICES.has(r.get("notice")):
		out["notice"] = r["notice"]
	return {"ok": true, "data": out, "dropped": dropped}


static func normalize_legacy_import(raw: Variant) -> Dictionary:
	var out := default_legacy_import()
	if not raw is Dictionary or not IMPORT_STATUSES.has(raw.get("status")):
		return out
	var r: Dictionary = raw
	out["status"] = r["status"]
	if is_finite_number(r.get("attempt_count")):
		out["attempt_count"] = maxi(0, int(r["attempt_count"]))
	if is_finite_number(r.get("attempted_at_unix_ms")):
		out["attempted_at_unix_ms"] = maxi(0, int(r["attempted_at_unix_ms"]))
	var sha: Variant = r.get("payload_sha256")
	if typeof(sha) == TYPE_STRING and sha.length() == 64 and sha.is_valid_hex_number(false):
		out["payload_sha256"] = String(sha).to_lower()
	for k: String in ["keys_present", "keys_imported", "keys_failed"]:
		out[k] = unique_strings(r.get(k), LEGACY_KEYS)
	if typeof(r.get("error_code")) == TYPE_STRING:
		out["error_code"] = r["error_code"]
	return out


## A deep, independent copy (replays play on it; nothing reaches the save).
static func deep_copy(state: Dictionary) -> Dictionary:
	return state.duplicate(true)
