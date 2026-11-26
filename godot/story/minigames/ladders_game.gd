class_name LaddersGame
extends RefCounted
## 5.2's siege ladder (port of the current, non-hard branch of src/story/minigames/action.ts
## LaddersGame): three ladders against the wall; climb a rung per press, never faster than one per
## LADDER_CLIMB_GAP (the input cap); change ladder left/right. Stones fall down the ladders (a
## LADDER_WARN warning, then the stone); one that meets him knocks him LADDER_HIT_TIME and slides
## him down LADDER_SLIDE_TIME × LADDER_SLIDE_RATE rungs: progress is lost, the climb goes on. Won at
## the top (`rungs`); there is no lost result. The dormant pitch, axe-men and hard-assault branches
## are not ported. Stones come from a generator seeded by the scene, so a run is reproducible. Pure
## logic; the step reads the inputs and the view draws it.

const S := GameConfig.Story

var rungs := 16
var lane := 1
## Fractional while sliding.
var rung := 0.0
var slide := 0.0
var hit_t := 0.0
var climb_t := 0.0
var spawn_t := 1.0
## [{"lane": int, "y": float, "warn": float}] (screen px from the top of the view).
var falling: Array = []
var view_h := 432.0
var hits := 0
var events: Array[String] = []
var _rng := RandomNumberGenerator.new()


func setup(p_rungs: int, p_view_h: float, seed_value: int) -> LaddersGame:
	rungs = p_rungs
	view_h = p_view_h
	_rng.seed = seed_value
	return self


## Screen y of a rung, scrolling so he stays in the lower part of the view (source rungY).
func rung_y(r: float) -> float:
	var scroll := maxf(0.0, rung - 6.0) * S.LADDER_RUNG_PX
	return view_h - 70.0 - r * S.LADDER_RUNG_PX + scroll


func hero_y() -> float:
	return rung_y(rung)


## One update: climbs pressed this tick, lane moves (-1/+1 per press). "running" | "won".
func update(dt: float, climbs: int, lane_moves: Array) -> String:
	events.clear()
	for m: int in lane_moves:
		lane = clampi(lane + m, 0, 2)
	climb_t -= dt
	if climbs > 0 and hit_t <= 0.0 and slide <= 0.0 and climb_t <= 0.0:
		climb_t = S.LADDER_CLIMB_GAP
		rung += 1.0
		events.append("climb")
	if slide > 0.0:
		slide -= dt
		rung = maxf(0.0, rung - dt * S.LADDER_SLIDE_RATE)
	hit_t -= dt
	spawn_t -= dt
	if spawn_t <= 0.0:
		spawn_t = S.LADDER_SPAWN * (0.7 + _rng.randf() * 0.6)
		falling.append({"lane": _rng.randi_range(0, 2), "y": -20.0, "warn": S.LADDER_WARN})
	var hy := hero_y()
	for k in range(falling.size() - 1, -1, -1):
		var f: Dictionary = falling[k]
		if float(f["warn"]) > 0.0:
			f["warn"] = float(f["warn"]) - dt
			continue
		f["y"] = float(f["y"]) + dt * S.LADDER_STONE_SPEED
		if int(f["lane"]) == lane and absf(float(f["y"]) - (hy - 14.0)) < 12.0 and hit_t <= 0.0:
			hit_t = S.LADDER_HIT_TIME
			slide = S.LADDER_SLIDE_TIME
			hits += 1
			events.append("hit")
			falling.remove_at(k)
			continue
		if float(f["y"]) > view_h + 20.0:
			falling.remove_at(k)
	return "won" if rung >= rungs else "running"


## Lanes with a stone coming at him (warning shown, or falling above him): what a player sees.
func threatened(l: int) -> bool:
	var hy := hero_y()
	for f: Dictionary in falling:
		if int(f["lane"]) == l and (float(f["warn"]) > 0.0 or (float(f["y"]) < hy and float(f["y"]) > hy - 150.0)):
			return true
	return false
