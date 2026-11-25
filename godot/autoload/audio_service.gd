extends Node
## Music continuity, buses and cue playback (port of src/core/audio.ts and src/fx/gameAudio.ts).
## - Tracks: the recorded files of src/fx/audioFiles.ts MUSIC_FILES ('intro' on reading screens,
##   'greenzone' during the walk, 'level2'-'level4') resume where they were left (source setTrack
##   keeps every element's position); 'medieval' (the synthesized dream loop) restarts from 0 on
##   every switch, like the source's new AudioBufferSourceNode.
## - Music level: AUDIO.MUSIC_VOLUME for 'medieval', AUDIO.MUSIC_FILE_VOLUME x the track's
##   AUDIO.MUSIC_FILE_GAIN trim for recorded tracks, times the duck factor.
## - Recorded effects (SOUND_FILES) start after their leading silence (source leadingSilence():
##   first sample above AUDIO.TRIM_LEVEL minus 10 ms), measured by tools/source_extract at 48 kHz.
## - Synthesized effects (src/fx/sounds.ts SOUNDS) are editor-rendered mono 22,050 Hz 16-bit PCM
##   WAVs (tools/source_extract); nothing is synthesized at runtime. They start at 0.
## - Effect requests follow src/core/audio.ts AudioEngine.play(): a request made while muted or
##   while the application is suspended (the source's AudioContext is not running) is dropped, not
##   deferred; the same cue again within 45 ms of audio time is dropped; `delay` (source
##   play({delay})) counts audio time, which does not advance while suspended.
## - In the background everything already playing or already scheduled is suspended (the source
##   suspends its AudioContext) and resumes on return.
## - Master level: muted or volume 0 is silence (bus muted), otherwise the volume (source master
##   gain `muted ? 0 : volume`).

const MUSIC := {
	&"intro": "res://assets/audio/recorded/intro-music.mp3",
	&"greenzone": "res://assets/audio/recorded/greenzone-music.mp3",
	&"level2": "res://assets/audio/recorded/level2-music.mp3",
	&"level3": "res://assets/audio/recorded/level3-music.mp3",
	&"level4": "res://assets/audio/recorded/level4-music.mp3",
	&"medieval": "res://assets/audio/synth/medieval.wav",
}
## Tracks that restart from the beginning instead of resuming (synthesized buffers in the source).
const RESTARTING_TRACKS: Array[StringName] = [&"medieval"]
const SFX := {
	&"bark": "res://assets/audio/recorded/dog-bark.mp3",
	&"treat": "res://assets/audio/recorded/food-collect.mp3",
	&"poop": "res://assets/audio/recorded/poos.mp3",
	&"pee": "res://assets/audio/recorded/pees-drop.mp3",
	&"drink": "res://assets/audio/recorded/pees-collect.wav",
	&"splash": "res://assets/audio/recorded/water.mp3",
	&"meow": "res://assets/audio/recorded/cat-meow.mp3",
	&"coin": "res://assets/audio/recorded/cash-after-cat.mp3",
	&"ball": "res://assets/audio/recorded/ball.mp3",
	&"alarm": "res://assets/audio/recorded/alarm-greenzone-under-attack.mp3",
	&"siren": "res://assets/audio/recorded/siren.mp3",
	&"laser": "res://assets/audio/recorded/laser-eyes.mp3",
}
const SYNTH_DIR := "res://assets/audio/synth/"
## src/fx/sounds.ts SOUNDS, in source order.
const SYNTH: Array[StringName] = [&"fetch", &"warning", &"empty", &"hurt", &"hit", &"swish", &"clang",
	&"flee", &"saved", &"star", &"jingle", &"gameover", &"click", &"glitch"]
## Generated Resource (exported); the source JSON is provenance only and is not exported.
const LEADING_SILENCE: SfxLeadingSilence = preload("res://data/audio/sfx_leading_silence.tres")
const POOL_SIZE := 8

var missing_cues: Dictionary = {}
## Every cue/track requested (tests assert the event->cue mapping through this).
var requested: Dictionary = {}
## Debug builds only: the last DIAG_LIMIT effects started, [[cue, offset, started_suspended], ...]
## (tests/diagnostics). Release builds record nothing.
const DIAG_LIMIT := 64
var diagnostics := OS.is_debug_build()
var started: Array = []
## False with the Dummy driver (headless, no sound card): requests are recorded, nothing plays,
## so no playback object is left unmixed at exit.
var output_available := true
## The track that should be playing ("" = none) and every track's resume position (seconds).
var current_track: StringName = &""
var track_positions: Dictionary = {}
var suspended := false
## Settings applied by AppState (source settings.muted / settings.volume).
var muted := false
var volume := 1.0
## Audio clock (source AudioContext.currentTime): seconds of unsuspended time since reset.
var audio_time := 0.0
## Effect requests dropped like the source drops them, by reason: muted, suspended, duplicate.
var dropped: Dictionary = {}
## Same-cue suppression window of the source play() (seconds of audio time).
const SAME_CUE_GAP := 0.045
## Seconds of leading silence skipped per effect.
var offsets: Dictionary = {}

var _music: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _streams: Dictionary = {}
var _duck := 1.0
## Delayed cues waiting for their start: [[cue, volume, pitch, seconds left], ...].
var _pending: Array = []
## Audio time of each cue's last accepted request (source lastPlayed).
var _last_played: Dictionary = {}
## Looping effects (source AudioEngine.loop: the siren during an attack): cue -> {"player":
## AudioStreamPlayer or null, "delay": seconds of audio time before it starts}.
var _loops: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	output_available = AudioServer.get_driver_name() != "Dummy"
	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	add_child(_music)
	for k in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_pool.append(p)
	offsets = LEADING_SILENCE.offsets.duplicate()


func apply_settings(p_muted: bool, p_volume: float) -> void:
	muted = p_muted
	volume = clampf(p_volume, 0.0, 1.0)
	var master := AudioServer.get_bus_index(&"Master")
	# Source master gain `muted ? 0 : volume`: zero is true silence, not a very low level.
	AudioServer.set_bus_mute(master, muted or volume <= 0.0)
	AudioServer.set_bus_volume_db(master, linear_to_db(volume) if volume > 0.0 else -80.0)


func _stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path)
	return _streams[path]


func _music_db() -> float:
	return linear_to_db(maxf(music_level(current_track), 0.0001))


## Linear music gain of `track` (source musicLevel() x the element's MUSIC_FILE_GAIN trim).
func music_level(track: StringName) -> float:
	if RESTARTING_TRACKS.has(track):
		return GameConfig.Audio.MUSIC_VOLUME * _duck
	return GameConfig.Audio.MUSIC_FILE_VOLUME * float(GameConfig.Audio.MUSIC_FILE_GAIN.get(String(track), 1.0)) * _duck


## The stream file of an effect cue ("" when the name is unknown).
func cue_path(cue: StringName) -> String:
	if SFX.has(cue):
		return SFX[cue]
	if SYNTH.has(cue):
		return SYNTH_DIR + String(cue) + ".wav"
	return ""


## Switches the music; the previous track keeps its position, the new one resumes from its own.
func play_music(track: StringName) -> void:
	requested[track] = int(requested.get(track, 0)) + 1
	if track == current_track:
		return
	if current_track != &"" and output_available and _music.playing:
		track_positions[current_track] = _music.get_playback_position()
	current_track = track
	if not output_available:
		return
	var stream := _stream(MUSIC[track])
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	_music.stream = stream
	_music.volume_db = _music_db()
	_music.play(0.0 if RESTARTING_TRACKS.has(track) else float(track_positions.get(track, 0.0)))
	_music.stream_paused = suspended


func stop_music() -> void:
	if current_track != &"" and output_available and _music.playing:
		track_positions[current_track] = _music.get_playback_position()
	_music.stop()
	current_track = &""


## Ducking factor applied to the music (pause, level end).
func set_duck(factor: float) -> void:
	_duck = factor
	_music.volume_db = _music_db()


func play(cue: StringName, gain: float = 1.0, pitch: float = 1.0, delay: float = 0.0) -> void:
	requested[cue] = int(requested.get(cue, 0)) + 1
	var path := cue_path(cue)
	if path == "":
		missing_cues[cue] = int(missing_cues.get(cue, 0)) + 1
		return
	# Source play(): nothing while muted or while the context is not running (background); the
	# same cue again within 45 ms is dropped; the time is taken when the request is made.
	if muted:
		_drop(&"muted")
		return
	if suspended:
		_drop(&"suspended")
		return
	if audio_time - float(_last_played.get(cue, -1.0)) < SAME_CUE_GAP:
		_drop(&"duplicate")
		return
	_last_played[cue] = audio_time
	if delay > 0.0:
		_pending.append([cue, gain, pitch, delay])
		return
	_start(cue, path, gain, pitch)


func _drop(reason: StringName) -> void:
	dropped[reason] = int(dropped.get(reason, 0)) + 1


func _start(cue: StringName, path: String, gain_scale: float, pitch: float) -> void:
	var offset: float = offsets.get(cue, 0.0)
	if diagnostics:
		started.append([cue, offset, suspended])
		if started.size() > DIAG_LIMIT:
			started.pop_front()
	if not output_available:
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = _stream(path)
	var gain: float = GameConfig.Audio.FILE_GAIN.get(String(cue), 1.0)
	p.volume_db = linear_to_db(GameConfig.Audio.SFX_VOLUME * gain * gain_scale)
	p.pitch_scale = pitch
	p.play(offset)


## Advances the audio clock and the delayed cues by `delta` seconds (both frozen while suspended,
## like the source AudioContext).
func advance_pending(delta: float) -> void:
	if suspended:
		return
	audio_time += delta
	for cue: StringName in _loops.keys():
		var entry: Dictionary = _loops[cue]
		if float(entry["delay"]) > 0.0:
			entry["delay"] = float(entry["delay"]) - delta
			if float(entry["delay"]) <= 0.0:
				_start_loop(cue)
	if _pending.is_empty():
		return
	var due: Array = []
	for item: Array in _pending:
		item[3] = float(item[3]) - delta
		if float(item[3]) <= 0.0:
			due.append(item)
	for item: Array in due:
		_pending.erase(item)
		_start(item[0], cue_path(item[0]), item[1], item[2])


func pending_count() -> int:
	return _pending.size()


## Starts a looping effect once (source loop(name, {volume, delay})): from its leading-silence
## offset to the end, at SFX volume x the file trim x `gain`, after `delay` seconds of audio time.
## A second request while it loops is ignored.
func loop(cue: StringName, gain: float = 1.0, delay: float = 0.0) -> void:
	if _loops.has(cue) or not SFX.has(cue):
		return
	requested[cue] = int(requested.get(cue, 0)) + 1
	var player: AudioStreamPlayer = null
	if output_available:
		var stream: AudioStream = _stream(SFX[cue]).duplicate()
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
			(stream as AudioStreamMP3).loop_offset = float(offsets.get(cue, 0.0))
		player = AudioStreamPlayer.new()
		player.bus = &"SFX"
		player.stream = stream
		var trim: float = GameConfig.Audio.FILE_GAIN.get(String(cue), 1.0)
		player.volume_db = linear_to_db(GameConfig.Audio.SFX_VOLUME * trim * gain)
		player.stream_paused = suspended
		add_child(player)
	_loops[cue] = {"player": player, "delay": delay}
	if delay <= 0.0:
		_start_loop(cue)


func _start_loop(cue: StringName) -> void:
	var entry: Dictionary = _loops[cue]
	entry["delay"] = 0.0
	var player: AudioStreamPlayer = entry["player"]
	if player:
		player.play(float(offsets.get(cue, 0.0)))


## Stops a looping effect (source stopLoop).
func stop_loop(cue: StringName) -> void:
	if not _loops.has(cue):
		return
	var player: AudioStreamPlayer = _loops[cue]["player"]
	_loops.erase(cue)
	if player:
		player.stop()
		player.queue_free()


func stop_all_loops() -> void:
	for cue: StringName in _loops.keys():
		stop_loop(cue)


## Loops requested and not stopped (started or still waiting for their delay).
func active_loops() -> Array:
	return _loops.keys()


## True when the loop has started (its delay elapsed).
func loop_started(cue: StringName) -> bool:
	return _loops.has(cue) and float(_loops[cue]["delay"]) <= 0.0


func _process(delta: float) -> void:
	advance_pending(delta)


## Suspends (true) or resumes (false) every player: music and effects.
func set_suspended(on: bool) -> void:
	suspended = on
	_music.stream_paused = on
	for p in _pool:
		p.stream_paused = on
	for cue: StringName in _loops:
		var lp: AudioStreamPlayer = _loops[cue]["player"]
		if lp:
			lp.stream_paused = on


func players() -> Array[AudioStreamPlayer]:
	var out: Array[AudioStreamPlayer] = [_music]
	out.append_array(_pool)
	return out


func _notification(what: int) -> void:
	if _music == null:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		set_suspended(true)
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		set_suspended(false)


## Stops every player and forgets session state (scene teardown, app exit, tests).
func stop_all() -> void:
	stop_all_loops()
	_pending.clear()
	_last_played.clear()
	stop_music()
	_music.stream = null
	for p in _pool:
		p.stop()
		p.stream = null


func reset_for_tests() -> void:
	stop_all()
	set_suspended(false)
	requested.clear()
	missing_cues.clear()
	dropped.clear()
	audio_time = 0.0
	started.clear()
	diagnostics = OS.is_debug_build()
	track_positions.clear()
	_duck = 1.0
