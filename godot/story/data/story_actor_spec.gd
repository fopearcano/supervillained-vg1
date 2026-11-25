class_name StoryActorSpec
extends Resource
## An actor a StageStep places: a handle for later steps, its cast role (or "legs" for the
## Professor at the dog's eye level), where it stands and what it does first.

@export var name := ""
@export var role := ""
## A map marker id, or "" to use `point`.
@export var at := ""
@export var point := Vector2.ZERO
@export var face := "S"
## "idle" | "goto" | "follow".
@export var behavior := "idle"
## goto target (marker id or "" for `target_point`).
@export var target := ""
@export var target_point := Vector2.ZERO
@export var speed := 2.0
## "player" faces the player.
@export var face_player := false
