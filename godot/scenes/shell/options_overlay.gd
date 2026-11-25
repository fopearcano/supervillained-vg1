class_name OptionsOverlay
extends OverlayPanel
## OPTIONS (source OptionsScene): SOUND, VOLUME, TEXT speed, CONTROLS, LEVELS (REPLAY),
## MERAVIGLIA BOOK, BACK. Each change is a confirmed change: saved at once and applied to audio and
## input (AppState.update_settings). The lives are on the title's counter, as in the source.

const VOLUME_STEPS := [0.25, 0.5, 0.7, 1.0]
const TEXT_SPEEDS := ["slow", "normal", "fast", "instant"]

## {"controls", "levels", "book", "back"} -> Callable
var actions: Dictionary = {}


func setup(p_actions: Dictionary) -> OptionsOverlay:
	actions = p_actions
	back_action = actions["back"]
	_refresh()
	return self


func _ready() -> void:
	super._ready()
	dim = 0.94
	menu_item_width = 160.0
	menu_item_height = 18.0
	menu_gap = 6.0


func _refresh() -> void:
	var s := AppState.settings
	items = [
		{"label": "SOUND: OFF" if s["muted"] else "SOUND: ON", "color": T.CYAN, "action": toggle_sound},
		{"label": "VOLUME: %d%%" % int(round(float(s["volume"]) * 100.0)), "color": T.CYAN, "action": cycle_volume},
		{"label": "TEXT: %s" % String(s["textSpeed"]).to_upper(), "color": T.CYAN, "action": cycle_text_speed},
		{"label": "CONTROLS", "color": T.GREEN, "action": actions["controls"]},
		{"label": "LEVELS (REPLAY)", "color": T.YELLOW, "action": actions["levels"]},
		{"label": "MERAVIGLIA BOOK", "color": T.PINK, "action": actions["book"]},
		{"label": "BACK", "color": T.WHITE, "action": actions["back"]},
	]
	queue_redraw()


func toggle_sound() -> void:
	AppState.set_setting("muted", not AppState.settings["muted"])
	_refresh()


## Source cycleVolume: the next step above the current volume, wrapping.
func cycle_volume() -> void:
	var v := float(AppState.settings["volume"])
	var i := -1
	for k in VOLUME_STEPS.size():
		if VOLUME_STEPS[k] >= v - 0.01:
			i = k
			break
	AppState.set_setting("volume", VOLUME_STEPS[(i + 1) % VOLUME_STEPS.size()])
	AudioService.play(&"click")
	_refresh()


func cycle_text_speed() -> void:
	var i := TEXT_SPEEDS.find(AppState.settings["textSpeed"])
	AppState.set_setting("textSpeed", TEXT_SPEEDS[(i + 1) % TEXT_SPEEDS.size()])
	_refresh()


func draw_content() -> void:
	T.draw_centered(self, size.x / 2.0, roundf(size.y * 0.22) - 8, "OPTIONS", T.YELLOW, 2, T.SHADOW)
	menu_top = roundf(size.y * 0.32)
