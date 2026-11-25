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
##     silence skipped, gains, buses) or raw from 0 s, starting at a safe master volume. The siren
##     also has the source's attack event (alarm, then the siren after AUDIO.SIREN_DELAY at
##     AUDIO.SIREN_VOLUME, looping until Stop) on a review-only player: the shipping AudioService
##     has no looping effect yet and is not changed for the station.
##   3 Title: the title portrait at the three review widths (TitlePortrait, x2 like the game), live
##     at the authored delays, with pause, frame step, first/middle/last and the memory report.
##   4 Sign-off: owner, date, equipment, environment, the reviewed-content fingerprint and the
##     final decision (APPROVED needs every field PASS and a nonblank owner, date and equipment).
## Decisions are saved on every change to <decisions dir>/m1_owner_decisions.json and .md (resumed
## on the next start only when their schema and content fingerprint match; otherwise they are set
## aside as .stale-<time> files and every field starts NOT EXECUTED). A failed save is shown in red
## and never reported as saved. Nothing is written to the game's save files.
##
##   godot --path godot res://tools/m1_review.tscn -- [--decisions <absolute dir>]
##   godot --path godot res://tools/m1_review.tscn -- --export <absolute dir>
##   godot --path godot res://tools/m1_review.tscn -- --selftest <absolute dir>
## --export writes the machine-readable inventories, the content fingerprint, the blank checklist,
## labelled contact sheets and captures of the review screens, runs automated self-checks (facts
## only, never a manual decision), verifies that every expected file exists, is nonempty and
## parses, and exits 0 only when everything holds (any write or check failure: ok:false, exit 1).
## --selftest exercises the station itself in a scratch directory (save/resume, stale content,
## save failure, approval and attribution refusal, the siren event mode, pausing on focus loss)
## and exits 0 only when every check holds. All three need a renderer (not --headless).

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
## Version of the decisions file layout and of the field list; saved decisions of another version
## are set aside, never merged (version 1: progress report 21, no version key, 362 fields).
const SCHEMA_VERSION := 2
const DECISIONS_FILE := "m1_owner_decisions"
## Source literals of the attack siren (src/config.ts AUDIO: SFX_VOLUME, FILE_GAIN.siren,
## SIREN_VOLUME, SIREN_DELAY) and of AudioEngine.stopLoop() (src/core/audio.ts: gain to 0 with
## time constant 0.08 s, source stopped 0.4 s later); the self-checks compare GameConfig with them.
const SOURCE_SIREN := {"sfx_volume": 0.9, "file_gain": 0.6, "volume": 0.45, "delay_s": 3.9}
const STOP_LOOP_TAU := 0.08
const STOP_LOOP_END := 0.4
## Title frame-memory budget of MILESTONES.md M1 / TEST_PLAN AST-010 ("<12 MB"), counted in
## decimal megabytes like test_AST_010_title_conversion.
const TITLE_MEMORY_LIMIT := 12 * 1000 * 1000
## Godot stream length vs the source fixture duration (seconds).
const DURATION_TOLERANCE := 0.001
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
	["siren", "effect", "recorded", "SOUND_FILES.siren; event attackStart: play('alarm') and loop('siren', {volume: SIREN_VOLUME, delay: SIREN_DELAY}) until attackEnd, levelComplete or gameOver (src/fx/gameAudio.ts); story fire: play('siren') once (src/story/walk.ts)", "Green Zone attack: after the alarm the siren loops, quieter, until the attack ends ([E] attack event). A story walk's fire plays it once (game path, one-shot)."],
	["laser", "effect", "recorded", "SOUND_FILES.laser (laser-eyes.mp3); event bump (src/systems/threats.ts: Bagnaskiz runs into Zampanò, who is knocked back and hurt)", "Bagnaskiz's laser eyes hit Zampanò and knock him back."],
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
	["C-MEMORY", "Memory report (shown on this tab): the title's frame memory and atlas pages are acceptable"],
]
## Review screens captured by --export (review_ui/tab_<n>_<name>.png).
const UI_TABS: Array[String] = ["animations", "audio", "audio_siren", "title"]
const FILTER_LABEL :="Nearest filtering: every animation's pixels stay crisp (no blur, no shimmer) at the review scale"
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
var _selftest_dir := ""
## {"sha256", "files": [[res path, sha256], ...]}: what the decisions are bound to.
var _fingerprint: Dictionary = {}
## Outcome of the last save: "" (nothing saved yet), "ok" or "failed".
var _save_state := ""
var _save_message := ""
## How the decisions file was found at start (resumed, none, set aside as stale).
var _load_message := ""
## True when stale decisions could not be set aside: saving would overwrite them, so it is refused.
var _save_blocked := false
var _status_note := ""
var _export_errors := PackedStringArray()
## SHA-256 of each title still --export saved, by file name.
var _still_hashes: Dictionary = {}
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
var _siren_button: Button
## Review-only player of the siren attack event: idle, waiting (the delay), looping, fading (Stop).
var _siren: AudioStreamPlayer
var _siren_state := "idle"
var _siren_wait := 0.0
var _siren_fade := 0.0
## The station's own players are paused while the application is in the background (focus lost or
## paused), like AudioService's; the siren delay does not advance meanwhile (source audio clock).
var _suspended := false

# Title tab.
var _portraits: Array[TitlePortrait] = []
var _title_info: Label
var _title_paused := false
var _title_last_frame := 0
var _title_cycle_start := 0
var _title_measured := 0.0
var _title_notes: LineEdit
var _memory_report := ""

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
		elif args[k] == "--selftest" and k + 1 < args.size():
			_selftest_dir = args[k + 1]
	_load_data()
	_build_fields()
	_reset_decisions()
	_env = _environment()
	_fingerprint = _content_fingerprint()
	_memory_report = _title_memory_report()
	if _export_dir == "" and _selftest_dir == "":
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
	elif _selftest_dir != "":
		_run_selftest.call_deferred()


func _reset_decisions() -> void:
	_decisions.clear()
	for f: Dictionary in _fields:
		_decisions[f["id"]] = "NOT EXECUTED"
	_notes.clear()
	_owner_info = {"name": "", "date": "", "equipment": "", "final": "NOT DECIDED"}


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
		var length := stream.get_length() if stream != null else 0.0
		it["duration_s"] = snappedf(length, 0.001)
		it["duration_exact_s"] = length
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
			it["fixture_duration_s"] = float(m["duration"])
		else:
			var sc: Dictionary = synth_cues[cue]
			it["fixture_duration_s"] = float(sc["duration"])
		it["duration_delta_s"] = absf(length - float(it["fixture_duration_s"]))
		_audio.append(it)
	_title_json = JSON.parse_string(FileAccess.get_file_as_string(TITLE_JSON_PATH))


## Deterministic fingerprint of the reviewed content: SHA-256 of the sorted "<res path> <sha256>"
## lines of the profile, both costume SpriteFrames, their sheet JSONs and every atlas page they use
## (with .import settings), the 32 audio files (with .import settings), the leading-silence and
## bus-layout resources, and the title SpriteFrames, its JSON, atlas pages, portrait script and
## shader. Any change to what the owner saw or heard changes it.
func _content_fingerprint() -> Dictionary:
	var paths := {PROFILE_PATH: true, "res://data/audio/sfx_leading_silence.tres": true,
		"res://data/audio/default_bus_layout.tres": true, "res://data/title/title_animation.tres": true,
		TITLE_JSON_PATH: true, "res://ui/title/title_portrait.gd": true, "res://ui/title/title_portrait.gdshader": true}
	for c: Dictionary in _costumes:
		paths[String(c["path"])] = true
		paths[String(c["sheet_json"])] = true
		var frames: SpriteFrames = c["frames"]
		for anim in frames.get_animation_names():
			for k in frames.get_frame_count(anim):
				var t := frames.get_frame_texture(anim, k) as AtlasTexture
				if t != null and t.atlas != null:
					paths[t.atlas.resource_path] = true
	for it: Dictionary in _audio:
		paths[String(it["path"])] = true
	for p: Dictionary in (_title_json["pages"] as Array):
		paths[String(p["target"])] = true
	for p: String in paths.keys():
		if FileAccess.file_exists(p + ".import"):
			paths[p + ".import"] = true
	var sorted: Array = paths.keys()
	sorted.sort()
	var files: Array = []
	var lines := PackedStringArray()
	for p: String in sorted:
		var sha := FileAccess.get_sha256(p) if FileAccess.file_exists(p) else ""
		files.append([p, sha])
		lines.append("%s %s" % [p, sha if sha != "" else "MISSING"])
	var text := "\n".join(lines) + "\n"
	return {"sha256": text.sha256_text(), "algorithm": "SHA-256 of the sorted '<res path> <file sha256>' lines, LF-terminated",
		"schema_version": SCHEMA_VERSION, "file_count": files.size(), "files": files}


## The title memory report (facts from title_frames.json, the SpriteFrames and the atlas import).
func _title_memory_report() -> String:
	var frames: SpriteFrames = TitlePortrait.FRAMES
	var n := frames.get_frame_count(&"portrait")
	var first := frames.get_frame_texture(&"portrait", 0)
	var memory := n * first.get_width() * first.get_height() * 4
	var pages := PackedStringArray()
	for p: Dictionary in (_title_json["pages"] as Array):
		var cfg := ConfigFile.new()
		var imported := cfg.load(String(p["target"]) + ".import") == OK
		pages.append("%s %d x %d px (%s bytes as RGBA8; import: %s)" % [String(p["target"]).get_file(), int(p["w"]), int(p["h"]),
			_thousands(int(p["w"]) * int(p["h"]) * 4),
			("compress/mode %d, mipmaps %s" % [int(cfg.get_value("params", "compress/mode", -1)), str(cfg.get_value("params", "mipmaps/generate", "?"))]) if imported else "no .import file"])
	return ("Memory report: %d frames of %d x %d px, uncompressed RGBA8 = %s bytes (%.2f MB; title_frames.json records %s bytes); "
		+ "limit < 12 MB (%s bytes): %s, %.1f %% of the limit. Atlas: %d page(s) (limit 2048 x 2048 each): %s.") % [
		n, first.get_width(), first.get_height(), _thousands(memory), memory / 1000000.0, _thousands(int(_title_json["memory_bytes"])),
		_thousands(TITLE_MEMORY_LIMIT), "within" if memory < TITLE_MEMORY_LIMIT else "OVER", 100.0 * memory / TITLE_MEMORY_LIMIT,
		pages.size(), "; ".join(pages)]


static func _thousands(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if v < 0 else "") + s + out


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
	_siren_button = _btn("Siren: attack event, loops until Stop [E]", func() -> void: _play_audio("siren"))
	side.add_child(_siren_button)
	side.add_child(_row([_btn("Stop [S]", func() -> void: _stop_audio(true)), _btn("Replay [R]", func() -> void: _play_audio(_last_mode)),
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
	_siren = AudioStreamPlayer.new()
	_siren.bus = &"SFX"
	add_child(_siren)
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
	root.add_child(_lbl(_memory_report + " C-MEMORY below is your decision on this report.", true))
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
	root.add_child(_lbl("Fill these in, then choose the final decision. APPROVED is possible only when every field of sections 1-3 is PASS and the owner name, date and equipment are filled in.", true))
	var grid := GridContainer.new()
	grid.columns = 2
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size = Vector2(520, 0)
	_name_edit.text_changed.connect(func(t: String) -> void: _set_owner("name", t))
	_date_edit = LineEdit.new()
	_date_edit.placeholder_text = "the review date, e.g. %s" % Time.get_date_string_from_system()
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
	root.add_child(_lbl("Reviewed content (decisions schema %d): fingerprint %s over %d files (the profile, both costume resources and sheets, the 32 audio files, the title resources). Saved decisions are resumed only for this exact content." % [
		SCHEMA_VERSION, _fingerprint["sha256"], _fingerprint["file_count"]], true))
	_summary = _lbl("", true)
	root.add_child(_summary)
	root.add_child(_row([_btn("Save now", _save_now), _btn("Open the decisions folder", func() -> void: OS.shell_open(ProjectSettings.globalize_path(_decisions_dir)))]))
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
	if it["cue"] == "siren":
		var s := _siren_config()
		lines.append("[b]Game path [Enter][/b] is a generic one-shot effect (AudioService.play, like the story fire); it does not loop.")
		lines.append("[b]Attack event [E][/b] (review-only player, source attackStart): the alarm plays at once through AudioService; %s s later the siren starts at %s s (its trimmed start), %s bus, gain %s (SFX %s x file %s x SIREN_VOLUME %s), and loops from %s s to the end until Stop, which fades it out like the source's stopLoop() (%s s). The delay does not advance while the window is in the background." % [
			s["delay_s"], s["start_s"], s["bus"], snappedf(float(s["gain"]), 0.0001), s["sfx_volume"], s["file_gain"], s["volume"], s["loop_offset_s"], STOP_LOOP_END])
	_audio_info.text = "\n".join(lines)
	_siren_button.disabled = it["cue"] != "siren"
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
	if mode == "siren" and cue != &"siren":
		return
	_last_mode = mode
	if mode == "game":
		if music:
			AudioService.track_positions.erase(cue)
			AudioService.play_music(cue)
		else:
			AudioService.play(cue)
		return
	if mode == "siren":
		_start_siren_event()
		return
	# A private copy: the loop flag of the shared (cached) resource AudioService plays stays as it is.
	var stream := _private_stream(String(it["path"]), music)
	_raw.stream = stream
	_raw.bus = StringName(String(it["bus"]))
	_raw.volume_db = linear_to_db(float(it["game_gain"]))
	_raw.play(maxf(0.0, stream.get_length() - 6.0) if mode == "seam" else 0.0)
	_raw.stream_paused = _suspended


## A duplicate of the stream resource with its own loop settings (MP3 only; WAV copies keep the
## imported loop mode).
static func _private_stream(path: String, loop: bool, loop_offset := 0.0) -> AudioStream:
	var shared: AudioStream = load(path)
	var copy := shared.duplicate() as AudioStream
	if copy is AudioStreamMP3:
		(copy as AudioStreamMP3).loop = loop
		(copy as AudioStreamMP3).loop_offset = loop_offset
	return copy


## The siren attack event as the source plays it (src/fx/gameAudio.ts attackStart, src/core/audio.ts
## loop()/startLoop()), with the port's own constants (GameConfig.Audio, AudioService.offsets).
func _siren_config() -> Dictionary:
	var offset := float(AudioService.offsets.get(&"siren", 0.0))
	var sfx := float(GameConfig.Audio.SFX_VOLUME)
	var file_gain := float(GameConfig.Audio.FILE_GAIN.get("siren", 1.0))
	var volume := float(GameConfig.Audio.SIREN_VOLUME)
	return {"path": AudioService.cue_path(&"siren"), "bus": "SFX", "delay_s": float(GameConfig.Audio.SIREN_DELAY),
		"sfx_volume": sfx, "file_gain": file_gain, "volume": volume, "gain": sfx * file_gain * volume,
		"start_s": offset, "loop": true, "loop_offset_s": offset, "alarm": "alarm through AudioService.play at the event",
		"stop": "gain to 0 with time constant %s s, stopped after %s s (source stopLoop)" % [STOP_LOOP_TAU, STOP_LOOP_END],
		"player": "review-only AudioStreamPlayer of tools/m1_review.gd; the shipping AudioService is unchanged"}


func _start_siren_event() -> void:
	var s := _siren_config()
	AudioService.play(&"alarm")
	_siren.stream = _private_stream(String(s["path"]), true, float(s["loop_offset_s"]))
	_siren.bus = StringName(String(s["bus"]))
	_siren.volume_db = linear_to_db(float(s["gain"]))
	_siren_wait = float(s["delay_s"])
	_siren_fade = 0.0
	_siren_state = "waiting"


## Advances the siren event by `delta` seconds of station audio time (frozen while suspended).
func _siren_step(delta: float) -> void:
	if _suspended or _siren_state == "idle" or _siren_state == "looping":
		return
	if _siren_state == "waiting":
		_siren_wait -= delta
		if _siren_wait <= 0.0:
			_siren_state = "looping"
			_siren.play(float(_siren_config()["start_s"]))
			_siren.stream_paused = _suspended
	elif _siren_state == "fading":
		_siren_fade += delta
		if _siren_fade >= STOP_LOOP_END:
			_siren.stop()
			_siren_state = "idle"
		else:
			_siren.volume_db = linear_to_db(maxf(float(_siren_config()["gain"]) * exp(-_siren_fade / STOP_LOOP_TAU), 0.00001))


## Stops everything. With `fade` (the Stop control), a looping siren fades out like the source's
## stopLoop(); a siren still waiting for its delay never starts.
func _stop_audio(fade := false) -> void:
	AudioService.stop_all()
	_raw.stop()
	if fade and _siren_state == "looping":
		_siren_state = "fading"
		_siren_fade = 0.0
	elif _siren_state != "fading" or not fade:
		_siren.stop()
		_siren_state = "idle"


func _set_suspended(on: bool) -> void:
	_suspended = on
	if _raw != null:
		_raw.stream_paused = on
	if _siren != null:
		_siren.stream_paused = on


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_set_suspended(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		_set_suspended(false)


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
	var paused := " (paused: window in the background)" if _suspended else ""
	if _siren_state == "waiting":
		_audio_pos.text = "Siren attack event: alarm playing, siren starts in %.2f s%s." % [maxf(_siren_wait, 0.0), paused]
	elif _siren_state == "looping" or _siren_state == "fading":
		_audio_pos.text = "Siren attack event: %s (review-only player) at %.2f s of %.2f s%s." % [
			"looping until Stop" if _siren_state == "looping" else "fading out after Stop", _siren.get_playback_position(), float(it["duration_s"]), paused]
	elif pos < 0.0:
		_audio_pos.text = "Stopped. Muted: %s. Suspended: %s." % [str(AudioService.muted), str(AudioService.suspended or _suspended)]
	else:
		_audio_pos.text = "Playing (%s): %.2f s of %.2f s%s" % [source, pos, float(it["duration_s"]), paused]


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
	var missing := _approval_missing()
	if FINALS[i] == "APPROVED" and not missing.is_empty():
		_loading = true
		_final_picker.select(FINALS.find(String(_owner_info["final"])))
		_loading = false
		_status_note = "APPROVED refused; it needs " + "; ".join(missing) + "."
		_refresh_all()
		return
	_owner_info["final"] = FINALS[i]
	_status_note = ""
	_after_change()


## What APPROVED still needs: every field PASS and a nonblank owner name, date and equipment.
func _approval_missing() -> PackedStringArray:
	var out := PackedStringArray()
	if _count("PASS") != _fields.size():
		out.append("every field PASS (%d of %d are PASS)" % [_count("PASS"), _fields.size()])
	for pair: Array in [["name", "the owner name"], ["date", "the date"], ["equipment", "the listening equipment and display"]]:
		if String(_owner_info[pair[0]]).strip_edges() == "":
			out.append(String(pair[1]))
	return out


func _after_change() -> void:
	if _owner_info["final"] == "APPROVED" and not _approval_missing().is_empty():
		_owner_info["final"] = "NOT DECIDED"
		_status_note = "The final decision went back to NOT DECIDED; APPROVED needs " + "; ".join(_approval_missing()) + "."
	_save()
	_refresh_all()


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
	var where := _save_line()
	_summary.text = "Fields: %d. PASS %d, FAIL %d, NOT EXECUTED %d. Final decision: %s.\nDecisions: %s%s%s" % [
		_fields.size(), _count("PASS"), _count("FAIL"), _count("NOT EXECUTED"), _owner_info["final"], where,
		("\n" + _load_message) if _load_message != "" else "", ("\n" + _status_note) if _status_note != "" and _status_note != _load_message else ""]
	_status.text = "PASS %d  FAIL %d  NOT EXECUTED %d  of %d fields   |   %s%s" % [_count("PASS"), _count("FAIL"), _count("NOT EXECUTED"), _fields.size(), where,
		("   |   " + _status_note) if _status_note != "" else ""]
	var bad := _save_state == "failed" or _save_blocked
	_status.add_theme_color_override("font_color", Color("#ff6b6b") if bad else Color("#e8e8ee"))
	_summary.add_theme_color_override("font_color", Color("#ff6b6b") if bad else Color("#e8e8ee"))


## The save state shown on screen. Export mode saves nothing and shows no local path (its screen
## captures are committed); a failed save is never shown as saved.
func _save_line() -> String:
	if _export_dir != "":
		return "export mode: nothing is saved"
	var where := ProjectSettings.globalize_path(_decisions_dir)
	if _save_blocked:
		return "SAVING DISABLED: " + _save_message
	match _save_state:
		"ok":
			return "saved %s to %s" % [_save_message, where]
		"failed":
			return "NOT SAVED: " + _save_message
	return "not saved yet (folder %s)" % where


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


## Resumes saved decisions only when their schema version and content fingerprint equal this
## station's. Anything else (another version, other content, an unreadable file) is renamed to
## m1_owner_decisions.stale-<time>.json/.md and every field starts NOT EXECUTED; if the rename
## fails, saving is disabled so the old file is never overwritten.
func _load_decisions() -> void:
	_save_blocked = false
	var path := _decisions_dir.path_join(DECISIONS_FILE + ".json")
	if not FileAccess.file_exists(path):
		_load_message = "No saved decisions in this folder: every field starts NOT EXECUTED."
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var reason := ""
	if not (data is Dictionary):
		reason = "the file is not a decisions file"
	else:
		var schema := int((data as Dictionary).get("schema_version", 1))
		var fp := String((data as Dictionary).get("content_fingerprint", ""))
		if schema != SCHEMA_VERSION:
			reason = "they were saved by decisions schema %d (this station: %d)" % [schema, SCHEMA_VERSION]
		elif fp != String(_fingerprint["sha256"]):
			reason = "they were made for other content (fingerprint %s; this station: %s)" % [fp.left(16) if fp != "" else "none", String(_fingerprint["sha256"]).left(16)]
	if reason != "":
		var stamp := Time.get_datetime_string_from_system().replace(":", "-")
		var moved := PackedStringArray()
		var failed := PackedStringArray()
		for ext: String in [".json", ".md"]:
			var from := _decisions_dir.path_join(DECISIONS_FILE + ext)
			if not FileAccess.file_exists(from):
				continue
			var to := _decisions_dir.path_join("%s.stale-%s%s" % [DECISIONS_FILE, stamp, ext])
			if DirAccess.rename_absolute(from, to) == OK and FileAccess.file_exists(to) and not FileAccess.file_exists(from):
				moved.append(to.get_file())
			else:
				failed.append(from.get_file())
		if not failed.is_empty():
			_save_blocked = true
			_save_message = "stale decisions (%s) could not be set aside (%s); nothing will be saved, so they are not overwritten" % [reason, ", ".join(failed)]
			_load_message = "Saved decisions NOT resumed: " + _save_message + "."
			_status_note = _load_message
			return
		_load_message = "Saved decisions NOT resumed: %s. They were set aside as %s; every field starts NOT EXECUTED." % [reason, ", ".join(moved)]
		_status_note = _load_message
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
	if _owner_info["final"] == "APPROVED" and not _approval_missing().is_empty():
		_owner_info["final"] = "NOT DECIDED"
	_load_message = "Resumed the saved decisions (schema %d, fingerprint %s)." % [SCHEMA_VERSION, String(_fingerprint["sha256"]).left(16)]


## Saves the JSON and Markdown copies; returns false (and shows NOT SAVED) when any directory,
## write or read-back fails.
func _save() -> bool:
	if _export_dir != "":
		return true
	if _save_blocked:
		return false
	var errors := PackedStringArray()
	var dir_error := _ensure_dir(_decisions_dir)
	if dir_error != "":
		errors.append(dir_error)
	else:
		var data := {
			"tool": "res://tools/m1_review.gd",
			"schema_version": SCHEMA_VERSION,
			"content_fingerprint": _fingerprint["sha256"],
			"content_fingerprint_files": _fingerprint["file_count"],
			"saved_at": Time.get_datetime_string_from_system(),
			"environment": _env,
			"owner": _owner_info,
			"decisions": _decisions,
			"notes": _notes,
			"summary": {"PASS": _count("PASS"), "FAIL": _count("FAIL"), "NOT EXECUTED": _count("NOT EXECUTED"), "fields": _fields.size()},
		}
		for pair: Array in [[DECISIONS_FILE + ".json", JSON.stringify(data, "  ", true) + "\n"], [DECISIONS_FILE + ".md", _markdown(false)]]:
			var e := _write(_decisions_dir.path_join(String(pair[0])), String(pair[1]))
			if e != "":
				errors.append(e)
	if errors.is_empty():
		_save_state = "ok"
		_save_message = Time.get_time_string_from_system()
		return true
	_save_state = "failed"
	_save_message = "; ".join(errors)
	push_error("m1_review: decisions NOT saved: " + _save_message)
	return false


func _save_now() -> void:
	_save()
	_refresh_all()


## Creates `dir` (with parents); returns "" or the failure.
static func _ensure_dir(dir: String) -> String:
	var err := DirAccess.make_dir_recursive_absolute(dir)
	if not DirAccess.dir_exists_absolute(dir):
		return "cannot create the folder %s (%s)" % [dir, error_string(err) if err != OK else "the path exists and is not a folder"]
	return ""


## Writes `text` and reads it back; returns "" or the failure.
static func _write(path: String, text: String) -> String:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "cannot open %s for writing (%s)" % [path, error_string(FileAccess.get_open_error())]
	var stored := f.store_string(text)
	var err := f.get_error()
	f.close()
	if not stored or err != OK:
		return "cannot write %s (%s)" % [path, error_string(err)]
	if FileAccess.get_file_as_bytes(path) != text.to_utf8_buffer():
		return "%s does not read back as written" % path
	return ""


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
	o.append("| Reviewed content | decisions schema %d; content fingerprint `%s` (SHA-256 over %d files, listed in `content_fingerprint.json`) |" % [SCHEMA_VERSION, _fingerprint["sha256"], _fingerprint["file_count"]])
	o.append("| Final M1 manual decision (APPROVED only when every field is PASS and the owner name, date and equipment are filled in) | %s |" % ("NOT DECIDED" if blank else String(_owner_info["final"])))
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
	o.append("A cell's field ID is `B-<cue>-<observation>`: AUDIBLE (clearly audible at the safe volume), INTENT (right for its expected use), START (no late start or cut attack; recorded effects skip their leading silence in the game), END (ends or loops cleanly; music: loop seam and track switch), CLEAN (no obvious clipping, distortion or artifacts). The siren is judged on both of its game uses: the one-shot game path and the attack event ([E] in the station: the alarm, then the siren after %s s at SIREN_VOLUME, looping until Stop)." % _siren_config()["delay_s"])
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
	o.append(_memory_report + " C-MEMORY is the reviewer's decision on this report.")
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
	if _selftest_dir == "":
		_siren_step(delta)
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
				KEY_E: _play_audio("siren")
				KEY_S: _stop_audio(true)
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

## Every file --export must produce, relative to the export folder.
func _expected_export_files() -> PackedStringArray:
	var out := PackedStringArray(["animation_inventory.json", "audio_inventory.json", "title_facts.json", "content_fingerprint.json",
		"M1_MANUAL_CHECKLIST.md", "selftest.json"])
	for ai in _actions.size():
		out.append("contact_sheets/zampano_%02d_%s.png" % [ai + 1, _actions[ai]])
	for idx in _title_still_frames():
		out.append("title_stills/" + _title_still_name(idx))
	for t in UI_TABS.size():
		out.append("review_ui/tab_%d_%s.png" % [t + 1, UI_TABS[t]])
	return out


## Each expected file exists, is nonempty and parses (JSON object, PNG image, checklist heading).
func _verify_export_files(skip: PackedStringArray) -> PackedStringArray:
	var problems := PackedStringArray()
	for rel in _expected_export_files():
		if skip.has(rel):
			continue
		var path := _export_dir.path_join(rel)
		if not FileAccess.file_exists(path):
			problems.append("%s: missing" % rel)
			continue
		var bytes := FileAccess.get_file_as_bytes(path)
		if bytes.is_empty():
			problems.append("%s: empty" % rel)
		elif rel.ends_with(".json"):
			if not (JSON.parse_string(bytes.get_string_from_utf8()) is Dictionary):
				problems.append("%s: not a JSON object" % rel)
		elif rel.ends_with(".png"):
			var img := Image.load_from_file(path)
			if img == null or img.is_empty():
				problems.append("%s: not a readable PNG" % rel)
		elif rel.ends_with(".md"):
			if not bytes.get_string_from_utf8().begins_with("# M1 manual checklist"):
				problems.append("%s: not the checklist" % rel)
	return problems


func _export_write(rel: String, text: String) -> void:
	var e := _write(_export_dir.path_join(rel), text)
	if e != "":
		_export_errors.append(e)


func _run_export() -> void:
	var dir_error := _ensure_dir(_export_dir)
	if dir_error != "":
		_export_errors.append(dir_error)
		_finish_export([])
		return
	var checks: Array[Dictionary] = []
	_export_write("animation_inventory.json", JSON.stringify(_animation_inventory(checks), "  ", true) + "\n")
	_export_write("audio_inventory.json", JSON.stringify(_audio_inventory(checks), "  ", true) + "\n")
	_export_write("title_facts.json", JSON.stringify(_title_facts(checks), "  ", true) + "\n")
	_export_write("content_fingerprint.json", JSON.stringify(_fingerprint, "  ", true) + "\n")
	_export_write("M1_MANUAL_CHECKLIST.md", _markdown(true))
	checks.append({"check": "checklist fields: 192 animation cells + A-FILTER, 32 x 5 audio + B-MUTE + B-VOLUME, 8 title (C-MEMORY included)", "ok": _fields.size() == 192 + 1 + 160 + 2 + 8 and _fields.size() == 363, "value": _fields.size()})
	checks.append(_fingerprint_check())
	checks.append(_siren_config_check())
	await _render_contact_sheets()
	await _capture_title_stills()
	var stills_ok := _still_hashes.size() == 3
	for k: String in _still_hashes:
		stills_ok = stills_ok and String(_still_hashes[k]).length() == 64
	checks.append({"check": "title stills: frames 0, 49 and 98 saved after the portraits were ready (value: SHA-256 per file)", "ok": stills_ok, "value": _still_hashes})
	await _capture_ui()
	_finish_export(checks)


func _finish_export(checks: Array[Dictionary]) -> void:
	var failed := PackedStringArray()
	for c: Dictionary in checks:
		if not c["ok"]:
			failed.append(String(c["check"]))
	var problems := PackedStringArray()
	if DirAccess.dir_exists_absolute(_export_dir):
		problems = _verify_export_files(PackedStringArray(["selftest.json"]))
		var ok := failed.is_empty() and problems.is_empty() and _export_errors.is_empty()
		_export_write("selftest.json", JSON.stringify({"checks": checks, "artifacts_expected": _expected_export_files().size(),
			"artifact_problems": problems, "write_errors": _export_errors, "ok": ok, "note": "automated facts only; no manual decision"}, "  ", true) + "\n")
		var last := _verify_export_files(PackedStringArray())
		for p in last:
			if not problems.has(p):
				problems.append(p)
	var result := {"ok": failed.is_empty() and problems.is_empty() and _export_errors.is_empty(), "checks": checks.size(), "failed": failed,
		"fields": _fields.size(), "artifacts_expected": _expected_export_files().size(), "artifact_problems": problems,
		"write_errors": _export_errors, "content_fingerprint": _fingerprint["sha256"]}
	print("M1REVIEW ", JSON.stringify(result))
	if not result["ok"]:
		printerr("m1_review: export FAILED (%d failed checks, %d artifact problems, %d write errors)" % [failed.size(), problems.size(), _export_errors.size()])
	_stop_audio()
	get_tree().quit(0 if result["ok"] else 1)


func _fingerprint_check() -> Dictionary:
	var again := _content_fingerprint()
	var all_present := true
	for f: Array in (_fingerprint["files"] as Array):
		all_present = all_present and String(f[1]).length() == 64
	return {"check": "content fingerprint: deterministic (computed twice), 64 hex digits, every covered file present (profile, costumes, sheets, atlas pages, 32 audio files, title resources)",
		"ok": again["sha256"] == _fingerprint["sha256"] and String(_fingerprint["sha256"]).length() == 64 and all_present and int(_fingerprint["file_count"]) > 40,
		"value": {"sha256": _fingerprint["sha256"], "files": _fingerprint["file_count"]}}


## The siren attack-event mode uses the port's constants, and they equal the source literals.
func _siren_config_check() -> Dictionary:
	var s := _siren_config()
	var source_offset := float(_leading_silence_offsets().get(&"siren", -1.0))
	var ok: bool = is_equal_approx(float(s["sfx_volume"]), float(SOURCE_SIREN["sfx_volume"])) and is_equal_approx(float(s["file_gain"]), float(SOURCE_SIREN["file_gain"])) \
		and is_equal_approx(float(s["volume"]), float(SOURCE_SIREN["volume"])) and is_equal_approx(float(s["delay_s"]), float(SOURCE_SIREN["delay_s"])) \
		and is_equal_approx(float(s["gain"]), 0.9 * 0.6 * 0.45) and is_equal_approx(float(s["start_s"]), source_offset) \
		and is_equal_approx(float(s["loop_offset_s"]), source_offset) and s["bus"] == "SFX" and bool(s["loop"]) and String(s["path"]).ends_with("/siren.mp3")
	return {"check": "siren attack event: SFX bus, gain 0.9 x 0.6 x 0.45, delay 3.9 s, start and loop at the trimmed offset (src/config.ts AUDIO, leading-silence resource)", "ok": ok, "value": s}


## The leading-silence offsets of the generated resource (what AudioService.offsets is copied from).
static func _leading_silence_offsets() -> Dictionary:
	return AudioService.LEADING_SILENCE.offsets


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
	var worst := 0.0
	for it: Dictionary in _audio:
		listed.append(String(it["cue"]))
		var key := "%s %s" % [it["provenance"], it["kind"]]
		counts[key] = int(counts[key]) + 1
		all_load = all_load and bool(it["loads"]) and float(it["duration_s"]) > 0.0
		hashes = hashes and it["sha256"] == it["manifest_sha256"] and String(it["sha256"]) != ""
		if it["provenance"] == "generated":
			synth_format = synth_format and it["format"] == "WAV PCM" and int(it["channels"]) == 1 and int(it["sample_rate"]) == 22050 and int(it["bits"]) == 16
		durations = durations and float(it["duration_delta_s"]) <= DURATION_TOLERANCE
		worst = maxf(worst, float(it["duration_delta_s"]))
	listed.sort()
	checks.append({"check": "the listening list is exactly AudioService's tracks, recorded effects and synth cues", "ok": listed == expected, "value": listed.size()})
	checks.append({"check": "5 recorded tracks, 12 recorded effects, 1 generated loop, 14 generated cues", "ok": counts == {"recorded music": 5, "recorded effect": 12, "generated music": 1, "generated effect": 14}, "value": counts})
	checks.append({"check": "every file loads with a positive length", "ok": all_load, "value": _audio.size()})
	checks.append({"check": "every file's SHA-256 equals the source asset manifest", "ok": hashes, "value": _audio.size()})
	checks.append({"check": "generated cues and loop are mono 22,050 Hz 16-bit PCM WAV", "ok": synth_format, "value": 15})
	checks.append({"check": "Godot stream length within %s s of the source fixture duration (unrounded values; value: the largest difference)" % DURATION_TOLERANCE, "ok": durations, "value": worst})
	return {"items": _audio, "counts": counts, "master_volume_at_start": SAFE_VOLUME, "duration_tolerance_s": DURATION_TOLERANCE,
		"siren_attack_event": _siren_config(),
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
	checks.append({"check": "title: uncompressed frame memory < 12 MB (12,000,000 bytes, as test_AST_010) and equal to title_frames.json", "ok": memory < TITLE_MEMORY_LIMIT and memory == int(_title_json["memory_bytes"]), "value": memory})
	checks.append({"check": "title: alpha threshold 110 (conversion) and 110/255 (portrait shader)", "ok": int(_title_json["alpha_cut"]) == 110 and absf(cut - 110.0 / 255.0) < 0.000001, "value": cut})
	return {
		"frames": n, "durations_s": durations, "durations_equal_title_frames_json": same, "authored_cycle_s": snappedf(total, 0.000001),
		"frame_size": [w, h], "canonical_width": int(_title_json["canonical_width"]), "probe_width": int(_title_json["probe_width"]),
		"alpha_cut_conversion": int(_title_json["alpha_cut"]), "alpha_cut_shader": cut, "crop": _title_json["crop"],
		"crop_margin": _title_json["crop_margin"], "source": _title_json["source"], "source_size": _title_json["source_size"],
		"pages": pages, "pages_within_2048": pages_ok, "memory_bytes": memory, "memory_bytes_title_frames_json": int(_title_json["memory_bytes"]),
		"memory_under_12_mb": memory < TITLE_MEMORY_LIMIT, "memory_limit_bytes": TITLE_MEMORY_LIMIT, "memory_report": _memory_report,
		"review_widths_px": TITLE_WIDTHS, "review_views_px": TITLE_VIEWS, "display_scale": 2,
		"first_middle_last": [0, floori(n / 2.0), n - 1], "portrait": "TitlePortrait: linear sampling + alpha-cut shader (title only)",
		"automated_test": "test_AST_010_title_conversion",
		"review": "tools/title_capture.gd stills and tools/m1_review.tscn (tab 3); these facts do not replace the human decisions C-*",
	}


## One labelled sheet per action: the normal and the armoured costume side by side, a row per
## direction, a column per frame (x2, nearest), each column headed by its authored duration.
func _render_contact_sheets() -> void:
	var out := _export_dir.path_join("contact_sheets")
	var dir_error := _ensure_dir(out)
	if dir_error != "":
		_export_errors.append(dir_error)
		return
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
		_save_png(vp.get_texture().get_image(), out.path_join("zampano_%02d_%s.png" % [ai + 1, a]))
		vp.queue_free()


## Saves a PNG and loads it back; a failure is recorded as an export error.
func _save_png(img: Image, path: String) -> void:
	if img == null or img.is_empty():
		_export_errors.append("no image to save as %s" % path)
		return
	var err := img.save_png(path)
	if err != OK:
		_export_errors.append("cannot save %s (%s)" % [path, error_string(err)])
		return
	var back := Image.load_from_file(path)
	if back == null or back.get_size() != img.get_size():
		_export_errors.append("%s does not load back as the saved image" % path)


func _sheet_label(parent: Node, pos: Vector2, text: String, size_px: int) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size_px)
	parent.add_child(l)


func _title_still_frames() -> Array[int]:
	var n := TitlePortrait.FRAMES.get_frame_count(&"portrait")
	return [0, floori(n / 2.0), n - 1]


static func _title_still_name(idx: int) -> String:
	return "title_frame_%02d_widths_88_99_124.png" % idx


## The first, middle and last title frames in tools/title_capture.gd's layout and scale (same
## viewport, ground, widths and x2 nearest enlargement), set only after the portraits are ready
## (title_capture.gd waits for the same since correction report 22). The SHA-256 of each saved
## file goes to selftest.json so the two tools' images can be compared byte for byte.
func _capture_title_stills() -> void:
	var out := _export_dir.path_join("title_stills")
	var dir_error := _ensure_dir(out)
	if dir_error != "":
		_export_errors.append(dir_error)
		return
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
	while not portraits.all(func(p: TitlePortrait) -> bool: return p.is_node_ready()):
		await get_tree().process_frame
	for idx in _title_still_frames():
		for p in portraits:
			p.stop()
			p.frame = idx
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		var path := out.path_join(_title_still_name(idx))
		_save_png(img, path)
		_still_hashes[_title_still_name(idx)] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	vp.queue_free()


## Captures of the review tabs as the reviewer sees them (supporting images, not evidence of any
## decision); the audio tab twice: its first item and the siren with the attack-event controls.
func _capture_ui() -> void:
	var out := _export_dir.path_join("review_ui")
	var dir_error := _ensure_dir(out)
	if dir_error != "":
		_export_errors.append(dir_error)
		return
	for t in UI_TABS.size():
		var tab := 2 if UI_TABS[t] == "title" else (1 if UI_TABS[t].begins_with("audio") else 0)
		_select_audio(_audio_cue_index("siren") if UI_TABS[t] == "audio_siren" else 0)
		_tabs.current_tab = tab
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_save_png(get_viewport().get_texture().get_image(), out.path_join("tab_%d_%s.png" % [t + 1, UI_TABS[t]]))
	_select_audio(0)


func _audio_cue_index(cue: String) -> int:
	for k in _audio.size():
		if _audio[k]["cue"] == cue:
			return k
	return 0


# --- Self-test: the station's own behaviour, in a scratch folder ----------------------------------

## --selftest <dir>: drives the station's own code (no human decision is made or implied) in
## <dir>/run-<time>: save and resume, a stale fingerprint, an old schema, save failures, approval
## and attribution refusal, the siren attack event and pausing on focus loss. The master bus is
## silent throughout (volume 0). Writes <dir>/station_selftest.json and exits 0 only when every
## check holds.
func _run_selftest() -> void:
	var checks: Array[Dictionary] = []
	var root_error := _ensure_dir(_selftest_dir)
	var run := _selftest_dir.path_join("run-%s-%d" % [Time.get_datetime_string_from_system().replace(":", "-"), Time.get_ticks_usec()])
	if root_error == "":
		root_error = _ensure_dir(run)
	if root_error != "":
		print("M1SELFTEST ", JSON.stringify({"ok": false, "errors": [root_error]}))
		get_tree().quit(1)
		return
	var add := func(check_name: String, ok: bool, value: Variant = null) -> void:
		checks.append({"check": check_name, "ok": ok, "value": value})
	AudioService.apply_settings(false, 0.0)

	# Fields.
	add.call("363 fields: 193 animation (192 cells + A-FILTER), 162 audio (32 x 5 + B-MUTE + B-VOLUME), 8 title (C-MEMORY included)",
		_fields.size() == 363 and _section_size("A") == 193 and _section_size("B") == 162 and _section_size("C") == 8 and _decisions.has("C-MEMORY"),
		{"fields": _fields.size(), "A": _section_size("A"), "B": _section_size("B"), "C": _section_size("C")})
	add.call("every field starts NOT EXECUTED, final NOT DECIDED, no owner data", _count("NOT EXECUTED") == 363 and _owner_info["final"] == "NOT DECIDED"
		and String(_owner_info["name"]) == "" and String(_owner_info["date"]) == "" and String(_owner_info["equipment"]) == "", _count("NOT EXECUTED"))
	checks.append(_fingerprint_check())
	checks.append(_siren_config_check())

	# Save and resume.
	_decisions_dir = run.path_join("resume")
	_reset_decisions()
	_decisions["A-normal-idle-n"] = "PASS"
	_decisions["B-bark-AUDIBLE"] = "FAIL"
	_decisions["C-MEMORY"] = "PASS"
	_notes["C"] = "self-test note"
	_owner_info["name"] = "Self-test"
	var saved := _save()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_decisions_dir.path_join(DECISIONS_FILE + ".json")))
	var md := FileAccess.get_file_as_string(_decisions_dir.path_join(DECISIONS_FILE + ".md"))
	add.call("save: m1_owner_decisions.json (schema %d, content fingerprint) and .md (fingerprint shown) written" % SCHEMA_VERSION,
		saved and _save_state == "ok" and data is Dictionary and int((data as Dictionary).get("schema_version", 0)) == SCHEMA_VERSION
		and (data as Dictionary).get("content_fingerprint", "") == _fingerprint["sha256"] and md.contains(String(_fingerprint["sha256"])), saved)
	_reset_decisions()
	_load_decisions()
	add.call("resume: decisions, notes and owner restored from the saved file", _decisions["A-normal-idle-n"] == "PASS" and _decisions["B-bark-AUDIBLE"] == "FAIL"
		and _decisions["C-MEMORY"] == "PASS" and _notes.get("C", "") == "self-test note" and _owner_info["name"] == "Self-test"
		and _count("NOT EXECUTED") == 360 and _load_message.begins_with("Resumed"), _count("NOT EXECUTED"))

	# Stale content fingerprint and an old schema (the 10eec20 layout has no schema_version).
	var stale_cases := [["stale_fingerprint", {"schema_version": SCHEMA_VERSION, "content_fingerprint": "0".repeat(64)}, "other content"],
		["old_schema", {}, "schema 1"]]
	for case: Array in stale_cases:
		_decisions_dir = run.path_join(String(case[0]))
		_ensure_dir(_decisions_dir)
		var stale: Dictionary = (case[1] as Dictionary).duplicate()
		stale["decisions"] = {"A-normal-idle-n": "PASS", "C-CROP": "PASS"}
		stale["owner"] = {"name": "Earlier", "date": "2026-01-01", "equipment": "old", "final": "NOT APPROVED"}
		_write(_decisions_dir.path_join(DECISIONS_FILE + ".json"), JSON.stringify(stale))
		_write(_decisions_dir.path_join(DECISIONS_FILE + ".md"), "# old\n")
		_reset_decisions()
		_load_decisions()
		var aside := DirAccess.get_files_at(_decisions_dir)
		var set_aside := 0
		for f in aside:
			if f.begins_with(DECISIONS_FILE + ".stale-"):
				set_aside += 1
		add.call("%s: nothing resumed (every field NOT EXECUTED, no owner data), both files set aside as .stale-<time>, the reason shown" % case[0],
			_count("NOT EXECUTED") == 363 and _owner_info["name"] == "" and _owner_info["final"] == "NOT DECIDED" and set_aside == 2
			and not FileAccess.file_exists(_decisions_dir.path_join(DECISIONS_FILE + ".json")) and _load_message.contains(String(case[2]))
			and _status_note == _load_message and not _save_blocked, {"set_aside": set_aside, "message_has_reason": _load_message.contains(String(case[2]))})
		var fresh := _save()
		var fresh_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_decisions_dir.path_join(DECISIONS_FILE + ".json")))
		add.call("%s: the next save writes a fresh file for this content and keeps the set-aside files" % case[0], fresh and fresh_data is Dictionary
			and (fresh_data as Dictionary).get("content_fingerprint", "") == _fingerprint["sha256"] and DirAccess.get_files_at(_decisions_dir).size() == 4, fresh)

	# Approval: every field PASS and a nonblank owner name, date and equipment.
	_decisions_dir = run.path_join("approval")
	_reset_decisions()
	_status_note = ""
	_owner_info["name"] = "Self-test"
	_owner_info["date"] = "2026-11-25"
	_owner_info["equipment"] = "none (automated self-test)"
	_on_final(FINALS.find("APPROVED"))
	add.call("approval refused while fields are not all PASS", _owner_info["final"] == "NOT DECIDED" and _status_note.contains("every field PASS"), _status_note.left(80))
	for id: String in _decisions:
		_decisions[id] = "PASS"
	for blanks: Array in [["", "", ""], ["   ", "2026-11-25", "speakers"], ["Self-test", " ", "speakers"], ["Self-test", "2026-11-25", ""]]:
		_owner_info["name"] = blanks[0]
		_owner_info["date"] = blanks[1]
		_owner_info["equipment"] = blanks[2]
		_status_note = ""
		_on_final(FINALS.find("APPROVED"))
		var want := PackedStringArray()
		if String(blanks[0]).strip_edges() == "":
			want.append("the owner name")
		if String(blanks[1]).strip_edges() == "":
			want.append("the date")
		if String(blanks[2]).strip_edges() == "":
			want.append("the listening equipment and display")
		var named := true
		for w in want:
			named = named and _status_note.contains(w)
		add.call("approval refused with every field PASS but missing attribution %s; the missing items are named" % str(blanks),
			_owner_info["final"] == "NOT DECIDED" and named and not _status_note.contains("every field PASS"), want)
	_owner_info["name"] = "Self-test"
	_owner_info["date"] = "2026-11-25"
	_owner_info["equipment"] = "none (automated self-test)"
	_on_final(FINALS.find("APPROVED"))
	var approved_file: Variant = JSON.parse_string(FileAccess.get_file_as_string(_decisions_dir.path_join(DECISIONS_FILE + ".json")))
	add.call("approval accepted only with every field PASS and all attribution (scratch folder only)", _owner_info["final"] == "APPROVED"
		and approved_file is Dictionary and ((approved_file as Dictionary)["owner"] as Dictionary)["final"] == "APPROVED", _owner_info["final"])
	_set_owner("equipment", "")
	add.call("clearing the equipment after approval returns the final decision to NOT DECIDED", _owner_info["final"] == "NOT DECIDED", _owner_info["final"])
	_set_owner("equipment", "none (automated self-test)")
	_on_final(FINALS.find("APPROVED"))
	_set_decision("C-MEMORY", "FAIL")
	add.call("a FAIL after approval returns the final decision to NOT DECIDED", _owner_info["final"] == "NOT DECIDED", _owner_info["final"])
	_set_decision("C-MEMORY", "PASS")
	_loading = false

	# Save failures: the folder cannot be created (a file is in the way) / the file cannot be written.
	var blocker := run.path_join("blocker_file")
	_write(blocker, "not a folder\n")
	print("m1_review self-test: the next two save-failure checks print expected ERROR lines")
	for target: Array in [["the decisions folder cannot be created", blocker.path_join("decisions")], ["the decisions file cannot be written", run.path_join("unwritable")]]:
		if String(target[0]).contains("written"):
			_ensure_dir(String(target[1]).path_join(DECISIONS_FILE + ".json"))
		_decisions_dir = String(target[1])
		_save_state = ""
		var ok := _save()
		_refresh_all()
		var red := _status.get_theme_color("font_color") == Color("#ff6b6b")
		add.call("save failure when %s: _save() is false, status and summary say NOT SAVED in red, nothing says saved" % target[0],
			not ok and _save_state == "failed" and _status.text.contains("NOT SAVED") and _summary.text.contains("NOT SAVED")
			and not _status.text.contains("saved ") and red, {"returned": ok, "state": _save_state})
	_decisions_dir = run.path_join("approval")
	_save()
	_refresh_all()
	add.call("a later successful save clears the failure", _save_state == "ok" and not _status.text.contains("NOT SAVED"), _save_state)

	# Siren attack event (review-only player, source constants).
	var s := _siren_config()
	var shared: AudioStreamMP3 = load(String(s["path"]))
	_select_audio(_audio_cue_index("siren"))
	add.call("siren selected: the attack-event control is enabled (and only for the siren)", not _siren_button.disabled, true)
	var alarms := int(AudioService.requested.get(&"alarm", 0))
	_play_audio("siren")
	add.call("attack event: the alarm is requested through AudioService at once", int(AudioService.requested.get(&"alarm", 0)) == alarms + 1, alarms + 1)
	add.call("attack event: waiting %s s, the siren not yet playing" % s["delay_s"], _siren_state == "waiting" and is_equal_approx(_siren_wait, float(s["delay_s"])) and not _siren.playing, _siren_wait)
	_siren_step(1.0)
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_siren_step(5.0)
	var frozen := _siren_state == "waiting" and is_equal_approx(_siren_wait, float(s["delay_s"]) - 1.0) and _suspended and AudioService.suspended
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	add.call("attack event: the delay does not advance while the window is in the background", frozen and not _suspended, _siren_wait)
	_siren_step(float(s["delay_s"]) - 1.0 + 0.05)
	var st := _siren.stream as AudioStreamMP3
	add.call("attack event: after the delay the siren plays on the SFX bus at gain %s from %s s" % [snappedf(float(s["gain"]), 0.0001), s["start_s"]],
		_siren_state == "looping" and _siren.playing and _siren.bus == &"SFX" and is_equal_approx(_siren.volume_db, linear_to_db(float(s["gain"]))),
		{"state": _siren_state, "volume_db": snappedf(_siren.volume_db, 0.001)})
	add.call("attack event: a private copy loops from the trimmed start; the shared siren resource (AudioService one-shot) does not loop",
		st != null and st != shared and st.loop and is_equal_approx(st.loop_offset, float(s["loop_offset_s"])) and not shared.loop
		and is_equal_approx(st.get_length(), shared.get_length()), {"copy_loop": st.loop if st != null else null, "shared_loop": shared.loop})
	_siren_step(30.0)
	add.call("attack event: still looping 30 s later (no end until Stop)", _siren_state == "looping" and _siren.playing, _siren_state)
	for pair: Array in [[NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_IN, "focus out/in"], [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_RESUMED, "application paused/resumed"]]:
		get_tree().root.propagate_notification(int(pair[0]))
		var paused := _siren.stream_paused
		get_tree().root.propagate_notification(int(pair[1]))
		add.call("attack event: the looping siren pauses and resumes on %s" % pair[2], paused and not _siren.stream_paused, paused)
	_stop_audio(true)
	var start_db := _siren.volume_db
	_siren_step(0.2)
	var fading := _siren_state == "fading" and _siren.playing and _siren.volume_db < start_db - 20.0
	_siren_step(0.25)
	add.call("Stop: the siren fades out like the source's stopLoop() (time constant %s s) and stops after %s s" % [STOP_LOOP_TAU, STOP_LOOP_END],
		fading and _siren_state == "idle" and not _siren.playing, {"fading_ok": fading, "state": _siren_state})
	_play_audio("siren")
	_stop_audio(true)
	_siren_step(10.0)
	add.call("Stop during the delay: the siren never starts", _siren_state == "idle" and not _siren.playing, _siren_state)
	_play_audio("game")
	var last: Array = AudioService.started.back() if not AudioService.started.is_empty() else []
	add.call("game path for the siren: a generic AudioService one-shot (not looping) from its trimmed start",
		not last.is_empty() and last[0] == &"siren" and is_equal_approx(float(last[1]), float(s["start_s"])) and not shared.loop and _siren_state == "idle", str(last))
	_stop_audio()
	_select_audio(0)
	add.call("another item selected: the attack-event control is disabled", _siren_button.disabled, true)

	# Raw and loop-seam playback pause with the application, like the game.
	for case: Array in [["bark", "raw"], ["intro", "seam"]]:
		_select_audio(_audio_cue_index(String(case[0])))
		_play_audio(String(case[1]))
		var shared_raw: AudioStream = load(String(_audio[_audio_index]["path"]))
		var playing := _raw.playing and _raw.stream != shared_raw
		var results := []
		for pair: Array in [[NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_IN], [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_RESUMED]]:
			get_tree().root.propagate_notification(int(pair[0]))
			var paused := _raw.stream_paused
			get_tree().root.propagate_notification(int(pair[1]))
			results.append(paused and not _raw.stream_paused)
		get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		_play_audio(String(case[1]))
		var starts_paused := _raw.stream_paused
		get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN)
		add.call("%s playback (%s, private stream copy) pauses on focus out and application pause, resumes on return, and starts paused while in the background" % [case[1], case[0]],
			playing and results == [true, true] and starts_paused and not _raw.stream_paused, results)
		_stop_audio()

	# Audio durations at the tightened tolerance.
	var worst := 0.0
	for it: Dictionary in _audio:
		worst = maxf(worst, float(it["duration_delta_s"]))
	add.call("audio: every Godot stream length is within %s s of the source fixture duration" % DURATION_TOLERANCE, worst <= DURATION_TOLERANCE, worst)

	_select_audio(0)
	AudioService.apply_settings(false, SAFE_VOLUME)
	var failed := PackedStringArray()
	for c: Dictionary in checks:
		if not c["ok"]:
			failed.append(String(c["check"]))
	var result := {"ok": failed.is_empty(), "checks": checks.size(), "failed": failed, "content_fingerprint": _fingerprint["sha256"],
		"schema_version": SCHEMA_VERSION, "note": "drives the station's own code in a scratch folder; no human decision is made or implied"}
	var write_error := _write(_selftest_dir.path_join("station_selftest.json"), JSON.stringify({"result": result, "checks": checks}, "  ", true) + "\n")
	if write_error != "":
		result["ok"] = false
		result["write_error"] = write_error
	print("M1SELFTEST ", JSON.stringify(result))
	get_tree().quit(0 if result["ok"] else 1)
