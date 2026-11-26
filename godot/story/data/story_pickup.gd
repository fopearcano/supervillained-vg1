class_name StoryPickup
extends Resource
## Something an objective places for Zampanò to pick up (a scrap of the lecture, a rag): a spot
## ring with an optional sprite; picking it shows `text` above him and applies `effects`.

@export var id := ""
## A map marker id, or "" to use `point`.
@export var at := ""
@export var point := Vector2.ZERO
## "shard" (a scrap of the lecture) | "spot" (a thing on the ground).
@export var kind := "spot"
@export var label := ""
## Shown above him when picked ("" = none).
@export var text := ""
## Sprite catalogue key drawn at the spot ("" = only the ring).
@export var sprite := ""
@export var effects: Dictionary = {}
## When set, he carries the thing after picking it (CarryPresenter label).
@export var carry_label := ""
## Sound when picked (an AudioService cue).
@export var sound := "jingle"
## 8.2: a study object is what the dream made of it only if he saw that marvel: with `seen_marvel`
## in the book its label and line are `seen_label` and `seen_text`, otherwise `label` and `text`.
@export var seen_marvel := ""
@export var seen_label := ""
@export var seen_text := ""


func seen(state: Dictionary) -> bool:
	return seen_marvel != "" and ((state.get("book", {}) as Dictionary).get("marvels", []) as Array).has(seen_marvel)


func shown_label(state: Dictionary) -> String:
	return seen_label if seen(state) else label


func shown_text(state: Dictionary) -> String:
	return seen_text if seen(state) else text
