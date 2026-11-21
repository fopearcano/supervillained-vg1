extends SceneTree
## First-party headless test runner (TEST_PLAN.md §3).
##   godot --headless --path godot --script res://tests/test_runner.gd -- --suite all
## Options: --suite all|unit|content|integration, --file <substring>, --case <substring>,
## --repeat <n>.
## Fails on assertion failures, engine errors/warnings, orphan nodes and timeouts; writes JSON and
## JUnit XML to res://test-results/ (git-ignored); exits non-zero on any failure.

const TIMEOUT_MS := 120000

var _capture: ErrorCapture


func _initialize() -> void:
	_run.call_deferred()


func _args() -> Dictionary:
	var out := {"suite": "all", "case": "", "repeat": 1, "file": ""}
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		args = OS.get_cmdline_args()
	for k in args.size():
		match args[k]:
			"--suite": out["suite"] = args[k + 1]
			"--case": out["case"] = args[k + 1]
			"--repeat": out["repeat"] = int(args[k + 1])
			"--file": out["file"] = args[k + 1]
	return out


func _run() -> void:
	var opts := _args()
	_capture = ErrorCapture.new()
	OS.add_logger(_capture)
	root.get_node("InputService").auto_update = false
	var suites: Array = TestRegistry.SUITES.keys() if opts["suite"] == "all" else [opts["suite"]]
	var results: Array = []
	var started := Time.get_ticks_msec()
	for suite: String in suites:
		for path: String in TestRegistry.SUITES[suite]:
			if opts["file"] != "" and not path.contains(opts["file"]):
				continue
			var script: GDScript = load(path)
			if script == null:
				results.append({"suite": suite, "file": path, "case": "load", "ok": false, "messages": ["cannot load script"], "ms": 0})
				continue
			for method in script.get_script_method_list():
				var name: String = method["name"]
				if not name.begins_with("test_") or (opts["case"] != "" and not name.contains(opts["case"])):
					continue
				for rep in int(opts["repeat"]):
					results.append(await _run_case(suite, path, script, name))
	OS.remove_logger(_capture)
	root.get_node("AudioService").stop_all()
	await process_frame
	_report(results, Time.get_ticks_msec() - started)


func _run_case(suite: String, path: String, script: GDScript, name: String) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var orphans_before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	_capture.take()
	root.get_node("InputService").reset_for_tests()
	var tc: TestCase = script.new()
	tc.tree = self
	tc.before_each()
	var done := [false]
	var runner := func() -> void:
		await tc.call(name)
		done[0] = true
	runner.call()
	while not done[0]:
		if Time.get_ticks_msec() - t0 > TIMEOUT_MS:
			tc.fail("timeout after %d ms" % TIMEOUT_MS)
			break
		await process_frame
	tc.after_each()
	await process_frame
	var messages: Array = Array(tc.failures)
	for e: Dictionary in _capture.take():
		var kind := "warning" if e["type"] == Logger.ERROR_TYPE_WARNING else "error"
		messages.append("engine %s: %s %s (%s)" % [kind, e["code"], e["rationale"], e["where"]])
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) - orphans_before
	if orphans > 0:
		messages.append("%d orphan node(s) leaked" % orphans)
	var ok := messages.is_empty()
	var ms := Time.get_ticks_msec() - t0
	print("%s %-58s %5d ms" % ["PASS" if ok else "FAIL", name, ms])
	for m in messages:
		print("       - ", m)
	return {"suite": suite, "file": path, "case": name, "ok": ok, "messages": messages, "ms": ms}


func _report(results: Array, total_ms: int) -> void:
	var failed := results.filter(func(r: Dictionary) -> bool: return not r["ok"])
	print("\n%d passed, %d failed, %d total (%.1f s), Godot %s" % [results.size() - failed.size(), failed.size(), results.size(), total_ms / 1000.0, Engine.get_version_info()["string"]])
	var dir := ProjectSettings.globalize_path("res://test-results")
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("results.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"godot": Engine.get_version_info()["string"], "total_ms": total_ms, "results": results}, "  "))
	f.close()
	var xml := PackedStringArray(['<?xml version="1.0" encoding="UTF-8"?>', '<testsuites tests="%d" failures="%d">' % [results.size(), failed.size()]])
	for r: Dictionary in results:
		xml.append('  <testcase classname="%s" name="%s" time="%.3f">' % [r["file"].xml_escape(), r["case"].xml_escape(), r["ms"] / 1000.0])
		if not r["ok"]:
			xml.append('    <failure message="%s"/>' % "; ".join(PackedStringArray(r["messages"])).xml_escape(true))
		xml.append('  </testcase>')
	xml.append('</testsuites>')
	var x := FileAccess.open(dir.path_join("junit.xml"), FileAccess.WRITE)
	x.store_string("\n".join(xml))
	x.close()
	quit(1 if not failed.is_empty() or results.is_empty() else 0)
