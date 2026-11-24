extends SceneTree
## Desktop self-test of the THROWAWAY M1 spike harness (no Android, no plugin): the harness runs
## against fake plugins that return valid, malformed, empty, non-string and wrong-shape results
## (including success or not_found with a per-key error), never answer, lack the signal or lack the
## method. Each case must end in exactly one M1_SPIKE_DONE line with the expected status/error
## (never a stopped coroutine), and every _summarize() result must carry keys, diagnostics and
## _values. The four lifecycle modes run against a recording fake: the held modes call the
## termination 2 s after the request, the immediate modes in the same frame; none prints DONE.
## Run: godot --headless --path godot --script res://platform/android/m1_migration_spike/harness/m1_spike_harness_selftest.gd

const HARNESS := preload("res://platform/android/m1_migration_spike/harness/m1_spike_harness.gd")
const KEYS := ["settings", "records", "coins", "story", "story-v1-backup"]
const NO_REPLY := "<no reply>"


class FakePlugin extends Object:
	signal legacy_read_completed(json)
	var replies: Array = []

	func readLegacyStore() -> void:
		if replies.is_empty():
			return
		var r: Variant = replies.pop_front()
		if r is String and r == NO_REPLY:
			return
		_reply.call_deferred(r)

	func _reply(r: Variant) -> void:
		legacy_read_completed.emit(r)


class FakeNoSignal extends Object:
	func readLegacyStore() -> void:
		pass


class FakeNoMethod extends Object:
	signal legacy_read_completed(json)


class FakeLifecycle extends Object:
	signal legacy_read_completed(json)
	var calls: Array = []

	func readLegacyStoreHeldForLifecycleTest() -> void:
		calls.append(["held_read", Engine.get_process_frames()])

	func readLegacyStoreQueuedForLifecycleTest() -> void:
		calls.append(["queued_read", Engine.get_process_frames()])

	func finishActivityForLifecycleTest() -> void:
		calls.append(["finish_activity", Engine.get_process_frames()])


var _passed := 0
var _failed := 0


func _initialize() -> void:
	_main.call_deferred()


static func _result(status: String, values: Dictionary, error: Variant = null, key_errors: Dictionary = {}) -> String:
	var keys := {}
	for k: String in KEYS:
		keys[k] = {"storage_key": "supervillained:" + k, "present": values.has(k), "raw": values.get(k, null), "error": key_errors.get(k, null)}
	return JSON.stringify({"spike": "sv_m1_migration_spike", "attempt": 1, "status": status, "error": error,
		"verified_origin": "https://localhost", "expected_origin": "https://localhost", "webview_package": null,
		"timestamp_utc": "2026-01-01T00:00:00.000Z", "diagnostics": {"page_url": "https://localhost/x"}, "keys": keys})


func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
	print("M1_SELFTEST %s %s%s" % ["PASS" if ok else "FAIL", name, "" if detail == "" else " (" + detail + ")"])


func _run_case(name: String, plugin: Object, expect_status: String, expect_errors: Array, expect_identical: Variant = null, use_singleton := false) -> void:
	var h: Node = HARNESS.new()
	h.plugin_override = plugin
	h.use_singleton = use_singleton
	h.quit_on_done = false
	h.timeout_s = 0.3
	h.watchdog_s = 1.5
	root.add_child(h)
	var waited := 0.0
	while not h._finished and waited < 5.0:
		await process_frame
		waited += 1.0 / 60.0
	await create_timer(1.8).timeout  # past the watchdog: a second DONE would show here
	var done_lines: Array = h.emitted.filter(func(l: String) -> bool: return l.begins_with("M1_SPIKE_DONE "))
	var done: Variant = JSON.parse_string(done_lines[0].trim_prefix("M1_SPIKE_DONE ")) if done_lines.size() == 1 else null
	var ok: bool = done is Dictionary and done.get("status") == expect_status
	if ok and not expect_errors.is_empty():
		ok = expect_errors.has(done.get("error"))
	if ok and expect_identical != null:
		ok = done.get("identical_reads") == expect_identical
	ok = ok and h.emitted.all(func(l: String) -> bool: return l.length() < 1000)
	_check(name, done_lines.size() == 1 and ok, "DONE lines %d: %s" % [done_lines.size(), done_lines])
	root.remove_child(h)
	h.free()
	if plugin != null:
		plugin.free()


func _run_lifecycle_case(name: String, mode: String, expect_calls: Array, immediate: bool) -> void:
	var fake := FakeLifecycle.new()
	var h: Node = HARNESS.new()
	h.plugin_override = fake
	h.use_singleton = false
	h.quit_on_done = false
	h.watchdog_s = 3.0
	h.lifecycle_mode_override = mode
	h.lifecycle_quit_hook = func() -> void: fake.calls.append(["quit", Engine.get_process_frames()])
	root.add_child(h)
	var start := Time.get_ticks_msec()
	while fake.calls.size() < 2 and Time.get_ticks_msec() - start < 5000:
		await process_frame
	await create_timer(3.5).timeout  # past the watchdog: a DONE line would show here
	var names: Array = fake.calls.map(func(c: Array) -> String: return c[0])
	var same_frame: bool = fake.calls.size() == 2 and fake.calls[0][1] == fake.calls[1][1]
	var active: bool = h.emitted.any(func(l: String) -> bool: return l.begins_with("M1_SPIKE_LIFECYCLE_ACTIVE "))
	var done: bool = h.emitted.any(func(l: String) -> bool: return l.begins_with("M1_SPIKE_DONE "))
	var ok: bool = names == expect_calls and not done and same_frame == immediate and active != immediate
	_check(name, ok, "calls %s, same frame %s, ACTIVE line %s, DONE line %s" % [fake.calls, same_frame, active, done])
	root.remove_child(h)
	h.free()
	fake.free()


func _fake(replies: Array) -> FakePlugin:
	var f := FakePlugin.new()
	f.replies = replies
	return f


func _main() -> void:
	var values := {"settings": "{\"muted\":true}", "records": "{}", "coins": "42", "story": "{\"version\":2}", "story-v1-backup": "{\"version\":1}"}
	var other := values.duplicate()
	other["coins"] = "43"
	var ok := _result("success", values)
	var nf := _result("not_found", {})
	var bad_keys := JSON.stringify({"status": "success", "keys": ["settings"]})
	var bad_entry := JSON.stringify({"status": "success", "keys": {"settings": "x", "records": "x", "coins": "x", "story": "x", "story-v1-backup": "x"}})
	var mismatch := ok.replace("\"raw\":\"42\"", "\"raw\":null")
	var unknown_status := ok.replace("\"status\":\"success\"", "\"status\":\"maybe\"")
	var success_none := _result("success", {})
	var not_found_some := _result("not_found", {"coins": "42"})
	var plugin_error := JSON.stringify({"status": "error", "error": "origin_mismatch", "keys": null, "diagnostics": {}})
	var not_found_key_error := _result("not_found", {}, null, {"coins": "SecurityError: access denied"})
	var success_key_error := _result("success", values, null, {"story": "SecurityError: access denied"})
	var error_no_code := JSON.stringify({"status": "error"})

	# _summarize() shape on every path.
	var h: Node = HARNESS.new()
	var inputs := {"valid": ok, "not_found": nf, "malformed": "{not json", "empty": "", "non-string": 42, "null": null,
		"array": "[1,2]", "keys not an object": bad_keys, "key entry not an object": bad_entry, "present/raw mismatch": mismatch,
		"unknown status": unknown_status, "success with no key": success_none, "not_found with a key": not_found_some,
		"plugin error": plugin_error, "error without code": error_no_code,
		"not_found with a key error": not_found_key_error, "success with a key error": success_key_error}
	var expect := {"valid": ["success", null], "not_found": ["not_found", null], "malformed": ["error", "unparseable_plugin_result"],
		"empty": ["error", "empty_plugin_result"], "non-string": ["error", "non_string_plugin_result"], "null": ["error", "non_string_plugin_result"],
		"array": ["error", "wrong_shape_plugin_result"], "keys not an object": ["error", "wrong_shape_plugin_result"],
		"key entry not an object": ["error", "wrong_shape_plugin_result"], "present/raw mismatch": ["error", "wrong_shape_plugin_result"],
		"unknown status": ["error", "wrong_shape_plugin_result"], "success with no key": ["error", "wrong_shape_plugin_result"],
		"not_found with a key": ["error", "wrong_shape_plugin_result"], "plugin error": ["error", "origin_mismatch"],
		"error without code": ["error", "plugin_error_without_code"],
		"not_found with a key error": ["error", "wrong_shape_plugin_result"],
		"success with a key error": ["error", "wrong_shape_plugin_result"]}
	for name: String in inputs:
		var s: Dictionary = h._summarize(1, inputs[name])
		var shape_ok: bool = s.get("keys") is Dictionary and s.get("diagnostics") is Dictionary and s.has("_values") \
			and (s["_values"] == null or s["_values"] is Dictionary)
		var values_ok: bool = (s["_values"] != null) == (s["status"] != "error")
		_check("summarize " + name, shape_ok and values_ok and s["status"] == expect[name][0] and s["error"] == expect[name][1],
			"%s / %s" % [s["status"], s["error"]])
	h.free()

	# Whole harness runs: exactly one DONE each.
	await _run_case("run: success twice, identical", _fake([ok, ok]), "success", [], true)
	await _run_case("run: not_found twice", _fake([nf, nf]), "not_found", [], true)
	await _run_case("run: values differ between reads", _fake([ok, _result("success", other)]), "success", [], false)
	await _run_case("run: malformed", _fake(["{not json", "{not json"]), "error", ["unparseable_plugin_result"])
	await _run_case("run: empty", _fake(["", ""]), "error", ["empty_plugin_result"])
	await _run_case("run: non-string", _fake([42, 42]), "error", ["non_string_plugin_result"])
	await _run_case("run: wrong shape", _fake([bad_entry, bad_entry]), "error", ["wrong_shape_plugin_result"])
	await _run_case("run: not_found with a per-key error", _fake([not_found_key_error, not_found_key_error]), "error", ["wrong_shape_plugin_result"])
	await _run_case("run: success with a per-key error", _fake([success_key_error, success_key_error]), "error", ["wrong_shape_plugin_result"])
	await _run_case("run: plugin error", _fake([plugin_error, plugin_error]), "error", ["origin_mismatch"])
	await _run_case("run: no reply (timeout)", _fake([NO_REPLY, NO_REPLY]), "error", ["harness_timeout"])
	await _run_case("run: singleton missing", null, "error", ["plugin_singleton_missing"])
	await _run_case("run: signal missing", FakeNoSignal.new(), "error", ["plugin_api_missing"])
	await _run_case("run: method missing", FakeNoMethod.new(), "error", ["plugin_method_missing"])

	# Lifecycle modes: which plugin calls, in which frame, and never a DONE line.
	await _run_lifecycle_case("lifecycle: quit during a held read", "quit_during_read", ["held_read", "quit"], false)
	await _run_lifecycle_case("lifecycle: Activity finished during a held read", "activity_finished_during_read", ["held_read", "finish_activity"], false)
	await _run_lifecycle_case("lifecycle: quit immediately after a queued request", "quit_immediately_after_request", ["queued_read", "quit"], true)
	await _run_lifecycle_case("lifecycle: Activity finished immediately after a queued request", "activity_finished_immediately_after_request", ["queued_read", "finish_activity"], true)
	print("M1_SELFTEST_RESULT %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
