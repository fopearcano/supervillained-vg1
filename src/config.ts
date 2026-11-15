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
  WALK_SPEED: 2.4,
  RUN_SPEED: 4.0,
  ACCEL: 16,
  DECEL: 20,
  /** Collision radius in tiles. */
  RADIUS: 0.26,
  /** Joystick magnitude above which Zampanò runs. */
  RUN_THRESHOLD: 0.82,
  /** Squash & stretch amount while moving. */
  BOB_AMOUNT: 0.06,
  /** Seconds of invulnerability after losing a life. */
  HURT_INVULN: 2,
  /** Distance to a vertical object (tree/pole/bush/fountain) that turns a pee into a marking. */
  MARK_DISTANCE: 1.05,
  /** Distance to a fountain to drink. */
  DRINK_DISTANCE: 1.0,
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
} as const;

export const OCCLUSION = {
  /** Alpha of a tall object hiding Zampanò. */
  FADED_ALPHA: 0.42,
  FADE_RATE: 10,
} as const;

export const HUNGER = {
  MAX: 100,
  START: 100,
  /** Drain per second by activity. */
  DRAIN_IDLE: 0.55,
  DRAIN_WALK: 0.95,
  DRAIN_RUN: 1.6,
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
  REGEN_TIME: 15,
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
  SPEED: 3.3,
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
  /** Max pull speed (tiles/s) at the ball. */
  MAGNET_STRENGTH: 3.4,
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
  SPEED: 2.3,
  FLEE_SPEED: 4.6,
  RADIUS: 0.3,
  HITS_TO_FLEE: 3,
  /** Pollution trail stamp. */
  TRAIL_RADIUS: 1.15,
  TRAIL_STRENGTH: 0.8,
  TRAIL_INTERVAL: 0.22,
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
  MUSIC_VOLUME: 0.32,
  SFX_VOLUME: 0.9,
} as const;
