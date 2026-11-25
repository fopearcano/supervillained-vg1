class_name GlitchRect
extends ColorRect
## Full-screen rect running fx/glitch.gdshader over what is drawn below it (src/fx/glitchFilter.ts
## uniforms). Shown only while an effect is active. Presentation only.

const SHADER: Shader = preload("res://fx/glitch.gdshader")

var fx_time := 0.0
var glitch := 0.0
var rgb := 0.0
var sepia := 0.0
var scanlines := 0.0
var flash := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = SHADER
	material = m
	visible = false


## Pushes the current values to the shader and shows the rect while anything is non-zero.
func apply() -> void:
	var m := material as ShaderMaterial
	m.set_shader_parameter(&"time", fx_time)
	m.set_shader_parameter(&"glitch", glitch)
	m.set_shader_parameter(&"rgb", rgb)
	m.set_shader_parameter(&"sepia", sepia)
	m.set_shader_parameter(&"scanlines", scanlines)
	m.set_shader_parameter(&"flash", flash)
	visible = glitch > 0.0 or rgb > 0.0 or sepia > 0.0 or scanlines > 0.0 or flash > 0.0
