class_name ControlsOverlay
extends OverlayPanel
## OPTIONS > CONTROLS (source ControlsScene): the three right-hand gestures, RUN held or toggled,
## the action switcher, the buttons for the right or the left hand, DEFAULTS, BACK. Every change
## is saved and applied at once (AppState → InputService); 'click' plays on each.

const BINDINGS := ["off", "action", "bark", "sword", "shield", "switch", "run"]
const BINDING_LABEL := {"off": "OFF", "action": "ACTION BUTTON", "bark": "BARK", "sword": "SWORD", "shield": "SHIELD", "switch": "SWITCH", "run": "RUN ON/OFF"}
const HELP := "GESTURES: ON THE BUTTON SIDE, ABOVE THE BUTTONS. SWORD AND SHIELD ONCE HE IS A KNIGHT.\n\nKEYS: J ACTION   B BARK\nU SWORD   I SHIELD (HOLD)\nQ SWITCH   K RUN"

var on_back: Callable


func setup(p_back: Callable) -> ControlsOverlay:
	on_back = p_back
	back_action = p_back
	_refresh()
	return self


func _ready() -> void:
	super._ready()
	dim = 1.0
	menu_item_width = 176.0
	menu_item_height = 16.0
	menu_gap = 4.0


func _refresh() -> void:
	var c: Dictionary = AppState.settings["controls"]
	items = [
		{"label": "SWIPE UP: %s" % BINDING_LABEL[c["swipeUp"]], "color": T.CYAN, "action": func() -> void: cycle("swipeUp")},
		{"label": "SWIPE DOWN: %s" % BINDING_LABEL[c["swipeDown"]], "color": T.CYAN, "action": func() -> void: cycle("swipeDown")},
		{"label": "DOUBLE TAP: %s" % BINDING_LABEL[c["doubleTap"]], "color": T.CYAN, "action": func() -> void: cycle("doubleTap")},
		{"label": "RUN: TAP ON/OFF" if c["run"] == "toggle" else "RUN: HOLD", "color": T.GREEN, "action": func() -> void: _apply_control("run", "hold" if c["run"] == "toggle" else "toggle")},
		{"label": "SWITCHER: ON" if c["switcher"] else "SWITCHER: OFF", "color": T.YELLOW, "action": func() -> void: _apply_control("switcher", not c["switcher"])},
		{"label": "BUTTONS: LEFT HAND" if c["hand"] == "left" else "BUTTONS: RIGHT HAND", "color": T.YELLOW, "action": func() -> void: _apply_control("hand", "right" if c["hand"] == "left" else "left")},
		{"label": "DEFAULTS", "color": T.PINK, "action": defaults},
		{"label": "BACK", "color": T.WHITE, "action": func() -> void: on_back.call()},
	]
	queue_redraw()


func cycle(key: String) -> void:
	var i := BINDINGS.find(AppState.settings["controls"][key])
	_apply_control(key, BINDINGS[(i + 1) % BINDINGS.size()])


func _apply_control(key: String, value: Variant) -> void:
	AppState.set_control(key, value)
	AudioService.play(&"click")
	_refresh()


func defaults() -> void:
	AppState.set_setting("controls", SaveService.default_settings()["controls"])
	AudioService.play(&"click")
	_refresh()


func draw_content() -> void:
	var top := roundf(maxf(64.0, size.y * 0.2))
	T.draw_centered(self, size.x / 2.0, top - 30, "CONTROLS", T.YELLOW, 2, T.SHADOW)
	menu_top = top
	var y := top + items.size() * (menu_item_height + menu_gap) + 10
	T.draw_centered(self, size.x / 2.0, y, "\n".join(T.wrap(HELP, 196)), Color("#9aa4c0"), 1, Color.BLACK)
