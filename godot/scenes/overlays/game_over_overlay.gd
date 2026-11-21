class_name GameOverOverlay
extends OverlayPanel
## GAME OVER card (src/scenes/overlays.ts GameOverScene): RETRY and QUIT TO TITLE.

signal retry_requested
signal title_requested

var score := 0


func _ready() -> void:
	super._ready()
	dim = 0.6
	items = [
		{"label": "RETRY", "color": T.YELLOW, "action": func() -> void: retry_requested.emit()},
		{"label": "QUIT TO TITLE", "color": T.PINK, "action": func() -> void: title_requested.emit()},
	]


func draw_content() -> void:
	var cx := size.x / 2.0
	var y := floorf(size.y * 0.26)
	T.draw_centered(self, cx, y, "GAME OVER", T.RED, 2, Color.WHITE)
	T.draw_centered(self, cx, y + 30, "ZAMPANO IS TOO HUNGRY\nTO GO ON...", T.PALE_ROSE, 1, Color.BLACK)
	T.draw_centered(self, cx, y + 60, "SCORE %s" % ScoringRules.format_score(score), T.CYAN, 1, T.SHADOW)
	menu_top = y + 84
