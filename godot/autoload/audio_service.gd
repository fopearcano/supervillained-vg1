extends Node
## Music continuity, buses and cue playback (port of the recorded-file half of src/core/audio.ts
## and src/fx/gameAudio.ts). Synthesized cues are rendered to WAV in a later milestone; until then
## a synthesized cue name is a silent no-op that is counted in `missing_cues` for review.

const MUSIC := {
	&"greenzone": "res://assets/audio/recorded/greenzone-music.mp3",
}
const SFX := {
	&"bark": "res://assets/audio/recorded/dog-bark.mp3",
	&"treat": "res://assets/audio/recorded/food-collect.mp3",
	&"poop": "res://assets/audio/recorded/poos.mp3",
	&"pee": "res://assets/audio/recorded/pees-drop.mp3",
	&"drink": "res://assets/audio/recorded/pees-collect.wav",
	&"splash": "res://assets/audio/recorded/water.mp3",
}
const POOL_SIZE := 8

var missing_cues: Dictionary = {}
## Every cue/track requested (tests assert the event->cue mapping through this).
var requested: Dictionary = {}
## False with the Dummy driver (headless, no sound card): requests are recorded, nothing plays,
## so no playback object is left unmixed at exit.
var output_available := true
var _music: AudioStreamPlayer
var _music_track: StringName = &""
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _streams: Dictionary = {}
var _duck := 1.0


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


func apply_settings(muted: bool, volume: float) -> void:
	var master := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_mute(master, muted)
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(volume, 0.0001)))


func _stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path)
	return _streams[path]


func play_music(track: StringName) -> void:
	requested[track] = int(requested.get(track, 0)) + 1
	if track == _music_track and (_music.playing or not output_available):
		return
	_music_track = track
	if not output_available:
		return
	var stream := _stream(MUSIC[track])
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	_music.stream = stream
	_music.volume_db = linear_to_db(GameConfig.Audio.MUSIC_FILE_VOLUME * _duck)
	_music.play()


func stop_music() -> void:
	_music.stop()
	_music_track = &""


## Ducking factor applied to the music (pause, level end).
func set_duck(factor: float) -> void:
	_duck = factor
	if _music.playing:
		_music.volume_db = linear_to_db(maxf(GameConfig.Audio.MUSIC_FILE_VOLUME * _duck, 0.0001))


func play(cue: StringName, volume: float = 1.0, pitch: float = 1.0) -> void:
	requested[cue] = int(requested.get(cue, 0)) + 1
	if not SFX.has(cue):
		missing_cues[cue] = int(missing_cues.get(cue, 0)) + 1
		return
	if not output_available:
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = _stream(SFX[cue])
	var gain: float = GameConfig.Audio.FILE_GAIN.get(String(cue), 1.0)
	p.volume_db = linear_to_db(GameConfig.Audio.SFX_VOLUME * gain * volume)
	p.pitch_scale = pitch
	p.play()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _music:
			_music.stream_paused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if _music:
			_music.stream_paused = false


## Stops every player (scene teardown, app exit, test runner shutdown).
func stop_all() -> void:
	stop_music()
	_music.stream = null
	for p in _pool:
		p.stop()
		p.stream = null
