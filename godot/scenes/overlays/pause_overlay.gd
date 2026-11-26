class_name PauseOverlay
extends OverlayPanel
## Pause menu (MENU button, Esc/P or Android Back): RESUME or RESTART.

signal resume_requested
signal restart_requested


func _ready() -> void:
	super._ready()
	items = [
		{"label": "RESUME", "color": T.GREEN, "action": func() -> void: resume_requested.emit()},
		{"label": "RESTART", "color": T.YELLOW, "action": func() -> void: restart_requested.emit()},
	]


func _process(delta: float) -> void:
	super._process(delta)
	if time > 0.25 and InputService.consume(&"menu"):
		resume_requested.emit()


func draw_content() -> void:
	menu_top = floor(size.y * 0.42)
	T.draw_centered(self, size.x / 2.0, menu_top - 40, "PAUSED", T.YELLOW, 2, T.SHADOW)
