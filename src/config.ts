/**
 * ALL tuning numbers live here: speeds, timers, thresholds, scores.
 * Units: distances in grid tiles (world units), time in seconds, speeds in tiles/second,
 * screen sizes in logical pixels.
 */

export const DISPLAY = {
  /** Preferred logical width; the integer upscale factor is picked to land near it. */
  TARGET_WIDTH: 216,
  MIN_WIDTH: 192,
  MAX_WIDTH: 270,
  /** Widest allowed aspect (w/h). Wider windows (desktop) get pillarboxed. */
  MAX_ASPECT: 0.62,
  /** Narrowest allowed aspect (w/h). Taller windows get letterboxed. */
  MIN_ASPECT: 0.42,
} as const;

export const LOOP = {
  /** Fixed logic step. */
  STEP: 1 / 60,
  /** Clamp of a single frame's elapsed time (avoids the spiral of death after a stall). */
  MAX_FRAME: 0.25,
  /** Max logic steps per rendered frame. */
  MAX_STEPS: 6,
} as const;

export const ISO = {
  TILE_W: 32,
  TILE_H: 16,
} as const;

export const CAMERA = {
  /** Exponential follow rate (1/s). Lower = lazier "handheld" camera. */
  FOLLOW_RATE: 5,
  /** Look-ahead in screen px along the movement direction. */
  LOOK_AHEAD: 22,
  LOOK_AHEAD_RATE: 2.5,
  /** Constant vertical bias (px): negative shows more of what's above (ahead on the path). */
  BIAS_Y: -18,
  /** Handheld sway amplitude (px) and speed. */
  SWAY_AMPLITUDE: 1.2,
  SWAY_SPEED: 0.7,
  /** Margin (px) beyond the map's screen bounds the camera may show. */
  BOUNDS_MARGIN: 8,
} as const;

export const PLAYER = {
  WALK_SPEED: 3.4,
  RUN_SPEED: 5.8,
  ACCEL: 16,
  DECEL: 20,
  /** Collision radius in tiles. */
  RADIUS: 0.26,
  /** Squash & stretch amount while moving. */
  BOB_AMOUNT: 0.06,
  /** Seconds of invulnerability after losing a life. */
  HURT_INVULN: 2,
  /** Distance to a vertical object (tree/pole/bush/fountain) that turns a pee into a marking. */
  MARK_DISTANCE: 1.05,
  /** Distance to a fountain to drink. */
  DRINK_DISTANCE: 1.0,
} as const;

/**
 * Running (the RUN button, Shift or K held): it spends ENERGY, which comes back while walking or
 * standing. Once empty, Zampanò can't run until the meter is back to MIN_TO_RUN.
 */
export const ENERGY = {
  MAX: 100,
  /** Spent per second of running (100 / 20 = a 5-second sprint from full). */
  DRAIN_RUN: 20,
  /** Recovered per second when standing / walking. */
  RECOVER_IDLE: 24,
  RECOVER_WALK: 13,
  /** After emptying it, the meter must be back to this before running again. */
  MIN_TO_RUN: 35,
  /** Arcade: recovery multiplier while hungry (hunger at or below HUNGER.LOW_WARNING). */
  HUNGRY_RECOVERY: 0.5,
} as const;

/** The title page (title art in assets/starting-page-images). */
export const TITLE = {
  /** Zampanò's portrait over the buttons, as a fraction of the screen width. */
  DOG_WIDTH: 0.46,
  /** The animated portrait's height / width (space kept for it while the GIF decodes). */
  DOG_ASPECT: 1.4,
  /** Share of the free space below the stack moved above it (lowers everything toward the footer). */
  LOWER: 0.75,
  /** SUPERVOID EDITIONS at the bottom links to the publisher. */
  PUBLISHER_URL: 'https://supervoideditions.com/',
  /** Background glitch (mostly vertical): flickering burst strength [min, max], faint level in between. */
  GLITCH_BURST: [0.25, 0.6],
  GLITCH_IDLE: 0.12,
  /** Background glitch: a burst every [min, max] seconds, lasting [min, max] seconds (rare, short). */
  GLITCH_EVERY: [3.5, 8],
  GLITCH_TIME: [0.08, 0.22],
  /** Old dirty film over the background (all strengths 0..1; 0 turns that part off). */
  FILM: {
    /** Grain: per-pixel noise, renewed every film frame. */
    GRAIN: 0.085,
    /** Film frames per second (grain, dust, flicker and weave change at this rate). */
    FPS: 18,
    /** Brightness flicker between film frames. */
    FLICKER: 0.035,
    /** Warm, faded colors (0 = untouched, 1 = full sepia). */
    SEPIA: 0.22,
    /** Darkened edges. */
    VIGNETTE: 0.5,
    /** Vertical scratches: chance each of the two shows in a film frame. */
    SCRATCHES: 0.55,
    /** Dust specks: chance per 22-px cell per film frame. */
    DUST: 0.045,
    /** Gate weave: the picture jumps up to this many pixels between film frames. */
    WEAVE: 1,
  },
} as const;

/** The GLOSSARY card on the title page (scenes/glossaryScene.ts). */
export const GLOSSARY = {
  /** Card width (px, at most the screen minus 16) and the dim behind it. */
  CARD_WIDTH: 200,
  DIM: 0.72,
  /** The red ring around the b) verb: margin around the text (px), overshoot (of 64 steps). */
  RING_PAD_X: 10,
  RING_PAD_Y: 7,
  RING_OVERSHOOT: 9,
  /** It draws itself: after RING_DELAY seconds, in RING_TIME seconds. */
  RING_DELAY: 0.35,
  RING_TIME: 0.55,
} as const;

/**
 * "You've been supervillained" (assets/starting-page-images): at the end of every level, before
 * its final info (the Green Zone's score, a story level's Professor), the logo snaps in at once.
 */
export const SUPERVILLAINED = {
  /** Logo width as a fraction of the screen width (and at most MAX_HEIGHT of its height). */
  WIDTH: 0.84,
  MAX_HEIGHT: 0.5,
  /** Vertical centre, as a fraction of the screen height. */
  Y: 0.44,
  /** Dim over the frozen level behind. */
  DIM: 0.72,
  /** The snap: it appears SNAP_FROM times its size and shrinks to it in SNAP_TIME seconds... */
  SNAP_FROM: 2.2,
  SNAP_TIME: 0.12,
  /** ...then thumps (scale wobble amplitude, frequency in rad/s, decay per second). */
  BOUNCE: 0.12,
  BOUNCE_FREQ: 34,
  BOUNCE_DECAY: 9,
  /** White flash and shake (px) at the snap. */
  FLASH_TIME: 0.3,
  SHAKE: 5,
  SHAKE_TIME: 0.4,
  /** Pulsing pale halo behind the logo: alpha (min, max), speed, size, blur. */
  GLOW_ALPHA: [0.55, 1],
  GLOW_SPEED: 4,
  GLOW_SCALE: 1.08,
  GLOW_BLUR: 6,
  /** Burst of sparkle and star sprites out of the logo: count, speed px/s, life s, gravity px/s². */
  SPARKS: 34,
  SPARK_SPEED: [70, 190],
  SPARK_LIFE: [0.55, 1.2],
  SPARK_GRAVITY: 120,
  /** Seconds it stays before the final info; a tap skips it after SKIP_AFTER. */
  HOLD: 2.4,
  SKIP_AFTER: 0.45,
} as const;

export const INPUT = {
  /** Virtual joystick radius in logical px. */
  JOYSTICK_RADIUS: 22,
  JOYSTICK_DEADZONE: 0.18,
  /** Fraction of screen width (from the left) where the floating joystick may spawn. */
  JOYSTICK_ZONE: 0.62,
  /** Pending keyboard/touch actions older than this are dropped (s). */
  ACTION_TTL: 0.25,
  /** Max movement (px) for a pointer press/release to count as a tap. */
  TAP_SLOP: 10,
  /**
   * Stick magnitude of keyboard walking: full walking speed, but below the story's "charging"
   * threshold (STORY.PACE.CHARGE_MAG). Holding Shift pushes it to 1 (and runs).
   */
  KEYBOARD_WALK_MAG: 0.8,
} as const;

export const OCCLUSION = {
  /** Alpha of a tall object hiding Zampanò. */
  FADED_ALPHA: 0.42,
  FADE_RATE: 10,
} as const;

export const HUNGER = {
  MAX: 100,
  START: 100,
  /** Drain per second by activity (scaled with PLAYER speeds: the same hunger per tile walked). */
  DRAIN_IDLE: 1.4,
  DRAIN_WALK: 2.3,
  DRAIN_RUN: 3.5,
  /** Hunger restored after losing a life. */
  REFILL_ON_LIFE_LOST: 50,
  /** Hunger below which the bar blinks. */
  LOW_WARNING: 25,
} as const;

export const TREAT = {
  HUNGER: 16,
  DIGESTION: 26,
  SCORE: 50,
  PICKUP_RADIUS: 0.55,
} as const;

export const DIGESTION = {
  MAX: 100,
  /** Seconds the "need to poop" warning lasts before the automatic poop. */
  WARNING_TIME: 3,
  /** Seconds Zampanò squats (no control). */
  SQUAT_TIME: 0.8,
} as const;

/** Pollution footprint of a poop, by surface. Radius in tiles, strength = dirt at the center. */
export const POOP = {
  LOW: { radius: 0.9, strength: 0.75 },
  MEDIUM: { radius: 1.7, strength: 1 },
  HEAVY: { radius: 2.6, strength: 1 },
  /** Unattended poops slowly spread: radius grows by this factor over GROW_TIME. */
  GROW_FACTOR: 1.45,
  GROW_TIME: 35,
  GROW_TICK: 0.5,
  /** Points for cleaning a poop pile with pee. */
  CLEAN_SCORE: 100,
} as const;

export const BLADDER = {
  MAX_CHARGES: 3,
  START_CHARGES: 3,
  /** Seconds to regenerate one charge. */
  REGEN_TIME: 18,
  PEE_TIME: 0.7,
  MARK_TIME: 0.9,
  RADIUS: 2.2,
  MARK_RADIUS: 3.2,
  SCORE: 20,
  MARK_SCORE: 150,
  /** Seconds between two drinks. */
  DRINK_COOLDOWN: 1.5,
  DRINK_TIME: 0.6,
} as const;

export const POLLUTION = {
  /** A tile counts as clean when its dirt is below this. */
  CLEAN_THRESHOLD: 0.3,
  /** Visual: overlay alpha = MIN + (MAX - MIN) * dirt (only drawn above VISIBLE). */
  VISIBLE: 0.04,
  OVERLAY_MIN_ALPHA: 0.3,
  OVERLAY_MAX_ALPHA: 0.95,
  /** Seconds the "freshly re-greened" highlight lasts. */
  FRESH_TIME: 1.2,
} as const;

export const ZONE = {
  /** Health (clean fraction) mapped to 0 stars and 5 stars. */
  HEALTH_ZERO_STARS: 0.8,
  HEALTH_FULL_STARS: 0.995,
  /** End-of-level health penalty per missing pee when PEES < POOPS. */
  PEE_DEFICIT_PENALTY: 0.012,
} as const;

export const LIVES = {
  START: 2,
} as const;

export const SCORE = {
  /** Time bonus per second under the level's par time. */
  TIME_BONUS_PER_SECOND: 10,
  /** End-of-level bonus per star. */
  STAR_BONUS: 500,
} as const;

export const CAT = {
  /** Faster than Zampanò walking, slower than running: catching one takes a run. */
  SPEED: 3.9,
  RADIUS: 0.22,
  TOUCH_RADIUS: 0.55,
  /** Cats start fleeing when Zampanò is closer than this. */
  ALERT_DISTANCE: 5,
  LIFETIME: 16,
  COINS: 5,
  SCORE: 250,
  /** Seconds between flee-direction re-evaluations. */
  THINK_INTERVAL: 0.18,
  SPAWN_MIN_DISTANCE: 5,
  SPAWN_MAX_DISTANCE: 8,
} as const;

export const BALL = {
  MAGNET_RADIUS: 3.6,
  /** Max pull speed (tiles/s) at the ball: beats walking near the ball, not running. */
  MAGNET_STRENGTH: 5,
  GRAB_RADIUS: 0.45,
  LIFETIME: 22,
  FETCH_TIME: 2,
  FETCH_HUNGER: 8,
  TIME_PENALTY: 5,
  SPAWN_MIN_DISTANCE: 4,
  SPAWN_MAX_DISTANCE: 7,
} as const;

export const ATTACK = {
  /** Under-attack triggers when health drops below this... */
  HEALTH_THRESHOLD: 0.95,
  /** ...and ends only once health is back above threshold + hysteresis. */
  HYSTERESIS: 0.004,
  /** Minimum seconds between two attacks. */
  COOLDOWN: 25,
  /** Seconds the big flashing title is shown. */
  TITLE_TIME: 2.6,
  /** Health deficit (below threshold) at which effects reach full intensity. */
  FULL_INTENSITY_DEFICIT: 0.08,
  BASE_INTENSITY: 0.35,
} as const;

export const BAGNASKIZ = {
  /** A little slower than Zampanò walking. */
  SPEED: 2.65,
  FLEE_SPEED: 5.6,
  RADIUS: 0.3,
  HITS_TO_FLEE: 3,
  /** Pollution trail stamp. */
  TRAIL_RADIUS: 0.95,
  TRAIL_STRENGTH: 0.8,
  TRAIL_INTERVAL: 0.25,
  KNOCKBACK_SPEED: 7,
  KNOCKBACK_DECAY: 9,
  STUN_TIME: 0.7,
  /** Bump into Zampanò: hunger loss and knockback. */
  BUMP_HUNGER: 6,
  BUMP_COOLDOWN: 1.2,
  SPAWN_DISTANCE: 9,
  /** Re-target interval (s). */
  RETARGET: 2.5,
  FLEE_SCORE: 400,
} as const;

export const BARK = {
  COOLDOWN: 0.45,
  RANGE: 2.8,
  /** Half-angle of the bark cone (radians). */
  HALF_ANGLE: 0.75,
  WAVE_SPEED: 9,
  ANIM_TIME: 0.3,
} as const;

export const FX = {
  SHAKE_DECAY: 9,
  SHAKE_POOP: 2,
  SHAKE_HURT: 4,
  SHAKE_BARK: 1.2,
  SHAKE_HIT: 3,
  POPUP_TIME: 1.1,
  SCORE_POPUP_TIME: 0.9,
  TRANSITION_TIME: 0.45,
} as const;

export const AUDIO = {
  DEFAULT_VOLUME: 0.7,
  /** Synthesized music (the dream's medieval loop). */
  MUSIC_VOLUME: 0.32,
  /** Recorded music (intro, Green Zone). */
  MUSIC_FILE_VOLUME: 0.55,
  SFX_VOLUME: 0.9,
  /** Per-file loudness trims for the recorded sounds (1 = as recorded). */
  FILE_GAIN: { coin: 2.4, laser: 1.3, poop: 1.2, meow: 1.1, siren: 0.6 } as Partial<Record<string, number>>,
  /** Leading silence below this level is skipped so a sound starts with the action. */
  TRIM_LEVEL: 0.01,
  /** The cash after a caught cat starts this many seconds after the meow. */
  CASH_DELAY: 0.35,
  /** The siren starts after the "under attack" alarm, quieter, and loops until the attack ends. */
  SIREN_DELAY: 3.9,
  SIREN_VOLUME: 0.45,
} as const;

/** Story mode (the VG1 campaign): dream walks, mini-games, meters, dialogue. */
export const STORY = {
  /** Dialogue typewriter, characters per second, per text-speed setting. */
  TEXT_CPS: { slow: 24, normal: 45, fast: 90, instant: 10000 },
  PICKUP_RADIUS: 0.7,
  /** Reach goals count as reached within this radius (tiles) unless a walk sets its own. */
  GOAL_RADIUS: 0.8,
  /** Sight cones: alert gained per second while seen, lost per second while hidden. */
  ALERT_GAIN: 2.2,
  ALERT_DECAY: 1.2,
  /** A hostile actor this close catches Zampanò. */
  HOSTILE_TOUCH: 0.6,
  /** Bushes hide him from guards farther than this. */
  BUSH_HIDE: 1.2,
  PACE: {
    GAIN: 0.06,
    CHARGE: -0.35,
    TURN_BACK: -0.6,
    STILL: -0.12,
    /** Stick magnitude that counts as charging. */
    CHARGE_MAG: 0.95,
    STILL_SPEED: 0.25,
    BACK_DOT: -0.3,
    /** Drain multiplier when Supervillain is full. */
    UNSHAKEABLE: 0.4,
    /** Pressure removed per companion walking beside him (within COMPANION_RANGE tiles). */
    COMPANION_RELIEF: 0.012,
    COMPANION_RANGE: 3,
    WARN_EVERY: 1.4,
  },
  THIRST: { MIN_SPEED: 0.55, MIRAGE_NEAR: 3.5, MIRAGE_JUMP: 3.5 },
  SCRAMBLE: { EVERY: 2.6, SETTLE_AT: 0.3 },
  FIRE: { PER_TICK: 3, KNOCKBACK: 6, HURT_TIME: 0.4 },
  RHYTHM: { WINDOW: 0.18, CUE_SPEED: 70, START_DELAY: 1.2 },
  WEEPING: { BEATS: 10, BPM_ROUND1: 46, BPM_ROUND2: 58, NEED: 6 },
  PARADE: { BEATS: 12, BPM: 72, NEED: 8 },
  LADDERS: {
    SPAWN: 1.2,
    SPAWN_HARD: 0.55,
    /** Fastest climbing: one rung per this many seconds, however fast he taps. */
    CLIMB_GAP: 0.12,
    PITCH_CHANCE: 0.35,
    STONE_SPEED: 190,
    PITCH_SPEED: 150,
    WARN: 0.6,
    HIT_TIME: 0.8,
    SLIDE_TIME: 0.35,
    SLIDE_RATE: 10,
    AXE_EVERY: 1.6,
    AXE_HIT_TIME: 1,
    AXE_SLIDE_TIME: 0.5,
  },
  TUG: { BASE: 0.08, GROW: 0.05, PULL: 0.035 },
  /** 1.1: the helmet slips over his eyes when he lowers his head (stands still, barks). */
  VISOR: { STILL_AFTER: 0.7, DOWN_RATE: 2.4, UP_RATE: 1.5, MAX: 0.86 },
  /** Characters he follows (1.2, 3.1, 3.4, 5.2, 7.2): they wait while he lags this far behind. */
  LEAD: { WAIT_DISTANCE: 3.2, SPEED: 2.2, ARRIVE: 1.8 },
  /**
   * Acting in a lull (2.3 the preacher, 3.3 the square, 7.8 the oath): a voice talks, then
   * pauses. Seconds of talk and of quiet (random in [min, max]); range of the action in tiles.
   */
  LULL: { TALK: [2.4, 3.4], QUIET: [1.4, 2.1], RANGE: 3.4, PHRASE_EVERY: 0.85 },
  /** 4.2: easing the boat alongside. Strokes closer together than MIN_GAP slosh water in. */
  BOAT: { STROKE: 0.11, MIN_GAP: 0.42, SPLASH: 0.3, DRAIN: 0.12 },
  /** 6.1: whisking the glasses away before the count's shot lands. */
  WHISK: { SHOTS: 6, WARN: 2.8, GAP: 0.9, RADIUS: 0.95, NEED: 3 },
  /** 6.4: seconds for the desert to bleach the drawing grey. */
  BLEACH_TIME: 36,
  /** 7.3: stay level with Pierre's shoulder (tiles ahead or behind along the march). */
  SHOULDER: { BAND: 1.2, LOSE: 0.2, GAIN: 0.12, SPEED: 1.5 },
  /** 7.4: how thick the smoke gets on the sightseeing route (0..1). */
  SMOKE: 0.82,
  /** Hidden goals heard rather than seen (7.5 the previous room, 7.7 the rattle of mail): seconds between sounds. */
  HEAR_EVERY: 1.6,
  CALM: { RATE: 0.14, PANIC_COST: 0.25, PANIC_TIME: 0.8 },
  CATAPULT: { SHOTS: 4, GRAVITY: 260, VX: 150, VY: 170, MIN_POWER: 0.35, POWER_RANGE: 0.75, OSC: 3 },
  RUMOUR: { ARRIVE_EVERY: 1.2 },
  /** The feeling fades: Commozione lost at the start of every dream sub-level (levels 2-7). */
  COMMOZIONE_FADE: 2,
  /** Commozione per correct weeping beat. */
  WEEP_HIT: 1,
  /** Commozione spent by the big actions ("an unmoved Zampanò cannot act"). */
  COST: { SERMON: 4, SPEAK_UP: 10, GESTURE: 10, ATONE: 8, VIGIL: 8, DEFY: 10, OATH_BARK: 5 },
  /** Standing thresholds for how the camp remembers him (ending notes). */
  STANDING: { FOND: 60, FAIR: 35 },
  /** Grace tiers (8.2 altar, ending). */
  GRACE: { HIGH: 70, LOW: 40 },
  /** Autopilot (automated playtests). */
  PILOT: {
    WALK_MAG: 0.7,
    RUN_MAG: 1,
    CONFIRM_EVERY: 0.22,
    STUCK_TIME: 2.5,
    STUCK_DIST: 0.3,
    JITTER_TIME: 0.6,
    REPATH: 0.25,
    LADDER_TAPS: 6,
    /** Falling things within this many px above him count as a threat. */
    LADDER_LOOKAHEAD: 150,
    TUG_TAPS: 8,
    /** Path costs: near a hostile, seen by a guard, next to fire. */
    DANGER: { HOSTILE_RADIUS: 2.2, HOSTILE_COST: 25, SEEN: 40, NEAR_FIRE: 6 },
  },
} as const;
