class_name PlayableCharacterProfile
extends Resource
## Zampano's animation and collision data for the prototype.

@export var id: StringName
@export var display_name: String
@export var normal_frames: SpriteFrames
## Contact point inside a 40×40 frame (pixels from the top-left).
@export var foot_anchor := Vector2i(20, 36)
@export var frame_size := Vector2i(40, 40)
@export var collision_radius := 0.26
## The plain costume sits and then alternates sitting/sniffing when idle (has a `sit` action).
@export var has_seated_idle := true
## Animation durations (seconds) of one full cycle, keyed by action, for fitting action timers.
@export var action_durations: Dictionary = {}
## Actions whose authored holds are fitted to the rule timer (source frameDurationsMs present).
@export var timed_actions: PackedStringArray = []
