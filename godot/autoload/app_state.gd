extends Node
## Current validated settings, records access and the selected playable profile.
## Owns no scene nodes and performs no file I/O itself (SaveService does).

signal settings_changed(settings: Dictionary)

const DEFAULT_PROFILE := &"zampano"
## Playable profiles present in this build (src/assets/manifest.ts PLAY_AS).
const PROFILES := {
	&"zampano": "res://data/characters/zampano_profile.tres",
	&"sbrimbrulon": "res://data/characters/sbrimbrulon_profile.tres",
	&"bagnaskiz": "res://data/characters/bagnaskiz_profile.tres",
}

## Developer launch override for the playable profile (`-- --as=<id>`), validated against
## PROFILES. The canonical game plays Zampanò; other profiles are a debug capability only
## (ARCHITECTURE.md §9.1). Reset on every reload().
var selected_profile: StringName = DEFAULT_PROFILE
## The last rejected `--as=` value ("" when none).
var rejected_profile := ""
var settings: Dictionary = {}


func _ready() -> void:
	reload()


## Re-reads the settings from SaveService and applies them (start-up, tests).
func reload() -> void:
	settings = SaveService.get_settings()
	var p := resolve_profile(OS.get_cmdline_user_args())
	selected_profile = p["profile"]
	rejected_profile = p["rejected"]
	if rejected_profile != "":
		push_warning("unknown playable profile '%s' (--as); playing %s" % [rejected_profile, DEFAULT_PROFILE])
	_apply()


## Pure: the profile selected by `--as=<id>` (the last one wins), or the default when absent or
## unknown. Returns {"profile": StringName, "rejected": String}.
static func resolve_profile(args: PackedStringArray) -> Dictionary:
	var out := {"profile": DEFAULT_PROFILE, "rejected": ""}
	for arg in args:
		if arg.begins_with("--as="):
			var id := StringName(arg.substr(5))
			if PROFILES.has(id):
				out = {"profile": id, "rejected": ""}
			else:
				out = {"profile": DEFAULT_PROFILE, "rejected": String(id)}
	return out


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
