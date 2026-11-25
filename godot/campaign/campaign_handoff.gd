class_name CampaignHandoff
extends RefCounted
## The Green Zone → campaign handoff (source Flow.levelComplete `next`: story.addWalk(coins, time)
## then the story continues from 1.0 into 1.1). M3 defines only the data contract and a stub
## receiver: no story content, no campaign state and no persistence (those arrive with M4/M5).

const FROM := "1.0"
const TO := "1.1"


## The handoff data for a completed walk: the level-end result, the walk's time and coins.
static func from_result(result: Dictionary) -> Dictionary:
	var stats: Dictionary = result.get("stats", {})
	return {
		"from": FROM,
		"to": TO,
		"result": result.duplicate(true),
		"time": float(stats.get("time", 0.0)),
		"coins": int(stats.get("coins", 0)),
	}


## Stub receiver (Main owns one): records what it was handed and does nothing else yet.
class Receiver:
	extends RefCounted

	signal received(data: Dictionary)

	var handoffs: Array[Dictionary] = []

	func receive(data: Dictionary) -> void:
		handoffs.append(data)
		received.emit(data)

	func last() -> Dictionary:
		return handoffs.back() if not handoffs.is_empty() else {}
