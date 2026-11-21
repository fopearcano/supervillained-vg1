class_name ScoringRules
extends RefCounted
## Port of src/systems/scoring.ts (pure).


## Zone health -> stars (0..5 in half-star steps).
static func stars_from_health(health: float) -> float:
	var t := (health - GameConfig.Zone.HEALTH_ZERO_STARS) / (GameConfig.Zone.HEALTH_FULL_STARS - GameConfig.Zone.HEALTH_ZERO_STARS)
	var raw := clampf(t, 0.0, 1.0) * 5.0
	return floor(raw * 2.0 + 1e-6) / 2.0


## End-of-level health: penalty when PEES < POOPS.
static func final_health(health: float, pees: int, poops: int) -> float:
	var deficit := maxi(0, poops - pees)
	return maxf(0.0, health - deficit * GameConfig.Zone.PEE_DEFICIT_PENALTY)


static func time_bonus(time_seconds: float, par_time: float) -> int:
	return maxi(0, int(floor(par_time - time_seconds))) * GameConfig.Score.TIME_BONUS_PER_SECOND


static func star_bonus(stars: float) -> int:
	return int(IsoGrid._js_round(stars * GameConfig.Score.STAR_BONUS))


static func new_stats(lives: int) -> Dictionary:
	return {"score": 0, "pees": 0, "poops": 0, "treats": 0, "coins": 0, "marks": 0, "lives": lives, "time": 0.0, "barkHits": 0}


static func format_time(seconds: float) -> String:
	var s := maxi(0, int(floor(seconds)))
	return "%02d:%02d" % [s / 60, s % 60]


static func format_score(score: float) -> String:
	return "%04d" % maxi(0, int(floor(score)))
