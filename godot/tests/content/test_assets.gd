extends TestCase
## Asset contract: hashes against the source tree, sheet geometry, frame coverage, anchors,
## import settings, frozen procedural sprites, the bitmap font and forbidden runtime content.

const MANIFEST := "res://data/source_asset_manifest.json"


func _manifest() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))


func _repo_root() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()


func _sha_bytes(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


func _sha(path: String) -> String:
	return _sha_bytes(FileAccess.get_file_as_bytes(path))


## Canonical LF bytes: a Windows CRLF checkout of a source text file compares equal to the blob.
static func _lf(bytes: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	for k in bytes.size():
		if bytes[k] == 13 and k + 1 < bytes.size() and bytes[k + 1] == 10:
			continue
		out.append(bytes[k])
	return out


## AST-001: every required source asset exists in the port and matches the approved manifest
## byte for byte: the runtime-authoritative source files (all sprite sheets and the pixel cast,
## the fifteen Color Ink banks and their manifest, the twelve effects and five music tracks, the
## font licence, the launcher art) are all copies, and every generated output matches its hash.
func test_AST_001_required_assets_present_and_match_manifest() -> void:
	var m := _manifest()
	assert_eq(m["audited_commit"], "95b69c04c5c3b9626e49719f8f916a44659cd265", "audited commit")
	var root := _repo_root()
	var have_source := FileAccess.file_exists(root.path_join("src/config.ts"))
	for e: Dictionary in m["copies"]:
		# Targets are the exact audited Git blobs (binary in .gitattributes): byte-for-byte.
		assert_eq(_sha("res://" + String(e["target"])), e["sha256"], "target " + String(e["target"]))
		if have_source:
			# The working-tree source may carry CRLF on Windows: compare canonical LF bytes.
			var src := FileAccess.get_file_as_bytes(root.path_join(e["source"]))
			var target := FileAccess.get_file_as_bytes("res://" + String(e["target"]))
			assert_eq(_sha_bytes(_lf(src)), _sha_bytes(_lf(target)), "source " + String(e["source"]))
	for e: Dictionary in m["generated"]:
		assert_eq(_sha("res://" + String(e["target"])), e["sha256"], "generated " + String(e["target"]))
	for e: Dictionary in m["outputs"]:
		if e["target"] == "data/source_asset_manifest.json":
			continue
		assert_eq(_sha("res://" + String(e["target"])), e["sha256"], "output " + String(e["target"]))
	assert_eq(m["toolchain"]["node"], "v" + FileAccess.get_file_as_string("res://tools/.node-version").strip_edges(), "generated under the pinned Node")
	assert_true(have_source, "source tree present next to /godot (guard)")
	# Coverage: every runtime-authoritative source file is copied (the title WebP is a converter input).
	var copied := {}
	for e: Dictionary in m["copies"]:
		copied[String(e["source"])] = true
	var required: Array[String] = []
	for dir in ["public/sprites", "public/sprites/pixel-cast", "public/environment-ink", "assets/sounds", "assets/music"]:
		for f in DirAccess.get_files_at(root.path_join(dir)):
			required.append(dir + "/" + f)
	required.append_array(["src/assets/fonts/OFL.txt", "public/icon-192.png"])
	assert_true(required.size() >= 72, "required source files (%d)" % required.size())
	for r in required:
		assert_true(copied.has(r), "required source asset copied: " + r)
	var inputs := {}
	for e: Dictionary in m["inputs"]:
		inputs[String(e["source"])] = e
	for r in ["assets/starting-page-images/app/Zampano-Samemala-3.webp", "src/assets/fonts/PressStart2P.woff2"]:
		if assert_true(inputs.has(r), "converter input recorded: " + r):
			assert_eq(_sha(root.path_join(r)), inputs[r]["sha256"], "input hash " + r)


## Chromium provenance is deterministic: every generated file records the build pinned by the
## locked playwright-core (browsers.json), never whatever browser the host happened to have.
func test_SLICE_chromium_provenance_is_the_pinned_build() -> void:
	var m := _manifest()
	var tc: Dictionary = m["toolchain"]
	var recorded := [tc["chromium"]]
	recorded.append(JSON.parse_string(FileAccess.get_file_as_string("res://data/audio/sfx_leading_silence.json"))["chromium"])
	recorded.append(fixture("source_font_glyphs")["chromium"])
	for e: Dictionary in m["generated"]:
		if e.has("chromium"):
			recorded.append(e["chromium"])
	for v: Variant in recorded:
		assert_eq(v, tc["chromium"], "one pinned Chromium version everywhere")
	assert_eq([tc["chromium_channel"], tc["chromium_pinned_by"]], ["chromium", "node_modules/playwright-core/browsers.json"], "pinned by playwright-core")
	var lock: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_repo_root().path_join("package-lock.json")))
	assert_eq(tc["playwright"], lock["packages"]["node_modules/playwright-core"]["version"], "playwright-core from the lockfile")
	var browsers := _repo_root().path_join("node_modules/playwright-core/browsers.json")
	if FileAccess.file_exists(browsers):
		for b: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(browsers))["browsers"]:
			if b["name"] == "chromium":
				assert_eq([tc["chromium"], tc["chromium_revision"]], [b["browserVersion"], b["revision"]], "matches the installed playwright-core browsers.json")


const PLAYABLES := "res://data/characters/playable_profiles.json"
const ACTIONS := ["idle", "walk", "run", "sniff", "pee", "poop", "eat", "bark", "fetch", "hurt", "sit", "tired"]
var _images := {}


func _playables() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(PLAYABLES))


func _layout(skin: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/characters/%s_sheet.json" % skin))


func _frames(skin: String) -> SpriteFrames:
	return load("res://data/characters/%s_frames.tres" % skin)


## The frame's pixels (atlas images cached per test case).
func _frame_image(sf: SpriteFrames, anim: StringName, f: int) -> Image:
	var at := sf.get_frame_texture(anim, f) as AtlasTexture
	var key := at.atlas.resource_path
	if not _images.has(key):
		_images[key] = at.atlas.get_image()
		(_images[key] as Image).convert(Image.FORMAT_RGBA8)
	return (_images[key] as Image).get_region(Rect2i(at.region))


static func _lowest_opaque_row(img: Image) -> int:
	for y in range(img.get_height() - 1, -1, -1):
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				return y
	return -1


## AST-002 geometry of one skin: exact sheet sizes, whole 40x40 frames on the grid, every row used.
func _check_sheet_geometry(skin: String) -> void:
	var layout := _layout(skin)
	var fw: int = layout["frame_w"]
	var fh: int = layout["frame_h"]
	assert_eq(Vector2i(fw, fh), Vector2i(40, 40), skin + " 40x40 frames")
	var main: Texture2D = load(layout["sheet"])
	var own: Dictionary = layout["anim_sheets"]
	var in_main: int = (layout["anim_order"] as Array).filter(func(a: String) -> bool: return not own.has(a)).size()
	assert_eq(Vector2i(main.get_width(), main.get_height()), Vector2i(8 * fw, in_main * 8 * fh), skin + " main sheet %dx%d" % [main.get_width(), main.get_height()])
	assert_eq(Vector2i(main.get_width(), main.get_height()), Vector2i(320, 3520), skin + " main sheet 320x3520")
	for anim: String in own:
		var t: Texture2D = load(own[anim])
		var n := int(layout["anims"][anim]["frames"])
		assert_eq(Vector2i(t.get_width(), t.get_height()), Vector2i(n * fw, 8 * fh), "%s %s sheet" % [skin, anim])
		assert_eq(Vector2i(t.get_width(), t.get_height()), Vector2i(80, 320), "%s %s sheet 80x320" % [skin, anim])
	var sf := _frames(skin)
	var used := {}
	for name: StringName in sf.get_animation_names():
		for f in sf.get_frame_count(name):
			var at := sf.get_frame_texture(name, f) as AtlasTexture
			var r := Rect2i(at.region)
			assert_true(r.size == Vector2i(fw, fh) and r.position.x % fw == 0 and r.position.y % fh == 0 and Rect2i(Vector2i.ZERO, at.atlas.get_size()).encloses(r), "%s %s %d region %s" % [skin, name, f, r])
			if at.atlas == main:
				used[r.position.y / fh] = true
	assert_eq(used.size(), in_main * 8, skin + " every main-sheet row used")


## AST-004 for one skin: every action in eight directions, no blank frame, distinct directions.
func _check_directions(skin: String) -> void:
	var sf := _frames(skin)
	for anim: String in ACTIONS:
		var seen := {}
		for dir in IsoGrid.DIRS8:
			var name := StringName("%s_%s" % [anim, dir.to_lower()])
			if not assert_true(sf.has_animation(name), "%s missing %s" % [skin, name]):
				continue
			for f in sf.get_frame_count(name):
				if _frame_image(sf, name, f).is_invisible():
					fail("%s %s frame %d is blank" % [skin, name, f])
			# No duplicated diagonals: every direction's first frame is distinct.
			var h := hash(_frame_image(sf, name, 0).get_data())
			if seen.has(h):
				fail("%s %s: %s duplicates %s" % [skin, anim, dir, seen[h]])
			seen[h] = dir


## AST-003 for one skin: standing frames (idle, sit) reach down to within two rows above the foot
## anchor in all eight directions and never below it, so the anchor is the art's ground contact
## point (diagonal poses end one row higher than the axis-aligned ones).
func _check_feet_on_anchor(skin: String) -> void:
	var layout := _layout(skin)
	assert_eq(Vector2i(int(layout["anchor_x"]), int(layout["anchor_y"])), Vector2i(20, 36), skin + " foot anchor")
	var sf := _frames(skin)
	for anim in ["idle", "sit"]:
		for dir in IsoGrid.DIRS8:
			var row := _lowest_opaque_row(_frame_image(sf, StringName("%s_%s" % [anim, dir.to_lower()]), 0))
			var a := int(layout["anchor_y"])
			assert_true(row >= a - 2 and row <= a - 1, "%s %s_%s feet on the anchor (lowest opaque row %d, anchor %d)" % [skin, anim, dir.to_lower(), row, a])


func test_AST_002_playable_sheet_geometry() -> void:
	var skins: Array = _playables()["skins"]
	assert_eq(skins.size(), 6, "six delivered playable skins (cross aliases the knight)")
	for skin: String in skins:
		_check_sheet_geometry(skin)


func test_AST_003_foot_anchor_renders_on_the_world_foot_point() -> void:
	var p := _playables()
	for skin: String in p["skins"]:
		_check_feet_on_anchor(skin)
	for play_as: String in p["play_as"]:
		var prof: PlayableCharacterProfile = load(AppState.PROFILES[StringName(play_as)])
		assert_eq([prof.foot_anchor, prof.frame_size], [Vector2i(20, 36), Vector2i(40, 40)], play_as + " profile anchor and frame")
		var dog: PlayableDog = load("res://entities/playable_dog/playable_dog.tscn").instantiate()
		dog.profile = prof
		tree.root.add_child(dog)
		dog.set_grid_position(10.5, 20.25)
		var body: AnimatedSprite2D = dog.get_node("VisualRoot/Body")
		assert_eq(body.sprite_frames, prof.normal_frames, play_as + " frames on the body")
		assert_false(body.centered, play_as + " not centred")
		var foot := IsoGrid.grid_to_screen(10.5, 20.25).round()
		assert_eq(dog.global_position, foot, play_as + " node on the whole-pixel foot point")
		# The anchor pixel of the frame lands exactly on the foot point.
		assert_eq(body.global_position + body.offset + Vector2(prof.foot_anchor), foot, play_as + " anchor renders on the foot point")
		dog.free()


func test_AST_004_every_action_has_eight_real_directions() -> void:
	for skin: String in _playables()["skins"]:
		_check_directions(skin)


func test_AST_006_cross_costume_aliases_the_knight_art() -> void:
	var p := _playables()
	assert_eq(p["aliases"], {"zampanoCross": "zampanoKnight"}, "source: zampanoCross uses the knight sheet, tired sheet and anims")
	var z: PlayableCharacterProfile = load(AppState.PROFILES[&"zampano"])
	assert_true(z.cross_frames != null and z.cross_frames == z.armoured_frames, "cross slot is the very same SpriteFrames as the armour")
	assert_eq(z.cross_frames.resource_path, "res://data/characters/zampanoKnight_frames.tres", "knight frames")
	assert_false(FileAccess.file_exists("res://data/characters/zampanoCross_frames.tres"), "no duplicated cross frames")
	assert_false(FileAccess.file_exists("res://data/characters/zampanoCross_sheet.json"), "no cross layout")
	for e: Dictionary in _manifest()["copies"]:
		assert_false(String(e["source"]).to_lower().contains("cross"), "no rag-cross art copied: " + String(e["source"]))
	for f in DirAccess.get_files_at("res://assets/sprites"):
		assert_false(f.to_lower().contains("cross") or f.to_lower().contains("rag"), "no retired rag-cross sprite: " + f)


func test_AST_007_armoured_zampano_actions_and_arms_alignment() -> void:
	var p := _playables()
	assert_eq(p["costumes"]["zampano"]["zampanoKnight"], "zampanoKnight", "armoured costume")
	assert_true((p["armoured_skins"] as Array).has("zampanoKnight"), "an armoured skin (carries sword and shield)")
	_check_sheet_geometry("zampanoKnight")
	_check_directions("zampanoKnight")
	# The source has no separate arms sprite: sword and shield are drawn inside the armoured frames,
	# so their alignment is the frames' own: same 40x40 frame and foot anchor as the plain art, feet
	# on the anchor in every direction, and art that differs from the plain costume.
	_check_feet_on_anchor("zampanoKnight")
	var plain := _frames("zampano")
	var knight := _frames("zampanoKnight")
	for dir in IsoGrid.DIRS8:
		var name := StringName("idle_" + dir.to_lower())
		assert_true(_frame_image(plain, name, 0).get_data() != _frame_image(knight, name, 0).get_data(), "armour art differs from plain " + name)
	var z: PlayableCharacterProfile = load(AppState.PROFILES[&"zampano"])
	assert_eq(z.armoured_frames, knight, "profile armoured slot")
	assert_true(z.can_use_arms_when_armoured, "arms capability on the armoured costume (granted by 2.3, DOG-009)")


## One PLAY_AS dog validates completely: profile wiring per source costumeFor(), both skins'
## geometry, directions, anchors and timing.
func _check_playable(play_as: String, normal: String, armoured: String) -> void:
	var p := _playables()
	assert_eq(p["costumes"][play_as], {"zampano": normal, "zampanoCross": normal, "zampanoKnight": armoured}, play_as + " costumes (source costumeFor)")
	var prof: PlayableCharacterProfile = load(AppState.PROFILES[StringName(play_as)])
	assert_eq([prof.id, prof.normal_frames, prof.cross_frames, prof.armoured_frames], [StringName(play_as), _frames(normal), _frames(normal), _frames(armoured)], play_as + " profile slots")
	assert_true(prof.has_seated_idle, play_as + " sits when idle")
	assert_eq(prof.collision_radius, GameConfig.Player.RADIUS, play_as + " player radius")
	var timing: Dictionary = fixture()["animation_skins"]
	for skin in [normal, armoured]:
		_check_sheet_geometry(skin)
		_check_directions(skin)
		_check_feet_on_anchor(skin)
		var sf := _frames(skin)
		for anim: String in timing[skin]:
			for dir in IsoGrid.DIRS8:
				var name := StringName("%s_%s" % [anim, dir.to_lower()])
				assert_eq([sf.get_frame_count(name), sf.get_animation_loop(name)], [int(timing[skin][anim]["frames"]), bool(timing[skin][anim]["loop"])], "%s %s frames/loop" % [skin, name])
	for anim: String in timing[normal]:
		assert_near(prof.action_durations[anim], float(timing[normal][anim]["duration"]), 1e-9, "%s %s duration" % [play_as, anim])


func test_AST_008_sbrimbrulon_normal_and_armoured_profiles_validate() -> void:
	_check_playable("sbrimbrulon", "sbrimbrulon", "sbrimbrulonKnight")
	var timing: Dictionary = fixture()["animation_skins"]
	assert_false(timing["sbrimbrulon"]["fetch"]["loop"] or timing["sbrimbrulon"]["hurt"]["loop"], "fetch and hurt play once (source SBRIMBRULON_ANIMS)")


func test_AST_009_bagnaskiz_profiles_validate_with_full_colour_signature() -> void:
	_check_playable("bagnaskiz", "bagnaskiz", "bagnaskizEmperor")
	assert_true(bool(fixture()["animation_skins"]["bagnaskiz"]["hurt"]["loop"]), "the bully's hurt loops (source)")
	# Full colour: the imported textures are the PNGs pixel for pixel (no palette reduction) and
	# keep the delivery's colour depth and his yellow eyes in every front-facing action.
	for skin in ["bagnaskiz", "bagnaskizEmperor"]:
		var layout := _layout(skin)
		for path: String in [layout["sheet"]] + (layout["anim_sheets"] as Dictionary).values():
			var imported := (load(path) as Texture2D).get_image()
			imported.convert(Image.FORMAT_RGBA8)
			var decoded := Image.load_from_file(ProjectSettings.globalize_path(path))
			decoded.convert(Image.FORMAT_RGBA8)
			# The importer's only change is fix_alpha_border (RGB of fully transparent pixels).
			var expected := decoded.duplicate() as Image
			expected.fix_alpha_edges()
			assert_true(imported.get_data() == expected.get_data(), path + " imported pixel for pixel (visible pixels and alpha unchanged)")
			var colours := {}
			for y in range(0, decoded.get_height(), 2):
				for x in decoded.get_width():
					var c := decoded.get_pixel(x, y)
					if c.a > 0.5:
						colours[c.to_rgba32()] = true
			assert_true(colours.size() > 1000, "%s full colour (%d colours, not the pixel cast's 32)" % [path, colours.size()])
		var sf := _frames(skin)
		for anim: String in ACTIONS:
			var img := _frame_image(sf, StringName(anim + "_s"), 0)
			var eyes := 0
			for y in img.get_height():
				for x in img.get_width():
					var c := img.get_pixel(x, y)
					if c.a > 0.5 and c.r8 >= 200 and c.g8 >= 170 and c.b8 <= 90:
						eyes += 1
			assert_true(eyes > 0, "%s %s_s keeps the yellow eyes" % [skin, anim])


## AST-011: every source cast role (CAST_KEYS) and the cat has explicit art: delivered roles their
## copied pixel-cast sheet, procedural-only roles a frozen sheet rendered by the source recipe, both
## built into complete SpriteFrames (every action x eight directions, frame counts as the source).
func test_AST_011_cast_roles_have_delivered_or_frozen_art() -> void:
	var roles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters/cast_roles.json"))["roles"]
	assert_eq(roles.size(), 45, "44 CAST_KEYS roles + the cat")
	var copies := {}
	for e: Dictionary in _manifest()["copies"]:
		copies["res://" + String(e["target"])] = e
	var generated := {}
	for e: Dictionary in _manifest()["generated"]:
		generated["res://" + String(e["target"])] = e
	var kinds := {}
	for key: String in roles:
		var role: Dictionary = roles[key]
		kinds[role["kind"]] = int(kinds.get(role["kind"], 0)) + 1
		if role["kind"] == "playable":
			assert_true(FileAccess.file_exists("res://data/characters/%s_frames.tres" % role["skin"]), key + " playable skin frames")
			continue
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(role["layout"]))
		var sheet: String = layout["sheet"]
		if role["kind"] == "delivered":
			assert_true(copies.has(sheet), "%s: delivered sheet is a manifest copy (%s)" % [key, sheet])
			if copies.has(sheet):
				assert_eq(copies[sheet]["source"], role["source"], key + " copied from its source sheet")
				assert_eq(_sha(sheet), copies[sheet]["sha256"], key + " sheet bytes")
		else:
			assert_true(generated.has(sheet), "%s: frozen sheet recorded as a generated output" % key)
			if generated.has(sheet):
				assert_eq(_sha(sheet), generated[sheet]["sha256"], key + " frozen sheet bytes")
				assert_true(String(generated[sheet]["recipe"]).contains("drawCritter"), key + " frozen from the source recipe")
		var sf: SpriteFrames = load("res://data/characters/cast/%s_frames.tres" % key)
		if not assert_true(sf != null, key + " SpriteFrames"):
			continue
		var anims: Dictionary = role["anims"]
		assert_eq(sf.get_animation_names().size(), anims.size() * 8, key + " every action in eight directions")
		for anim: String in anims:
			for dir in IsoGrid.DIRS8:
				var name := StringName("%s_%s" % [anim, dir.to_lower()])
				if not assert_true(sf.has_animation(name), "%s missing %s" % [key, name]):
					continue
				assert_eq(sf.get_frame_count(name), int(anims[anim]), "%s %s frames" % [key, name])
				for f in sf.get_frame_count(name):
					if _frame_image(sf, name, f).is_invisible():
						fail("%s %s frame %d is blank" % [key, name, f])
	assert_eq(kinds, {"playable": 5, "delivered": 23, "procedural": 17}, "roles by kind")


func test_SLICE_green_zone_bank_frames_and_tile_atlas() -> void:
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


func test_SLICE_ground_tile_names_exclude_floor_art() -> void:
	var ts: TileSet = load("res://data/environment/ch01_greenzone_tileset.tres")
	for name: String in ts.get_meta(&"tile_coords"):
		assert_false(name.begins_with("floorArt_"), "authored floor frame %s must not be used by 1.0" % name)


func _env_fixture() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_environment.json"))


## The verbatim environment manifest (CRLF in the audited commit; JSON ignores it).
func _env_manifest() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/manifest.json"))


## AST-012: all fifteen Color Ink banks are present and every frame validates: inside its bank,
## non-blank, anchor inside the frame; every native game frame (the source generators' sizes and
## anchors) is delivered with exactly that geometry, so withEnvironmentArt replaces all of them;
## authored floor frames are native 32x16 tiles anchored at (16, 0).
func test_AST_012_all_environment_banks_and_native_frames_validate() -> void:
	var fx := _env_fixture()
	var native: Dictionary = fx["native_contract"]
	var zones: Dictionary = _env_manifest()["zones"]
	assert_eq(zones.size(), 15, "fifteen environment banks")
	assert_eq(native.size(), 104, "native level frames (tiles, story tiles, props)")
	for id: String in zones:
		var zone: Dictionary = zones[id]
		var ref: Dictionary = fx["zones"][id]
		var path := "res://assets/environment/" + String(zone["image"])
		var tex: Texture2D = load(path)
		if not assert_true(tex != null, id + " bank imported"):
			continue
		var size := Vector2i(tex.get_width(), tex.get_height())
		assert_eq(size, Vector2i(int(ref["size"][0]), int(ref["size"][1])), id + " bank size")
		var img := tex.get_image()
		var frames: Dictionary = zone["frames"]
		assert_eq(frames.size(), int(ref["frames"]), id + " frame count")
		var floor_art := 0
		for name: String in frames:
			var f: Dictionary = frames[name]
			var r := Rect2i(int(f["x"]), int(f["y"]), int(f["w"]), int(f["h"]))
			if not assert_true(r.size.x >= 1 and r.size.y >= 1 and Rect2i(Vector2i.ZERO, size).encloses(r), "%s/%s inside the bank" % [id, name]):
				continue
			assert_true(int(f["anchorX"]) <= r.size.x and int(f["anchorY"]) <= r.size.y, "%s/%s anchor inside the frame" % [id, name])
			if img.get_region(r).is_invisible():
				fail("%s/%s is blank" % [id, name])
			if native.has(name):
				assert_eq([r.size.x, r.size.y, int(f["anchorX"]), int(f["anchorY"])], (native[name] as Array).map(func(v: Variant) -> int: return int(v)), "%s/%s native geometry" % [id, name])
			elif name.begins_with("floorArt_"):
				floor_art += 1
				assert_eq([r.size.x, r.size.y, int(f["anchorX"]), int(f["anchorY"])], [32, 16, 16, 0], "%s/%s native floor tile" % [id, name])
			else:
				fail("%s/%s is neither a native frame nor floor art" % [id, name])
		for name: String in native:
			assert_true(frames.has(name), "%s delivers native frame %s" % [id, name])
		assert_eq(floor_art, int(ref["floor_art"]), id + " floor-art frames")
		assert_eq([ref["rejected"], ref["missing"], ref["floor_rejected"], ref["other"]], [[], [], [], []], id + " source: nothing rejected or missing")


## AST-013: the nineteen authored floor compositions match the approved manifest: keys, art bank,
## dimensions, tile counts, distinct frames; each is selected by its chapter's themes and uses only
## native floor frames of its bank inside the map (source readFloorDesigns rules).
func test_AST_013_floor_composition_keys_and_counts() -> void:
	var fx: Dictionary = _env_fixture()["floor_designs"]
	var m := _env_manifest()
	var designs: Dictionary = m["floorDesigns"]
	assert_eq(designs.size(), 19, "nineteen authored compositions")
	var keys := designs.keys()
	keys.sort()
	var fx_keys := fx.keys()
	fx_keys.sort()
	assert_eq(keys, fx_keys, "composition keys")
	assert_true(designs.has("1:arcade"), "obsolete 1:arcade kept as data (never applied to 1.0, AST-014)")
	for key: String in designs:
		var d: Dictionary = designs[key]
		var ref: Dictionary = fx[key]
		var tiles: Dictionary = d["tiles"]
		var w := int(d["width"])
		var h := int(d["height"])
		assert_eq([d["environment"], w, h, tiles.size()], [ref["environment"], int(ref["width"]), int(ref["height"]), int(ref["tiles"])], key + " bank/size/count")
		var chapter := key.get_slice(":", 0)
		assert_true((m["chapterThemes"][chapter] as Dictionary).values().has(d["environment"]), key + " bank selected by chapter " + chapter)
		var frames: Dictionary = m["zones"][d["environment"]]["frames"]
		var distinct := {}
		for index: String in tiles:
			var name: String = tiles[index]
			distinct[name] = true
			var ok := index.is_valid_int() and int(index) >= 0 and int(index) < w * h and name.begins_with("floorArt_") and frames.has(name)
			if ok:
				var f: Dictionary = frames[name]
				ok = [int(f["w"]), int(f["h"]), int(f["anchorX"]), int(f["anchorY"])] == [32, 16, 16, 0]
			if not ok:
				fail("%s tile %s -> %s invalid" % [key, index, name])
		assert_eq(distinct.size(), int(ref["distinct_frames"]), key + " distinct frames")
		assert_eq([ref["chapter_selects_environment"], int(ref["invalid_tiles"])], [true, 0], key + " valid in the source")


## AST-016: every texture the game ships imports losslessly without mipmaps and is filtered nearest
## (project default, no per-node override in the runtime scenes); the font atlas is raw BMFont data.
func test_AST_016_lossless_nearest_no_mipmaps() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 0, "nearest filtering")
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility", "compatibility renderer")
	var pngs: Array[String] = []
	var stack: Array[String] = ["res://assets"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			stack.append(dir.path_join(sub))
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".png"):
				pngs.append(dir.path_join(f))
	assert_true(pngs.size() > 100, "every shipped PNG checked (%d)" % pngs.size())
	for path in pngs:
		var cfg := ConfigFile.new()
		if not assert_eq(cfg.load(path + ".import"), OK, path + ".import"):
			continue
		if path == "res://assets/fonts/pixel_font.png":
			continue
		assert_eq([cfg.get_value("remap", "importer", ""), cfg.get_value("params", "compress/mode", -1), cfg.get_value("params", "mipmaps/generate", true)], ["texture", 0, false], path + " lossless, no mipmaps")
	for scene in ["res://entities/playable_dog/playable_dog.tscn", "res://scenes/green_zone/green_zone_scene.tscn", "res://world/world_2d.tscn"]:
		if FileAccess.file_exists(scene):
			assert_false(FileAccess.get_file_as_string(scene).contains("texture_filter = 2"), scene + " no linear filter override")
	# The font atlas is read raw by the BMFont importer (no separate texture import).
	var fcfg := ConfigFile.new()
	assert_eq(fcfg.load("res://assets/fonts/pixel_font.png.import"), OK, "font atlas .import")
	assert_eq(fcfg.get_value("remap", "importer", ""), "skip", "font atlas consumed by the BMFont importer")
	var fnt := ConfigFile.new()
	assert_eq(fnt.load("res://assets/fonts/pixel_font.fnt.import"), OK, "font .import")
	assert_eq(fnt.get_value("params", "scaling_mode", -1), 1, "integer-only font scaling")


## Every art key the source declares (src/assets/manifest.ts CHARACTERS and SPRITES, the native
## level frames, the fifteen banks) resolved to explicit port art; returns the keys with none.
## Characters need SpriteFrames; a sprite variant is satisfied by the sprite catalogue (frozen
## generator output or the Green Zone bank), by every environment bank (palette props and story
## tiles: withEnvironmentArt replaces the generated frame), or by a delivered copy.
func _missing_required_art(extra: Array = []) -> PackedStringArray:
	var missing := PackedStringArray()
	var roles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters/cast_roles.json"))["roles"]
	var playables: Dictionary = _playables()
	var characters: Array = (playables["playable_keys"] as Array) + roles.keys() + ["bagnaskiz"]
	for key: String in characters:
		var skin := String(playables["aliases"].get(key, key))
		var path := "res://data/characters/%s_frames.tres" % skin
		if not ResourceLoader.exists(path):
			path = "res://data/characters/cast/%s_frames.tres" % key
		if roles.has(key) and roles[key]["kind"] == "playable":
			path = "res://data/characters/%s_frames.tres" % roles[key]["skin"]
		if not ResourceLoader.exists(path):
			missing.append("character " + key)
	var cat: SpriteCatalog = load("res://data/environment/green_zone_sprites.tres")
	var zones: Dictionary = _env_manifest()["zones"]
	var copies := {}
	for e: Dictionary in _manifest()["copies"]:
		copies[String(e["target"]).get_file().get_basename()] = true
	var sprites: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/environment/ch01_greenzone_frames.json"))["sprite_variants"]
	var keys: Array = []
	for key: String in sprites:
		for v in int(sprites[key]["variants"]):
			keys.append("%s_%d" % [key, v])
	keys.append_array(_env_fixture()["native_contract"].keys())
	keys.append_array(extra)
	for name: String in keys:
		if cat.has_key(name) and not cat.texture(name).get_image().is_invisible():
			continue
		var in_every_bank := true
		for id: String in zones:
			in_every_bank = in_every_bank and (zones[id]["frames"] as Dictionary).has(name)
		if in_every_bank:
			continue
		if copies.has(name.trim_suffix("_0")):
			continue
		missing.append("sprite " + name)
	return missing


## AST-017: no required art is missing (checked against every source key), the check reports an
## absent key, the builder fails on a missing frame, and no runtime script draws or substitutes
## procedural art (generated art exists only as frozen files).
func test_AST_017_missing_required_art_fails_and_no_runtime_fallback() -> void:
	assert_eq(_missing_required_art(), PackedStringArray(), "every source art key has explicit port art")
	assert_eq(_missing_required_art(["unicorn_0"]), PackedStringArray(["sprite unicorn_0"]), "an absent key is reported")
	var cat: SpriteCatalog = load("res://data/environment/green_zone_sprites.tres")
	assert_false(cat.has_key("unicorn_0"), "catalogue has no silent default")
	var builder := FileAccess.get_file_as_string("res://tools/build_resources.gd")
	assert_true(builder.contains("sheet lacks rows for") and builder.contains("environment frame missing: ") and builder.contains("quit(1)"), "the resource builder fails on missing frames")
	var bad: PackedStringArray = []
	var stack: Array[String] = ["res://"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			if sub.begins_with(".") or sub in ["tests", "tools", "test-results"]:
				continue
			stack.append(dir.path_join(sub))
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var src := FileAccess.get_file_as_string(dir.path_join(f))
			for pattern in ["Image.create", "ImageTexture.create_from_image", ".set_pixel(", "placeholder"]:
				if src.contains(pattern):
					bad.append("%s uses %s" % [dir.path_join(f), pattern])
	assert_eq(bad, PackedStringArray(), "no runtime procedural art")


## AST-018: nothing but runtime art ships: no ZIP deliveries, art archive, originals, prompts or
## source grids, screenshots, WOFF2/GIF/WebP sources or unused title files under the project, every
## copied file comes from a runtime path of the source, and the export filter drops tests, tools,
## JSON provenance and documentation.
func test_AST_018_export_excludes_archives_originals_and_unused_files() -> void:
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
			var lower := (dir.path_join(f)).to_lower()
			for pattern in [".zip", ".woff2", ".gif", ".webp", ".psd", ".aseprite", "art-archive", "/originals", "prompt", "screenshot", "source-grid", "starting-page-images"]:
				if lower.contains(pattern):
					bad.append(dir.path_join(f))
	assert_eq(bad, PackedStringArray(), "forbidden files")
	for e: Dictionary in _manifest()["copies"]:
		var src := String(e["source"])
		var runtime := src.begins_with("public/") or src.begins_with("assets/music/") or src.begins_with("assets/sounds/") or src == "src/assets/fonts/OFL.txt"
		assert_true(runtime and not src.contains("originals") and not src.contains("art-archive"), "copy from a runtime source path: " + src)
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK, "export presets")
	var exclude := String(cfg.get_value("preset.0", "exclude_filter", ""))
	for f in ["tests/*", "tools/*", "data/*.json", "data/*/*.json", "*.md"]:
		assert_true(exclude.contains(f), "export excludes " + f)


## Frame delays (seconds) stored in an animated WebP's ANMF chunks (24-bit little-endian ms at
## payload offset 12), read straight from the file.
static func _webp_delays(bytes: PackedByteArray) -> Array:
	var out: Array = []
	var pos := 12
	while pos + 8 <= bytes.size():
		var fourcc := bytes.slice(pos, pos + 4).get_string_from_ascii()
		var size := bytes.decode_u32(pos + 4)
		if fourcc == "ANMF":
			var p := pos + 8 + 12
			out.append(bytes[p] | (bytes[p + 1] << 8) | (bytes[p + 2] << 16))
		pos += 8 + size + (size & 1)
	return out


## AST-010: the title conversion (src/ui/titleAnim.ts executed in Chromium by the extractor): 99
## frames, the WebP's exact delays (source rule max(0.02 s, delay)), frame 0 probed at 256 px,
## alpha cut 110, one shared DOG_CROP_MARGIN crop, the 2x resize and second alpha cut (binary
## alpha), canonical width ceil(270 * 0.46) = 125, pages <= 2048x2048, < 12 MB of frames; shown
## only through TitlePortrait (linear sampling + alpha-cut shader). The first/middle/last images
## for approval are docs/porting/captures/title_m1 (tools/title_capture.gd, real renderer).
func test_AST_010_title_conversion() -> void:
	var t: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/title/title_frames.json"))
	var root := _repo_root()
	var anim_src := FileAccess.get_file_as_string(root.path_join("src/ui/titleAnim.ts"))
	var config_src := FileAccess.get_file_as_string(root.path_join("src/config.ts"))
	assert_true(anim_src.contains("const PROBE_WIDTH = 256;") and anim_src.contains("const ALPHA_CUT = 110;") and anim_src.contains("resizeWidth: fw * 2, resizeHeight: fh * 2, resizeQuality: 'high'"), "source probe, cut and 2x resize")
	assert_true(config_src.contains("DOG_CROP_MARGIN: [0.05, 0.03]") and config_src.contains("DOG_WIDTH: 0.46") and config_src.contains("MAX_WIDTH: 270"), "source title constants")
	assert_eq([int(t["probe_width"]), int(t["alpha_cut"]), t["crop_margin"]], [256, 110, [0.05, 0.03]], "conversion parameters")
	assert_eq([int(t["canonical_width"]), int(t["frame_w"])], [ceili(270 * 0.46), 125], "canonical width 125")
	# One shared crop: every frame has the size makeFrame derives from the frame-0 box.
	var crop: Dictionary = t["crop"]
	assert_true(Rect2i(0, 0, int(t["source_size"][0]), int(t["source_size"][1])).encloses(Rect2i(int(crop["x"]), int(crop["y"]), int(crop["w"]), int(crop["h"]))), "crop inside the source frame")
	assert_eq(int(t["frame_h"]), maxi(1, roundi(float(crop["h"]) * 125.0 / float(crop["w"]))), "frame height from the shared crop")
	# 99 frames, the WebP's own delays.
	var webp := FileAccess.get_file_as_bytes(root.path_join(String(t["source"]["source"])))
	assert_eq(_sha_bytes(webp), t["source"]["sha256"], "title WebP is the audited source")
	var ms := _webp_delays(webp)
	assert_eq([int(t["count"]), ms.size()], [99, 99], "99 frames")
	var durations: Array = t["durations"]
	for k in ms.size():
		assert_near(float(durations[k]), maxf(0.02, float(ms[k]) / 1000.0), 1e-12, "frame %d delay" % k)
	# Atlas pages and memory.
	var memory := int(t["count"]) * int(t["frame_w"]) * int(t["frame_h"]) * 4
	assert_eq(int(t["memory_bytes"]), memory, "frame memory")
	assert_true(memory < 12 * 1000 * 1000, "under 12 MB of uncompressed frames (%d bytes)" % memory)
	var pages := {}
	for p: Dictionary in t["pages"]:
		var tex: Texture2D = load(p["target"])
		assert_true(tex.get_width() <= 2048 and tex.get_height() <= 2048, "%s within 2048x2048" % p["target"])
		var img := tex.get_image()
		img.convert(Image.FORMAT_RGBA8)
		pages[p["target"]] = img
	# Frames: non-blank, binary alpha (second alpha cut), in their page.
	var sf: SpriteFrames = load("res://data/title/title_animation.tres")
	assert_eq([sf.get_frame_count(&"portrait"), sf.get_animation_loop(&"portrait"), sf.get_animation_speed(&"portrait")], [99, true, 1.0], "looping portrait animation")
	for k in 99:
		var at := sf.get_frame_texture(&"portrait", k) as AtlasTexture
		assert_near(sf.get_frame_duration(&"portrait", k), float(durations[k]), 1e-6, "frame %d hold (float32 in SpriteFrames)" % k)
		var img: Image = (pages[at.atlas.resource_path] as Image).get_region(Rect2i(at.region))
		assert_eq(img.get_size(), Vector2i(125, int(t["frame_h"])), "frame %d size" % k)
		assert_false(img.is_invisible(), "frame %d not blank" % k)
		if k % 7 == 0:
			for y in img.get_height():
				for x in img.get_width():
					var a := img.get_pixel(x, y).a8
					if a != 0 and a != 255:
						fail("frame %d pixel %d,%d alpha %d not cut" % [k, x, y, a])
	# Title-only smooth scaling.
	var portrait := TitlePortrait.new()
	tree.root.add_child(portrait)
	assert_eq([portrait.texture_filter, portrait.sprite_frames, portrait.animation, portrait.is_playing()], [CanvasItem.TEXTURE_FILTER_LINEAR, sf, &"portrait", true], "linear-sampled looping portrait")
	var mat := portrait.material as ShaderMaterial
	assert_true(mat != null and mat.shader.resource_path == "res://ui/title/title_portrait.gdshader", "alpha-cut shader")
	# The headless dummy renderer compiles no shaders: read the uniform's default from the code.
	var code := mat.shader.code
	var cut := code.get_slice("uniform float alpha_cut = ", 1).get_slice(";", 0)
	assert_near(cut.to_float(), 110.0 / 255.0, 1e-12, "alpha cut 110 of 255")
	assert_true(code.contains("c.a = c.a >= alpha_cut ? 1.0 : 0.0;"), "binary alpha after linear sampling")
	portrait.fit_width(99.0)
	assert_near(portrait.scale.x, 99.0 / 125.0, 1e-6, "smooth scale to the logical width (float32 Vector2)")
	portrait.free()
	var linear_users: PackedStringArray = []
	var stack: Array[String] = ["res://"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			if not sub.begins_with(".") and sub not in ["tests", "tools", "test-results"]:
				stack.append(dir.path_join(sub))
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd") or f.ends_with(".tscn"):
				var text := FileAccess.get_file_as_string(dir.path_join(f))
				if text.contains("TEXTURE_FILTER_LINEAR") or text.contains("texture_filter = 2"):
					linear_users.append(dir.path_join(f))
	assert_eq(linear_users, PackedStringArray(["res://ui/title/title_portrait.gd"]), "only the title portrait samples linearly")
	for idx in [0, 49, 98]:
		assert_true(FileAccess.file_exists(root.path_join("docs/porting/captures/title_m1/title_frame_%02d_widths_88_99_124.png" % idx)), "review image for frame %d" % idx)


## AST-020: the generated bitmap font matches the source (src/ui/pixelFont.ts in Chromium): glyph
## image hashes, 8 px advance and union cell height, the source's word wrap (layoutLines, executed),
## the ASCII fallback ('?'), the borrowed IPA marks (ˈ = ', ː = :) and the schwa as the font's own
## "e" turned by 180 degrees; the WOFF2 source and the OFL licence are retained.
func test_AST_020_bitmap_font_matches_source() -> void:
	var src: Dictionary = fixture("source_font_glyphs")
	var advance := int(src["advance"])
	var cell_h := int(src["cell_h"])
	assert_eq([advance, PixelText.ADVANCE, PixelText.CELL_H], [8, 8, cell_h], "8 px advance, union cell height")
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/fonts/pixel_font.png"))
	img.convert(Image.FORMAT_RGBA8)
	assert_eq([img.get_width(), img.get_height()], [advance * 96, cell_h], "95 ASCII cells + the schwa cell")
	# Glyph images.
	for code_s: String in src["glyph_alpha_sha256_16"]:
		var code := int(code_s)
		var bits := PackedByteArray()
		var x0 := (code - 32) * advance
		for y in cell_h:
			for x in advance:
				bits.append(1 if img.get_pixel(x0 + x, y).a > 0.0 else 0)
		assert_eq(_sha_bytes(bits).substr(0, 16), src["glyph_alpha_sha256_16"][code_s], "glyph %d" % code)
	# Schwa: "e" rotated by 180 degrees inside its own bounding box, in the extra cell.
	var ek := ("e".unicode_at(0) - 32) * advance
	var bx0 := advance
	var by0 := cell_h
	var bx1 := -1
	var by1 := -1
	for y in cell_h:
		for x in advance:
			if img.get_pixel(ek + x, y).a > 0.0:
				bx0 = mini(bx0, x)
				bx1 = maxi(bx1, x)
				by0 = mini(by0, y)
				by1 = maxi(by1, y)
	assert_true(bx1 >= bx0 and by1 >= by0, "the e glyph has pixels")
	var schwa_x := 95 * advance
	for y in cell_h:
		for x in advance:
			var want := false
			if x >= bx0 and x <= bx1 and y >= by0 and y <= by1:
				want = img.get_pixel(ek + bx0 + bx1 - x, by0 + by1 - y).a > 0.0
			assert_eq(img.get_pixel(schwa_x + x, y).a > 0.0, want, "schwa pixel %d,%d" % [x, y])
	# Every probed character resolves to the source's atlas cell through the port's font path
	# (PixelText.sanitize, then the BMFont glyph): '?' fallback, borrowed marks, the schwa.
	var font: FontFile = load("res://assets/fonts/pixel_font.fnt")
	var glyph_x: Dictionary = src["glyph_x"]
	assert_true(glyph_x.size() >= 15, "probe characters")
	for ch: String in glyph_x:
		var shown := PixelText.sanitize(ch)
		var code := shown.unicode_at(0)
		if not assert_true(font.has_char(code), "font has %s for %s" % [shown, ch]):
			continue
		var uv := font.get_glyph_uv_rect(0, Vector2i(8, 0), font.get_glyph_index(8, code, 0))
		assert_eq(int(uv.position.x), int(glyph_x[ch]), "%s (U+%04X) shows the source cell" % [ch, ch.unicode_at(0)])
	assert_eq(font.get_char_size("W".unicode_at(0), 8), Vector2(8, 8), "8 px advance and cell")
	# Word wrap: the source's layoutLines() cases, line for line.
	var cases: Array = src["wrap"]
	assert_true(cases.size() >= 100, "wrapping fixtures")
	for c: Dictionary in cases:
		assert_eq(Array(PixelText.wrap(c["text"], int(c["max_width"]), int(c["scale"]))), c["lines"], "wrap %s at %d px x%d" % [JSON.stringify(c["text"]), c["max_width"], c["scale"]])
	# Sources retained: the WOFF2 converter input (not exported) and the OFL licence (exported).
	var root := _repo_root()
	var woff := false
	for e: Dictionary in _manifest()["inputs"]:
		if e["source"] == "src/assets/fonts/PressStart2P.woff2":
			woff = true
			assert_eq(_sha(root.path_join(e["source"])), e["sha256"], "WOFF2 source hash")
	assert_true(woff, "WOFF2 recorded as the converter input")
	var ofl := false
	for e: Dictionary in _manifest()["copies"]:
		if e["target"] == "assets/fonts/OFL.txt":
			ofl = true
	assert_true(ofl and FileAccess.get_file_as_string("res://assets/fonts/OFL.txt").contains("SIL OPEN FONT LICENSE"), "OFL retained")


func _audio_fixture() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_audio.json"))


## Decodes a whole stream through its own playback at the mix rate; returns [peak, seconds].
func _decode_peak(stream: AudioStream) -> Array:
	var pb := stream.instantiate_playback()
	pb.start(0.0)
	var peak := 0.0
	var frames := 0
	var limit := int(AudioServer.get_mix_rate() * (stream.get_length() + 1.0))
	while pb.is_playing() and frames < limit:
		var chunk := pb.mix_audio(1.0, 8192)
		frames += chunk.size()
		for v in chunk:
			peak = maxf(peak, maxf(absf(v.x), absf(v.y)))
	pb.stop()
	return [peak, frames / AudioServer.get_mix_rate()]


## AUD-001 five recorded tracks, AUD-002 twelve recorded effects, AUD-003 each decodes and is
## non-silent, AUD-004 each maps to the source's cue (src/fx/audioFiles.ts, executed).
func test_AUD_001_002_003_004_recorded_tracks_and_effects_decode_and_map() -> void:
	var fx := _audio_fixture()
	var sound_files: Dictionary = fx["sound_files"]
	var music_files: Dictionary = fx["music_files"]
	assert_eq(music_files.size(), 5, "five recorded music tracks in the source")
	assert_eq(sound_files.size(), 12, "twelve recorded effects in the source")
	var copy_of := {}
	for e: Dictionary in _manifest()["copies"]:
		copy_of[String(e["source"])] = "res://" + String(e["target"])
	var recorded_tracks: Array = AudioService.MUSIC.keys().filter(func(k: StringName) -> bool: return not AudioService.RESTARTING_TRACKS.has(k))
	assert_eq(recorded_tracks.size(), 5, "AudioService: five recorded tracks")
	assert_eq(AudioService.SFX.size(), 12, "AudioService: twelve recorded effects")
	var pairs: Array = []
	for track: String in music_files:
		pairs.append([AudioService.MUSIC, StringName(track), String(music_files[track])])
	for cue: String in sound_files:
		pairs.append([AudioService.SFX, StringName(cue), String(sound_files[cue])])
	for pair: Array in pairs:
		var table: Dictionary = pair[0]
		var cue_name: StringName = pair[1]
		var source: String = pair[2]
		if not assert_true(table.has(cue_name), "AudioService maps %s" % cue_name):
			continue
		# AUD-004: the cue plays the copy of exactly the source's file.
		assert_eq(table[cue_name], copy_of.get(source, "?"), "%s -> %s" % [cue_name, source])
		var stream: AudioStream = load(table[cue_name])
		if not assert_true(stream != null, "%s decodes (loads)" % cue_name):
			continue
		var ref: Dictionary = fx["decoded_48k"][source]
		assert_near(stream.get_length(), float(ref["duration"]), 0.002, "%s length equals Chromium's decode" % cue_name)
		# AUD-003: a full decode through the stream's own playback reaches the end, is non-silent
		# and is as loud as Chromium's decode (different decoders and resamplers: within 15 %).
		var got := _decode_peak(stream)
		assert_near(float(got[1]), stream.get_length(), 0.2, "%s decodes to its end" % cue_name)
		assert_true(float(got[0]) > 0.3, "%s non-silent (peak %.3f)" % [cue_name, got[0]])
		assert_near(float(got[0]) / float(ref["peak"]), 1.0, 0.15, "%s peak %.3f vs source decode %.3f" % [cue_name, got[0], ref["peak"]])
	# Per-track trims of the source (AUDIO.MUSIC_FILE_GAIN).
	for track: StringName in recorded_tracks:
		assert_near(AudioService.music_level(track), GameConfig.Audio.MUSIC_FILE_VOLUME * float(GameConfig.Audio.MUSIC_FILE_GAIN.get(String(track), 1.0)), 1e-12, "%s music level" % track)
	assert_near(AudioService.music_level(&"level4"), 0.55 * 0.5, 1e-12, "level 4 trimmed by 6 dB")


## AUD-005-008: the medieval loop and the fourteen synthesized cues are the source's own render
## (src/fx/sounds.ts via src/core/synth.ts, executed by tools/source_extract) as deterministic mono
## 22,050 Hz signed 16-bit little-endian PCM WAV, imported without change; recipe/input hashes,
## sample counts, output hashes, duration, amplitude, loop and cue behaviour match the fixture.
func test_AUD_005_006_007_008_synthesized_wavs_match_the_source_render() -> void:
	var fx: Dictionary = _audio_fixture()["synth"]
	assert_eq([fx["rate"], fx["bits"], fx["channels"]], [22050, 16, 1], "format contract")
	var cues: Dictionary = fx["cues"]
	assert_eq(cues.size(), 14, "fourteen synthesized cues")
	var names: Array[StringName] = []
	for n: String in cues:
		names.append(StringName(n))
	assert_eq(AudioService.SYNTH, names, "AudioService.SYNTH lists the source SOUNDS in order")
	# The WAVs come from the audited recipe sources.
	var root := _repo_root()
	var recipe_inputs := 0
	for e: Dictionary in _manifest()["inputs"]:
		if String(e["source"]) in ["src/core/synth.ts", "src/fx/sounds.ts"]:
			recipe_inputs += 1
			assert_eq(_sha_bytes(_lf(FileAccess.get_file_as_bytes(root.path_join(e["source"])))), e["sha256"], "recipe source " + String(e["source"]))
	assert_eq(recipe_inputs, 2, "both recipe sources recorded as inputs")
	var all := {}
	for n: String in cues:
		all[n] = cues[n]
	all["medieval"] = fx["music"]["medieval"]
	for n: String in all:
		var e: Dictionary = all[n]
		var path := "res://" + String(e["target"])
		assert_eq(path, "res://assets/audio/synth/%s.wav" % n, n + " target")
		assert_eq(String(e["recipe_sha256"]).length(), 64, n + " recipe hash recorded")
		var bytes := FileAccess.get_file_as_bytes(path)
		assert_eq(_sha_bytes(bytes), e["sha256"], n + " WAV bytes")
		# RIFF/WAVE, PCM, mono, 22,050 Hz, 16-bit little-endian, one data chunk.
		assert_eq(bytes.slice(0, 4).get_string_from_ascii() + bytes.slice(8, 16).get_string_from_ascii(), "RIFFWAVEfmt ", n + " RIFF header")
		assert_eq([bytes.decode_u16(20), bytes.decode_u16(22), bytes.decode_u32(24), bytes.decode_u16(34)], [1, 1, 22050, 16], n + " PCM mono 22050 Hz 16-bit")
		assert_eq(bytes.slice(36, 40).get_string_from_ascii(), "data", n + " data chunk")
		var samples := int(e["samples"])
		assert_eq(bytes.decode_u32(40), samples * 2, n + " data size")
		if n != "medieval":
			assert_eq(samples, ceili(float(e["source_duration"]) * 22050.0) + 1, n + " sample count = source renderSound length")
		# Import: lossless and untouched.
		var cfg := ConfigFile.new()
		assert_eq(cfg.load(path + ".import"), OK, n + " .import")
		assert_eq([cfg.get_value("params", "compress/mode"), cfg.get_value("params", "edit/trim"), cfg.get_value("params", "edit/normalize"),
				cfg.get_value("params", "force/8_bit"), cfg.get_value("params", "force/mono"), cfg.get_value("params", "force/max_rate")],
				[0, false, false, false, false, false], n + " imported as plain PCM")
		var s: AudioStreamWAV = load(path)
		assert_eq([s.format, s.mix_rate, s.stereo], [AudioStreamWAV.FORMAT_16_BITS, 22050, false], n + " stream format")
		assert_eq(s.data.size(), samples * 2, n + " stream samples")
		assert_eq(_sha_bytes(s.data), e["pcm_sha256"], n + " imported PCM equals the source render")
		var peak := 0
		for k in samples:
			peak = maxi(peak, absi(s.data.decode_s16(k * 2)))
		assert_eq(peak, int(e["peak"]), n + " peak amplitude")
		assert_true(peak > 3000, n + " audible (peak %d)" % peak)
		# Quantization round(clamp(x, -1, 1) * 32767) of the rendered float samples.
		for p: Array in e["probe"]:
			var q := s.data.decode_s16(int(p[0]) * 2)
			assert_eq(q, int(p[2]), "%s sample %d" % [n, p[0]])
			assert_true(absf(clampf(float(p[1]), -1.0, 1.0) * 32767.0 - q) <= 0.5 + 1e-6, "%s sample %d quantized from %.9f" % [n, p[0], p[1]])
		# Loop and cue behaviour: mix a quarter second past the end.
		var pb := s.instantiate_playback()
		pb.start(0.0)
		var frames := int(AudioServer.get_mix_rate() * (s.get_length() + 0.25))
		while frames > 0:
			pb.mix_audio(1.0, mini(frames, 8192))
			frames -= 8192
		if n == "medieval":
			assert_eq([s.loop_mode, s.loop_begin, s.loop_end], [AudioStreamWAV.LOOP_FORWARD, 0, samples], "medieval loops over the whole buffer")
			assert_eq([cfg.get_value("params", "edit/loop_mode"), cfg.get_value("params", "edit/loop_end")], [2, samples], "loop set at import")
			assert_true(pb.is_playing(), "medieval still playing past its end (loops)")
		else:
			assert_eq(s.loop_mode, AudioStreamWAV.LOOP_DISABLED, n + " one-shot")
			assert_false(pb.is_playing(), n + " ends")
			assert_eq(AudioService.cue_path(StringName(n)), path, n + " cue path")
		pb.stop()
	assert_eq(int(fx["music"]["medieval"]["loop"]["end"]), int(fx["music"]["medieval"]["samples"]), "fixture loop end")
	assert_eq(AudioService.MUSIC[&"medieval"], "res://assets/audio/synth/medieval.wav", "medieval track")
	assert_true(AudioService.RESTARTING_TRACKS.has(&"medieval"), "medieval restarts from 0 (new buffer source in the source)")
	assert_near(AudioService.music_level(&"medieval"), GameConfig.Audio.MUSIC_VOLUME, 1e-12, "medieval at AUDIO.MUSIC_VOLUME")
	assert_false(FileAccess.get_file_as_string("res://autoload/audio_service.gd").contains("AudioStreamGenerator"), "no runtime synthesis")


func test_SLICE_drink_wav_is_imported_lossless() -> void:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://assets/audio/recorded/pees-collect.wav.import"), OK, "wav .import")
	assert_eq(cfg.get_value("params", "compress/mode", -1), 0, "PCM (no QOA/ADPCM)")
	var s: AudioStreamWAV = load("res://assets/audio/recorded/pees-collect.wav")
	assert_true(s.format in [AudioStreamWAV.FORMAT_8_BITS, AudioStreamWAV.FORMAT_16_BITS], "uncompressed sample format (%d)" % s.format)


func test_SLICE_leading_silence_data_from_source() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/audio/sfx_leading_silence.json"))
	assert_eq(d["recipe"], "src/core/audio.ts leadingSilence() in Chromium WebAudio", "recipe")
	assert_eq(d["trim_level"], 0.01, "AUDIO.TRIM_LEVEL")
	for cue in ["bark", "treat", "poop", "pee", "drink", "splash"]:
		var o: Dictionary = d["offsets"][cue]
		assert_true(float(o["48000"]["offset"]) >= 0.0 and float(o["48000"]["offset"]) < float(o["48000"]["duration"]), cue + " offset inside the clip")
		assert_near(float(o["48000"]["offset"]), float(o["44100"]["offset"]), 0.001, cue + " offset independent of the decode rate")
	# The runtime reads the generated Resource (exported), never the JSON (not exported).
	var res: SfxLeadingSilence = load("res://data/audio/sfx_leading_silence.tres")
	assert_eq([res.audited_commit, res.runtime_rate, res.trim_level], [d["audited_commit"], 48000, 0.01], "resource header")
	assert_eq(res.offsets.keys().size(), 12, "twelve recorded effects")
	for cue: String in d["offsets"]:
		var want := float(d["offsets"][cue]["48000"]["offset"])
		assert_near(res.offsets[StringName(cue)], want, absf(want) * 1e-14, cue + " offset equals the extracted value")
	assert_eq(AudioService.LEADING_SILENCE, res, "AudioService preloads the generated Resource")
	var audio_src := FileAccess.get_file_as_string("res://autoload/audio_service.gd")
	assert_false(audio_src.contains(".json"), "AudioService reads no JSON")


func test_SLICE_export_ships_ofl_and_the_app_label() -> void:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK, "export presets")
	assert_true(String(cfg.get_value("preset.0", "include_filter", "")).contains("assets/fonts/OFL.txt"), "OFL.txt exported with the font")
	assert_false(String(cfg.get_value("preset.0", "exclude_filter", "")).contains("*.txt"), "no exclusion catches OFL.txt")
	assert_eq(cfg.get_value("preset.0.options", "package/unique_name", ""), "com.zampano.supervillained", "package id")
	var strings := _repo_root().path_join("android/app/src/main/res/values/strings.xml")
	assert_true(FileAccess.file_exists(strings), "Capacitor strings.xml present")
	var xml := FileAccess.get_file_as_string(strings)
	var label := xml.get_slice("<string name=\"app_name\">", 1).get_slice("</string>", 0)
	assert_eq(cfg.get_value("preset.0.options", "package/name", ""), label, "Android label restored from the Capacitor app_name")
	assert_eq(ProjectSettings.get_setting("application/config/quit_on_go_back"), false, "Back never quits the app")
