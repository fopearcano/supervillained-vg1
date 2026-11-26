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
	## Synthesized music (the dream's medieval loop).
	const MUSIC_VOLUME := 0.32
	## Recorded music (intro, Green Zone, levels 2-4).
	const MUSIC_FILE_VOLUME := 0.55
	## Per-track loudness trims of the recorded music (1 = as recorded).
	const MUSIC_FILE_GAIN := {"level2": 0.58, "level3": 0.84, "level4": 0.5}
	const SFX_VOLUME := 0.9
	const FILE_GAIN := {"coin": 2.4, "laser": 1.3, "poop": 1.2, "meow": 1.1, "siren": 0.6}
	const TRIM_LEVEL := 0.01
	## The cash after a caught cat starts this many seconds after the meow.
	const CASH_DELAY := 0.35
	## The siren starts after the "under attack" alarm, quieter, and loops until the attack ends.
	const SIREN_DELAY := 3.9
	const SIREN_VOLUME := 0.45


## Story fights (src/config.ts COMBAT; rules in story/combat/combat_rules.gd): BARK from the start,
## the SWORD and the SHIELD once Zampanò is a knight (2.3). Nobody dies: a foe with no HP left is
## routed (runs off); Zampanò at 0 HEALTH is knocked down and the fight starts again. Distances in
## tiles, times in seconds, angles in radians.
class Combat:
	## Walking speed with the shield up (also read by PlayableDog).
	const SHIELD_SPEED := 0.55
	## Zampanò's hearts in a fight (a fight may set its own).
	const HEALTH := 5
	const SWORD_RANGE := 1.45
	const SWORD_HALF_ARC := 1.15
	const SWORD_DAMAGE := 1.0
	## Shorter than the cooldown: one opening, one blow (no chains).
	const SWORD_STUN := 0.3
	const SWORD_KNOCK := 2.6
	const SWORD_COOLDOWN := 0.42
	## A parried blow: both step back a little.
	const SWORD_PARRY_KNOCK := 1.6
	## The swing's pose and its arc on screen.
	const SWORD_ACTION_TIME := 0.22
	## A bark is never parried, but staggers only briefly: a bark-only fight is a slow one.
	const BARK_RADIUS := 2.3
	const BARK_DAMAGE := 0.5
	const BARK_STUN := 0.3
	const BARK_KNOCK := 3.2
	const BARK_COOLDOWN := 1.1
	## Blows from within this half-angle of where he faces are blocked.
	const SHIELD_HALF_ARC := 1.35
	## A tap (button, swipe, I pressed once) raises it this long; holding keeps it up.
	const SHIELD_PULSE := 0.8
	## Raising it shoves whoever is right in front (no stagger).
	const SHIELD_BASH_RANGE := 1.2
	const SHIELD_BASH_KNOCK := 4.0
	## A blocked blow staggers the attacker.
	const SHIELD_BLOCK_STUN := 0.6
	const SHIELD_BLOCK_KNOCK := 3.0
	const FOE_HP := 2.0
	const FOE_CHASE_SPEED := 1.6
	const FOE_CHASE_RADIUS := 5.0
	## They stop this close to him and swing.
	const FOE_STOP_AT := 0.75
	const FOE_ATTACK_RANGE := 0.95
	## A swing lands if he is still this close when it comes down.
	const FOE_REACH := 1.25
	## The raised arm before the blow (the ring under them fills): time to raise the shield.
	const FOE_WINDUP := 0.5
	const FOE_COOLDOWN := 1.5
	## Right after a swing they are open (no parry) this long.
	const FOE_RECOVER := 0.6
	const FOE_KNOCK_DECAY := 9.0
	const HURT_KNOCK := 4.5
	const HURT_INVULN := 0.9
	const HURT_TIME := 0.3
	## The KNOCKED DOWN card before the fight starts again.
	const KNOCKED_CARD := 1.8
	## A routed foe runs off at this speed.
	const ROUT_SPEED := 3.2


class Cat:
	const SPEED := 3.9
	const RADIUS := 0.22
	const TOUCH_RADIUS := 0.55
	const ALERT_DISTANCE := 5.0
	const LIFETIME := 16.0
	const COINS := 5
	const SCORE := 250
	const THINK_INTERVAL := 0.18
	const SPAWN_MIN_DISTANCE := 5.0
	const SPAWN_MAX_DISTANCE := 8.0


class Ball:
	const MAGNET_RADIUS := 3.6
	const MAGNET_STRENGTH := 5.0
	const GRAB_RADIUS := 0.45
	const LIFETIME := 22.0
	const FETCH_TIME := 2.0
	const FETCH_HUNGER := 8.0
	const TIME_PENALTY := 5.0
	const SPAWN_MIN_DISTANCE := 4.0
	const SPAWN_MAX_DISTANCE := 7.0


class Attack:
	const HEALTH_THRESHOLD := 0.95
	const HYSTERESIS := 0.004
	const COOLDOWN := 25.0
	const TITLE_TIME := 2.6
	const FULL_INTENSITY_DEFICIT := 0.08
	const BASE_INTENSITY := 0.35


class Bagnaskiz:
	const SPEED := 2.65
	const FLEE_SPEED := 5.6
	const RADIUS := 0.3
	const HITS_TO_FLEE := 3
	const TRAIL_RADIUS := 0.95
	const TRAIL_STRENGTH := 0.8
	const TRAIL_INTERVAL := 0.25
	const KNOCKBACK_SPEED := 7.0
	const KNOCKBACK_DECAY := 9.0
	const STUN_TIME := 0.7
	const BUMP_HUNGER := 6.0
	const BUMP_COOLDOWN := 1.2
	const SPAWN_DISTANCE := 9.0
	const RETARGET := 2.5
	const FLEE_SCORE := 400


## "You've been supervillained" at the end of the Green Zone (src/scenes/supervillainedScene.ts).
class Supervillained:
	const WIDTH := 0.84
	const MAX_HEIGHT := 0.5
	const Y := 0.44
	const DIM := 0.72
	const SNAP_FROM := 2.2
	const SNAP_TIME := 0.12
	const BOUNCE := 0.12
	const BOUNCE_FREQ := 34.0
	const BOUNCE_DECAY := 9.0
	const FLASH_TIME := 0.3
	const SHAKE := 5.0
	const SHAKE_TIME := 0.4
	const GLOW_ALPHA := [0.55, 1.0]
	const GLOW_SPEED := 4.0
	const GLOW_SCALE := 1.08
	const GLOW_BLUR := 6.0
	const SPARKS := 34
	const SPARK_SPEED := [70.0, 190.0]
	const SPARK_LIFE := [0.55, 1.2]
	const SPARK_GRAVITY := 120.0
	const HOLD := 2.4
	const SKIP_AFTER := 0.45


## The title page (src/scenes/overlays.ts TitleScene).
class Title:
	const DOG_WIDTH := 0.46
	const DOG_ASPECT := 1.35
	const DOG_CROP_MARGIN := [0.05, 0.03]
	const TOP := 0.07
	const DOG_MENU_GAP := 6
	const INSERT_BRAIN_GAP := 12
	const BLOCK_MIN_MARGIN := 8
	const SHINE_EVERY := [1.4, 3.6]
	const SHINE_TIME := 1.6
	const SHINE_WIDTH := 14
	const SHINE_SLANT := 7
	const SHINE_ALPHA := 0.45
	const INSERT_BRAIN_BLINK := 1
	const TEXT_GLITCH_EVERY := [1.8, 4.5]
	const TEXT_GLITCH_TIME := [0.06, 0.2]
	const TEXT_GLITCH_BURST := [0.45, 1]
	const TEXT_GLITCH_IDLE := 0.35
	const FOOTER_GLOW_ALPHA := [0.05, 0.75]
	const FOOTER_GLOW_SPEED := 1.2
	const FOOTER_GLOW_BLUR := 3
	const FOOTER_GLOW_COLOR := "#c8ffb8"
	const PUBLISHER_URL := "https://supervoideditions.com/"
	const GLITCH_BURST := [0.25, 0.6]
	const GLITCH_IDLE := 0.12
	const GLITCH_EVERY := [3.5, 8]
	const GLITCH_TIME := [0.08, 0.22]
	const FILM := {"GRAIN": 0.085, "FPS": 18, "FLICKER": 0.035, "SEPIA": 0.22, "VIGNETTE": 0.5, "SCRATCHES": 0.55, "DUST": 0.045, "WEAVE": 1}


## The COUCH card (src/scenes/couchScene.ts).
class Couch:
	const CARD_WIDTH := 204
	const DIM := 0.72
	const BAR_WIDTH := 50


## The GLOSSARY card (src/scenes/glossaryScene.ts).
class Glossary:
	const CARD_WIDTH := 200
	const DIM := 0.72
	const RING_PAD_X := 10
	const RING_PAD_Y := 7
	const RING_OVERSHOOT := 9
	const RING_DELAY := 0.35
	const RING_TIME := 0.55


## Maps the source config group names to the inner classes above (CFG-001 parity test).
## Story mode tuning (the parts of src/config.ts STORY the M5R engine uses; values as in the source).
class Story:
	## Dialogue typewriter, characters per second, per text-speed setting.
	const TEXT_CPS := {"slow": 24.0, "normal": 45.0, "fast": 90.0, "instant": 10000.0}
	const PICKUP_RADIUS := 0.7
	## His bark animation (src/story/combat.ts bark, chapters/helpers.ts bark: 0.3 s).
	const BARK_ANIM := 0.3
	## Reach goals count as reached within this radius (tiles) unless an objective sets its own.
	const GOAL_RADIUS := 0.8
	## 1.1: the bucket slips over his eyes when he lowers his head (stands still, barks).
	const VISOR_STILL_AFTER := 0.7
	const VISOR_DOWN_RATE := 2.4
	const VISOR_UP_RATE := 1.5
	const VISOR_MAX := 0.86
	## Characters he follows wait while he lags this far behind.
	const LEAD_WAIT_DISTANCE := 3.2
	const LEAD_ARRIVE := 1.8
	## Someone blocking a gap: pushing counts as one bump at most every BUMP_EVERY seconds.
	const BUMP_EVERY := 0.5
	## The dialogue box: bottom edge BOTTOM px above the screen's bottom, MIN_H tall, grows upward.
	const DIALOGUE_BOTTOM := 18
	const DIALOGUE_MIN_H := 74
	const DIALOGUE_PAD := 32
	## Speech above a character is kept this far inside the view (sides; top, below the HUD).
	const SAY_INSET_SIDE := 4
	const SAY_INSET_TOP := 76
	## A tap/confirm is read after these guards (a held key does not skip): lines, cards.
	const LINE_GUARD := 0.15
	const CARD_GUARD := 0.4
	## The options appear this long after the prompt has finished typing.
	const CHOICE_DELAY := 0.3
	## The real-input driver confirms every this many seconds.
	const PILOT_CONFIRM_EVERY := 0.22
	## Floating lines above characters live this long (s).
	const FLOAT_TIME := 1.6
	const NOTICE_TIME := 2.2
	## Sight cones (src/config.ts STORY): alert fills this fast while seen, drains while not; a
	## hostile closer than HOSTILE_TOUCH catches him; in a bush he is seen only within BUSH_HIDE.
	const ALERT_GAIN := 2.2
	const ALERT_DECAY := 1.2
	const HOSTILE_TOUCH := 0.6
	const BUSH_HIDE := 1.2
	## A story hiding spot (a bush the scene places) covers him within this distance of it.
	const HIDE_PROP_RADIUS := 0.7
	## The caught card ("BACK TO WHERE YOU STARTED") before the walk starts again.
	const CAUGHT_CARD := 1.6
	## A checkpoint is passed within this distance.
	const CHECKPOINT_RADIUS := 1.2
	## Acting in a lull (2.2 the preacher, 3.3 the square): seconds of talk and of quiet ([min, max],
	## drawn from the scene's seeded generator), the action's range and the phrase interval.
	const LULL_TALK := [2.4, 3.4]
	const LULL_QUIET := [1.4, 2.1]
	const LULL_RANGE := 3.4
	const LULL_PHRASE_EVERY := 0.85
	## Beat games (4.1, 4.3): the timing window either side of a beat, the cue speed (px/s) and the
	## lead-in before beat 0.
	const RHYTHM_WINDOW := 0.18
	const RHYTHM_CUE_SPEED := 70.0
	const RHYTHM_START_DELAY := 1.2
	const PARADE_BEATS := 12
	const PARADE_BPM := 72.0
	const PARADE_NEED := 8
	## 4.3: the rowing is the parade's beat count and need, 8 BPM slower.
	const ROWING_BPM_DROP := 8.0
	## A beat game's result shows this long before the scene goes on.
	const MINI_RESULT_HOLD := 0.8
	## 4.2: easing the boat alongside. Strokes closer together than MIN_GAP slosh water in.
	const BOAT_STROKE := 0.11
	const BOAT_MIN_GAP := 0.42
	const BOAT_SPLASH := 0.3
	const BOAT_DRAIN := 0.12
	const BOAT_SWAMP_TIME := 1.2
	## 5.2's ladder (src/config.ts STORY.LADDERS, the non-hard branch): rungs, the climb's input cap
	## (one rung per CLIMB_GAP however fast he taps), stones (spawn interval × 0.7–1.3, warning,
	## speed in px/s), a hit's stun and slide (rungs per second), the rung spacing on screen.
	const LADDER_RUNGS := 16
	const LADDER_CLIMB_GAP := 0.12
	const LADDER_SPAWN := 1.2
	const LADDER_WARN := 0.6
	const LADDER_STONE_SPEED := 190.0
	const LADDER_HIT_TIME := 0.8
	const LADDER_SLIDE_TIME := 0.35
	const LADDER_SLIDE_RATE := 10.0
	const LADDER_RUNG_PX := 22.0
	## The hero's walk cycle spans this many rungs (source: frame = rung × frames / 4).
	const LADDER_RUNGS_PER_CYCLE := 4.0
	## 6.2: a garbled piece of the offer reaches him every RUMOUR_ARRIVE_EVERY seconds.
	const RUMOUR_ARRIVE_EVERY := 1.2
	## 7.1/7.7's tug: the force grows (BASE + time × GROW per second); a pull takes back PULL.
	const TUG_BASE := 0.08
	const TUG_GROW := 0.05
	const TUG_PULL := 0.035


static func groups() -> Dictionary:
	return {
		"DISPLAY": Display, "LOOP": Loop, "ISO": Iso, "CAMERA": Camera, "PLAYER": Player,
		"ENERGY": Energy, "INPUT": InputCfg, "OCCLUSION": Occlusion, "HUNGER": Hunger,
		"TREAT": Treat, "DIGESTION": Digestion, "POOP": Poop, "BLADDER": Bladder,
		"POLLUTION": Pollution, "ZONE": Zone, "LIVES": Lives, "SCORE": Score, "BARK": Bark,
		"FX": Fx, "CAT": Cat, "BALL": Ball, "ATTACK": Attack, "BAGNASKIZ": Bagnaskiz,
		"SUPERVILLAINED": Supervillained, "TITLE": Title, "COUCH": Couch, "GLOSSARY": Glossary,
	}
