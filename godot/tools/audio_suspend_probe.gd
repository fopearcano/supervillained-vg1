extends SceneTree
## Live-playback check of AudioService background suspension (not part of the suite: with the
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
	audio.play(&"pee")
	var late: Array = audio.players().filter(func(p: AudioStreamPlayer) -> bool: return p.stream != null and not live.has(p))
	var late_paused: bool = late.size() == 1 and late[0].stream_paused
	audio.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	var resumed: Array = live.map(func(p: AudioStreamPlayer) -> bool: return p.playing and not p.stream_paused)
	var ok: bool = live.size() == 2 and not paused.has(false) and late_paused and not resumed.has(false)
	print(JSON.stringify({"live_players": live.size(), "paused_in_background": paused, "late_effect_paused": late_paused, "resumed": resumed, "ok": ok}))
	audio.stop_all()
	# Let the audio server release the stopped playbacks before exiting (no leak report at exit).
	for k in 3:
		await process_frame
	quit(0 if ok else 1)
