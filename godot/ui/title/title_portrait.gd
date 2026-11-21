class_name TitlePortrait
extends AnimatedSprite2D
## The title page's animated portrait of Zampanò: the converted frames (data/title, canonical
## 125 px width) at the WebP's own delays, looping. The only node in the game that samples
## linearly: scaling to the current logical width is smooth (source high-quality canvas resize),
## then the alpha-cut shader keeps the edges crisp. The title scene itself arrives with M4.

const FRAMES: SpriteFrames = preload("res://data/title/title_animation.tres")
const SHADER: Shader = preload("res://ui/title/title_portrait.gdshader")
## Canonical frame width (ceil(DISPLAY.MAX_WIDTH * TITLE.DOG_WIDTH)).
const CANONICAL_WIDTH := 125


func _ready() -> void:
	sprite_frames = FRAMES
	animation = &"portrait"
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var m := ShaderMaterial.new()
	m.shader = SHADER
	material = m
	play()


## Scales the portrait to `logical_width` px (source titleFrames(round(width * DOG_WIDTH))).
func fit_width(logical_width: float) -> void:
	var s := logical_width / float(CANONICAL_WIDTH)
	scale = Vector2(s, s)
