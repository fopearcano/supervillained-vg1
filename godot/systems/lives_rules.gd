class_name LivesRules
extends RefCounted
## Port of src/systems/lives.ts: lives chosen on the title (START..MAX) cost Green Zone speed.


## Lives kept within START..MAX (JavaScript Math.round; non-finite falls back to START).
static func clamp_lives(n: float) -> int:
	if not is_finite(n):
		return GameConfig.Lives.START
	return clampi(int(IsoGrid._js_round(n)), GameConfig.Lives.START, GameConfig.Lives.MAX)


## The title counter's next value: one more life, back to START after MAX.
static func next_lives(n: float, step: int = 1) -> int:
	var span := GameConfig.Lives.MAX - GameConfig.Lives.START + 1
	return GameConfig.Lives.START + ((((clamp_lives(n) - GameConfig.Lives.START + step) % span) + span) % span)


## Speed multiplier in the Green Zone walk: each life above START costs SPEED_COST.
static func lives_speed(n: float) -> float:
	return 1.0 - (clamp_lives(n) - GameConfig.Lives.START) * GameConfig.Lives.SPEED_COST
