class_name PlayableCharacterProfile
extends Resource
## A playable dog (ARCHITECTURE.md §9.1). The same PlayableDog scene plays Zampanò, Sbrimbrulòn
## and Bagnaskiz from these resources; only Zampanò is canonical in the campaign.

@export var id: StringName
@export var display_name: String
## Costumes: normal (reality), cross-equivalent and armoured (dream). Cross aliases armour art.
@export var normal_frames: SpriteFrames
@export var cross_frames: SpriteFrames
@export var armoured_frames: SpriteFrames
## Contact point inside a 40×40 frame (pixels from the top-left).
@export var foot_anchor := Vector2i(20, 36)
@export var frame_size := Vector2i(40, 40)
@export var collision_radius := 0.26
@export var sprite_scale := 1.0
@export var can_bark := true
@export var can_use_arms_when_armoured := true
## The plain costume sits and then alternates sitting/sniffing when idle (has a `sit` action).
@export var has_seated_idle := true
@export var name_color := Color.WHITE
## Animation durations (seconds) of one full cycle, keyed by action, for fitting action timers.
@export var action_durations: Dictionary = {}
## Actions whose authored holds are fitted to the rule timer (source frameDurationsMs present).
@export var timed_actions: PackedStringArray = []
