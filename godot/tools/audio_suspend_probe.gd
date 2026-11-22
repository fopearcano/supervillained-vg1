extends SceneTree
## Live-playback check of AudioService background suspension: live music and effects pause and
## resume, a new effect requested in the background is dropped (not part of the suite: with the
## Dummy driver started playbacks are never mixed and leak at exit, F-07). Run it on a host with an
## audio device, without --headless, for a clean exit; prints a JSON verdict and exits 1 on failure:
##   godot --path godot --script res://tools/audio_suspend_probe.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var audio := root.get_node("AudioService")
	audio.output_available = true
	audio.play_music(&"greenzone")
	audio.play(&"bark")
	var live: Array = audio.players().filter(func(p: AudioStreamPlayer) -> bool: return p.playing)
	audio.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var paused: Array = live.map(func(p: AudioStreamPlayer) -> bool: return p.stream_paused and not p.playing)
	# A new effect requested in the background is dropped (source: the AudioContext is not running).
	audio.play(&"pee")
	var late: Array = audio.players().filter(func(p: AudioStreamPlayer) -> bool: return p.stream != null and not live.has(p))
	var late_dropped: bool = late.is_empty() and int(audio.dropped.get(&"suspended", 0)) == 1
	audio.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	var resumed: Array = live.map(func(p: AudioStreamPlayer) -> bool: return p.playing and not p.stream_paused)
	var replayed: bool = audio.players().any(func(p: AudioStreamPlayer) -> bool: return p.stream != null and not live.has(p))
	var ok: bool = live.size() == 2 and not paused.has(false) and late_dropped and not replayed and not resumed.has(false)
	print(JSON.stringify({"live_players": live.size(), "paused_in_background": paused, "late_effect_dropped": late_dropped, "replayed_on_resume": replayed, "resumed": resumed, "ok": ok}))
	audio.stop_all()
	# Let the audio server release the stopped playbacks before exiting (no leak report at exit).
	for k in 3:
		await process_frame
	quit(0 if ok else 1)
