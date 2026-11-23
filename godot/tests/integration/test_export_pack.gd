extends TestCase
## Exports the Android preset as a PCK with this very Godot binary, then runs that pack as the
## only res:// (packed runtime): every runtime resource loads from it, excluded content is absent,
## the exported leading-silence Resource reaches AudioService, the real main scene starts, and a
## 600-frame packed startup logs no engine error or warning. The packed runs get their own user
## data directory (XDG_DATA_HOME / APPDATA / HOME), so they never touch a real save, and an empty
## isolated --path, so no file of the checkout can satisfy a res:// lookup (a source-only sentinel
## must not resolve there; with the checkout as --path the same sentinel does resolve, the control).
## Android device behaviour (APK, lifecycle, hardware) is not covered here (AND-001…013).

const PROBE := "res://tests/automation/pck_probe.gd"
## Development-only trees: never runtime data (platform/ holds native spikes and tooling).
const SKIP_DIRS := [".godot", "tests", "tools", "test-results", "platform"]
## Exists in the source tree only (tests/ is excluded from every export).
const SENTINEL := "res://tests/automation/pck_source_only_sentinel.tres"

var _env: Dictionary = {}
var _work := ""


func after_each() -> void:
	for k: String in _env:
		if _env[k] == null:
			OS.unset_environment(k)
		else:
			OS.set_environment(k, _env[k])
	_env.clear()
	if _work != "":
		_remove_tree(_work)
		_work = ""


func _remove_tree(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.include_hidden = true
	for f in d.get_files():
		DirAccess.remove_absolute(dir.path_join(f))
	for sub in d.get_directories():
		_remove_tree(dir.path_join(sub))
	DirAccess.remove_absolute(dir)


## Every resource the project itself can load, outside tests/tools/platform and any directory with
## a .gdignore (Godot neither imports nor exports those), except the JSON build inputs.
func _runtime_resources(dir: String, out: Array) -> void:
	if FileAccess.file_exists(dir.path_join(".gdignore")):
		return
	var d := DirAccess.open(dir)
	for f in d.get_files():
		var p := dir.path_join(f)
		if f.ends_with(".import") or f.ends_with(".uid") or f.ends_with(".json") or f.ends_with(".md"):
			continue
		if FileAccess.file_exists(p + ".import"):
			var cfg := ConfigFile.new()
			cfg.load(p + ".import")
			if cfg.get_value("remap", "importer", "") == "skip":
				continue  # consumed by another import (the font page PNG lives in the .fnt import)
		if ResourceLoader.exists(p):
			out.append(p)
	for sub in d.get_directories():
		if dir == "res://" and sub in SKIP_DIRS:
			continue
		_runtime_resources(dir.path_join(sub), out)


func _errors(lines: Array) -> PackedStringArray:
	var bad := PackedStringArray()
	for chunk: String in lines:
		for line in chunk.split("\n"):
			if line.begins_with("ERROR") or line.begins_with("WARNING") or line.begins_with("SCRIPT ERROR") or line.contains("leaked"):
				bad.append(line)
	return bad


func _isolated_user_data(dir: String) -> void:
	for k in ["XDG_DATA_HOME", "APPDATA", "HOME"]:
		_env[k] = OS.get_environment(k) if OS.has_environment(k) else null
	OS.set_environment("XDG_DATA_HOME", dir)
	OS.set_environment("APPDATA", dir)
	if OS.get_name() == "macOS":
		OS.set_environment("HOME", dir)


func test_SLICE_android_pck_has_runtime_data_and_starts_clean() -> void:
	var exe := OS.get_executable_path()
	var work := ProjectSettings.globalize_path("user://").path_join("pck_%d" % OS.get_process_id())
	_work = work
	DirAccess.make_dir_recursive_absolute(work.path_join("userdata"))
	var pck := work.path_join("supervillained_android.pck")
	var out: Array = []
	var code := OS.execute(exe, ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--export-pack", "Android", pck], out, true)
	assert_eq(code, 0, "Android preset PCK export exit code")
	assert_eq(_errors(out), PackedStringArray(), "export logs no error or warning")
	assert_true(FileAccess.file_exists(pck), "PCK written")
	var resources: Array = []
	_runtime_resources("res://", resources)
	assert_true(resources.has("res://data/audio/sfx_leading_silence.tres"), "the leading-silence Resource is runtime data")
	assert_true(resources.size() > 80, "runtime resource list (%d)" % resources.size())
	assert_false(resources.any(func(p: String) -> bool: return p.begins_with("res://platform/")), "no development-only platform path in the expected runtime list")
	# Source-only paths a hermetic packed run must not resolve: the sentinel and every file of the
	# development-only platform tree.
	assert_true(FileAccess.file_exists(SENTINEL) and ResourceLoader.exists(SENTINEL), "the source-only sentinel exists in the checkout")
	var absent: Array = [SENTINEL]
	_source_files("res://platform", absent)
	var expect := work.path_join("expected.json")
	var f := FileAccess.open(expect, FileAccess.WRITE)
	f.store_string(JSON.stringify({"resources": resources, "raw_files": ["res://assets/fonts/OFL.txt"], "absent": absent}))
	f.close()
	_isolated_user_data(work.path_join("userdata"))
	var isolated := work.path_join("isolated_root")
	DirAccess.make_dir_recursive_absolute(isolated)
	# Control: with the checkout as --path, files missing from the pack resolve from disk, so the
	# sentinel is seen (the check can detect leakage).
	out.clear()
	code = OS.execute(exe, ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--main-pack", pck, "--script", ProjectSettings.globalize_path(PROBE), "--", "--expect", expect, "--absent-only"], out, true)
	var control := _probe_report(out)
	assert_true(code == 0 and (control.get("resolved_absent", []) as Array).has(SENTINEL), "control: with the checkout as --path the packed run resolves the source-only sentinel")
	# Hermetic run: an empty --path, so res:// is the pack and nothing else.
	out.clear()
	code = OS.execute(exe, ["--headless", "--path", isolated, "--main-pack", pck, "--script", ProjectSettings.globalize_path(PROBE), "--", "--expect", expect], out, true)
	assert_eq(code, 0, "packed probe exit code")
	assert_eq(_errors(out), PackedStringArray(), "packed probe logs no error or warning")
	var report := _probe_report(out)
	if not assert_false(report.is_empty(), "probe report"):
		return
	assert_eq(report["resolved_absent"], [], "no source-only path (sentinel, %d platform files) resolves in the hermetic packed run" % (absent.size() - 1))
	assert_eq([report["missing"], report["unloadable"], report["forbidden"]], [[], [], []], "every runtime resource loads from the pack; no excluded content (tests, tools, platform, JSON, docs, scripts)")
	assert_eq((report["audio_offsets"] as Dictionary).size(), 12, "exported leading silence reaches AudioService")
	assert_near(float(report["audio_offsets"]["bark"]), 0.0947083333333333, 1e-9, "bark offset from the pack")
	assert_eq([report["running_scene"], report["quit_on_go_back"]], ["res://scenes/green_zone/green_zone_scene.tscn", false], "main scene starts the Green Zone; Back never quits")
	assert_true(int(report["dog_frames"]) > 0, "Zampanò's SpriteFrames load from the pack")
	out.clear()
	code = OS.execute(exe, ["--headless", "--path", isolated, "--main-pack", pck, "--quit-after", "600"], out, true)
	assert_eq(code, 0, "600-frame packed startup exit code")
	assert_eq(_errors(out), PackedStringArray(), "600-frame packed startup logs no engine error or warning")
	assert_eq(DirAccess.get_files_at(isolated).size() + DirAccess.get_directories_at(isolated).size(), 0, "the isolated --path stays empty")
	print("       PCK %d bytes, %d runtime resources checked, %d packed files, %d source-only paths unresolved (control resolved %d)" % [FileAccess.get_file_as_bytes(pck).size(), resources.size(), int(report["files"]), absent.size(), (control.get("resolved_absent", []) as Array).size()])


## Every file under a source directory (hidden ones included); nothing when it does not exist.
func _source_files(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.include_hidden = true
	for f in d.get_files():
		out.append(dir.path_join(f))
	for sub in d.get_directories():
		_source_files(dir.path_join(sub), out)


## The probe's PCK_PROBE report from a child's output, or {}.
func _probe_report(lines: Array) -> Dictionary:
	for line in "".join(lines).split("
"):
		if line.begins_with("PCK_PROBE "):
			var parsed: Variant = JSON.parse_string(line.trim_prefix("PCK_PROBE "))
			return parsed if parsed is Dictionary else {}
	return {}
