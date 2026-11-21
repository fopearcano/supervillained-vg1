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


func test_P_AST_001_copies_and_outputs_match_manifest_and_source() -> void:
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


func test_P_AST_002_playable_sheet_geometry() -> void:
	var main: Texture2D = load("res://assets/sprites/zampano.png")
	var tired: Texture2D = load("res://assets/sprites/zampano-tired.png")
	assert_eq(Vector2i(main.get_width(), main.get_height()), Vector2i(320, 3520), "main sheet 320x3520")
	assert_eq(Vector2i(tired.get_width(), tired.get_height()), Vector2i(80, 320), "tired sheet 80x320")
	assert_eq(main.get_height() % 40, 0, "whole 40 px rows")


func test_P_AST_003_foot_anchor() -> void:
	var p: PlayableCharacterProfile = load("res://data/characters/zampano_profile.tres")
	assert_eq(p.foot_anchor, Vector2i(20, 36), "foot anchor")
	var dog: PlayableDog = load("res://entities/playable_dog/playable_dog.tscn").instantiate()
	var body: AnimatedSprite2D = dog.get_node("VisualRoot/Body")
	assert_eq(body.offset, Vector2(-20, -36), "sprite offset puts the anchor on the foot point")
	assert_false(body.centered, "not centred")
	dog.free()


func test_P_AST_004_every_action_has_eight_real_directions() -> void:
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


func test_P_AST_012_environment_frames_and_tile_atlas() -> void:
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


func test_P_AST_016_lossless_nearest_no_mipmaps() -> void:
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


func test_P_AST_017_required_sprites_present() -> void:
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


func test_P_AST_018_no_forbidden_runtime_content() -> void:
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


func test_P_AST_020_bitmap_font_matches_source_glyphs() -> void:
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
