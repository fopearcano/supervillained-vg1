extends Control
## M1 manual-review station: a development-only scene (tools/ is excluded from every export preset,
## and the hermetic PCK smoke fails if any tools/ file reaches the pack). It presents the material
## of the three manual M1 checks (MILESTONES.md M1, "Manual gameplay/tests") and records the
## reviewer's own decisions. Nothing here judges a check: every PASS/FAIL comes from a human click.
##   1 Animations: every Zampanò animation of the profile's costumes (normal; armoured, which the
##     cross costume aliases), every action including tired, the eight directions at once in a
##     compass, live at the authored frame timing with nearest filtering; pause, replay and frame
##     step; resource, animation, direction, frame number and authored duration on screen.
##   2 Audio: the five recorded tracks, twelve recorded effects, the generated medieval loop and the
##     fourteen generated cues (AUD-001-008), played through AudioService (the game path: leading
##     silence skipped, gains, buses) or raw from 0 s, starting at a safe master volume.
##   3 Title: the title portrait at the three review widths (TitlePortrait, x2 like the game), live
##     at the authored delays, with pause, frame step and first/middle/last.
##   4 Sign-off: owner, date, environment and the final decision.
## Decisions are saved on every change to <decisions dir>/m1_owner_decisions.json and .md (resumed
## on the next start). Nothing is written to the game's save files.
##
##   godot --path godot res://tools/m1_review.tscn -- [--decisions <absolute dir>]
##   godot --path godot res://tools/m1_review.tscn -- --export <absolute dir>
## --export writes the machine-readable inventories, the blank checklist, labelled contact sheets
## and captures of the review screens, runs automated self-checks (facts only, never a manual
## decision) and exits 0 when they all hold. Both need a renderer (not --headless).

const PROFILE_PATH := "res://data/characters/zampano_profile.tres"
const MANIFEST_PATH := "res://data/source_asset_manifest.json"
const AUDIO_FIXTURE_PATH := "res://tests/fixtures/source_audio.json"
const TITLE_JSON_PATH := "res://data/title/title_frames.json"
const DIRS: Array[String] = ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
## Compass cell (column, row) of each direction in the 3x3 stage; the centre shows the item.
const DIR_CELL := {
	"nw": Vector2i(0, 0), "n": Vector2i(1, 0), "ne": Vector2i(2, 0),
	"w": Vector2i(0, 1), "e": Vector2i(2, 1),
	"sw": Vector2i(0, 2), "s": Vector2i(1, 2), "se": Vector2i(2, 2),
}
const CELL := 176
const SPRITE_SCALE := 3
## Seconds a finished one-shot animation holds its last frame before the automatic replay.
const ONE_SHOT_HOLD := 0.75
## Master volume at start (linear); the reviewer raises it only after a quiet first listen.
const SAFE_VOLUME := 0.25
const DECISIONS: Array[String] = ["NOT EXECUTED", "PASS", "FAIL"]
const FINALS: Array[String] = ["NOT DECIDED", "APPROVED", "NOT APPROVED"]
const BACKGROUNDS: Array[Color] = [Color("#2b2b36"), Color("#8c8c99"), Color("#e8e8ee")]
const SHEET_BG := Color("#3c3c4a")
const TITLE_BG := Color("#120818")
## Logical title widths of the narrowest, preferred and widest views (192, 216, 270 px x 0.46),
## laid out like tools/title_capture.gd.
const TITLE_WIDTHS: Array[int] = [88, 99, 124]
const TITLE_VIEWS: Array[int] = [192, 216, 270]
const TITLE_SIZE := Vector2i(8 + (126 + 8) * 3, 8 + 172 + 8)
## Listening order: recorded tracks and effects (AUD-001-004), then the generated loop and cues
## (AUD-005-008). [cue, kind, provenance, source reference, expected use]
const AUDIO_ITEMS := [
	["intro", "music", "recorded", "MUSIC_FILES.intro; setTrack('intro')", "Reading screens: title, briefing and story pages."],
	["greenzone", "music", "recorded", "MUSIC_FILES.greenzone; setTrack('greenzone')", "Green Zone level music."],
	["level2", "music", "recorded", "MUSIC_FILES.level2; chapter music", "Level 2, On the edge of dreams."],
	["level3", "music", "recorded", "MUSIC_FILES.level3; chapter music", "Level 3, Venice."],
	["level4", "music", "recorded", "MUSIC_FILES.level4; chapter music", "Level 4, The sea."],
	["bark", "effect", "recorded", "SOUND_FILES.bark; event bark (rate 0.95-1.05)", "Zampanò barks."],
	["treat", "effect", "recorded", "SOUND_FILES.treat; event treat", "A treat is eaten."],
	["poop", "effect", "recorded", "SOUND_FILES.poop; event poop", "Zampanò poops."],
	["pee", "effect", "recorded", "SOUND_FILES.pee; event pee", "Zampanò pees."],
	["drink", "effect", "recorded", "SOUND_FILES.drink; event drink", "Zampanò drinks."],
	["splash", "effect", "recorded", "SOUND_FILES.splash; event splash (volume 0.7)", "Zampanò splashes into water."],
	["meow", "effect", "recorded", "SOUND_FILES.meow; event cat", "A cat is met (the coin follows after a short delay)."],
	["coin", "effect", "recorded", "SOUND_FILES.coin; events cat (delayed) and poopCleaned (rate 1.5, volume 0.5)", "Cash after the cat; a cleaned-up poop."],
	["ball", "effect", "recorded", "SOUND_FILES.ball; event ballSpawn", "A ball appears."],
	["alarm", "effect", "recorded", "SOUND_FILES.alarm; event attackStart", "The Green Zone is under attack."],
	["siren", "effect", "recorded", "SOUND_FILES.siren; event attackStart (looped after a delay)", "Attack siren, looped during an attack."],
	["laser", "effect", "recorded", "SOUND_FILES.laser; event bump", "Zampanò bumps into an obstacle."],
	["medieval", "music", "generated", "src/fx/sounds.ts renderMedievalMusic(); chapters 5-7 music", "Dream-chapter music loop (restarts from 0 on every switch)."],
	["fetch", "effect", "generated", "SOUNDS.fetch; event fetch", "The ball is fetched."],
	["warning", "effect", "generated", "SOUNDS.warning; events digestWarning and pollutionSurge (rate 0.82, volume 0.75)", "Digestion warning; pollution surge."],
	["empty", "effect", "generated", "SOUNDS.empty; events peeEmpty and tired (rate 0.8)", "Pee tank empty; Zampanò is tired."],
	["hurt", "effect", "generated", "SOUNDS.hurt; event lifeLost, combat and minigame damage", "A life is lost; Zampanò is hurt."],
	["hit", "effect", "generated", "SOUNDS.hit; event barkHit, combat hits", "A bark or a blow hits."],
	["swish", "effect", "generated", "SOUNDS.swish; story combat", "Sword swing."],
	["clang", "effect", "generated", "SOUNDS.clang; story combat", "Sword or shield clang."],
	["flee", "effect", "generated", "SOUNDS.flee; event bagnaskizFled, combat", "A foe runs away."],
	["saved", "effect", "generated", "SOUNDS.saved; event attackEnd", "The attack is repelled."],
	["star", "effect", "generated", "SOUNDS.star; marking pee (+0.12 s), end-screen stars", "A star or marking reward."],
	["jingle", "effect", "generated", "SOUNDS.jingle; event levelComplete", "Level complete."],
	["gameover", "effect", "generated", "SOUNDS.gameover; event gameOver", "Game over."],
	["click", "effect", "generated", "SOUNDS.click; menus and buttons", "UI click."],
	["glitch", "effect", "generated", "SOUNDS.glitch; glitch transitions", "Glitch transition."],
]
const AUDIO_OBS := [
	["AUDIBLE", "Audibility: clearly audible at the safe volume"],
	["INTENT", "Intent: sounds right for its expected use"],
	["START", "Start: no late start or cut attack (recorded effects skip their leading silence in the game)"],
	["END", "Transitions: ends or loops cleanly (music: loop seam and track switch)"],
	["CLEAN", "No obvious clipping, distortion or artifacts"],
]
const TITLE_OBS := [
	["C-CROP", "Common crop: the figure does not shift or jump between frames; the same crop at every width"],
	["C-ALPHA", "Alpha edges: crisp cut-out edges, no halo, fringe or holes"],
	["C-SCALE", "Title-only scaling: the portrait is scaled smoothly at all three widths (pixel art elsewhere stays crisp)"],
	["C-FIRST", "First frame (0) looks right at every width"],
	["C-MIDDLE", "Middle frame (49) looks right at every width"],
	["C-LAST", "Last frame (98) looks right at every width"],
	["C-TIMING", "Playback timing matches the source animation (authored delays, smooth loop)"],
]
const FILTER_LABEL := "Nearest filtering: every animation's pixels stay crisp (no blur, no shimmer) at the review scale"
const MUTE_LABEL := "Mute silences playback and unmuting restores it"
const VOLUME_LABEL := "The volume control changes loudness; 0 % is silent"

var _profile: PlayableCharacterProfile
## [{"key", "label", "slots", "path", "frames": SpriteFrames, "sheet": Dictionary}]
var _costumes: Array[Dictionary] = []
var _actions: PackedStringArray = []
var _audio: Array[Dictionary] = []
var _title_json: Dictionary = {}
var _manifest_sha: Dictionary = {}
## Ordered decision fields: {"id", "section", "group", "label"}.
var _fields: Array[Dictionary] = []
var _decisions: Dictionary = {}
var _notes: Dictionary = {}
var _owner_info := {"name": "", "date": "", "equipment": "", "final": "NOT DECIDED"}
var _env: Dictionary = {}
var _decisions_dir := "user://m1_review"
var _export_dir := ""
var _status: Label
var _tabs: TabContainer

# Animations tab.
var _anim_list: ItemList
var _stage: ColorRect
var _sprites: Dictionary = {}
var _dir_labels: Dictionary = {}
var _dir_pickers: Dictionary = {}
var _centre: Label
var _anim_info: RichTextLabel
var _anim_notes: LineEdit
var _filter_picker: OptionButton
var _anim_index := 0
var _anim_paused := false
var _auto_replay := true
var _bg_index := 0
var _hold := 0.0

# Audio tab.
var _audio_list: ItemList
var _audio_info: RichTextLabel
var _audio_pos: Label
var _audio_pickers: Dictionary = {}
var _audio_notes: LineEdit
var _mute_box: CheckBox
var _volume: HSlider
var _volume_label: Label
var _raw: AudioStreamPlayer
var _audio_index := 0
var _last_mode := "game"

# Title tab.
var _portraits: Array[TitlePortrait] = []
var _title_info: Label
var _title_paused := false
var _title_last_frame := 0
var _title_cycle_start := 0
var _title_measured := 0.0
var _title_notes: LineEdit

# Sign-off tab.
var _name_edit: LineEdit
var _date_edit: LineEdit
var _equipment_edit: LineEdit
var _final_picker: OptionButton
var _summary: Label

var _pickers_by_id: Dictionary = {}
var _loading := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for k in args.size():
		if args[k] == "--decisions" and k + 1 < args.size():
			_decisions_dir = args[k + 1]
		elif args[k] == "--export" and k + 1 < args.size():
			_export_dir = args[k + 1]
	_load_data()
	_build_fields()
	for f: Dictionary in _fields:
		_decisions[f["id"]] = "NOT EXECUTED"
	_env = _environment()
	if _export_dir == "":
		_load_decisions()
	_setup_window()
	_build_ui()
	AudioService.set_duck(1.0)
	_apply_volume()
	_select_anim(0)
	_select_audio(0)
	_refresh_all()
	if _export_dir != "":
		_run_export.call_deferred()


# --- Data -----------------------------------------------------------------------------------------

func _load_data() -> void:
	_profile = load(PROFILE_PATH)
	var slots := {"normal": _profile.normal_frames, "cross": _profile.cross_frames, "armoured": _profile.armoured_frames}
	var by_path: Dictionary = {}
	for slot: String in ["normal", "cross", "armoured"]:
		var fr: SpriteFrames = slots[slot]
		var p := fr.resource_path
		if not by_path.has(p):
			var sheet_path := p.replace("_frames.tres", "_sheet.json")
			var sheet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(sheet_path))
			by_path[p] = {"path": p, "frames": fr, "slots": [], "sheet": sheet, "sheet_json": sheet_path}
			_costumes.append(by_path[p])
		(by_path[p]["slots"] as Array).append(slot)
	for c: Dictionary in _costumes:
		var s: Array = c["slots"]
		c["key"] = "armoured" if s.has("armoured") else String(s[0])
		c["label"] = " / ".join(PackedStringArray(s))
	var order: Array = (_costumes[0]["sheet"] as Dictionary)["anim_order"]
	for a: Variant in order:
		_actions.append(String(a))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	for list_key: String in ["copies", "outputs", "generated"]:
		for e: Dictionary in (manifest[list_key] as Array):
			_manifest_sha[String(e["target"])] = String(e["sha256"])
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AUDIO_FIXTURE_PATH))
	var decoded: Dictionary = fixture["decoded_48k"]
	var synth: Dictionary = fixture["synth"]
	var synth_cues: Dictionary = synth["cues"]
	for k in AUDIO_ITEMS.size():
		var row: Array = AUDIO_ITEMS[k]
		var cue := String(row[0])
		var kind := String(row[1])
		var path: String = AudioService.MUSIC[StringName(cue)] if kind == "music" else AudioService.cue_path(StringName(cue))
		var it := {"order": k + 1, "cue": cue, "kind": kind, "provenance": String(row[2]), "source": String(row[3]),
			"use": String(row[4]), "path": path, "bus": "Music" if kind == "music" else "SFX",
			"aud_ids": "AUD-001-004" if row[2] == "recorded" else "AUD-005-008"}
		var info: Dictionary = _wav_info(path) if path.ends_with(".wav") else _mp3_info(path)
		it.merge(info)
		var stream: AudioStream = load(path)
		it["loads"] = stream != null
		it["duration_s"] = snappedf(stream.get_length(), 0.001) if stream != null else 0.0
		if kind == "music":
			it["game_gain"] = snappedf(AudioService.music_level(StringName(cue)), 0.0001)
			it["game_start_s"] = 0.0
		else:
			it["game_gain"] = snappedf(GameConfig.Audio.SFX_VOLUME * float(GameConfig.Audio.FILE_GAIN.get(cue, 1.0)), 0.0001)
			it["game_start_s"] = snappedf(float(AudioService.offsets.get(StringName(cue), 0.0)), 0.00001)
		var rel := path.trim_prefix("res://")
		it["sha256"] = FileAccess.get_sha256(path)
		it["manifest_sha256"] = String(_manifest_sha.get(rel, ""))
		it["bytes"] = FileAccess.get_file_as_bytes(path).size()
		if row[2] == "recorded":
			var src := _fixture_source(fixture, cue, kind)
			var d: Dictionary = decoded.get(src, {})
			it["source_file"] = src
			it["fixture_duration_s"] = float(d.get("duration", 0.0))
			it["fixture_channels"] = int(d.get("channels", 0))
		elif cue == "medieval":
			var m: Dictionary = (synth["music"] as Dictionary)["medieval"]
			it["fixture_duration_s"] = snappedf(float(m["duration"]), 0.001)
		else:
			var sc: Dictionary = synth_cues[cue]
			it["fixture_duration_s"] = snappedf(float(sc["duration"]), 0.001)
		_audio.append(it)
	_title_json = JSON.parse_string(FileAccess.get_file_as_string(TITLE_JSON_PATH))


func _fixture_source(fixture: Dictionary, cue: String, kind: String) -> String:
	var table: Dictionary = fixture["music_files"] if kind == "music" else fixture["sound_files"]
	return String(table.get(cue, ""))


func _build_fields() -> void:
	for c: Dictionary in _costumes:
		for a in _actions:
			for d: String in DIRS:
				_add_field("A-%s-%s-%s" % [c["key"], a, d], "A", "A-%s-%s" % [c["key"], a], "%s %s %s" % [c["key"], a, d.to_upper()])
	_add_field("A-FILTER", "A", "A", FILTER_LABEL)
	for it: Dictionary in _audio:
		for o: Array in AUDIO_OBS:
			_add_field("B-%s-%s" % [it["cue"], o[0]], "B", "B-" + String(it["cue"]), String(o[1]))
	_add_field("B-MUTE", "B", "B", MUTE_LABEL)
	_add_field("B-VOLUME", "B", "B", VOLUME_LABEL)
	for o: Array in TITLE_OBS:
		_add_field(String(o[0]), "C", "C", String(o[1]))


func _add_field(id: String, section: String, group: String, label: String) -> void:
	_fields.append({"id": id, "section": section, "group": group, "label": label})


## WAV header facts (format, channels, rate, bits) read from the file itself.
static func _wav_info(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"format": "unreadable"}
	var head := f.get_buffer(12)
	if head.slice(0, 4).get_string_from_ascii() != "RIFF" or head.slice(8, 12).get_string_from_ascii() != "WAVE":
		return {"format": "not RIFF/WAVE"}
	while f.get_position() + 8 <= f.get_length():
		var id := f.get_buffer(4).get_string_from_ascii()
		var size := f.get_32()
		if id == "fmt ":
			var fmt := f.get_16()
			var channels := f.get_16()
			var rate := f.get_32()
			f.seek(f.get_position() + 6)
			var bits := f.get_16()
			return {"format": "WAV PCM" if fmt == 1 else "WAV format %d" % fmt, "channels": channels, "sample_rate": rate, "bits": bits}
		f.seek(f.get_position() + size + (size & 1))
	return {"format": "WAV without fmt chunk"}


## MP3 facts (MPEG version and layer, channels, rate) from the first frame header after any ID3v2 tag.
static func _mp3_info(path: String) -> Dictionary:
	var b := FileAccess.get_file_as_bytes(path)
	var i := 0
	if b.size() > 10 and b.slice(0, 3).get_string_from_ascii() == "ID3":
		i = 10 + ((b[6] & 0x7f) << 21 | (b[7] & 0x7f) << 14 | (b[8] & 0x7f) << 7 | (b[9] & 0x7f))
	var rates: Array[int] = [44100, 48000, 32000]
	while i + 4 <= b.size():
		if b[i] == 0xFF and (b[i + 1] & 0xE0) == 0xE0:
			var version := (b[i + 1] >> 3) & 3
			var layer := (b[i + 1] >> 1) & 3
			var bitrate := (b[i + 2] >> 4) & 15
			var rate_index := (b[i + 2] >> 2) & 3
			if version != 1 and layer != 0 and rate_index != 3 and bitrate != 15 and bitrate != 0:
				var rate := rates[rate_index]
				if version == 2:
					rate = rate >> 1
				elif version == 0:
					rate = rate >> 2
				var names := {3: "MPEG-1", 2: "MPEG-2", 0: "MPEG-2.5"}
				return {"format": "%s layer %d" % [names[version], 4 - layer], "channels": 1 if ((b[i + 3] >> 6) & 3) == 3 else 2, "sample_rate": rate}
		i += 1
	return {"format": "MP3 without a frame header"}


func _environment() -> Dictionary:
	var v := Engine.get_version_info()
	return {
		"os": "%s %s" % [OS.get_name(), OS.get_version()],
		"godot": String(v["string"]),
		"adapter": "%s (%s)" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor()],
		"renderer": "%s / %s %s" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_video_adapter_api_version()],
		"screen": "%s at %.0f Hz, scale %.2f" % [str(DisplayServer.screen_get_size()), DisplayServer.screen_get_refresh_rate(), DisplayServer.screen_get_scale()],
		"audio": "%s, output device '%s', %d Hz" % [AudioServer.get_driver_name(), AudioServer.get_output_device(), int(AudioServer.get_mix_rate())],
	}


# --- Window and UI --------------------------------------------------------------------------------

func _setup_window() -> void:
	var w := get_window()
	w.title = "SUPERVILLAINED - M1 manual review (development tool)"
	var usable := DisplayServer.screen_get_usable_rect()
	var size_wanted := Vector2i(mini(1320, usable.size.x), mini(900, usable.size.y))
	w.size = size_wanted
	w.position = usable.position + (usable.size - size_wanted) / 2
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#1d1d24")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 8
	root.offset_top = 8
	root.offset_right = -8
	root.offset_bottom = -8
	add_child(root)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.focus_mode = Control.FOCUS_NONE
	root.add_child(_tabs)
	_tabs.add_child(_build_animation_tab())
	_tabs.add_child(_build_audio_tab())
	_tabs.add_child(_build_title_tab())
	_tabs.add_child(_build_signoff_tab())
	_tabs.set_tab_title(0, "1 Animations")
	_tabs.set_tab_title(1, "2 Audio")
	_tabs.set_tab_title(2, "3 Title")
	_tabs.set_tab_title(3, "4 Sign-off")
	_tabs.tab_changed.connect(_on_tab_changed)
	_status = _lbl("")
	root.add_child(_status)


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _lbl(text: String, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _picker(on_pick: Callable) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	for d in DECISIONS:
		o.add_item(d)
	o.item_selected.connect(on_pick)
	return o


func _row(children: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	for c: Control in children:
		h.add_child(c)
	return h


func _build_animation_tab() -> Control:
	var root := HBoxContainer.new()
	_anim_list = ItemList.new()
	_anim_list.custom_minimum_size = Vector2(250, 0)
	_anim_list.focus_mode = Control.FOCUS_NONE
	for c: Dictionary in _costumes:
		for a in _actions:
			_anim_list.add_item("%s %s" % [c["key"], a])
	_anim_list.item_selected.connect(_select_anim)
	root.add_child(_anim_list)
	_stage = ColorRect.new()
	_stage.color = BACKGROUNDS[0]
	_stage.custom_minimum_size = Vector2(CELL * 3, CELL * 3)
	_stage.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.add_child(_stage)
	for d: String in DIRS:
		var cell: Vector2i = DIR_CELL[d]
		var origin := Vector2(cell.x * CELL, cell.y * CELL)
		var s := AnimatedSprite2D.new()
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
		# Foot anchor (20, 36) of the 40x40 frame on the cell's foot point.
		s.position = origin + Vector2(CELL / 2.0 - 20 * SPRITE_SCALE, 116 - 36 * SPRITE_SCALE)
		_stage.add_child(s)
		_sprites[d] = s
		var l := _lbl("")
		l.position = origin + Vector2(6, 118)
		_stage.add_child(l)
		_dir_labels[d] = l
		var p := _picker(func(i: int) -> void: _set_decision(_anim_field(d), DECISIONS[i]))
		p.position = origin + Vector2(6, 142)
		p.size = Vector2(CELL - 12, 28)
		_stage.add_child(p)
		_dir_pickers[d] = p
	_centre = _lbl("")
	_centre.position = Vector2(CELL + 8, CELL + 8)
	_centre.size = Vector2(CELL - 16, CELL - 16)
	_centre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_centre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_centre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stage.add_child(_centre)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(side)
	_anim_info = RichTextLabel.new()
	_anim_info.bbcode_enabled = true
	_anim_info.fit_content = true
	_anim_info.focus_mode = Control.FOCUS_NONE
	side.add_child(_anim_info)
	side.add_child(_row([_btn("Play / pause [Space]", _toggle_anim), _btn("Replay [R]", _replay_anim)]))
	side.add_child(_row([_btn("< Frame [Left]", func() -> void: _step_anim(-1)), _btn("Frame > [Right]", func() -> void: _step_anim(1))]))
	side.add_child(_row([_btn("< Previous [Up]", func() -> void: _move_anim(-1)), _btn("Next > [Down]", func() -> void: _move_anim(1))]))
	var auto := CheckBox.new()
	auto.text = "Replay one-shot animations automatically"
	auto.button_pressed = true
	auto.focus_mode = Control.FOCUS_NONE
	auto.toggled.connect(func(on: bool) -> void: _auto_replay = on)
	side.add_child(auto)
	side.add_child(_btn("Background: dark / grey / light [B]", _cycle_background))
	side.add_child(_lbl("Each direction cell has its own decision. Notes for this action:", true))
	_anim_notes = LineEdit.new()
	_anim_notes.placeholder_text = "e.g. NE frame 3 faces the wrong way"
	_anim_notes.text_changed.connect(func(t: String) -> void: _set_note(_anim_group(), t))
	side.add_child(_anim_notes)
	side.add_child(_btn("Mark all eight directions PASS", _pass_all_directions))
	side.add_child(_lbl("Whole section, after every animation:", true))
	side.add_child(_lbl(FILTER_LABEL, true))
	_filter_picker = _picker(func(i: int) -> void: _set_decision("A-FILTER", DECISIONS[i]))
	_pickers_by_id["A-FILTER"] = _filter_picker
	side.add_child(_filter_picker)
	return root


func _build_audio_tab() -> Control:
	var root := HBoxContainer.new()
	_audio_list = ItemList.new()
	_audio_list.custom_minimum_size = Vector2(300, 0)
	_audio_list.focus_mode = Control.FOCUS_NONE
	for it: Dictionary in _audio:
		_audio_list.add_item("%02d %s %s" % [it["order"], it["cue"], it["provenance"]])
	_audio_list.item_selected.connect(_select_audio)
	root.add_child(_audio_list)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(side)
	side.add_child(_lbl("Before the first sound: set the computer's own volume low. The station starts at 25 % master volume. Audio pauses while this window is not focused, like the game.", true))
	_audio_info = RichTextLabel.new()
	_audio_info.bbcode_enabled = true
	_audio_info.fit_content = true
	_audio_info.focus_mode = Control.FOCUS_NONE
	side.add_child(_audio_info)
	side.add_child(_row([_btn("Play, game path [Enter]", func() -> void: _play_audio("game")), _btn("Play raw file from 0 s [W]", func() -> void: _play_audio("raw")),
		_btn("Music: last 6 s and loop [L]", func() -> void: _play_audio("seam"))]))
	side.add_child(_row([_btn("Stop [S]", _stop_audio), _btn("Replay [R]", func() -> void: _play_audio(_last_mode)),
		_btn("< Previous [Up]", func() -> void: _move_audio(-1)), _btn("Next > [Down]", func() -> void: _move_audio(1))]))
	_mute_box = CheckBox.new()
	_mute_box.text = "Mute [M]"
	_mute_box.focus_mode = Control.FOCUS_NONE
	_mute_box.toggled.connect(func(_on: bool) -> void: _apply_volume())
	_volume = HSlider.new()
	_volume.min_value = 0
	_volume.max_value = 100
	_volume.step = 1
	_volume.value = SAFE_VOLUME * 100.0
	_volume.custom_minimum_size = Vector2(240, 0)
	_volume.focus_mode = Control.FOCUS_NONE
	_volume.value_changed.connect(func(_v: float) -> void: _apply_volume())
	_volume_label = _lbl("")
	side.add_child(_row([_mute_box, _lbl("   Master volume"), _volume, _volume_label]))
	_audio_pos = _lbl("")
	side.add_child(_audio_pos)
	var grid := GridContainer.new()
	grid.columns = 2
	for o: Array in AUDIO_OBS:
		var obs := String(o[0])
		grid.add_child(_lbl(String(o[1])))
		var p := _picker(func(i: int) -> void: _set_decision("B-%s-%s" % [_audio[_audio_index]["cue"], obs], DECISIONS[i]))
		_audio_pickers[obs] = p
		grid.add_child(p)
	side.add_child(grid)
	_audio_notes = LineEdit.new()
	_audio_notes.placeholder_text = "Notes for this sound"
	_audio_notes.text_changed.connect(func(t: String) -> void: _set_note("B-" + String(_audio[_audio_index]["cue"]), t))
	side.add_child(_audio_notes)
	side.add_child(_btn("Mark all five observations PASS", _pass_all_audio))
	var g2 := GridContainer.new()
	g2.columns = 2
	for pair: Array in [["B-MUTE", MUTE_LABEL], ["B-VOLUME", VOLUME_LABEL]]:
		var id := String(pair[0])
		g2.add_child(_lbl("Whole section: " + String(pair[1])))
		var p := _picker(func(i: int) -> void: _set_decision(id, DECISIONS[i]))
		_pickers_by_id[id] = p
		g2.add_child(p)
	side.add_child(g2)
	_raw = AudioStreamPlayer.new()
	add_child(_raw)
	return root


func _build_title_tab() -> Control:
	var root := VBoxContainer.new()
	var cont := SubViewportContainer.new()
	cont.stretch = true
	cont.stretch_shrink = 2
	cont.custom_minimum_size = Vector2(TITLE_SIZE * 2)
	cont.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cont.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var vp := SubViewport.new()
	vp.size = TITLE_SIZE
	cont.add_child(vp)
	var bg := ColorRect.new()
	bg.color = TITLE_BG
	bg.size = Vector2(TITLE_SIZE)
	vp.add_child(bg)
	for k in TITLE_WIDTHS.size():
		var p := TitlePortrait.new()
		vp.add_child(p)
		p.fit_width(float(TITLE_WIDTHS[k]))
		p.position = Vector2(8 + k * (126 + 8), 8)
		_portraits.append(p)
	root.add_child(cont)
	var widths := PackedStringArray()
	for k in TITLE_WIDTHS.size():
		widths.append("%d px wide (view %d px)" % [TITLE_WIDTHS[k], TITLE_VIEWS[k]])
	root.add_child(_lbl("Left to right: " + ", ".join(widths) + "; shown at x2 like the game."))
	root.add_child(_row([_btn("Play / pause [Space]", _toggle_title), _btn("Replay [R]", _replay_title),
		_btn("< Frame [Left]", func() -> void: _step_title(-1)), _btn("Frame > [Right]", func() -> void: _step_title(1)),
		_btn("First [1]", func() -> void: _jump_title(0)), _btn("Middle [2]", func() -> void: _jump_title(_title_middle())),
		_btn("Last [3]", func() -> void: _jump_title(_title_count() - 1))]))
	_title_info = _lbl("")
	root.add_child(_title_info)
	var grid := GridContainer.new()
	grid.columns = 2
	for o: Array in TITLE_OBS:
		var id := String(o[0])
		grid.add_child(_lbl(String(o[1])))
		var p := _picker(func(i: int) -> void: _set_decision(id, DECISIONS[i]))
		_pickers_by_id[id] = p
		grid.add_child(p)
	root.add_child(grid)
	_title_notes = LineEdit.new()
	_title_notes.placeholder_text = "Notes for the title"
	_title_notes.text_changed.connect(func(t: String) -> void: _set_note("C", t))
	root.add_child(_title_notes)
	return root


func _build_signoff_tab() -> Control:
	var root := VBoxContainer.new()
	root.add_child(_lbl("Fill these in, then choose the final decision. APPROVED is possible only when every field of sections 1-3 is PASS.", true))
	var grid := GridContainer.new()
	grid.columns = 2
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size = Vector2(520, 0)
	_name_edit.text_changed.connect(func(t: String) -> void: _set_owner("name", t))
	_date_edit = LineEdit.new()
	_date_edit.text_changed.connect(func(t: String) -> void: _set_owner("date", t))
	_equipment_edit = LineEdit.new()
	_equipment_edit.placeholder_text = "e.g. laptop speakers; 27-inch monitor"
	_equipment_edit.text_changed.connect(func(t: String) -> void: _set_owner("equipment", t))
	_final_picker = OptionButton.new()
	_final_picker.focus_mode = Control.FOCUS_NONE
	for f in FINALS:
		_final_picker.add_item(f)
	_final_picker.item_selected.connect(_on_final)
	for pair: Array in [["Owner name", _name_edit], ["Date", _date_edit], ["Listening equipment and display", _equipment_edit], ["Final M1 manual decision", _final_picker]]:
		grid.add_child(_lbl(String(pair[0])))
		grid.add_child(pair[1] as Control)
	root.add_child(grid)
	var env := PackedStringArray()
	for k: String in _env:
		env.append("%s: %s" % [k, _env[k]])
	root.add_child(_lbl("Environment (recorded automatically):\n" + "\n".join(env), true))
	_summary = _lbl("", true)
	root.add_child(_summary)
	root.add_child(_row([_btn("Save now", _save), _btn("Open the decisions folder", func() -> void: OS.shell_open(ProjectSettings.globalize_path(_decisions_dir)))]))
	return root


# --- Animations -----------------------------------------------------------------------------------

func _anim_costume() -> Dictionary:
	return _costumes[floori(float(_anim_index) / _actions.size())]


func _anim_action() -> String:
	return _actions[_anim_index % _actions.size()]


func _anim_group() -> String:
	return "A-%s-%s" % [_anim_costume()["key"], _anim_action()]


func _anim_field(d: String) -> String:
	return "%s-%s" % [_anim_group(), d]


func _select_anim(i: int) -> void:
	_anim_index = clampi(i, 0, _anim_list.item_count - 1)
	_anim_list.select(_anim_index)
	_anim_list.ensure_current_is_visible()
	var frames: SpriteFrames = _anim_costume()["frames"]
	for d: String in DIRS:
		var s: AnimatedSprite2D = _sprites[d]
		s.sprite_frames = frames
		s.play(StringName("%s_%s" % [_anim_action(), d]))
		if _anim_paused:
			s.pause()
	_hold = 0.0
	_refresh_anim()


func _move_anim(step: int) -> void:
	_select_anim(_anim_index + step)


func _toggle_anim() -> void:
	_anim_paused = not _anim_paused
	for d: String in DIRS:
		var s: AnimatedSprite2D = _sprites[d]
		if _anim_paused:
			s.pause()
		else:
			s.play()


func _replay_anim() -> void:
	_anim_paused = false
	_hold = 0.0
	for d: String in DIRS:
		var s: AnimatedSprite2D = _sprites[d]
		var a := s.animation
		s.stop()
		s.play(a)


func _step_anim(step: int) -> void:
	_anim_paused = true
	var first: AnimatedSprite2D = _sprites[DIRS[0]]
	var n := first.sprite_frames.get_frame_count(first.animation)
	var f := posmod(first.frame + step, n)
	for d: String in DIRS:
		var s: AnimatedSprite2D = _sprites[d]
		s.pause()
		s.frame = f


func _cycle_background() -> void:
	_bg_index = (_bg_index + 1) % BACKGROUNDS.size()
	_stage.color = BACKGROUNDS[_bg_index]
	var dark := _bg_index == 0
	for d: String in DIRS:
		(_dir_labels[d] as Label).add_theme_color_override("font_color", Color.WHITE if dark else Color.BLACK)
	_centre.add_theme_color_override("font_color", Color.WHITE if dark else Color.BLACK)


func _pass_all_directions() -> void:
	for d: String in DIRS:
		_set_decision(_anim_field(d), "PASS")


static func _frame_ms(frames: SpriteFrames, anim: StringName, idx: int) -> float:
	return frames.get_frame_duration(anim, idx) / frames.get_animation_speed(anim) * 1000.0


static func _fmt_ms(ms: float) -> String:
	return str(snappedf(ms, 0.01))


func _anim_frame_list(frames: SpriteFrames, anim: StringName) -> PackedStringArray:
	var out := PackedStringArray()
	for k in frames.get_frame_count(anim):
		out.append(_fmt_ms(_frame_ms(frames, anim, k)))
	return out


func _refresh_anim() -> void:
	var c := _anim_costume()
	var frames: SpriteFrames = c["frames"]
	var a := _anim_action()
	var first := StringName("%s_%s" % [a, DIRS[0]])
	var n := frames.get_frame_count(first)
	var loop := frames.get_animation_loop(first)
	var total := 0.0
	for k in n:
		total += _frame_ms(frames, first, k)
	var atlas := (frames.get_frame_texture(first, 0) as AtlasTexture).atlas.resource_path
	_centre.text = "%s\n%s\n%d frames, %s\ncycle %s ms" % [c["key"], a, n, "loop" if loop else "one-shot", _fmt_ms(total)]
	_anim_info.text = ("[b]Costume[/b] %s (profile slots: %s)\n[b]Resource[/b] %s\n[b]Sheet[/b] %s\n[b]Animations[/b] %s_<direction>, directions %s\n"
		+ "[b]Playback[/b] %s, %d frames, speed %s\n[b]Authored frame durations (ms)[/b] %s\n[b]Cycle[/b] %s ms; profile action duration %s s\n"
		+ "Item %d of %d. Each cell shows: direction, frame number / frame count, the frame's authored duration.") % [
		c["key"], c["label"], c["path"], atlas, a, " ".join(PackedStringArray(DIRS)).to_upper(),
		"loops" if loop else "one-shot (holds the last frame)", n, str(frames.get_animation_speed(first)),
		", ".join(_anim_frame_list(frames, first)), _fmt_ms(total), str(_profile.action_durations.get(a, "-")),
		_anim_index + 1, _anim_list.item_count]
	_loading = true
	for d: String in DIRS:
		(_dir_pickers[d] as OptionButton).select(DECISIONS.find(String(_decisions[_anim_field(d)])))
	_anim_notes.text = String(_notes.get(_anim_group(), ""))
	_loading = false


func _process_anim(delta: float) -> void:
	var one_shot_done := true
	for d: String in DIRS:
		var s: AnimatedSprite2D = _sprites[d]
		if s.sprite_frames == null:
			return
		var n := s.sprite_frames.get_frame_count(s.animation)
		(_dir_labels[d] as Label).text = "%s  %d/%d  %s ms" % [d.to_upper(), s.frame + 1, n, _fmt_ms(_frame_ms(s.sprite_frames, s.animation, s.frame))]
		if s.is_playing() or s.sprite_frames.get_animation_loop(s.animation) or s.frame != n - 1:
			one_shot_done = false
	if one_shot_done and _auto_replay and not _anim_paused:
		_hold += delta
		if _hold >= ONE_SHOT_HOLD:
			_replay_anim()


# --- Audio ----------------------------------------------------------------------------------------

func _select_audio(i: int) -> void:
	_audio_index = clampi(i, 0, _audio.size() - 1)
	_audio_list.select(_audio_index)
	_audio_list.ensure_current_is_visible()
	var it := _audio[_audio_index]
	var lines := PackedStringArray([
		"[b]%s[/b] (%s %s, %s)" % [it["cue"], it["provenance"], it["kind"], it["aud_ids"]],
		"[b]Resource[/b] %s" % it["path"],
		"[b]File[/b] %s, %s channel(s), %s Hz%s, %s s, %d bytes" % [it["format"], it["channels"], it["sample_rate"], (", %s bit" % it["bits"]) if it.has("bits") else "", it["duration_s"], it["bytes"]],
		"[b]Expected use[/b] %s" % it["use"],
		"[b]Source[/b] %s" % it["source"],
		"[b]Game path[/b] %s bus, gain %s, starts at %s s%s" % [it["bus"], it["game_gain"], it["game_start_s"], " (leading silence skipped)" if float(it["game_start_s"]) > 0.0 else ""],
	])
	_audio_info.text = "\n".join(lines)
	_loading = true
	for o: Array in AUDIO_OBS:
		(_audio_pickers[String(o[0])] as OptionButton).select(DECISIONS.find(String(_decisions["B-%s-%s" % [it["cue"], o[0]]])))
	_audio_notes.text = String(_notes.get("B-" + String(it["cue"]), ""))
	_loading = false


func _move_audio(step: int) -> void:
	_stop_audio()
	_select_audio(_audio_index + step)


func _play_audio(mode: String) -> void:
	_stop_audio()
	var it := _audio[_audio_index]
	var cue := StringName(String(it["cue"]))
	var music: bool = it["kind"] == "music"
	if mode == "seam" and not music:
		mode = "raw"
	_last_mode = mode
	if mode == "game":
		if music:
			AudioService.track_positions.erase(cue)
			AudioService.play_music(cue)
		else:
			AudioService.play(cue)
		return
	var stream: AudioStream = load(String(it["path"]))
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = music
	_raw.stream = stream
	_raw.bus = StringName(String(it["bus"]))
	_raw.volume_db = linear_to_db(float(it["game_gain"]))
	_raw.play(maxf(0.0, stream.get_length() - 6.0) if mode == "seam" else 0.0)


func _stop_audio() -> void:
	AudioService.stop_all()
	_raw.stop()


func _apply_volume() -> void:
	AudioService.apply_settings(_mute_box.button_pressed, _volume.value / 100.0)
	_volume_label.text = "%d %%" % int(_volume.value)


func _pass_all_audio() -> void:
	for o: Array in AUDIO_OBS:
		_set_decision("B-%s-%s" % [_audio[_audio_index]["cue"], o[0]], "PASS")


func _process_audio() -> void:
	var it := _audio[_audio_index]
	var pos := -1.0
	var source := ""
	if _raw.playing:
		pos = _raw.get_playback_position()
		source = "raw file"
	else:
		var path := String(it["path"])
		for p: AudioStreamPlayer in AudioService.players():
			if p.playing and p.stream != null and p.stream.resource_path == path:
				pos = p.get_playback_position()
				source = "game path"
	if pos < 0.0:
		_audio_pos.text = "Stopped. Muted: %s. Suspended: %s." % [str(AudioService.muted), str(AudioService.suspended)]
	else:
		_audio_pos.text = "Playing (%s): %.2f s of %.2f s" % [source, pos, float(it["duration_s"])]


# --- Title ----------------------------------------------------------------------------------------

func _title_count() -> int:
	return _portraits[0].sprite_frames.get_frame_count(&"portrait")


## The middle frame as tools/title_capture.gd picks it (n / 2, 49 of 99).
func _title_middle() -> int:
	return floori(_title_count() / 2.0)


func _title_ms(idx: int) -> float:
	return _frame_ms(_portraits[0].sprite_frames, &"portrait", idx)


func _toggle_title() -> void:
	_title_paused = not _title_paused
	for p in _portraits:
		if _title_paused:
			p.pause()
		else:
			p.play()


func _replay_title() -> void:
	_title_paused = false
	for p in _portraits:
		p.stop()
		p.play(&"portrait")
	_title_cycle_start = Time.get_ticks_usec()


func _step_title(step: int) -> void:
	_jump_title(posmod(_portraits[0].frame + step, _title_count()))


func _jump_title(idx: int) -> void:
	_title_paused = true
	for p in _portraits:
		p.pause()
		p.frame = idx


func _process_title() -> void:
	var f := _portraits[0].frame
	if f == 0 and _title_last_frame == _title_count() - 1:
		var now := Time.get_ticks_usec()
		if _title_cycle_start > 0:
			_title_measured = (now - _title_cycle_start) / 1000000.0
		_title_cycle_start = now
	_title_last_frame = f
	var total := 0.0
	var before := 0.0
	for k in _title_count():
		if k < f:
			before += _title_ms(k)
		total += _title_ms(k)
	_title_info.text = "Frame %d of %d (index %d), authored delay %s ms, starts at %s ms of an authored %s ms cycle. %s Last measured cycle: %s s." % [
		f + 1, _title_count(), f, _fmt_ms(_title_ms(f)), _fmt_ms(before), _fmt_ms(total), "Paused." if _title_paused else "Playing.",
		"-" if _title_measured == 0.0 else str(snappedf(_title_measured, 0.001))]


# --- Decisions ------------------------------------------------------------------------------------

func _set_decision(id: String, value: String) -> void:
	if _loading or not _decisions.has(id):
		return
	_decisions[id] = value
	if _pickers_by_id.has(id):
		_loading = true
		(_pickers_by_id[id] as OptionButton).select(DECISIONS.find(value))
		_loading = false
	_after_change()


func _set_note(group: String, text: String) -> void:
	if _loading:
		return
	_notes[group] = text
	_after_change()


func _set_owner(key: String, text: String) -> void:
	if _loading:
		return
	_owner_info[key] = text
	_after_change()


func _on_final(i: int) -> void:
	if _loading:
		return
	if FINALS[i] == "APPROVED" and _count("PASS") != _fields.size():
		_loading = true
		_final_picker.select(FINALS.find(String(_owner_info["final"])))
		_loading = false
		_status.text = "APPROVED needs every field PASS: %d of %d are PASS." % [_count("PASS"), _fields.size()]
		return
	_owner_info["final"] = FINALS[i]
	_after_change()


func _after_change() -> void:
	if _owner_info["final"] == "APPROVED" and _count("PASS") != _fields.size():
		_owner_info["final"] = "NOT DECIDED"
	_refresh_all()
	_save()


func _count(value: String) -> int:
	var n := 0
	for id: String in _decisions:
		if _decisions[id] == value:
			n += 1
	return n


func _refresh_all() -> void:
	_loading = true
	for id: String in _pickers_by_id:
		(_pickers_by_id[id] as OptionButton).select(DECISIONS.find(String(_decisions[id])))
	for d: String in DIRS:
		(_dir_pickers[d] as OptionButton).select(DECISIONS.find(String(_decisions[_anim_field(d)])))
	for o: Array in AUDIO_OBS:
		(_audio_pickers[String(o[0])] as OptionButton).select(DECISIONS.find(String(_decisions["B-%s-%s" % [_audio[_audio_index]["cue"], o[0]]])))
	if _name_edit.text != _owner_info["name"]:
		_name_edit.text = String(_owner_info["name"])
	if _owner_info["date"] == "":
		_owner_info["date"] = Time.get_date_string_from_system()
	if _date_edit.text != _owner_info["date"]:
		_date_edit.text = String(_owner_info["date"])
	if _equipment_edit.text != _owner_info["equipment"]:
		_equipment_edit.text = String(_owner_info["equipment"])
	_final_picker.select(FINALS.find(String(_owner_info["final"])))
	_loading = false
	for k in _anim_list.item_count:
		var c: Dictionary = _costumes[floori(float(k) / _actions.size())]
		var group := "A-%s-%s" % [c["key"], _actions[k % _actions.size()]]
		_anim_list.set_item_text(k, "%s %s   %s" % [c["key"], _actions[k % _actions.size()], _tag(group)])
	for k in _audio.size():
		var it := _audio[k]
		_audio_list.set_item_text(k, "%02d %s (%s)   %s" % [it["order"], it["cue"], it["provenance"], _tag("B-" + String(it["cue"]))])
	# Export mode saves nothing and shows no local path (its screen captures are committed).
	var where := "export mode: nothing is saved" if _export_dir != "" else "saved to " + ProjectSettings.globalize_path(_decisions_dir)
	_summary.text = "Fields: %d. PASS %d, FAIL %d, NOT EXECUTED %d. Final decision: %s.\nDecisions: %s" % [
		_fields.size(), _count("PASS"), _count("FAIL"), _count("NOT EXECUTED"), _owner_info["final"], where]
	_status.text = "PASS %d  FAIL %d  NOT EXECUTED %d  of %d fields   |   %s" % [_count("PASS"), _count("FAIL"), _count("NOT EXECUTED"), _fields.size(), where]


## Progress tag of a group: "-" (nothing decided), "n/m PASS", or "FAIL" when any field failed.
func _tag(group: String) -> String:
	var total := 0
	var passed := 0
	for f: Dictionary in _fields:
		if f["group"] != group:
			continue
		total += 1
		var v := String(_decisions[f["id"]])
		if v == "FAIL":
			return "FAIL"
		if v == "PASS":
			passed += 1
	return "-" if passed == 0 else "%d/%d PASS" % [passed, total]


func _load_decisions() -> void:
	var path := _decisions_dir.path_join("m1_owner_decisions.json")
	if not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary):
		push_warning("m1_review: %s is not a decisions file; starting empty" % path)
		return
	var d: Dictionary = data
	var saved: Dictionary = d.get("decisions", {})
	for id: String in saved:
		if _decisions.has(id) and DECISIONS.has(String(saved[id])):
			_decisions[id] = String(saved[id])
	var notes: Dictionary = d.get("notes", {})
	for g: String in notes:
		_notes[g] = String(notes[g])
	var o: Dictionary = d.get("owner", {})
	for k: String in ["name", "date", "equipment", "final"]:
		if o.has(k):
			_owner_info[k] = String(o[k])


func _save() -> void:
	if _export_dir != "":
		return
	DirAccess.make_dir_recursive_absolute(_decisions_dir)
	var data := {
		"tool": "res://tools/m1_review.gd",
		"saved_at": Time.get_datetime_string_from_system(),
		"environment": _env,
		"owner": _owner_info,
		"decisions": _decisions,
		"notes": _notes,
		"summary": {"PASS": _count("PASS"), "FAIL": _count("FAIL"), "NOT EXECUTED": _count("NOT EXECUTED"), "fields": _fields.size()},
	}
	_write(_decisions_dir.path_join("m1_owner_decisions.json"), JSON.stringify(data, "  ", true) + "\n")
	_write(_decisions_dir.path_join("m1_owner_decisions.md"), _markdown(false))


static func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("m1_review: cannot write %s" % path)
		return
	f.store_string(text)


static func _md(text: String) -> String:
	return text.replace("|", "\\|").replace("\n", " ")


## The checklist: blank (every field NOT EXECUTED, no owner data) or the current decisions.
func _markdown(blank: bool) -> String:
	var dec := func(id: String) -> String: return "NOT EXECUTED" if blank else String(_decisions[id])
	var note := func(group: String) -> String: return "" if blank else _md(String(_notes.get(group, "")))
	var o := PackedStringArray()
	o.append("# M1 manual checklist (SUPERVILLAINED Godot port)")
	o.append("")
	o.append("Generated by `res://tools/m1_review.gd`: `--export` writes this blank copy; the review station saves the owner's filled copy as `m1_owner_decisions.md` (with `m1_owner_decisions.json`). Every field is PASS, FAIL or NOT EXECUTED and is set only by the human reviewer; automated facts are in `animation_inventory.json`, `audio_inventory.json` and `title_facts.json` and are not decisions.")
	o.append("")
	o.append("## Owner sign-off")
	o.append("")
	o.append("| Field | Value |")
	o.append("|---|---|")
	o.append("| Owner name | %s |" % ("" if blank else _md(String(_owner_info["name"]))))
	o.append("| Date | %s |" % ("" if blank else _md(String(_owner_info["date"]))))
	if blank:
		o.append("| Environment | recorded automatically by the review station when the owner saves |")
	else:
		for k: String in _env:
			o.append("| Environment: %s | %s |" % [k, _md(String(_env[k]))])
	o.append("| Listening equipment and display | %s |" % ("" if blank else _md(String(_owner_info["equipment"]))))
	o.append("| Final M1 manual decision (APPROVED only when every field is PASS) | %s |" % ("NOT DECIDED" if blank else String(_owner_info["final"])))
	o.append("")
	o.append("Fields: %d (animations %d, audio %d, title %d)." % [_fields.size(), _section_size("A"), _section_size("B"), _section_size("C")]
		+ ("" if blank else " PASS %d, FAIL %d, NOT EXECUTED %d." % [_count("PASS"), _count("FAIL"), _count("NOT EXECUTED")]))
	o.append("")
	o.append("## A. Zampanò animations (editor preview of every animation and direction at nearest filtering)")
	o.append("")
	o.append("A cell's field ID is `A-<costume>-<action>-<direction>` (for example `A-normal-idle-n`). Observation per cell: the animation plays at its authored frame timing, faces the right way, and has no blank, wrong or jumping frame.")
	for c: Dictionary in _costumes:
		var frames: SpriteFrames = c["frames"]
		o.append("")
		o.append("### Costume `%s` (profile slots: %s): `%s`" % [c["key"], c["label"], c["path"]])
		o.append("")
		var head := "| Action | Playback | Authored frame ms |"
		var rule := "|---|---|---|"
		for d: String in DIRS:
			head += " %s |" % d.to_upper()
			rule += "---|"
		o.append(head + " Notes |")
		o.append(rule + "---|")
		for a in _actions:
			var first := StringName("%s_n" % a)
			var line := "| %s | %s, %d frames | %s |" % [a, "loop" if frames.get_animation_loop(first) else "one-shot", frames.get_frame_count(first), ", ".join(_anim_frame_list(frames, first))]
			for d: String in DIRS:
				line += " %s |" % dec.call("A-%s-%s-%s" % [c["key"], a, d])
			o.append(line + " %s |" % note.call("A-%s-%s" % [c["key"], a]))
	o.append("")
	o.append("| ID | Observation | Decision |")
	o.append("|---|---|---|")
	o.append("| A-FILTER | %s | %s |" % [FILTER_LABEL, dec.call("A-FILTER")])
	o.append("")
	o.append("## B. Audio (AUD-001-008: recorded and generated cues at a safe volume)")
	o.append("")
	o.append("A cell's field ID is `B-<cue>-<observation>`: AUDIBLE (clearly audible at the safe volume), INTENT (right for its expected use), START (no late start or cut attack; recorded effects skip their leading silence in the game), END (ends or loops cleanly; music: loop seam and track switch), CLEAN (no obvious clipping, distortion or artifacts).")
	o.append("")
	o.append("| # | Cue | Provenance | Resource | Format | Ch | Rate (Hz) | Duration (s) | Expected use | AUDIBLE | INTENT | START | END | CLEAN | Notes |")
	o.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	for it: Dictionary in _audio:
		var line := "| %d | %s | %s %s | `%s` | %s | %s | %s | %s | %s |" % [it["order"], it["cue"], it["provenance"], it["kind"], it["path"], it["format"], it["channels"], it["sample_rate"], it["duration_s"], _md(String(it["use"]))]
		for ob: Array in AUDIO_OBS:
			line += " %s |" % dec.call("B-%s-%s" % [it["cue"], ob[0]])
		o.append(line + " %s |" % note.call("B-" + String(it["cue"])))
	o.append("")
	o.append("| ID | Observation | Decision |")
	o.append("|---|---|---|")
	o.append("| B-MUTE | %s | %s |" % [MUTE_LABEL, dec.call("B-MUTE")])
	o.append("| B-VOLUME | %s | %s |" % [VOLUME_LABEL, dec.call("B-VOLUME")])
	o.append("")
	o.append("## C. Title (AST-010 human part)")
	o.append("")
	o.append("| ID | Observation | Decision |")
	o.append("|---|---|---|")
	for ob: Array in TITLE_OBS:
		o.append("| %s | %s | %s |" % [ob[0], ob[1], dec.call(String(ob[0]))])
	o.append("")
	o.append(("Title notes: %s" % note.call("C")).strip_edges(false, true))
	o.append("")
	return "\n".join(o)


func _section_size(section: String) -> int:
	var n := 0
	for f: Dictionary in _fields:
		if f["section"] == section:
			n += 1
	return n


# --- Input and frame loop -------------------------------------------------------------------------

func _on_tab_changed(_tab: int) -> void:
	_stop_audio()


func _process(delta: float) -> void:
	_process_anim(delta)
	_process_audio()
	_process_title()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match _tabs.current_tab:
		0:
			match k.keycode:
				KEY_SPACE: _toggle_anim()
				KEY_R: _replay_anim()
				KEY_LEFT: _step_anim(-1)
				KEY_RIGHT: _step_anim(1)
				KEY_UP: _move_anim(-1)
				KEY_DOWN: _move_anim(1)
				KEY_B: _cycle_background()
				_: return
		1:
			match k.keycode:
				KEY_ENTER, KEY_KP_ENTER: _play_audio("game")
				KEY_W: _play_audio("raw")
				KEY_L: _play_audio("seam")
				KEY_S: _stop_audio()
				KEY_R: _play_audio(_last_mode)
				KEY_UP: _move_audio(-1)
				KEY_DOWN: _move_audio(1)
				KEY_M: _mute_box.button_pressed = not _mute_box.button_pressed
				_: return
		2:
			match k.keycode:
				KEY_SPACE: _toggle_title()
				KEY_R: _replay_title()
				KEY_LEFT: _step_title(-1)
				KEY_RIGHT: _step_title(1)
				KEY_1: _jump_title(0)
				KEY_2: _jump_title(_title_middle())
				KEY_3: _jump_title(_title_count() - 1)
				_: return
		_:
			return
	get_viewport().set_input_as_handled()


# --- Export: inventories, contact sheets, captures, self-checks -----------------------------------

func _run_export() -> void:
	DirAccess.make_dir_recursive_absolute(_export_dir)
	var checks: Array[Dictionary] = []
	_write(_export_dir.path_join("animation_inventory.json"), JSON.stringify(_animation_inventory(checks), "  ", true) + "\n")
	_write(_export_dir.path_join("audio_inventory.json"), JSON.stringify(_audio_inventory(checks), "  ", true) + "\n")
	_write(_export_dir.path_join("title_facts.json"), JSON.stringify(_title_facts(checks), "  ", true) + "\n")
	_write(_export_dir.path_join("M1_MANUAL_CHECKLIST.md"), _markdown(true))
	checks.append({"check": "checklist fields: 192 animation cells + A-FILTER, 32 x 5 audio + B-MUTE + B-VOLUME, 7 title", "ok": _fields.size() == 192 + 1 + 160 + 2 + 7, "value": _fields.size()})
	await _render_contact_sheets()
	await _capture_title_stills()
	await _capture_ui()
	var failed := PackedStringArray()
	for c: Dictionary in checks:
		if not c["ok"]:
			failed.append(String(c["check"]))
	_write(_export_dir.path_join("selftest.json"), JSON.stringify({"checks": checks, "ok": failed.is_empty(), "note": "automated facts only; no manual decision"}, "  ", true) + "\n")
	print("M1REVIEW ", JSON.stringify({"ok": failed.is_empty(), "checks": checks.size(), "failed": failed, "fields": _fields.size()}))
	_stop_audio()
	get_tree().quit(0 if failed.is_empty() else 1)


func _animation_inventory(checks: Array[Dictionary]) -> Dictionary:
	var resources: Array = []
	var total_anims := 0
	var total_frames := 0
	var all_match := true
	var all_regions := true
	for c: Dictionary in _costumes:
		var frames: SpriteFrames = c["frames"]
		var sheet: Dictionary = c["sheet"]
		var sheet_anims: Dictionary = sheet["anims"]
		var anims: Array = []
		var expected := PackedStringArray()
		for a in _actions:
			for d: String in DIRS:
				expected.append("%s_%s" % [a, d])
		var present := PackedStringArray()
		for anim_name in frames.get_animation_names():
			present.append(anim_name)
		present.sort()
		var exp_sorted := expected.duplicate()
		exp_sorted.sort()
		checks.append({"check": "%s: exactly the %d required actions x 8 directions" % [c["path"], _actions.size()], "ok": present == exp_sorted, "value": present.size()})
		for anim_name in expected:
			var anim := StringName(anim_name)
			if not frames.has_animation(anim):
				all_match = false
				continue
			var a := anim_name.substr(0, anim_name.rfind("_"))
			var d := anim_name.substr(anim_name.rfind("_") + 1)
			var n := frames.get_frame_count(anim)
			var ms: Array = []
			var regions: Array = []
			var atlas := ""
			var total := 0.0
			for k in n:
				var t := frames.get_frame_texture(anim, k) as AtlasTexture
				var v := snappedf(_frame_ms(frames, anim, k), 0.001)
				ms.append(v)
				total += v
				if t == null or t.region.size != Vector2(40, 40):
					all_regions = false
				else:
					atlas = t.atlas.resource_path
					regions.append([int(t.region.position.x), int(t.region.position.y), int(t.region.size.x), int(t.region.size.y)])
			var src: Dictionary = sheet_anims[a]
			var src_ms: Array = []
			for k in int(src["frames"]):
				src_ms.append(float((src["frameDurationsMs"] as Array)[k]) if src.has("frameDurationsMs") else 1000.0 / float(src["fps"]))
			var match_src: bool = n == int(src["frames"]) and frames.get_animation_loop(anim) == bool(src["loop"])
			for k in mini(n, src_ms.size()):
				match_src = match_src and absf(float(ms[k]) - float(src_ms[k])) < 0.01
			all_match = all_match and match_src
			anims.append({"name": anim_name, "action": a, "direction": d, "frames": n, "loop": frames.get_animation_loop(anim),
				"speed": frames.get_animation_speed(anim), "frame_ms": ms, "cycle_ms": snappedf(total, 0.001), "atlas": atlas, "regions": regions})
			total_anims += 1
			total_frames += n
		var sheets := {"main": String(sheet["sheet"])}
		var extra: Dictionary = sheet["anim_sheets"]
		for k: String in extra:
			sheets[k] = String(extra[k])
		var sheet_sha := {}
		for k: String in sheets:
			sheet_sha[k] = String(_manifest_sha.get(String(sheets[k]).trim_prefix("res://"), ""))
		resources.append({"key": c["key"], "profile_slots": c["slots"], "path": c["path"], "sheet_json": c["sheet_json"], "sheets": sheets,
			"sheet_sha256_manifest": sheet_sha, "animation_count": anims.size(), "animations": anims})
	checks.append({"check": "every animation's frame count, loop flag and authored per-frame durations equal the source sheet JSON (src/assets/manifest.ts)", "ok": all_match, "value": total_anims})
	checks.append({"check": "every frame is a 40x40 AtlasTexture region", "ok": all_regions, "value": total_frames})
	checks.append({"check": "profile costumes: cross and armoured share the knight resource (AST-006 alias), normal is separate", "ok": _costumes.size() == 2 and _profile.cross_frames == _profile.armoured_frames and _profile.normal_frames != _profile.armoured_frames, "value": _costumes.size()})
	return {
		"profile": {"path": PROFILE_PATH, "id": String(_profile.id), "display_name": _profile.display_name,
			"foot_anchor": [_profile.foot_anchor.x, _profile.foot_anchor.y], "frame_size": [_profile.frame_size.x, _profile.frame_size.y],
			"action_durations_s": _profile.action_durations, "timed_actions": Array(_profile.timed_actions),
			"costume_slots": {"normal": _profile.normal_frames.resource_path, "cross": _profile.cross_frames.resource_path, "armoured": _profile.armoured_frames.resource_path}},
		"required_actions": Array(_actions), "required_actions_source": "anim_order of the costume sheet JSON (src/assets/manifest.ts CHARACTERS)",
		"directions": DIRS, "resources": resources,
		"totals": {"resources": _costumes.size(), "actions": _actions.size(), "directions": DIRS.size(), "animations": total_anims, "frames": total_frames},
		"review": "live in tools/m1_review.tscn (tab 1); these facts do not replace the human decisions A-*",
	}


func _audio_inventory(checks: Array[Dictionary]) -> Dictionary:
	var expected := PackedStringArray()
	for k: StringName in AudioService.MUSIC:
		expected.append(String(k))
	for k: StringName in AudioService.SFX:
		expected.append(String(k))
	for k: StringName in AudioService.SYNTH:
		expected.append(String(k))
	expected.sort()
	var listed := PackedStringArray()
	var counts := {"recorded music": 0, "recorded effect": 0, "generated music": 0, "generated effect": 0}
	var all_load := true
	var hashes := true
	var synth_format := true
	var durations := true
	for it: Dictionary in _audio:
		listed.append(String(it["cue"]))
		var key := "%s %s" % [it["provenance"], it["kind"]]
		counts[key] = int(counts[key]) + 1
		all_load = all_load and bool(it["loads"]) and float(it["duration_s"]) > 0.0
		hashes = hashes and it["sha256"] == it["manifest_sha256"] and String(it["sha256"]) != ""
		if it["provenance"] == "generated":
			synth_format = synth_format and it["format"] == "WAV PCM" and int(it["channels"]) == 1 and int(it["sample_rate"]) == 22050 and int(it["bits"]) == 16
		durations = durations and absf(float(it["duration_s"]) - float(it["fixture_duration_s"])) <= 0.1
	listed.sort()
	checks.append({"check": "the listening list is exactly AudioService's tracks, recorded effects and synth cues", "ok": listed == expected, "value": listed.size()})
	checks.append({"check": "5 recorded tracks, 12 recorded effects, 1 generated loop, 14 generated cues", "ok": counts == {"recorded music": 5, "recorded effect": 12, "generated music": 1, "generated effect": 14}, "value": counts})
	checks.append({"check": "every file loads with a positive length", "ok": all_load, "value": _audio.size()})
	checks.append({"check": "every file's SHA-256 equals the source asset manifest", "ok": hashes, "value": _audio.size()})
	checks.append({"check": "generated cues and loop are mono 22,050 Hz 16-bit PCM WAV", "ok": synth_format, "value": 15})
	checks.append({"check": "Godot stream length within 0.1 s of the source fixture duration", "ok": durations, "value": _audio.size()})
	return {"items": _audio, "counts": counts, "master_volume_at_start": SAFE_VOLUME,
		"review": "listened to in tools/m1_review.tscn (tab 2); these facts do not replace the human decisions B-*"}


func _title_facts(checks: Array[Dictionary]) -> Dictionary:
	var frames: SpriteFrames = _portraits[0].sprite_frames
	var n := frames.get_frame_count(&"portrait")
	var durations: Array = []
	var total := 0.0
	var json_durations: Array = _title_json["durations"]
	var same := json_durations.size() == n
	for k in n:
		var s := frames.get_frame_duration(&"portrait", k) / frames.get_animation_speed(&"portrait")
		durations.append(snappedf(s, 0.000001))
		total += s
		if k < json_durations.size():
			same = same and absf(s - float(json_durations[k])) < 0.000001
	var first := frames.get_frame_texture(&"portrait", 0)
	var w := first.get_width()
	var h := first.get_height()
	var memory := n * w * h * 4
	var pages: Array = _title_json["pages"]
	var pages_ok := true
	for p: Dictionary in pages:
		pages_ok = pages_ok and int(p["w"]) <= 2048 and int(p["h"]) <= 2048
	var cut: float = RenderingServer.shader_get_parameter_default(TitlePortrait.SHADER.get_rid(), &"alpha_cut")
	checks.append({"check": "title: 99 frames", "ok": n == 99, "value": n})
	checks.append({"check": "title: per-frame delays equal title_frames.json", "ok": same, "value": snappedf(total, 0.001)})
	checks.append({"check": "title: frame %dx%d, canonical width 125" % [w, h], "ok": w == 125 and int(_title_json["canonical_width"]) == 125, "value": [w, h]})
	checks.append({"check": "title: atlas pages <= 2048x2048", "ok": pages_ok, "value": pages.size()})
	checks.append({"check": "title: uncompressed frame memory < 12 MB and equal to title_frames.json", "ok": memory < 12 * 1024 * 1024 and memory == int(_title_json["memory_bytes"]), "value": memory})
	checks.append({"check": "title: alpha threshold 110 (conversion) and 110/255 (portrait shader)", "ok": int(_title_json["alpha_cut"]) == 110 and absf(cut - 110.0 / 255.0) < 0.000001, "value": cut})
	return {
		"frames": n, "durations_s": durations, "durations_equal_title_frames_json": same, "authored_cycle_s": snappedf(total, 0.000001),
		"frame_size": [w, h], "canonical_width": int(_title_json["canonical_width"]), "probe_width": int(_title_json["probe_width"]),
		"alpha_cut_conversion": int(_title_json["alpha_cut"]), "alpha_cut_shader": cut, "crop": _title_json["crop"],
		"crop_margin": _title_json["crop_margin"], "source": _title_json["source"], "source_size": _title_json["source_size"],
		"pages": pages, "pages_within_2048": pages_ok, "memory_bytes": memory, "memory_bytes_title_frames_json": int(_title_json["memory_bytes"]),
		"memory_under_12_mb": memory < 12 * 1024 * 1024, "review_widths_px": TITLE_WIDTHS, "review_views_px": TITLE_VIEWS, "display_scale": 2,
		"first_middle_last": [0, floori(n / 2.0), n - 1], "portrait": "TitlePortrait: linear sampling + alpha-cut shader (title only)",
		"automated_test": "test_AST_010_title_conversion",
		"review": "tools/title_capture.gd stills and tools/m1_review.tscn (tab 3); these facts do not replace the human decisions C-*",
	}


## One labelled sheet per action: the normal and the armoured costume side by side, a row per
## direction, a column per frame (x2, nearest), each column headed by its authored duration.
func _render_contact_sheets() -> void:
	var out := _export_dir.path_join("contact_sheets")
	DirAccess.make_dir_recursive_absolute(out)
	var sheet_scale := 2
	var cell := 40 * sheet_scale + 4
	var side_w := 40 + 8 * cell
	var w := 12 + side_w * _costumes.size() + 24 * (_costumes.size() - 1) + 12
	var h := 12 + 26 + 24 + 22 + DIRS.size() * cell + 8
	for ai in _actions.size():
		var a := _actions[ai]
		var vp := SubViewport.new()
		vp.size = Vector2i(w, h)
		vp.transparent_bg = false
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var bg := ColorRect.new()
		bg.color = SHEET_BG
		bg.size = Vector2(w, h)
		vp.add_child(bg)
		var normal: SpriteFrames = _costumes[0]["frames"]
		var first := StringName("%s_n" % a)
		_sheet_label(vp, Vector2(12, 10), "Zampanò, action '%s': %s, %d frames, authored ms per frame %s" % [a, "loop" if normal.get_animation_loop(first) else "one-shot", normal.get_frame_count(first), ", ".join(_anim_frame_list(normal, first))], 16)
		for ci in _costumes.size():
			var c: Dictionary = _costumes[ci]
			var frames: SpriteFrames = c["frames"]
			var x0 := 12 + ci * (side_w + 24)
			_sheet_label(vp, Vector2(x0, 38), "%s (%s): %s" % [c["key"], c["label"], String(c["path"]).get_file()], 14)
			var fa := StringName("%s_n" % a)
			for k in frames.get_frame_count(fa):
				_sheet_label(vp, Vector2(x0 + 40 + k * cell, 62), "f%d %s" % [k + 1, _fmt_ms(_frame_ms(frames, fa, k))], 12)
			for di in DIRS.size():
				var d := DIRS[di]
				var y := 84 + di * cell
				_sheet_label(vp, Vector2(x0, y + 30), d.to_upper(), 14)
				var anim := StringName("%s_%s" % [a, d])
				for k in frames.get_frame_count(anim):
					var sp := Sprite2D.new()
					sp.texture = frames.get_frame_texture(anim, k)
					sp.centered = false
					sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					sp.scale = Vector2(sheet_scale, sheet_scale)
					sp.position = Vector2(x0 + 40 + k * cell, y)
					vp.add_child(sp)
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png(out.path_join("zampano_%02d_%s.png" % [ai + 1, a]))
		vp.queue_free()


func _sheet_label(parent: Node, pos: Vector2, text: String, size_px: int) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size_px)
	parent.add_child(l)


## The first, middle and last title frames in tools/title_capture.gd's layout and scale (same
## viewport, ground, widths and x2 nearest enlargement), set only after the portraits are ready:
## run as a --script, title_capture.gd sets frame 0 before TitlePortrait._ready() starts playback,
## so its first image can show a later frame (its middle and last images are unaffected).
func _capture_title_stills() -> void:
	var out := _export_dir.path_join("title_stills")
	DirAccess.make_dir_recursive_absolute(out)
	var vp := SubViewport.new()
	vp.size = TITLE_SIZE
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var bg := ColorRect.new()
	bg.color = TITLE_BG
	bg.size = Vector2(TITLE_SIZE)
	vp.add_child(bg)
	var portraits: Array[TitlePortrait] = []
	for k in TITLE_WIDTHS.size():
		var p := TitlePortrait.new()
		vp.add_child(p)
		p.fit_width(float(TITLE_WIDTHS[k]))
		p.position = Vector2(8 + k * (126 + 8), 8)
		portraits.append(p)
	await get_tree().process_frame
	var n := portraits[0].sprite_frames.get_frame_count(&"portrait")
	for idx: int in [0, floori(n / 2.0), n - 1]:
		for p in portraits:
			p.stop()
			p.frame = idx
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		img.save_png(out.path_join("title_frame_%02d_widths_88_99_124.png" % idx))
	vp.queue_free()


## Captures of the three review tabs as the reviewer sees them (supporting images, not evidence of
## any decision).
func _capture_ui() -> void:
	var out := _export_dir.path_join("review_ui")
	DirAccess.make_dir_recursive_absolute(out)
	var names: Array[String] = ["animations", "audio", "title"]
	for t in names.size():
		_tabs.current_tab = t
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(out.path_join("tab_%d_%s.png" % [t + 1, names[t]]))
