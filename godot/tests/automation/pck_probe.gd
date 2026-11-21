extends SceneTree
## Runs INSIDE an exported pack (never exported itself: tests/ is excluded):
##   godot --headless --main-pack <file.pck> --script <absolute path of this file> -- --expect <list.json>
## res:// is then the pack only. Checks every expected runtime path loads from the pack, that no
## excluded content was packed, that the exported leading-silence Resource reaches AudioService,
## and that the real main scene starts. Prints one line: PCK_PROBE {json}.
## No class_name and no static references to project classes: they live in the pack.

var _report := {"missing": [], "unloadable": [], "forbidden": [], "files": 0}


func _initialize() -> void:
	_run.call_deferred()


func _walk(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.include_hidden = true
	for f in d.get_files():
		out.append(dir.path_join(f))
	for sub in d.get_directories():
		_walk(dir.path_join(sub), out)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var expect_path := ""
	for k in args.size():
		if args[k] == "--expect" and k + 1 < args.size():
			expect_path = args[k + 1]
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(expect_path))
	for p: String in expected["resources"]:
		if not ResourceLoader.exists(p):
			_report["missing"].append(p)
		elif load(p) == null:
			_report["unloadable"].append(p)
	for p: String in expected["raw_files"]:
		if not FileAccess.file_exists(p) or FileAccess.get_file_as_bytes(p).is_empty():
			_report["missing"].append(p)
	var all: Array = []
	_walk("res://", all)
	_report["files"] = all.size()
	for p: String in all:
		var rel := p.trim_prefix("res://")
		var bad := rel.begins_with("tests/") or rel.begins_with("tools/") or rel.begins_with("test-results/")
		bad = bad or rel.ends_with(".json") or rel.ends_with(".md") or rel.ends_with(".mjs") or rel.ends_with(".ps1") or rel.ends_with(".sh")
		if bad:
			_report["forbidden"].append(rel)
	var audio := root.get_node_or_null("AudioService")
	_report["audio_offsets"] = audio.offsets if audio else {}
	_report["quit_on_go_back"] = ProjectSettings.get_setting("application/config/quit_on_go_back")
	var main_path: String = ProjectSettings.get_setting("application/run/main_scene")
	var main: Node = load(main_path).instantiate()
	root.add_child(main)
	for k in 60:
		await process_frame
	var current: Node = main.get("current_scene")
	_report["main_scene"] = main_path
	_report["running_scene"] = current.scene_file_path if current else ""
	_report["dog_frames"] = current.world.player.body_sprite.sprite_frames.get_animation_names().size() if current and current.get("world") else 0
	root.remove_child(main)
	main.free()
	audio.stop_all()
	_report["ok"] = _report["missing"].is_empty() and _report["unloadable"].is_empty() and _report["forbidden"].is_empty()
	print("PCK_PROBE ", JSON.stringify(_report))
	quit(0)
