// Title portrait (ARCHITECTURE §15 step 7) and the end-of-level Supervillained logo: the node samples
// its texture linearly when it is scaled to the current logical width, then the source's alpha cut
// (ALPHA_CUT = 110 of 255, src/ui/titleAnim.ts and titleArt.ts) restores crisp edges. Pixel art
// never uses this.
shader_type canvas_item;

uniform float alpha_cut = 0.43137254901960786; // 110 / 255

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	c.a = c.a >= alpha_cut ? 1.0 : 0.0;
	COLOR = c;
}
