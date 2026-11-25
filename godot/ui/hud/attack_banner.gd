class_name AttackBanner
extends Control
## "GREEN ZONE / UNDER ATTACK" (port of src/ui/attackBanner.ts): a big flashing title when the
## attack starts, then a small blinking reminder with a hint, and "ZONE SAVED!" when it ends.
## Presentation only: the scene drives it from the threat signals.

const T := preload("res://ui/theme/pixel_text.gd")

var active := false
var hint := ""
var _t := 0.0
var _saved_t := -1.0
var _jitter := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func layout(view: Vector2i) -> void:
	size = Vector2(view)
	queue_redraw()


func start() -> void:
	active = true
	_t = 0.0
	_saved_t = -1.0


func end() -> void:
	active = false
	_saved_t = 0.0


func big_title_shown() -> bool:
	return active and _t < GameConfig.Attack.TITLE_TIME


func saved_shown() -> bool:
	return _saved_t >= 0.0 and _saved_t < 2.0


func update_banner(dt: float, p_hint: String) -> void:
	_t += dt
	if _saved_t >= 0.0:
		_saved_t += dt
	hint = p_hint
	visible = active or saved_shown()
	# Jitter like a broken signal (cosmetic randomness, as in the source).
	_jitter = int(round((randf() * 2.0 - 1.0) * 3.0)) if big_title_shown() and randf() < 0.25 else 0
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var cx := roundf(w / 2.0)
	if saved_shown() and int(floor(_saved_t * 6.0)) % 2 == 0:
		T.draw_centered(self, cx, roundf(h * 0.4) - 8, "ZONE SAVED!", T.GREEN, 2, Color("#002a08"))
	if not active:
		return
	var flash := int(floor(_t * 7.0)) % 2 == 0
	if big_title_shown():
		if flash:
			T.draw_centered(self, cx + _jitter, roundf(h * 0.36) - 8, "GREEN ZONE", T.ORANGE, 2, Color("#2a0a00"))
		if flash or _t > GameConfig.Attack.TITLE_TIME * 0.5:
			T.draw_centered(self, cx - _jitter, roundf(h * 0.36 + 20) - 8, "UNDER ATTACK", T.YELLOW, 2, Color("#2a0a00"))
		return
	if int(floor(_t * 3.0)) % 2 == 0:
		T.draw_centered(self, cx, 58, "UNDER ATTACK!", T.RED, 1, Color.BLACK)
	if hint != "":
		T.draw_centered(self, cx, 70, hint, T.WHITE, 1, Color.BLACK)
