class_name ScoringRules
extends RefCounted
## Minimal score formatting shared by the rules and HUD.


static func format_score(score: float) -> String:
	return "%04d" % maxi(0, int(floor(score)))
