class_name WorldText
extends Node2D
## Pixel text placed in the world: the floating EXIT label, score popups (rise and fade over
## FX.SCORE_POPUP_TIME) and the blinking poop-warning mark above the dog.

var text := ""
var color := Color.WHITE
var outline := Color.BLACK
var life := -1.0
var age := 0.0
var rise := 0.0


func _process(delta: float) -> void:
	if life > 0.0:
		age += delta
		if age >= life:
			queue_free()
			return
		modulate.a = 1.0 - maxf(0.0, (age / life - 0.5) * 2.0)
		position.y -= rise * delta
	queue_redraw()


func _draw() -> void:
	var w := PixelText.width(text)
	var p := Vector2(-floor(w / 2.0), -8)
	for o: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		PixelText.draw(self, p + o, text, outline)
	PixelText.draw(self, p, text, color)
