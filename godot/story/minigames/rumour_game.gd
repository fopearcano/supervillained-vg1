class_name RumourGame
extends RefCounted
## 6.2's garbled news (port of src/story/minigames/words.ts RumourGame): the pieces of the offer reach
## him one every RUMOUR_ARRIVE_EVERY seconds, in a shuffled order (a generator seeded by the scene);
## each shows garbled; a tap on the piece that comes next in the offer's own order places it (its full
## text joins the account); a tap on a later one is "garbled: that came later" and places nothing.
## Won when every piece is placed; there is no lost result. Pure logic: the step maps taps to pieces
## through `layout`, the view draws the same layout. Every word is in the step's Resource.

const S := GameConfig.Story

var pieces: Array = []
## Arrival order (piece indices), the pieces arrived so far, the pieces placed (in order).
var order: Array[int] = []
var arrived := 0
var placed: Array[int] = []
var wrong := 0
var arrive_t := 0.0
var events: Array[String] = []


func setup(p_pieces: Array, seed_value: int) -> RumourGame:
	pieces = p_pieces
	order = []
	for k in pieces.size():
		order.append(k)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for k in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var tmp := order[k]
		order[k] = order[j]
		order[j] = tmp
	return self


## The buttons of the arrived, unplaced pieces [{"id": piece index, "rect"}], from y 220 (source).
func layout(w: float) -> Array:
	var out: Array = []
	var y := 220.0
	for n in arrived:
		var k := order[n]
		if placed.has(k):
			continue
		out.append({"id": k, "rect": Rect2(10, y, w - 20, 16)})
		y += 20.0
	return out


## One update: `tapped` is the tapped piece's index (-1 = none). "running" | "won".
func update(dt: float, tapped: int) -> String:
	events.clear()
	arrive_t -= dt
	if arrived < pieces.size() and arrive_t <= 0.0:
		arrive_t = S.RUMOUR_ARRIVE_EVERY
		arrived += 1
		events.append("arrive")
	if tapped >= 0:
		if tapped == placed.size():
			placed.append(tapped)
			events.append("placed")
		else:
			wrong += 1
			events.append("wrong")
	return "won" if placed.size() == pieces.size() else "running"
