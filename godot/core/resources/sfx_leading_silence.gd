class_name SfxLeadingSilence
extends Resource
## Seconds of leading silence skipped at the start of each recorded prototype effect.

@export var audited_commit := ""
@export var runtime_rate := 48000
@export var trim_level := 0.0
## cue -> seconds
@export var offsets: Dictionary[StringName, float] = {}
