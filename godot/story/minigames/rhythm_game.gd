class_name RhythmGame
extends RefCounted
## A beat game, single mode (port of src/story/minigames/rhythm.ts RhythmGame; 4.1's parade, 4.3's
## rowing): cues travel toward a hit line, one per beat; a press within RHYTHM_WINDOW of an unjudged
## beat is a hit, a press outside any window is "too early" (no effect), a beat left unjudged past its
## window is a miss. The game ends RESULT_AFTER seconds after the last beat: won with `need` hits or
## more, otherwise lost. Deterministic: beat k is at k × 60 / bpm; time starts at −START_DELAY.
## Pure logic: the step reads the inputs and the view draws `time`, `judged` and the feedback.

const S := GameConfig.Story
const RESULT_AFTER := 0.8

var beats := 12
var bpm := 72.0
var need := 8
var time := 0.0
var hits := 0
## beat index -> true (hit) / false (miss)
var judged: Dictionary = {}
## "hit" | "miss" | "early" | "" and how long it still shows.
var feedback := ""
var feedback_t := 0.0
## Metronome: the last beat whose click was played (-1 = none).
var last_click := -1
## Events of the last update, in order ("click", "hit", "miss", "early"): the step plays their sounds.
var events: Array[String] = []


func setup(p_beats: int, p_bpm: float, p_need: int) -> RhythmGame:
	beats = p_beats
	bpm = p_bpm
	need = p_need
	time = -S.RHYTHM_START_DELAY
	return self


func beat_time() -> float:
	return 60.0 / bpm


func beat_at(k: int) -> float:
	return k * beat_time()


## The nearest beat to now and how far off it is (seconds, signed).
func nearest() -> Array:
	var k := int(round(time / beat_time()))
	return [k, time - beat_at(k)]


## One update: `pressed` is this tick's press. "running" | "won" | "lost".
func update(dt: float, pressed: bool) -> String:
	events.clear()
	time += dt
	feedback_t = maxf(0.0, feedback_t - dt)
	var idx := int(floor(time / beat_time()))
	if idx >= 0 and idx != last_click and idx < beats:
		last_click = idx
		events.append("click")
	if pressed:
		var n := nearest()
		var k := int(n[0])
		if k >= 0 and k < beats and absf(float(n[1])) <= S.RHYTHM_WINDOW and not judged.has(k):
			_judge(k, true)
		else:
			_show("early", 0.4)
			events.append("early")
	for k in beats:
		if not judged.has(k) and time - beat_at(k) > S.RHYTHM_WINDOW:
			_judge(k, false)
	if time > beat_at(beats - 1) + RESULT_AFTER:
		return "won" if hits >= need else "lost"
	return "running"


func _judge(k: int, ok: bool) -> void:
	judged[k] = ok
	if ok:
		hits += 1
	_show("hit" if ok else "miss", 0.6)
	events.append("hit" if ok else "miss")


func _show(what: String, seconds: float) -> void:
	feedback = what
	feedback_t = seconds
