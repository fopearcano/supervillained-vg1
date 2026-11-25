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
