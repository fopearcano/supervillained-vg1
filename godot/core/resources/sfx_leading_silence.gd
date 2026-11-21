class_name SfxLeadingSilence
extends Resource
## Seconds of leading silence skipped at the start of each recorded effect (the source's
## leadingSilence(): first sample above AUDIO.TRIM_LEVEL minus 10 ms), measured by
## tools/source_extract in Chromium at `runtime_rate`. Built by tools/build_resources.gd from
## data/audio/sfx_leading_silence.json; the JSON is provenance only and is not exported.

@export var audited_commit := ""
@export var runtime_rate := 48000
@export var trim_level := 0.0
## cue -> seconds
@export var offsets: Dictionary[StringName, float] = {}
