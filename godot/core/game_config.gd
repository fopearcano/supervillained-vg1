class_name GameConfig
extends RefCounted
## Every tuning number used by the port, copied from src/config.ts (audited commit 95b69c0).
## Units: distances in grid tiles, time in seconds, speeds in tiles/second, screen sizes in
## logical pixels. Values are verified against the source export by the CFG-001 content test;
## never change one to compensate for a porting bug.


class Display:
	const TARGET_WIDTH := 216
	const MIN_WIDTH := 192
	const MAX_WIDTH := 270
	const MAX_ASPECT := 0.62
	const MIN_ASPECT := 0.42


class Loop:
	const STEP := 1.0 / 60.0
	const MAX_FRAME := 0.25
	const MAX_STEPS := 6


class Iso:
	const TILE_W := 32
	const TILE_H := 16


class Camera:
	const FOLLOW_RATE := 5.0
	const LOOK_AHEAD := 22.0
	const LOOK_AHEAD_RATE := 2.5
	const BIAS_Y := -18.0
	const SWAY_AMPLITUDE := 1.2
	const SWAY_SPEED := 0.7
	const BOUNDS_MARGIN := 8.0


class Player:
	const WALK_SPEED := 4.4
	const RUN_SPEED := 7.5
	const ACCEL := 16.0
	const DECEL := 20.0
	const RADIUS := 0.26
	const BOB_AMOUNT := 0.06
	const IDLE_PHASE_TIME := 3.0
	const HURT_INVULN := 2.0
	const MARK_DISTANCE := 1.05
	const DRINK_DISTANCE := 1.0
	const BOUNCE := 1.5


class Energy:
	const MAX := 100.0
	const DRAIN_RUN := 20.0
	const RECOVER_IDLE := 24.0
	const RECOVER_WALK := 13.0
	const MIN_TO_RUN := 35.0
	const HUNGRY_RECOVERY := 0.5


class InputCfg:
	const JOYSTICK_RADIUS := 22.0
	const JOYSTICK_DEADZONE := 0.18
	const JOYSTICK_ZONE := 0.62
	const ACTION_TTL := 0.25
	const TAP_SLOP := 10.0
	const KEYBOARD_WALK_MAG := 0.8
	const SWIPE_MIN := 16.0
	const SWIPE_MAX_TIME := 0.45
	const SWIPE_RATIO := 1.2
	const DOUBLE_TAP_TIME := 0.32
	const DOUBLE_TAP_DIST := 18.0
	const TAP_MAX_TIME := 0.3
	const GESTURE_FLASH := 0.5


class Occlusion:
	const FADED_ALPHA := 0.42
	const FADE_RATE := 10.0


class Hunger:
	const MAX := 100.0
	const START := 100.0
	const DRAIN_IDLE := 1.4
	const DRAIN_WALK := 2.98
	const DRAIN_RUN := 4.52
	const REFILL_ON_LIFE_LOST := 50.0
	const LOW_WARNING := 25.0


class Treat:
	const HUNGER := 16.0
	const DIGESTION := 26.0
	const SCORE := 50
	const PICKUP_RADIUS := 0.55


class Digestion:
	const MAX := 100.0
	const WARNING_TIME := 3.0
	const SQUAT_TIME := 0.8


class Poop:
	const LOW := {"radius": 0.9, "strength": 0.75}
	const MEDIUM := {"radius": 1.7, "strength": 1.0}
	const HEAVY := {"radius": 2.6, "strength": 1.0}
	const GROW_FACTOR := 1.45
	const GROW_TIME := 35.0
	const GROW_TICK := 0.5
	const CLEAN_SCORE := 100


class Bladder:
	const MAX_CHARGES := 3
	const START_CHARGES := 3
	const REGEN_TIME := 18.0
	const PEE_TIME := 0.7
	const MARK_TIME := 0.9
	const RADIUS := 2.2
	const MARK_RADIUS := 3.2
	const SCORE := 20
	const MARK_SCORE := 150
	const DRINK_COOLDOWN := 1.5
	const DRINK_TIME := 0.6


class Pollution:
	const CLEAN_THRESHOLD := 0.3
	const VISIBLE := 0.04
	const OVERLAY_MIN_ALPHA := 0.3
	const OVERLAY_MAX_ALPHA := 0.95
	const FRESH_TIME := 1.2


class Zone:
	const HEALTH_ZERO_STARS := 0.8
	const HEALTH_FULL_STARS := 0.995
	const PEE_DEFICIT_PENALTY := 0.012


class Lives:
	const START := 2
	const MAX := 9
	const SPEED_COST := 0.05


class Score:
	const TIME_BONUS_PER_SECOND := 10
	const STAR_BONUS := 500


class Bark:
	const COOLDOWN := 0.45
	const RANGE := 2.8
	const HALF_ANGLE := 0.75
	const WAVE_SPEED := 9.0
	const ANIM_TIME := 0.3


class Fx:
	const SHAKE_DECAY := 9.0
	const SHAKE_POOP := 2.0
	const SHAKE_HURT := 4.0
	const SHAKE_BARK := 1.2
	const SHAKE_HIT := 3.0
	const POPUP_TIME := 1.1
	const SCORE_POPUP_TIME := 0.9
	const TRANSITION_TIME := 0.45


class Audio:
	const DEFAULT_VOLUME := 0.7
	const MUSIC_FILE_VOLUME := 0.55
	const SFX_VOLUME := 0.9
	const FILE_GAIN := {"coin": 2.4, "laser": 1.3, "poop": 1.2, "meow": 1.1, "siren": 0.6}


## Subset of COMBAT used outside story fights (src/config.ts COMBAT.SHIELD.SPEED).
class Combat:
	const SHIELD_SPEED := 0.55


## Maps the source config group names to the inner classes above (CFG-001 parity test).
static func groups() -> Dictionary:
	return {
		"DISPLAY": Display, "LOOP": Loop, "ISO": Iso, "CAMERA": Camera, "PLAYER": Player,
		"ENERGY": Energy, "INPUT": InputCfg, "OCCLUSION": Occlusion, "HUNGER": Hunger,
		"TREAT": Treat, "DIGESTION": Digestion, "POOP": Poop, "BLADDER": Bladder,
		"POLLUTION": Pollution, "ZONE": Zone, "LIVES": Lives, "SCORE": Score, "BARK": Bark,
		"FX": Fx,
	}
