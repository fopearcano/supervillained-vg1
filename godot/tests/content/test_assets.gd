extends TestCase
## Asset contract: hashes against the source tree, sheet geometry, frame coverage, anchors,
## import settings, frozen procedural sprites, the bitmap font and forbidden runtime content.

const MANIFEST := "res://data/source_asset_manifest.json"


func _manifest() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))


func _repo_root() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()


func _sha(path: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(FileAccess.get_file_as_bytes(path))
	return ctx.finish().hex_encode()


func test_AST_001_copies_match_manifest_and_source() -> void:
	var m := _manifest()
	assert_eq(m["audited_commit"], "95b69c04c5c3b9626e49719f8f916a44659cd265", "audited commit")
	var root := _repo_root()
	var have_source := FileAccess.file_exists(root.path_join("src/config.ts"))
	for e: Dictionary in m["copies"]:
		assert_eq(_sha("res://" + String(e["target"])), e["sha256"], "target " + String(e["target"]))
		if have_source:
			assert_eq(_sha(root.path_join(e["source"])), e["sha256"], "source " + String(e["source"]))
	for e: Dictionary in m["generated"]:
		assert_eq(_sha("res://" + String(e["target"])), e["sha256"], "generated " + String(e["target"]))
	assert_true(have_source, "source tree present next to /godot (guard)")


func test_AST_002_playable_sheet_geometry() -> void:
	var main: Texture2D = load("res://assets/sprites/zampano.png")
	var tired: Texture2D = load("res://assets/sprites/zampano-tired.png")
	assert_eq(Vector2i(main.get_width(), main.get_height()), Vector2i(320, 3520), "main sheet 320x3520")
	assert_eq(Vector2i(tired.get_width(), tired.get_height()), Vector2i(80, 320), "tired sheet 80x320")
	assert_eq(main.get_height() % 40, 0, "whole 40 px rows")


func test_AST_003_foot_anchor() -> void:
	var p: PlayableCharacterProfile = load("res://data/characters/zampano_profile.tres")
	assert_eq(p.foot_anchor, Vector2i(20, 36), "foot anchor")
	var dog: PlayableDog = load("res://entities/playable_dog/playable_dog.tscn").instantiate()
	var body: AnimatedSprite2D = dog.get_node("VisualRoot/Body")
	assert_eq(body.offset, Vector2(-20, -36), "sprite offset puts the anchor on the foot point")
	assert_false(body.centered, "not centred")
	dog.free()


func test_AST_004_every_action_has_eight_real_directions() -> void:
	var p: PlayableCharacterProfile = load("res://data/characters/zampano_profile.tres")
	var sf := p.normal_frames
	var images := {}
	for anim in ["idle", "walk", "run", "sniff", "pee", "poop", "eat", "bark", "fetch", "hurt", "sit", "tired"]:
		var per_dir := {}
		for dir in IsoGrid.DIRS8:
			var name := StringName("%s_%s" % [anim, dir.to_lower()])
			if not assert_true(sf.has_animation(name), "missing " + name):
				continue
			for f in sf.get_frame_count(name):
				var at := sf.get_frame_texture(name, f) as AtlasTexture
				var key := at.atlas.resource_path
				if not images.has(key):
					images[key] = at.atlas.get_image()
				var img: Image = (images[key] as Image).get_region(Rect2i(at.region))
				if img.is_invisible():
					fail("%s frame %d is blank" % [name, f])
				if f == 0:
					per_dir[dir] = img.get_data()
		# No duplicated diagonals: every direction's first frame is distinct.
		var seen := {}
		for dir: String in per_dir:
			var h := hash(per_dir[dir])
			if seen.has(h):
				fail("%s: %s duplicates %s" % [anim, dir, seen[h]])
			seen[h] = dir


func test_AST_012_environment_frames_and_tile_atlas() -> void:
	var env: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/environment/ch01_greenzone_frames.json"))
	var bank: Texture2D = load("res://assets/environment/ch01_greenzone.png")
	assert_eq(Vector2i(bank.get_width(), bank.get_height()), Vector2i(512, 512), "bank size")
	var bank_img := bank.get_image()
	for name in ["grass_0", "grass_3", "tallGrass_0", "water_1", "forest_2", "dirt_3", "fresh_0", "exitRing_0", "path_15_1", "tree_2", "bush_1", "pole_0", "fountain_0", "forestTree_1", "exitFlag_0"]:
		var f: Dictionary = env["frames"][name]
		var r := Rect2i(int(f["x"]), int(f["y"]), int(f["w"]), int(f["h"]))
		assert_true(Rect2i(0, 0, 512, 512).encloses(r), name + " inside bank")
		assert_false(bank_img.get_region(r).is_invisible(), name + " not blank")
	var ts: TileSet = load("res://data/environment/ch01_greenzone_tileset.tres")
	var coords: Dictionary = ts.get_meta(&"tile_coords")
	var atlas := (ts.get_source(0) as TileSetAtlasSource).texture.get_image()
	for name: String in coords:
		var c: Vector2i = coords[name]
		assert_false(atlas.get_region(Rect2i(c.x * 32, c.y * 22, 32, 22)).is_invisible(), "tile " + name + " not blank")


func test_AST_014_green_zone_ignores_obsolete_arcade_floor() -> void:
	var ts: TileSet = load("res://data/environment/ch01_greenzone_tileset.tres")
	for name: String in ts.get_meta(&"tile_coords"):
		assert_false(name.begins_with("floorArt_"), "authored floor frame %s must not be used by 1.0" % name)


func test_AST_016_lossless_nearest_no_mipmaps() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 0, "nearest filtering")
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility", "compatibility renderer")
	for path in ["res://assets/sprites/zampano.png", "res://assets/sprites/zampano-tired.png", "res://assets/environment/ch01_greenzone.png",
			"res://assets/generated/environment/ch01_greenzone_tiles.png", "res://assets/generated/sprites/treat.png"]:
		var cfg := ConfigFile.new()
		assert_eq(cfg.load(path + ".import"), OK, path + ".import")
		assert_eq(cfg.get_value("params", "compress/mode", -1), 0, path + " lossless")
		assert_eq(cfg.get_value("params", "mipmaps/generate", true), false, path + " no mipmaps")
	# The font atlas is read raw by the BMFont importer (no separate texture import).
	var fcfg := ConfigFile.new()
	assert_eq(fcfg.load("res://assets/fonts/pixel_font.png.import"), OK, "font atlas .import")
	assert_eq(fcfg.get_value("remap", "importer", ""), "skip", "font atlas consumed by the BMFont importer")
	var fnt := ConfigFile.new()
	assert_eq(fnt.load("res://assets/fonts/pixel_font.fnt.import"), OK, "font .import")
	assert_eq(fnt.get_value("params", "scaling_mode", -1), 1, "integer-only font scaling")


func test_AST_017_required_sprites_present() -> void:
	var cat: SpriteCatalog = load("res://data/environment/green_zone_sprites.tres")
	var required := ["tree_0", "tree_1", "tree_2", "forestTree_0", "forestTree_1", "bush_0", "bush_1", "pole_0", "fountain_0",
		"exitFlag_0", "exitRing_0", "treat_0", "poop_0", "shadow_0", "shadowSmall_0", "star_0", "star_1", "star_2",
		"dogFace_0", "peeIcon_0", "barkIcon_0", "drop_0", "drop_1", "runIcon_0"]
	for key in required:
		if assert_true(cat.has_key(key), "missing sprite " + key):
			assert_false(cat.texture(key).get_image().is_invisible(), key + " not blank")
	# Frozen procedural sprites keep the manifest's geometry.
	assert_eq(cat.size_of("treat_0"), Vector2i(13, 8), "treat size")
	assert_eq(cat.anchor("treat_0"), Vector2i(6, 7), "treat anchor")
	assert_eq(cat.anchor("poop_0"), Vector2i(5, 8), "poop anchor")


func test_AST_018_no_forbidden_runtime_content() -> void:
	var bad: PackedStringArray = []
	var stack: Array[String] = ["res://"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		var d := DirAccess.open(dir)
		if d == null:
			continue
		for sub in d.get_directories():
			if sub.begins_with(".") or sub == "test-results":
				continue
			stack.append(dir.path_join(sub))
		for f in d.get_files():
			var lower := f.to_lower()
			if lower.ends_with(".zip") or lower.ends_with(".woff2") or lower.ends_with(".gif") or dir.contains("art-archive") or dir.contains("originals"):
				bad.append(dir.path_join(f))
	assert_eq(bad, PackedStringArray(), "forbidden files")


func test_AST_020_bitmap_font_matches_source_glyphs() -> void:
	var src: Dictionary = fixture("source_font_glyphs")
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/fonts/pixel_font.png"))
	assert_eq(img.get_height(), int(src["cell_h"]), "cell height")
	for code_s: String in src["glyph_alpha_sha256_16"]:
		var code := int(code_s)
		var bits := PackedByteArray()
		var x0 := (code - 32) * int(src["advance"])
		for y in int(src["cell_h"]):
			for x in int(src["advance"]):
				bits.append(1 if img.get_pixel(x0 + x, y).a > 0.0 else 0)
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(bits)
		assert_eq(ctx.finish().hex_encode().substr(0, 16), src["glyph_alpha_sha256_16"][code_s], "glyph %d" % code)
	var font: FontFile = load("res://assets/fonts/pixel_font.fnt")
	for ch in ["A", "ə", "ˈ", "ː"]:
		assert_true(font.has_char(ch.unicode_at(0)), "font has %s" % ch)
	assert_eq(font.get_char_size("W".unicode_at(0), 8), Vector2(8, 8), "8 px advance and cell")
	assert_eq(PixelText.sanitize("café"), "caf?", "unknown glyphs show as ?")


func test_AUD_001_recorded_audio_loads() -> void:
	for path in ["res://assets/audio/recorded/greenzone-music.mp3", "res://assets/audio/recorded/dog-bark.mp3",
			"res://assets/audio/recorded/food-collect.mp3", "res://assets/audio/recorded/poos.mp3",
			"res://assets/audio/recorded/pees-drop.mp3", "res://assets/audio/recorded/pees-collect.wav",
			"res://assets/audio/recorded/water.mp3"]:
		var s: AudioStream = load(path)
		if assert_true(s != null, path + " loads"):
			assert_true(s.get_length() > 0.05, path + " has length (%.2f s)" % s.get_length())
