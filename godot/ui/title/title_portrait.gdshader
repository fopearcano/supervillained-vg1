// Title portrait only (ARCHITECTURE §15 step 7): the node samples its texture linearly when the
// canonical 125 px frames are scaled to the current logical width, then the source's alpha cut
// (ALPHA_CUT = 110 of 255, src/ui/titleAnim.ts) restores crisp edges. Pixel art never uses this.
shader_type canvas_item;

uniform float alpha_cut = 0.43137254901960786; // 110 / 255

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	c.a = c.a >= alpha_cut ? 1.0 : 0.0;
	COLOR = c;
}
