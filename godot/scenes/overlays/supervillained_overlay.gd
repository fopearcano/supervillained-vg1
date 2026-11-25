class_name SupervillainedOverlay
extends Control
## "You've been supervillained" (port of src/scenes/supervillainedScene.ts): the logo snaps in over
## the frozen level (oversized, a white flash, a shake, a bark), sparkles and stars burst out of
## it, then `done` fires after SUPERVILLAINED.HOLD seconds, or on a tap/confirm after SKIP_AFTER.
## The logo is scaled like the source titleTexture: smooth (linear) sampling to the logical width,
## then the same alpha cut (110 of 255) as the title portrait.

signal done

const SV := GameConfig.Supervillained
const LOGO: Texture2D = preload("res://assets/branding/supervillained_logo.png")
const ALPHA_CUT: Shader = preload("res://ui/title/title_portrait.gdshader")
const SPARK_TINTS := [Color8(0xff, 0xff, 0xff), Color8(0xd4, 0xff, 0x3a), Color8(0xff, 0xe2, 0x3a), Color8(0xff, 0x4f, 0xd8), Color8(0x3f, 0xf0, 0xff)]

var catalog: SpriteCatalog
## Seconds since the snap.
var time := -1.0
var finished := false
var logo_width := 0
var _stage := Node2D.new()
var _logo := Sprite2D.new()
var _glow := Sprite2D.new()
var _flash := ColorRect.new()
var _dim := ColorRect.new()
## [sprite, vx, vy, age, life, spin]
var _sparks: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputService.clear_pending()
	_dim.color = Color(0, 0, 0, SV.DIM)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	for s: Sprite2D in [_glow, _logo]:
		s.texture = LOGO
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var m := ShaderMaterial.new()
		m.shader = ALPHA_CUT
		s.material = m
	# A pale halo (the source blurs it; here an unblurred tinted copy).
	_glow.modulate = Color8(0xff, 0xf3, 0xa0)
	_stage.add_child(_glow)
	_stage.add_child(_logo)
	_stage.visible = false
	add_child(_stage)
	_flash.color = Color.WHITE
	_flash.modulate.a = 0.0
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var w := size.x
	var h := size.y
	_dim.size = size
	_flash.size = size
	var nw := float(LOGO.get_width())
	var nh := float(LOGO.get_height())
	logo_width = maxi(40, mini(int(JsMath.round(w * SV.WIDTH)), int(floor(h * SV.MAX_HEIGHT * nw / nh))))
	_stage.position = Vector2(JsMath.round(w / 2.0), JsMath.round(h * SV.Y))


func _process(delta: float) -> void:
	step(delta)


func step(dt: float) -> void:
	if finished:
		return
	if time < 0.0:
		_snap()
	time += dt
	var t := time
	var base := float(logo_width) / float(LOGO.get_width())
	var s: float
	if t < SV.SNAP_TIME:
		var p := t / SV.SNAP_TIME
		s = SV.SNAP_FROM + (1.0 - SV.SNAP_FROM) * (1.0 - pow(1.0 - p, 3.0))
	else:
		var u := t - SV.SNAP_TIME
		s = 1.0 + SV.BOUNCE * exp(-SV.BOUNCE_DECAY * u) * sin(SV.BOUNCE_FREQ * u)
	_logo.scale = Vector2.ONE * s * base
	_glow.scale = Vector2.ONE * s * base * SV.GLOW_SCALE
	var ga: float = SV.GLOW_ALPHA[0]
	var gb: float = SV.GLOW_ALPHA[1]
	_glow.modulate.a = 0.0 if t < SV.SNAP_TIME else ga + (gb - ga) * (0.5 + 0.5 * sin(t * SV.GLOW_SPEED))
	var shake := SV.SHAKE * (1.0 - t / SV.SHAKE_TIME) if t < SV.SHAKE_TIME else 0.0
	_stage.position = Vector2(JsMath.round(size.x / 2.0 + (randf() * 2.0 - 1.0) * shake), JsMath.round(size.y * SV.Y + (randf() * 2.0 - 1.0) * shake))
	_flash.modulate.a = maxf(0.0, 1.0 - t / SV.FLASH_TIME) * 0.9
	for k: Array in _sparks:
		var sp: Sprite2D = k[0]
		k[3] += dt
		k[2] += SV.SPARK_GRAVITY * dt
		sp.position += Vector2(k[1], k[2]) * dt
		sp.rotation += k[5] * dt
		var left: float = 1.0 - k[3] / k[4]
		sp.modulate.a = clampf(left * 2.0, 0.0, 1.0)
		sp.visible = left > 0.0
	var tapped := InputService.consume(&"confirm")
	if t >= SV.HOLD or (tapped and t >= SV.SKIP_AFTER):
		_finish()


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		if time >= SV.SKIP_AFTER:
			_finish()


## The moment it appears: sounds and the burst of sprites.
func _snap() -> void:
	time = 0.0
	_stage.visible = true
	AudioService.play(&"glitch")
	AudioService.play(&"bark")
	AudioService.play(&"star", 1.0, 1.5)
	var half_w := logo_width / 2.0
	var half_h := half_w * LOGO.get_height() / LOGO.get_width()
	for i in SV.SPARKS:
		var star := i % 3 == 0
		var key := "star_%d" % (i % 3) if star else "sparkle_0"
		var sp := Sprite2D.new()
		if catalog:
			sp.texture = catalog.texture(key)
		sp.modulate = Color.WHITE if star else SPARK_TINTS[i % SPARK_TINTS.size()]
		var ang := (float(i) / SV.SPARKS) * PI * 2.0 + randf() * 0.4
		sp.position = Vector2(cos(ang) * half_w * 0.8, sin(ang) * half_h * 0.8)
		var v := lerpf(SV.SPARK_SPEED[0], SV.SPARK_SPEED[1], randf())
		_sparks.append([sp, cos(ang) * v, sin(ang) * v - 40.0, 0.0, lerpf(SV.SPARK_LIFE[0], SV.SPARK_LIFE[1], randf()), (randf() * 2.0 - 1.0) * 6.0])
		_stage.add_child(sp)
		_stage.move_child(sp, 1)  # behind the logo, in front of its halo


func _finish() -> void:
	if finished:
		return
	finished = true
	done.emit()
