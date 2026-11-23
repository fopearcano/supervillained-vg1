extends Node
## THROWAWAY M1 migration spike harness (main scene of the spike APK only; the committed project
## ignores this folder). Verifies the SvMigrationSpike singleton and its API, reads the legacy
## store twice in this process (idempotence), prints machine-readable logcat lines and quits. It
## never writes a save: it does not call SaveService, and it does not parse or normalize the raw
## values (it only hashes them for the log).
##
## Logcat lines (tag "godot"), driven by `adb shell am start` with no touch input:
##   M1_SPIKE_START {...}
##   M1_SPIKE_CHUNK <attempt> <index>/<count> <base64 of a slice of the plugin's raw JSON>
##   M1_SPIKE_SUMMARY <attempt> {status, error, verified_origin, expected_origin, webview_package, timestamp_utc}
##   M1_SPIKE_KEY <attempt> <key> {present, length, sha256, error}
## Every line stays well under 1000 characters: Godot's Android logger truncates a print at 1023.
##   M1_SPIKE_IDEMPOTENT {"identical": bool, ...}
##   M1_SPIKE_DONE {"status": "success" | "not_found" | "error", ...}

const PLUGIN_NAME := "SvMigrationSpike"
const SIGNAL_NAME := "legacy_read_completed"
const METHOD_NAME := "readLegacyStore"
const KEYS := ["settings", "records", "coins", "story", "story-v1-backup"]
const TIMEOUT_S := 30.0
const CHUNK := 600

var _plugin: Object
var _pending := ""


func _ready() -> void:
	print("M1_SPIKE_START ", JSON.stringify({"godot": Engine.get_version_info()["string"], "os": OS.get_name(), "keys": KEYS}))
	_run.call_deferred()


func _run() -> void:
	if not Engine.has_singleton(PLUGIN_NAME):
		_done({"status": "error", "error": "plugin_singleton_missing"})
		return
	_plugin = Engine.get_singleton(PLUGIN_NAME)
	# The singleton's Java methods are dispatched by name (has_method() does not list them): the
	# signal is checked here, the method by the call itself (a missing method ends in an error
	# result, never in success).
	if not _plugin.has_signal(SIGNAL_NAME):
		_done({"status": "error", "error": "plugin_api_missing", "missing_signal": SIGNAL_NAME})
		return
	_plugin.connect(SIGNAL_NAME, _on_result)
	var summaries: Array[Dictionary] = []
	var raws: Array = []
	for attempt in [1, 2]:
		var raw := await _read_once()
		var summary := _summarize(attempt, raw)
		raws.append(summary.get("_values", null))
		summary.erase("_values")
		summaries.append(summary)
		_print_chunks(attempt, raw)
		var keys: Dictionary = summary["keys"]
		summary.erase("keys")
		summary.erase("diagnostics")
		print("M1_SPIKE_SUMMARY %d %s" % [attempt, JSON.stringify(summary)])
		for k: String in KEYS:
			print("M1_SPIKE_KEY %d %s %s" % [attempt, k, JSON.stringify(keys.get(k, {}))])
	var identical: bool = summaries[0]["status"] == summaries[1]["status"] and raws[0] == raws[1] and raws[0] != null
	print("M1_SPIKE_IDEMPOTENT ", JSON.stringify({"identical": identical, "statuses": [summaries[0]["status"], summaries[1]["status"]]}))
	_done({"status": summaries[0]["status"], "error": summaries[0].get("error"), "identical_reads": identical})


func _read_once() -> String:
	_pending = ""
	_plugin.call(METHOD_NAME)
	var waited := 0.0
	while _pending == "" and waited < TIMEOUT_S:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if _pending == "":
		return JSON.stringify({"status": "error", "error": "harness_timeout"})
	return _pending


func _on_result(json: String) -> void:
	_pending = json


## Status, origin and per-key presence/length/SHA-256 of the raw strings (UTF-8), no parsing of
## the values themselves. `_values` (removed before printing) holds the raw strings for the
## in-process idempotence comparison.
func _summarize(attempt: int, raw: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"attempt": attempt, "status": "error", "error": "unparseable_plugin_result", "_values": null}
	var d: Dictionary = parsed
	var out := {"attempt": attempt, "status": d.get("status", "error"), "error": d.get("error"),
		"verified_origin": d.get("verified_origin"), "expected_origin": d.get("expected_origin"),
		"webview_package": d.get("webview_package"), "timestamp_utc": d.get("timestamp_utc"),
		"diagnostics": d.get("diagnostics"), "keys": {}, "_values": null}
	if typeof(d.get("keys")) == TYPE_DICTIONARY:
		var values := {}
		for k: String in KEYS:
			var r: Dictionary = d["keys"].get(k, {})
			var v: Variant = r.get("raw")
			values[k] = v
			out["keys"][k] = {"present": r.get("present"), "error": r.get("error"),
				"length": (v as String).length() if v is String else null,
				"sha256": (v as String).sha256_text() if v is String else null}
		out["_values"] = values
	return out


func _print_chunks(attempt: int, raw: String) -> void:
	var b64 := Marshalls.utf8_to_base64(raw)
	var count := ceili(float(b64.length()) / CHUNK)
	for i in count:
		print("M1_SPIKE_CHUNK %d %d/%d %s" % [attempt, i + 1, count, b64.substr(i * CHUNK, CHUNK)])


func _done(result: Dictionary) -> void:
	print("M1_SPIKE_DONE ", JSON.stringify(result))
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()
