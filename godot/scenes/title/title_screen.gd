class_name TitleScreen
extends OverlayPanel
## The title page (port of src/scenes/overlays.ts TitleScene, M4 shell): SUPERVILLAINED and the
## edition title at the top, Zampanò's animated portrait, NEW GAME / CONTINUE / COUCH / OPTIONS /
## GLOSSARY / QUIT, INSERT BRAIN with the lives counter (tap it or LEFT/RIGHT: more lives, less
## speed) and LIFE FOR SPEED blinking under it, SUPERVOID EDITIONS (the publisher's site) at the
## bottom. CONTINUE is preselected when a story is saved. Layout follows the source's TITLE
## constants; the logo lettering, film and glitch filters are simplified (M8 presentation debt).

const TT := GameConfig.Title
const SPRITES: SpriteCatalog = preload("res://data/environment/green_zone_sprites.tres")
const TEXT: ShellText = preload("res://data/shell/shell_text.tres")
const LOGO := "SUPERVILLAINED"
const LOGO_COLOR := Color("#d4ff3a")
const LOGO_OUTLINE := Color("#120818")
const VIOLET := Color("#a77bff")

## {"new_game", "cont", "couch", "options", "glossary", "quit", "publisher"} -> Callable
var actions: Dictionary = {}
## True while another screen covers the title (it keeps animating but takes no input).
var covered: Callable = func() -> bool: return false
var lives_rect := Rect2()
var footer_rect := Rect2()
var logo_scale := 1
var dog_rect := Rect2()
var menu_y := 0.0
var _portrait: TitlePortrait
var _shine_button := -1
var _shine_time := 0.0
var _next_shine := 1.2
var _last_shine := -1
var _footer_flash := 0.0


func setup(p_actions: Dictionary, has_progress: bool) -> TitleScreen:
	actions = p_actions
	items = [
		{"label": "NEW GAME", "color": T.RED, "action": actions["new_game"]},
		{"label": "CONTINUE", "color": T.YELLOW, "action": actions["cont"]},
		{"label": "COUCH", "color": T.ORANGE, "action": actions["couch"]},
		{"label": "OPTIONS", "color": T.CYAN, "action": actions["options"]},
		{"label": "GLOSSARY", "color": VIOLET, "action": actions["glossary"]},
		{"label": "QUIT", "color": T.PINK, "action": actions["quit"]},
	]
	selected = 1 if has_progress else 0
	back_action = actions["quit"]
	return self


func _ready() -> void:
	super._ready()
	dim = 0.15
	menu_item_width = 150.0
	menu_item_height = 18.0
	menu_gap = 6.0
	_portrait = TitlePortrait.new()
	add_child(_portrait)
	resized.connect(_layout)
	_layout()


func resize(logical: Vector2i) -> void:
	size = Vector2(logical)
	_layout()


func _menu_height() -> float:
	return items.size() * menu_item_height + (items.size() - 1) * menu_gap


## Source TitleScene.layout(): the title near the top, then one block (portrait, buttons, INSERT
## BRAIN row, LIFE FOR SPEED) centred between the edition line and the publisher line.
func _layout() -> void:
	var w := size.x
	var h := size.y
	logo_scale = 1
	for sc in [4, 3, 2, 1]:
		if T.width(LOGO, sc) + 8 <= w:
			logo_scale = sc
			break
	var half_title := roundf(T.CELL_H * logo_scale / 2.0)
	var title_y := roundf(h * TT.TOP) + half_title
	var edition_y := title_y + half_title + 10
	var header_bottom := edition_y + 5
	var footer_top := h - 6 - T.CELL_H
	var row_h := 12.0
	var below: float = TT.DOG_MENU_GAP + _menu_height() + TT.INSERT_BRAIN_GAP + row_h + 5 + T.CELL_H
	var space := footer_top - header_bottom
	var max_dog_h: float = space - below - 2 * TT.BLOCK_MIN_MARGIN
	var dog_w := maxf(24.0, minf(roundf(w * TT.DOG_WIDTH), floorf(max_dog_h / TT.DOG_ASPECT)))
	var dog_h := roundf(dog_w * TT.DOG_ASPECT)
	var my: float = TT.DOG_CROP_MARGIN[1]
	var top_pad := roundf(dog_h * my / (1 + 2 * my))
	var margin := maxf(0.0, roundf((space - (dog_h - top_pad) - below) / 2.0))
	var dog_y := header_bottom + margin - top_pad
	dog_rect = Rect2(roundf(w / 2.0 - dog_w / 2.0), dog_y, dog_w, dog_h)
	menu_y = dog_y + dog_h + TT.DOG_MENU_GAP
	menu_top = menu_y
	if _portrait:
		_portrait.fit_width(dog_w)
		_portrait.position = dog_rect.position
	queue_redraw()


func _process(delta: float) -> void:
	_footer_flash = maxf(0.0, _footer_flash - delta)
	_animate_shine(delta)
	if covered.call():
		time += delta
		queue_redraw()
		return
	if time < 0.5:
		time += delta
		queue_redraw()
		return
	if time > 0.6:
		if Input.is_action_just_pressed(&"move_right"):
			change_lives(1)
		elif Input.is_action_just_pressed(&"move_left"):
			change_lives(-1)
	super._process(delta)


func change_lives(step: int) -> void:
	AppState.step_lives(step)
	AudioService.play(&"click")
	queue_redraw()


func on_tap(pos: Vector2) -> void:
	if time <= 0.6 or covered.call():
		return
	if lives_rect.grow_individual(6, 5, 6, 5).has_point(pos):
		change_lives(1)
	elif footer_rect.grow(6).has_point(pos):
		_footer_flash = 0.25
		actions["publisher"].call()


## A slow glint crossing one button now and then (never the same one twice in a row).
func _animate_shine(delta: float) -> void:
	if time <= 0.5:
		return
	if _shine_button < 0:
		_next_shine -= delta
		if _next_shine > 0.0:
			return
		var pick := randi() % items.size()
		if pick == _last_shine and items.size() > 1:
			pick = (pick + 1) % items.size()
		_shine_button = pick
		_last_shine = pick
		_shine_time = 0.0
	_shine_time += delta
	if _shine_time / TT.SHINE_TIME >= 1.0:
		_shine_button = -1
		_next_shine = lerpf(TT.SHINE_EVERY[0], TT.SHINE_EVERY[1], randf())


func insert_brain_visible() -> bool:
	return time > 0.6 and fmod(time, TT.INSERT_BRAIN_BLINK) < TT.INSERT_BRAIN_BLINK * 0.6


func draw_content() -> void:
	var w := size.x
	var h := size.y
	var cx := roundf(w / 2.0)
	var jitter := int(round((randf() * 2.0 - 1.0) * 4.0 * (1.0 - time / 0.9))) if time < 0.9 else 0
	var half_title := roundf(T.CELL_H * logo_scale / 2.0)
	var title_y := roundf(h * TT.TOP) + half_title
	T.draw_centered(self, cx + jitter, title_y - half_title, LOGO, LOGO_COLOR, logo_scale, LOGO_OUTLINE)
	if time > 0.25:
		var ed := TEXT.get_text("edition")
		var ew := ed.length() * 8 + (ed.length() - 1) * 6
		for k in ed.length():
			T.draw(self, Vector2(cx - jitter - ew / 2.0 + k * 14, title_y + half_title + 10 - 4), ed[k], T.HOT_PINK, 1, T.SHADOW)
	if _portrait:
		_portrait.visible = time > 0.35
	menu_hidden = time <= 0.5
	# INSERT BRAIN, the lives counter and LIFE FOR SPEED.
	var best_y := menu_y + _menu_height() + TT.INSERT_BRAIN_GAP
	var row_h := 12.0
	var label := "INSERT BRAIN"
	var lives_text := "%dx" % AppState.lives()
	var face := SPRITES.texture("dogFace_0")
	var box_w := 4 + T.width(lives_text) + 2 + face.get_width() + 4
	var x0 := roundf(cx - (T.width(label) + 8 + box_w) / 2.0)
	var bx := x0 + T.width(label) + 8
	lives_rect = Rect2(bx, best_y, box_w, row_h)
	if insert_brain_visible():
		T.draw(self, Vector2(x0, best_y + 2), label, T.WHITE, 1, Color.BLACK)
		T.draw_centered(self, cx, best_y + row_h + 5, "LIFE FOR SPEED", Color("#8ad4ff"), 1, Color.BLACK)
	if time > 0.5:
		draw_rect(lives_rect, Color(0, 0, 0, 0.45))
		T._frame(self, lives_rect, Color(T.YELLOW, 0.9))
		T.draw(self, Vector2(bx + 4, best_y + 2), lives_text, T.YELLOW, 1, Color.BLACK)
		draw_texture(face, Vector2(bx + 4 + T.width(lives_text) + 2, best_y + roundf((row_h - face.get_height()) / 2.0)))
	# SUPERVOID EDITIONS.
	var footer := "SUPERVOID EDITIONS"
	var fw := footer.length() * 9 - 1
	footer_rect = Rect2(cx - fw / 2.0, h - 6 - T.CELL_H, fw, T.CELL_H)
	var glow := 0.05 + 0.7 * (0.5 - 0.5 * cos(time * TT.FOOTER_GLOW_SPEED))
	for k in footer.length():
		var p := Vector2(footer_rect.position.x + k * 9, footer_rect.position.y)
		T.draw(self, p + Vector2(0, 1), footer[k], Color(Color(TT.FOOTER_GLOW_COLOR), glow * 0.5))
		T.draw(self, p, footer[k], Color(T.GREEN, 0.55 if _footer_flash > 0.0 else 1.0), 1, Color.BLACK)


func _draw() -> void:
	super._draw()
	# The glint over one button (masked to it).
	if _shine_button >= 0 and _shine_button < item_rects().size():
		var r := item_rects()[_shine_button].grow(-1)
		var p := _shine_time / TT.SHINE_TIME
		var e := 0.5 - 0.5 * cos(p * PI)
		var bw: float = TT.SHINE_WIDTH
		var sl: float = TT.SHINE_SLANT
		var x := roundf(r.position.x - bw - sl + (r.size.x + bw + 2 * sl) * e)
		var a: float = TT.SHINE_ALPHA * sin(p * PI)
		var poly := PackedVector2Array([Vector2(x + sl, r.position.y), Vector2(x + sl + bw, r.position.y), Vector2(x + bw, r.end.y), Vector2(x, r.end.y)])
		var clipped := Geometry2D.intersect_polygons(poly, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]))
		for c in clipped:
			draw_colored_polygon(c, Color(1, 1, 1, a))
