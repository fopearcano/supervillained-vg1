class_name TugGame
extends RefCounted
## A tug against a force that keeps growing (port of src/story/minigames/action.ts TugGame): each
## pull (a tap, J/X, Space, Enter) moves the rope back TUG_PULL; the force is TUG_BASE + time ×
## TUG_GROW per second; the rope is kept within [-0.3, 1]. It is meant to be lost: when the rope
## reaches 1 the result is "lost" (7.1: nobody recognizes the prince however hard he rows; 7.7:
## Aleaume wriggles free into the breach). There is no won result. Pure logic; the step reads the
## pulls, the view draws the rope.

const S := GameConfig.Story

var time := 0.0
var pos := 0.0
var pulls := 0
var events: Array[String] = []


func update(dt: float, p_pulls: int) -> String:
	events.clear()
	time += dt
	var force := S.TUG_BASE + time * S.TUG_GROW
	pos = clampf(pos + force * dt - p_pulls * S.TUG_PULL, -0.3, 1.0)
	pulls += p_pulls
	if p_pulls > 0:
		events.append("pull")
	return "lost" if pos >= 1.0 else "running"
