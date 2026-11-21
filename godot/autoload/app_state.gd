extends Node
## Current validated settings, records access and the selected playable profile.
## Owns no scene nodes and performs no file I/O itself (SaveService does).

signal settings_changed(settings: Dictionary)

## Developer launch override for the playable profile (`-- --as=<id>`). The canonical game
## plays Zampanò; other profiles are a debug capability only (ARCHITECTURE.md §9.1).
var selected_profile: StringName = &"zampano"
var settings: Dictionary = {}


func _ready() -> void:
	reload()


## Re-reads the settings from SaveService and applies them (start-up, tests).
func reload() -> void:
	settings = SaveService.get_settings()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--as="):
			selected_profile = StringName(arg.substr(5))
	_apply()


func update_settings(new_settings: Dictionary) -> void:
	if SaveService.set_settings(new_settings)["changed"]:
		settings = SaveService.get_settings()
		_apply()
		settings_changed.emit(settings)


func _apply() -> void:
	var c: Dictionary = settings["controls"]
	InputService.run_toggle = c["run"] == "toggle"
	InputService.left_handed = c["hand"] == "left"
	AudioService.apply_settings(settings["muted"], settings["volume"])


func lives() -> int:
	return int(settings["lives"])
