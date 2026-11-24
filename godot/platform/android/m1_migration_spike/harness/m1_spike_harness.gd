extends Node
## THROWAWAY M1 migration spike harness (main scene of the spike APK only; the committed project
## ignores this folder). Verifies the SvMigrationSpike singleton and its signal, reads the legacy
## store twice in this process (idempotence), prints machine-readable logcat lines and quits. It
## never writes a save: it does not call SaveService, and it does not parse or normalize the raw
## values (it only checks the result's shape and hashes the raw strings for the log).
##
## Logcat lines (tag "godot"), driven by `adb shell am start` with no touch input:
##   M1_SPIKE_START {...}
##   M1_SPIKE_CHUNK <attempt> <index>/<count> <base64 of a slice of the plugin's raw JSON>
##   M1_SPIKE_SUMMARY <attempt> {status, error, verified_origin, expected_origin, webview_package, timestamp_utc}
##   M1_SPIKE_KEY <attempt> <key> {present, length, sha256, error}
##   M1_SPIKE_IDEMPOTENT {"identical": bool, ...}
##   M1_SPIKE_DONE {"status": "success" | "not_found" | "error", ...}   (exactly once)
## Every line stays well under 1000 characters: Godot's Android logger truncates a print at 1023.
## A malformed, empty, non-string or wrong-shape plugin result is an error result (a success or
## not_found result must carry a null error for every key), and a watchdog guarantees one
## M1_SPIKE_DONE line even if a read never returns or the coroutine stops.
##
## Lifecycle tests (tools/run_upgrade_test.ps1 creates and removes the marker through run-as):
##   user://m1_lifecycle_quit.flag      a held read, then Godot quits while it is active (after 2 s);
##   user://m1_lifecycle_finish.flag    a held read, then the plugin finishes the Activity (its real
##                                      onDestroy) while it is active (after 2 s);
##   user://m1_lifecycle_immediate_quit.flag / _immediate_finish.flag
##                                      a queued read (its start is posted 5 s later), then Godot
##                                      quits / the Activity is finished in the same frame, without
##                                      waiting: the termination lands while the start is pending.
## None prints M1_SPIKE_DONE; a result reaching GDScript would print M1_SPIKE_LIFECYCLE_RESULT_RECEIVED.

const PLUGIN_NAME := "SvMigrationSpike"
const SIGNAL_NAME := "legacy_read_completed"
const METHOD_NAME := "readLegacyStore"
const HELD_METHOD_NAME := "readLegacyStoreHeldForLifecycleTest"
const QUEUED_METHOD_NAME := "readLegacyStoreQueuedForLifecycleTest"
const KEYS := ["settings", "records", "coins", "story", "story-v1-backup"]
const STATUSES := ["success", "not_found", "error"]
const CHUNK := 600
const QUIT_FLAG := "user://m1_lifecycle_quit.flag"
const FINISH_FLAG := "user://m1_lifecycle_finish.flag"
const IMMEDIATE_QUIT_FLAG := "user://m1_lifecycle_immediate_quit.flag"
const IMMEDIATE_FINISH_FLAG := "user://m1_lifecycle_immediate_finish.flag"
const FINISH_METHOD_NAME := "finishActivityForLifecycleTest"

## Test hooks (harness/m1_spike_harness_selftest.gd): a fake plugin, no singleton lookup, no quit,
## shorter waits, a lifecycle mode without a marker file and a stand-in for the lifecycle quit;
## every printed line is also kept in `emitted`.
var plugin_override: Object = null
var use_singleton := true
var quit_on_done := true
var timeout_s := 30.0
var watchdog_s := 150.0
var lifecycle_mode_override := ""
var lifecycle_quit_hook := Callable()
var emitted: Array[String] = []

var _plugin: Object = null
var _pending: Variant = null
var _received := false
var _finished := false
var _lifecycle_active := false


func _ready() -> void:
	_emit("M1_SPIKE_START " + JSON.stringify({"godot": Engine.get_version_info().get("string", ""), "os": OS.get_name(), "keys": KEYS}))
	get_tree().create_timer(watchdog_s).timeout.connect(_on_watchdog)
	_run.call_deferred()


func _run() -> void:
	if plugin_override != null:
		_plugin = plugin_override
	elif use_singleton and Engine.has_singleton(PLUGIN_NAME):
		_plugin = Engine.get_singleton(PLUGIN_NAME)
	if _plugin == null:
		_done({"status": "error", "error": "plugin_singleton_missing"})
		return
	# The singleton's Java methods are dispatched by name (has_method() does not list them): the
	# signal is checked here, the method by the call itself (a missing method ends in an error
	# result through the timeout or the watchdog, never in success).
	if not _plugin.has_signal(SIGNAL_NAME):
		_done({"status": "error", "error": "plugin_api_missing", "missing_signal": SIGNAL_NAME})
		return
	_plugin.connect(SIGNAL_NAME, _on_result)
	var mode := _lifecycle_mode()
	if mode != "":
		await _lifecycle(mode)
		return
	var summaries: Array[Dictionary] = []
	for attempt in [1, 2]:
		var raw: Variant = await _read_once(METHOD_NAME)
		var summary := _summarize(attempt, raw)
		summaries.append(summary)
		_print_attempt(attempt, raw, summary)
	var first: Dictionary = summaries[0]
	var second: Dictionary = summaries[1]
	var status := str(first.get("status", "error"))
	var values: Variant = first.get("_values", null)
	var identical: bool = status == str(second.get("status", "error")) and values != null and values == second.get("_values", null)
	_emit("M1_SPIKE_IDEMPOTENT " + JSON.stringify({"identical": identical, "statuses": [status, str(second.get("status", "error"))]}))
	_done({"status": status, "error": first.get("error", null), "identical_reads": identical})


func _read_once(method: String) -> Variant:
	_pending = null
	_received = false
	# A JNISingleton does not list its Java methods; any other object (a test double) must have it.
	if _plugin.get_class() != "JNISingleton" and not _plugin.has_method(method):
		return JSON.stringify({"status": "error", "error": "plugin_method_missing", "method": method})
	_plugin.call(method)
	var waited := 0.0
	while not _received and waited < timeout_s:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if not _received:
		return JSON.stringify({"status": "error", "error": "harness_timeout"})
	return _pending


func _on_result(json: Variant = null) -> void:
	if _lifecycle_active:
		_emit("M1_SPIKE_LIFECYCLE_RESULT_RECEIVED " + JSON.stringify({"type": type_string(typeof(json))}))
	_pending = json
	_received = true


## Never fails: always returns attempt, status, error, keys (Dictionary), diagnostics (Dictionary)
## and _values (the raw strings by key, or null when the result is not a valid read). A malformed,
## empty, non-string or wrong-shape result becomes status "error" with a specific error code.
func _summarize(attempt: int, raw: Variant) -> Dictionary:
	var out := {"attempt": attempt, "status": "error", "error": null, "verified_origin": null,
		"expected_origin": null, "webview_package": null, "timestamp_utc": null,
		"diagnostics": {}, "keys": {}, "_values": null}
	if not raw is String:
		out["error"] = "non_string_plugin_result"
		return out
	if (raw as String).is_empty():
		out["error"] = "empty_plugin_result"
		return out
	var json := JSON.new()
	if json.parse(raw) != OK:
		out["error"] = "unparseable_plugin_result"
		return out
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		return _wrong_shape(out, "top level is not an object")
	var d: Dictionary = parsed
	var status: Variant = d.get("status", null)
	if not status is String or not STATUSES.has(status):
		return _wrong_shape(out, "status")
	for field in ["verified_origin", "expected_origin", "webview_package", "timestamp_utc"]:
		out[field] = d.get(field, null)
	var diag: Variant = d.get("diagnostics", null)
	out["diagnostics"] = diag if diag is Dictionary else {}
	if status == "error":
		var err: Variant = d.get("error", null)
		out["error"] = err if err is String and not (err as String).is_empty() else "plugin_error_without_code"
		return out
	var keys: Variant = d.get("keys", null)
	if not keys is Dictionary:
		return _wrong_shape(out, "keys")
	var values := {}
	var summary_keys := {}
	var present_count := 0
	for k: String in KEYS:
		var r: Variant = (keys as Dictionary).get(k, null)
		if not r is Dictionary:
			return _wrong_shape(out, "keys." + k)
		var present: Variant = (r as Dictionary).get("present", null)
		var value: Variant = (r as Dictionary).get("raw", null)
		var err: Variant = (r as Dictionary).get("error", null)
		if not present is bool or not (value == null or value is String) or not (err == null or err is String) or present != (value is String):
			return _wrong_shape(out, "keys." + k + " fields")
		# A per-key read error makes the read an error: success and not_found need a null error on every key.
		if err != null:
			return _wrong_shape(out, "keys.%s.error is not null under status %s" % [k, status])
		if present:
			present_count += 1
		values[k] = value
		summary_keys[k] = {"present": present, "error": err,
			"length": (value as String).length() if value is String else null,
			"sha256": (value as String).sha256_text() if value is String else null}
	if (status == "success") != (present_count > 0):
		return _wrong_shape(out, "status %s with %d keys present" % [status, present_count])
	out["status"] = status
	out["keys"] = summary_keys
	out["_values"] = values
	return out


func _wrong_shape(out: Dictionary, where: String) -> Dictionary:
	out["status"] = "error"
	out["error"] = "wrong_shape_plugin_result"
	out["error_detail"] = where
	out["keys"] = {}
	out["diagnostics"] = out.get("diagnostics", {}) if out.get("diagnostics", {}) is Dictionary else {}
	out["_values"] = null
	return out


func _print_attempt(attempt: int, raw: Variant, summary: Dictionary) -> void:
	if raw is String and not (raw as String).is_empty():
		var b64 := Marshalls.utf8_to_base64(raw)
		var count := ceili(float(b64.length()) / CHUNK)
		for i in count:
			_emit("M1_SPIKE_CHUNK %d %d/%d %s" % [attempt, i + 1, count, b64.substr(i * CHUNK, CHUNK)])
	var line := {}
	for field in ["attempt", "status", "error", "error_detail", "verified_origin", "expected_origin", "webview_package", "timestamp_utc"]:
		if summary.has(field):
			line[field] = summary[field]
	_emit("M1_SPIKE_SUMMARY %d %s" % [attempt, JSON.stringify(line)])
	var keys: Variant = summary.get("keys", {})
	if keys is Dictionary:
		for k: String in KEYS:
			if (keys as Dictionary).has(k):
				_emit("M1_SPIKE_KEY %d %s %s" % [attempt, k, JSON.stringify(keys[k])])


func _lifecycle_mode() -> String:
	if lifecycle_mode_override != "":
		return lifecycle_mode_override
	if FileAccess.file_exists(QUIT_FLAG):
		return "quit_during_read"
	if FileAccess.file_exists(FINISH_FLAG):
		return "activity_finished_during_read"
	if FileAccess.file_exists(IMMEDIATE_QUIT_FLAG):
		return "quit_immediately_after_request"
	if FileAccess.file_exists(IMMEDIATE_FINISH_FLAG):
		return "activity_finished_immediately_after_request"
	return ""


func _lifecycle(mode: String) -> void:
	_lifecycle_active = true
	var immediate := mode.ends_with("_immediately_after_request")
	var method := QUEUED_METHOD_NAME if immediate else HELD_METHOD_NAME
	_emit("M1_SPIKE_LIFECYCLE " + JSON.stringify({"mode": mode, "method": method}))
	var frame := Engine.get_process_frames()
	_plugin.call(method)
	if not immediate:
		await get_tree().create_timer(2.0).timeout
		_emit("M1_SPIKE_LIFECYCLE_ACTIVE " + JSON.stringify({"mode": mode, "result_received": _received}))
	_finished = true
	var info := JSON.stringify({"frames_since_request": Engine.get_process_frames() - frame, "result_received": _received})
	if mode.begins_with("quit_"):
		_emit("M1_SPIKE_LIFECYCLE_QUIT " + info)
		if lifecycle_quit_hook.is_valid():
			lifecycle_quit_hook.call()
		else:
			get_tree().quit()
	else:
		_emit("M1_SPIKE_LIFECYCLE_FINISH_ACTIVITY " + info)
		_plugin.call(FINISH_METHOD_NAME)


func _on_watchdog() -> void:
	if not _finished:
		_done({"status": "error", "error": "harness_watchdog"})


func _done(result: Dictionary) -> void:
	if _finished:
		return
	_finished = true
	_emit("M1_SPIKE_DONE " + JSON.stringify(result))
	if quit_on_done:
		await get_tree().create_timer(1.0).timeout
		get_tree().quit()


func _emit(line: String) -> void:
	emitted.append(line)
	print(line)
