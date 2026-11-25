class_name BoatGame
extends RefCounted
## 4.2: easing the skiff alongside (port of src/story/minigames/action.ts BoatGame). Each stroke moves
## it BOAT_STROKE closer; a stroke sooner than BOAT_MIN_GAP after the last sloshes BOAT_SPLASH of water
## in instead; the water drains at BOAT_DRAIN per second; at a full boat he is swamped: half the
## distance lost and BOAT_SWAMP_TIME without strokes. Won when alongside (progress 1); there is no
## lost result. Pure logic; the step reads the strokes, the view draws the two bars.

const S := GameConfig.Story

var time := 0.0
var progress := 0.0
var water := 0.0
var last_stroke := -9.0
var swamped_t := 0.0
## Events of the last update ("stroke", "splash", "swamped").
var events: Array[String] = []


func update(dt: float, strokes: int) -> String:
	events.clear()
	time += dt
	swamped_t -= dt
	if strokes > 0 and swamped_t <= 0.0:
		if time - last_stroke < S.BOAT_MIN_GAP:
			water += S.BOAT_SPLASH
			events.append("splash")
		else:
			progress = minf(1.0, progress + S.BOAT_STROKE)
			events.append("stroke")
		last_stroke = time
	water = maxf(0.0, water - S.BOAT_DRAIN * dt)
	if water >= 1.0:
		water = 0.0
		progress = maxf(0.0, progress - 0.5)
		swamped_t = S.BOAT_SWAMP_TIME
		events.append("swamped")
	return "won" if progress >= 1.0 else "running"
