extends SceneTree
## Editor-time resource builder (ARCHITECTURE.md §16). Run headless in two phases, with an import
## between them (tools/build_assets.sh / build_assets.ps1 do this):
##   godot --headless --path godot --script res://tools/build_resources.gd -- --phase images
##   godot --headless --path godot --import
##   godot --headless --path godot --script res://tools/build_resources.gd -- --phase resources
## Inputs are the byte-identical copies and layout data written by tools/source_extract.
## Outputs are rewritten only when their bytes change; a missing frame fails the build.
## `-- --phase all --check` rebuilds everything in memory and fails (exit 1) on any byte
## difference with the committed outputs, without writing.

const ENV_FRAMES := "res://data/environment/ch01_greenzone_frames.json"
const PROFILES_JSON := "res://data/characters/playable_profiles.json"
## Display names of the PLAY_AS dogs.
const DISPLAY_NAMES := {"zampano": "Zampanò", "sbrimbrulon": "Sbrimbrulòn", "bagnaskiz": "Bagnaskiz"}
const TILE_ATLAS := "res://assets/generated/environment/ch01_greenzone_tiles.png"
const TILESET_OUT := "res://data/environment/ch01_greenzone_tileset.tres"
const SPRITES_OUT := "res://data/environment/green_zone_sprites.tres"
const SFX_SILENCE_JSON := "res://data/audio/sfx_leading_silence.json"
const SFX_SILENCE_OUT := "res://data/audio/sfx_leading_silence.tres"
const FLOOR_ART_ATLAS := "res://assets/generated/environment/ch01_greenzone_floor_art.png"
const FLOOR_CELL := Vector2i(32, 16)
const FLOOR_COLUMNS := 16

## Atlas cell for every ground tile (texture_region_size). 22 px fits tall grass (21 px) evenly.
const CELL := Vector2i(32, 22)
const GRASS_WIND := [0, 1, 2, 1]
const WIND_STEP := 0.24
const WATER_STEP := 0.55
const DEEP_STEP := 0.72
const ATLAS_ROWS := 7

var _failures: PackedStringArray = []
var _changed := 0
var _checked := 0
var _check := false


func _initialize() -> void:
	var phase := "all"
	var args := OS.get_cmdline_user_args()
	for k in args.size():
		if args[k] == "--phase" and k + 1 < args.size():
			phase = args[k + 1]
		elif args[k] == "--check":
			_check = true
	if phase == "images" or phase == "all":
		_build_tile_atlas()
		_build_floor_art_atlas()
	if phase == "resources" or phase == "all":
		_build_tileset()
		_build_sprite_catalog()
		_build_characters()
		_build_sfx_silence()
	if _failures.is_empty():
		if _check:
			print("build_resources check (%s): OK, %d outputs identical" % [phase, _checked])
		else:
			print("build_resources (%s): OK, %d file(s) changed" % [phase, _changed])
		quit(0)
	else:
		for f in _failures:
			printerr("build_resources: ", f)
		quit(1)


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		_failures.append("cannot read " + path)
		return {}
	return parsed


func _load_image(res_path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(res_path))
	if img == null:
		_failures.append("cannot load image " + res_path)
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


func _write_if_changed(res_path: String, bytes: PackedByteArray) -> void:
	var abs_path := ProjectSettings.globalize_path(res_path)
	_checked += 1
	if FileAccess.file_exists(abs_path) and FileAccess.get_file_as_bytes(abs_path) == bytes:
		return
	if _check:
		_failures.append("%s %s" % ["DIFFERS" if FileAccess.file_exists(abs_path) else "MISSING", res_path])
		return
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()
	_changed += 1


## Saves through ResourceSaver into a temp file and replaces the target only if bytes differ.
func _save_resource(res: Resource, res_path: String) -> void:
	var tmp := res_path.get_basename() + ".tmp.tres"
	var err := ResourceSaver.save(res, tmp)
	if err != OK:
		_failures.append("save failed %s (%d)" % [res_path, err])
		return
	var tmp_abs := ProjectSettings.globalize_path(tmp)
	var text := FileAccess.get_file_as_string(tmp_abs).replace(tmp, res_path)
	DirAccess.remove_absolute(tmp_abs)
	_write_if_changed(res_path, text.to_utf8_buffer())


## The recorded effects' leading silence as an exported Resource (the JSON stays out of exports).
func _build_sfx_silence() -> void:
	var src := _json(SFX_SILENCE_JSON)
	if src.is_empty():
		return
	var res := SfxLeadingSilence.new()
	res.audited_commit = src["audited_commit"]
	res.runtime_rate = int(src["runtime_rate"])
	res.trim_level = float(src["trim_level"])
	var rate := str(res.runtime_rate)
	var cues: Array = (src["offsets"] as Dictionary).keys()
	cues.sort()
	for cue: String in cues:
		res.offsets[StringName(cue)] = float(src["offsets"][cue][rate]["offset"])
	_save_resource(res, SFX_SILENCE_OUT)


# --- Ground tiles -------------------------------------------------------------------------------

## Atlas layout: name -> {cell: Vector2i, frames: [frame names]}. Animated alternatives rotate
## their frame lists by the per-cell phase the source picks with hash2 (WORLD-004).
func _tile_layout() -> Dictionary:
	var layout := {}
	var static_names := ["grass_0", "grass_1", "grass_2", "grass_3", "forest_0", "forest_1", "forest_2",
		"dirt_0", "dirt_1", "dirt_2", "dirt_3", "fresh_0", "exitRing_0"]
	for c in static_names.size():
		layout[static_names[c]] = {"cell": Vector2i(c, 0), "frames": [static_names[c]], "step": 0.0}
	for m in 16:
		for v in 2:
			var idx := m * 2 + v
			var name := "path_%d_%d" % [m, v]
			layout[name] = {"cell": Vector2i(idx % 16, 1 + idx / 16), "frames": [name], "step": 0.0}
	for p in 2:
		layout["water_phase%d" % p] = {"cell": Vector2i(p * 2, 3), "frames": ["water_%d" % p, "water_%d" % ((p + 1) % 2)], "step": WATER_STEP}
	for p in 4:
		var frames := []
		for k in 4:
			frames.append("tallGrass_%d" % GRASS_WIND[(p + k) % 4])
		layout["tallGrass_phase%d" % p] = {"cell": Vector2i(p * 4, 4), "frames": frames, "step": WIND_STEP}
	# Deep water (phase-rotated like water, 0.72 s) and the wall base under wall blocks.
	for p in 2:
		layout["deep_phase%d" % p] = {"cell": Vector2i(p * 2, 5), "frames": ["deep_%d" % p, "deep_%d" % ((p + 1) % 2)], "step": DEEP_STEP}
	layout["wallBase_0"] = {"cell": Vector2i(4, 5), "frames": ["wallBase_0"], "step": 0.0}
	# Story grounds (three variants each) so the shared IsoWorld can draw any map.
	var col := 5
	var row := 5
	for kind in ["floor", "stone", "sand", "snow", "dock", "carpet"]:
		for v in 3:
			var name := "%s_%d" % [kind, v]
			layout[name] = {"cell": Vector2i(col, row), "frames": [name], "step": 0.0}
			col += 1
			if col >= 16:
				col = 0
				row += 1
	return layout


## Authored floor-composition frames (floorArt_*), in name order, for visual-only floor designs.
func _floor_art_names(frames: Dictionary) -> Array:
	var names: Array = []
	for name: String in frames:
		if name.begins_with("floorArt_"):
			names.append(name)
	names.sort()
	return names


func _build_floor_art_atlas() -> void:
	var env := _json(ENV_FRAMES)
	if env.is_empty():
		return
	var bank := _load_image(env["image"])
	if bank == null:
		return
	var frames: Dictionary = env["frames"]
	var names := _floor_art_names(frames)
	var rows := int(ceil(names.size() / float(FLOOR_COLUMNS)))
	var atlas := Image.create_empty(FLOOR_CELL.x * FLOOR_COLUMNS, FLOOR_CELL.y * rows, false, Image.FORMAT_RGBA8)
	for k in names.size():
		var f: Dictionary = frames[names[k]]
		if int(f["w"]) != 32 or int(f["h"]) != 16 or int(f["anchorX"]) != 16 or int(f["anchorY"]) != 0:
			_failures.append("floor frame %s breaks the native floor contract" % names[k])
			continue
		atlas.blit_rect(bank, Rect2i(int(f["x"]), int(f["y"]), 32, 16), Vector2i((k % FLOOR_COLUMNS) * 32, (k / FLOOR_COLUMNS) * 16))
	_write_if_changed(FLOOR_ART_ATLAS, atlas.save_png_to_buffer())


func _build_tile_atlas() -> void:
	var env := _json(ENV_FRAMES)
	if env.is_empty():
		return
	var bank := _load_image(env["image"])
	if bank == null:
		return
	var frames: Dictionary = env["frames"]
	var atlas := Image.create_empty(CELL.x * 16, CELL.y * ATLAS_ROWS, false, Image.FORMAT_RGBA8)
	var layout := _tile_layout()
	for name: String in layout:
		var entry: Dictionary = layout[name]
		var cell: Vector2i = entry["cell"]
		var list: Array = entry["frames"]
		for k in list.size():
			var fname: String = list[k]
			if not frames.has(fname):
				_failures.append("environment frame missing: " + fname)
				continue
			var f: Dictionary = frames[fname]
			if int(f["w"]) != 32 or int(f["h"]) > CELL.y or int(f["anchorX"]) != 16:
				_failures.append("environment frame %s breaks the ground contract" % fname)
				continue
			var src := Rect2i(int(f["x"]), int(f["y"]), int(f["w"]), int(f["h"]))
			atlas.blit_rect(bank, src, Vector2i((cell.x + k) * CELL.x, cell.y * CELL.y))
	_write_if_changed(TILE_ATLAS, atlas.save_png_to_buffer())


func _build_tileset() -> void:
	var env := _json(ENV_FRAMES)
	var frames: Dictionary = env.get("frames", {})
	var texture: Texture2D = load(TILE_ATLAS)
	if texture == null:
		_failures.append("tile atlas not imported: " + TILE_ATLAS)
		return
	texture.set_id_for_path(TILESET_OUT, "1_tiles")
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
	ts.tile_size = Vector2i(32, 16)
	var src := TileSetAtlasSource.new()
	src.resource_scene_unique_id = "atlas_ground"
	src.texture = texture
	src.texture_region_size = CELL
	var coords := {}
	var layout := _tile_layout()
	for name: String in layout:
		var entry: Dictionary = layout[name]
		var cell: Vector2i = entry["cell"]
		var list: Array = entry["frames"]
		src.create_tile(cell)
		var first: Dictionary = frames.get(list[0], {"anchorY": 0})
		var data := src.get_tile_data(cell, 0)
		# Content sits at the top of the 22 px cell; the anchor (16, anchorY) lands on the tile's
		# top vertex, which is the cell centre minus 8 px.
		data.texture_origin = Vector2i(0, int(first["anchorY"]) - 3)
		if list.size() > 1:
			src.set_tile_animation_frames_count(cell, list.size())
			src.set_tile_animation_columns(cell, 0)
			for k in list.size():
				src.set_tile_animation_frame_duration(cell, k, entry["step"])
		coords[name] = cell
	ts.add_source(src, 0)
	# Source 1: authored floor-composition frames, used only by visual floor designs (MAP-006).
	var floor_tex: Texture2D = load(FLOOR_ART_ATLAS)
	if floor_tex == null:
		_failures.append("floor-art atlas not imported: " + FLOOR_ART_ATLAS)
		return
	var floor_src := TileSetAtlasSource.new()
	floor_src.resource_scene_unique_id = "atlas_floor_art"
	floor_src.texture = floor_tex
	floor_src.texture_region_size = FLOOR_CELL
	var floor_coords := {}
	var names := _floor_art_names(frames)
	for k in names.size():
		var c := Vector2i(k % FLOOR_COLUMNS, k / FLOOR_COLUMNS)
		floor_src.create_tile(c)
		floor_coords[names[k]] = c
	ts.add_source(floor_src, 1)
	ts.set_meta(&"tile_coords", coords)
	ts.set_meta(&"floor_art_coords", floor_coords)
	ts.set_meta(&"source", "public/environment-ink ch01_greenzone (audited 95b69c0)")
	_save_resource(ts, TILESET_OUT)


# --- Static sprites -----------------------------------------------------------------------------

func _build_sprite_catalog() -> void:
	var env := _json(ENV_FRAMES)
	var frames: Dictionary = env.get("frames", {})
	var variants: Dictionary = env.get("sprite_variants", {})
	var bank: Texture2D = load(env.get("image", ""))
	if bank == null:
		_failures.append("environment bank not imported")
		return
	bank.set_id_for_path(SPRITES_OUT, "1_bank")
	var cat := SpriteCatalog.new()
	var entries := {}
	# Props delivered in the Color Ink bank (current final art).
	for key in ["tree", "forestTree", "bush", "pole", "fountain", "exitFlag", "exitRing", "wallBlock"]:
		# exitRing is a ground-contract tile frame (no SPRITES entry): one variant.
		var n: int = int(variants[key]["variants"]) if variants.has(key) else 1
		for v in n:
			var fname := "%s_%d" % [key, v]
			if not frames.has(fname):
				_failures.append("environment frame missing: " + fname)
				continue
			var f: Dictionary = frames[fname]
			var at := AtlasTexture.new()
			at.resource_scene_unique_id = "spr_" + fname
			at.atlas = bank
			at.region = Rect2(int(f["x"]), int(f["y"]), int(f["w"]), int(f["h"]))
			at.filter_clip = true
			entries[fname] = {"texture": at, "anchor": Vector2i(int(f["anchorX"]), int(f["anchorY"])), "size": Vector2i(int(f["w"]), int(f["h"]))}
	# Frozen procedural sprites (exact output of the source generators).
	var manifest := _json("res://data/source_asset_manifest.json")
	var tex_id := 2
	for g: Dictionary in manifest.get("generated", []):
		if not g.has("frame_w"):
			continue
		var tex: Texture2D = load("res://" + String(g["target"]))
		if tex == null:
			_failures.append("generated sprite not imported: " + String(g["target"]))
			continue
		tex.set_id_for_path(SPRITES_OUT, "%d_%s" % [tex_id, g["key"]])
		tex_id += 1
		for v in int(g["variants"]):
			var at := AtlasTexture.new()
			at.resource_scene_unique_id = "spr_%s_%d" % [g["key"], v]
			at.atlas = tex
			at.region = Rect2(v * int(g["frame_w"]), 0, int(g["frame_w"]), int(g["frame_h"]))
			at.filter_clip = true
			entries["%s_%d" % [g["key"], v]] = {"texture": at, "anchor": Vector2i(int(g["anchor_x"]), int(g["anchor_y"])), "size": Vector2i(int(g["frame_w"]), int(g["frame_h"]))}
	var run_icon: Texture2D = load("res://assets/sprites/run_icon.png")
	run_icon.set_id_for_path(SPRITES_OUT, "%d_run_icon" % tex_id)
	entries["runIcon_0"] = {"texture": run_icon, "anchor": Vector2i.ZERO, "size": Vector2i(run_icon.get_width(), run_icon.get_height())}
	cat.entries = entries
	_save_resource(cat, SPRITES_OUT)


# --- Playable characters ------------------------------------------------------------------------

static func sheet_layout_path(skin: String) -> String:
	return "res://data/characters/%s_sheet.json" % skin


static func frames_path(skin: String) -> String:
	return "res://data/characters/%s_frames.tres" % skin


static func profile_path(play_as: String) -> String:
	return "res://data/characters/%s_profile.tres" % play_as


## SpriteFrames for every playable skin, then one PlayableCharacterProfile per PLAY_AS dog whose
## normal/cross/armoured slots are the source costumeFor() skins (aliases reuse the same frames).
func _build_characters() -> void:
	var profiles := _json(PROFILES_JSON)
	if profiles.is_empty():
		return
	for skin: String in profiles["skins"]:
		_build_frames(skin)
	for play_as: String in profiles["play_as"]:
		_build_profile(play_as, profiles)


func _build_frames(skin: String) -> void:
	var out := frames_path(skin)
	var layout := _json(sheet_layout_path(skin))
	if layout.is_empty():
		return
	var sheet: Texture2D = load(layout["sheet"])
	var own_sheets := {}
	for anim: String in layout["anim_sheets"]:
		own_sheets[anim] = load(layout["anim_sheets"][anim])
	if sheet == null:
		_failures.append("character sheet not imported: " + skin)
		return
	sheet.set_id_for_path(out, "1_sheet")
	var ext := 2
	for anim: String in own_sheets:
		(own_sheets[anim] as Texture2D).set_id_for_path(out, "%d_%s" % [ext, anim])
		ext += 1
	var fw: int = layout["frame_w"]
	var fh: int = layout["frame_h"]
	var rows := sheet.get_height() / fh
	var dirs: Array = layout["sheet_dirs"]
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	var row := 0
	for anim: String in layout["anim_order"]:
		var def: Dictionary = layout["anims"][anim]
		var n: int = int(def["frames"])
		var holds: Array = def.get("frameDurationsMs", [])
		var own: Texture2D = own_sheets.get(anim)
		for d in dirs.size():
			var anim_name := StringName("%s_%s" % [anim, String(dirs[d]).to_lower()])
			sf.add_animation(anim_name)
			sf.set_animation_loop(anim_name, bool(def["loop"]))
			# Authored holds: speed 1 and per-frame durations in seconds; uniform cycles: source FPS.
			sf.set_animation_speed(anim_name, 1.0 if not holds.is_empty() else float(def["fps"]))
			for f in n:
				var at := AtlasTexture.new()
				at.resource_scene_unique_id = "zf_%s_%d" % [anim_name, f]
				if own != null:
					at.atlas = own
					at.region = Rect2(f * fw, d * fh, fw, fh)
				elif row < rows:
					at.atlas = sheet
					at.region = Rect2(f * fw, row * fh, fw, fh)
				else:
					_failures.append("%s sheet lacks rows for %s" % [skin, anim_name])
					continue
				at.filter_clip = true
				var duration := float(holds[f]) / 1000.0 if not holds.is_empty() else 1.0
				sf.add_frame(anim_name, at, duration)
			if own == null:
				row += 1
	if row * fh != sheet.get_height():
		_failures.append("%s sheet rows used %d != sheet rows %d" % [skin, row, rows])
	_save_resource(sf, out)


func _build_profile(play_as: String, profiles: Dictionary) -> void:
	var out := profile_path(play_as)
	var costumes: Dictionary = profiles["costumes"][play_as]
	var slots: Dictionary = profiles["costume_slots"]
	var aliases: Dictionary = profiles["aliases"]
	var skin_of := func(slot: String) -> String:
		var skin := String(costumes[slots[slot]])
		return String(aliases.get(skin, skin))
	var normal_skin: String = skin_of.call("normal")
	var layout := _json(sheet_layout_path(normal_skin))
	if layout.is_empty():
		return
	var profile := PlayableCharacterProfile.new()
	profile.id = StringName(play_as)
	profile.display_name = DISPLAY_NAMES[play_as]
	var ext := 1
	var loaded := {}
	for slot: String in ["normal", "cross", "armoured"]:
		var skin: String = skin_of.call(slot)
		if not loaded.has(skin):
			var res: SpriteFrames = load(frames_path(skin))
			if res == null:
				_failures.append("frames not built: " + skin)
				return
			res.set_id_for_path(out, "%d_frames" % ext)
			ext += 1
			loaded[skin] = res
		profile.set(slot + "_frames", loaded[skin])
	var durations := {}
	var timed := PackedStringArray()
	for anim: String in layout["anim_order"]:
		var def: Dictionary = layout["anims"][anim]
		durations[anim] = float(def["frames"]) / float(def["fps"])
		if not (def.get("frameDurationsMs", []) as Array).is_empty():
			timed.append(anim)
	profile.foot_anchor = Vector2i(int(layout["anchor_x"]), int(layout["anchor_y"]))
	profile.frame_size = Vector2i(int(layout["frame_w"]), int(layout["frame_h"]))
	profile.collision_radius = GameConfig.Player.RADIUS
	profile.has_seated_idle = (layout["anims"] as Dictionary).has("sit")
	profile.action_durations = durations
	profile.timed_actions = timed
	_save_resource(profile, out)
