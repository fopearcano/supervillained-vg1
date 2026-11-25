// Retro glitch / CRT post effect (port of src/fx/glitchFilter.ts): horizontal slice displacement,
// RGB split, sepia palette shift, scanlines and a white flash over what is already drawn below
// this full-screen rect. Used for the glitch transition and the "under attack" look.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest, repeat_disable;
uniform float time = 0.0;
uniform float glitch = 0.0;
uniform float rgb = 0.0;
uniform float sepia = 0.0;
uniform float scanlines = 0.0;
uniform float flash = 0.0;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 one_px = SCREEN_PIXEL_SIZE;
	float py = uv.y / one_px.y;
	float tick = floor(time * 12.0);
	float band = floor(py / 5.0);
	float r = rand(vec2(band, tick));
	float shift = 0.0;
	if (r < glitch * 0.4) {
		shift = floor((rand(vec2(band * 1.7, tick + 3.1)) - 0.5) * 30.0 * glitch);
	}
	uv.x += shift * one_px.x;
	float split = floor(rgb + 0.5) * one_px.x;
	vec4 cg = texture(screen_texture, clamp(uv, vec2(0.0), vec2(1.0)));
	float cr = texture(screen_texture, clamp(uv + vec2(split, 0.0), vec2(0.0), vec2(1.0))).r;
	float cb = texture(screen_texture, clamp(uv - vec2(split, 0.0), vec2(0.0), vec2(1.0))).b;
	vec3 col = vec3(cr, cg.g, cb);
	vec3 sep = vec3(
		dot(col, vec3(0.393, 0.769, 0.189)),
		dot(col, vec3(0.349, 0.686, 0.168)),
		dot(col, vec3(0.272, 0.534, 0.131))
	) * vec3(1.08, 0.82, 0.55);
	col = mix(col, sep, sepia);
	col *= 1.0 - scanlines * 0.28 * mod(floor(py), 2.0);
	col = mix(col, vec3(1.0), flash);
	COLOR = vec4(col, 1.0);
}
