extends Node
## Current validated settings, records access, the campaign session (the saved campaign, or a
## replay's deep copy with persistence off) and the selected playable profile.
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
## Replay session (ARCHITECTURE.md §6): a deep copy of the campaign; nothing persists while true.
var replaying := false
var replay_state: Dictionary = {}
var replay_id := ""
## Unix milliseconds (tests inject a clock).
var clock: Callable = func() -> int: return int(Time.get_unix_time_from_system() * 1000.0)


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
	InputService.gesture_bindings = {"swipeUp": c["swipeUp"], "swipeDown": c["swipeDown"], "doubleTap": c["doubleTap"]}
	InputService.switcher_enabled = c["switcher"]
	AudioService.apply_settings(settings["muted"], settings["volume"])


## Changes one top-level setting and saves it (a confirmed change). Returns the saved settings.
func set_setting(key: String, value: Variant) -> Dictionary:
	var s := settings.duplicate(true)
	s[key] = value
	update_settings(s)
	return settings


func set_control(key: String, value: Variant) -> Dictionary:
	var s := settings.duplicate(true)
	s["controls"][key] = value
	update_settings(s)
	return settings


## The title's lives counter (source nextLives): one more life, back to the start after the most.
func step_lives(step: int) -> int:
	set_setting("lives", LivesRules.next_lives(lives(), step))
	return lives()


# --- Campaign session -----------------------------------------------------------------------------

func now_ms() -> int:
	return clock.call()


## The campaign in play: the replay's copy during a replay, otherwise the saved campaign (a copy).
func campaign() -> Dictionary:
	return replay_state.duplicate(true) if replaying else SaveService.get_campaign()


func has_progress() -> bool:
	return not (SaveService.get_campaign()["completed"] as Array).is_empty()


## Where CONTINUE goes (CampaignFlow.continue_target over the saved campaign).
func continue_target() -> Dictionary:
	return CampaignFlow.continue_target(SaveService.get_campaign(), SaveService.CATALOG)


## Source Flow.toTitle continueLabel: the next scene, the finished-story line, or "" without progress.
func continue_label() -> String:
	if not has_progress():
		return ""
	var label := SaveService.CATALOG.continue_label(SaveService.get_campaign()["completed"])
	return label if label != "" else "THE STORY IS FINISHED: REPLAY ANY LEVEL"


## NEW GAME (source resetCampaign): the exact default campaign, saved at once.
func new_game() -> bool:
	end_replay()
	return SaveService.save_campaign(CampaignSchema.new_campaign(), now_ms())


## The Green Zone walk (1.0) handed over by CONTINUE (source addWalk then finishSub): its coins go
## to the campaign purse, its time to the play time, then 1.0 is complete; two campaign saves, as in
## the source. A replay hands over nothing. Returns {"saved": bool, "replay": bool}.
func complete_walk(coins: int, seconds: float, sub_id: String = "1.0") -> Dictionary:
	if replaying:
		return {"saved": false, "replay": true}
	var st := SaveService.get_campaign()
	if coins != 0:
		st["coins"] = maxi(0, int(st["coins"]) + coins)
	st["playTime"] = float(st["playTime"]) + maxf(0.0, seconds)
	var a: bool = SaveService.save_campaign(st, now_ms())
	st = SaveService.get_campaign()
	CampaignFlow.finish(st, sub_id, false)
	var b: bool = SaveService.save_campaign(st, now_ms())
	return {"saved": a and b, "replay": false}


## A replay of a finished scene starts from a deep copy; persistence stays off until end_replay().
func begin_replay(id: String) -> void:
	replaying = true
	replay_id = id
	replay_state = CampaignSchema.deep_copy(SaveService.get_campaign())


func end_replay() -> void:
	replaying = false
	replay_id = ""
	replay_state = {}


## The Green Zone record and the campaign persist only outside replays.
func persists() -> bool:
	return not replaying


## The one-time "dream rewritten" notice (source showNotice): true once, then cleared and saved.
func take_story_notice() -> bool:
	var st := SaveService.get_campaign()
	if not CampaignMigration.consume_notice(st):
		return false
	SaveService.data["campaign"] = st
	SaveService.write_to_disk()
	return true


func lives() -> int:
	return int(settings["lives"])
