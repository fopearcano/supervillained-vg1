class_name LetterGame
extends RefCounted
## 5.4's writing table (port of src/story/minigames/words.ts LetterGame): the barons' account is
## assembled from fragments in a fixed order — each slot's text before it, then the chosen word; a tap
## on a slot cycles its word. Reading it aloud sends it (the answer phase shows the two accounts of the
## reply, kept apart); WRITE IT AGAIN returns to the table; HEAR THE ANSWER OUT finishes: "named" when
## the debt slot names the debt, else "necessity". Every word is in the step's Resource (`slots`).
## Pure logic: the step maps taps to button ids (`layout`), the view draws the same layout.

var slots: Array = []
var picks: Array[int] = []
## The slot and option that name the debt outright.
var debt_slot := 1
var debt_option := 1
var phase := "write"
var sent := 0
var outcome := ""
var events: Array[String] = []


func setup(p_slots: Array, p_debt_slot: int, p_debt_option: int) -> LetterGame:
	slots = p_slots
	debt_slot = p_debt_slot
	debt_option = p_debt_option
	picks = []
	for s: Dictionary in slots:
		picks.append(0)
	return self


## The letter as assembled, fragments in order.
func letter() -> String:
	var out := ""
	for k in slots.size():
		var s: Dictionary = slots[k]
		out += String(s["before"]) + String((s["options"] as Array)[picks[k]])
	return out + "."


## Buttons [{"id", "rect": Rect2}] at view width `w` (the source's layout: from y 200 in the write
## phase, y 320 in the answer phase; each 16 px + 4).
func layout(w: float) -> Array:
	var out: Array = []
	var y := 200.0
	if phase == "write":
		for k in slots.size():
			out.append({"id": "slot%d" % k, "rect": Rect2(16, y, w - 32, 16)})
			y += 20.0
		out.append({"id": "send", "rect": Rect2(16, y + 6, w - 32, 16)})
	else:
		y = 320.0
		out.append({"id": "again", "rect": Rect2(16, y, w - 32, 16)})
		out.append({"id": "accept", "rect": Rect2(16, y + 20, w - 32, 16)})
	return out


## Handles one pick ("slotN", "send", "again", "accept"; "" = none). "running" | "won".
func pick(id: String) -> String:
	events.clear()
	if id == "":
		return "running"
	events.append("click")
	if id.begins_with("slot"):
		var k := int(id.substr(4))
		picks[k] = (picks[k] + 1) % (slots[k]["options"] as Array).size()
	elif id == "send" and phase == "write":
		sent += 1
		phase = "answer"
		events.append("sent")
	elif id == "again" and phase == "answer":
		phase = "write"
	elif id == "accept" and phase == "answer":
		outcome = "named" if picks[debt_slot] == debt_option else "necessity"
		return "won"
	return "running"
