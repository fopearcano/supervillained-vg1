class_name CombatRules
extends RefCounted
## Fight rules, pure (port of src/systems/combat.ts): who is in the sword's arc, what a blow or a
## bark does to a foe, a foe's swing (wind-up, blow, cooldown), whether the shield blocks it.
## Nobody dies: a foe with no HP left is routed (runs off). The scene side is CombatController.
## Numbers in GameConfig.Combat; positions in grid space (tiles), 64-bit floats.

const C := GameConfig.Combat


## One fighter's state (source `Foe`).
class Foe:
	extends RefCounted
	var hp := 0.0
	var max_hp := 0.0
	## Seconds left staggered (no moving, no swinging).
	var stun := 0.0
	## Seconds before the next swing may start.
	var cooldown := 0.0
	## Seconds left of a raised arm (0 = not swinging).
	var windup := 0.0
	var routed := false


static func new_foe(hp: float = C.FOE_HP) -> Foe:
	var f := Foe.new()
	f.hp = hp
	f.max_hp = hp
	f.cooldown = C.FOE_COOLDOWN * 0.5
	return f


## Is the target within `range_` of the origin and within `half_angle` of the facing (fx, fy)?
## Anything nearly on top of the origin counts as in front.
static func in_arc(ox: float, oy: float, fx: float, fy: float, tx: float, ty: float, range_: float, half_angle: float) -> bool:
	var dx := tx - ox
	var dy := ty - oy
	var d := JsMath.hypot(dx, dy)
	if d > range_:
		return false
	if d < 0.3:
		return true
	var fl := JsMath.hypot(fx, fy)
	if fl == 0.0:
		fl = 1.0
	return (dx * fx + dy * fy) / (d * fl) >= cos(half_angle)


## A sword blow lands: HP down, the swing interrupted and its cooldown spent, staggered for `stun`
## (it replaces what was left: the blow uses up the opening it was struck in). A bark
## (`interrupt` false) wounds and staggers, but a swing already coming still comes.
## "hit" | "routed" | "none".
static func damage_foe(f: Foe, damage: float, stun: float, interrupt: bool = true) -> String:
	if f.routed:
		return "none"
	f.hp = maxf(0.0, f.hp - damage)
	if interrupt:
		f.stun = stun
		f.windup = 0.0
		f.cooldown = C.FOE_COOLDOWN - C.FOE_RECOVER
	elif f.windup <= 0.0:
		f.stun = maxf(f.stun, stun)
	if f.hp <= 1e-6:
		f.routed = true
		return "routed"
	return "hit"


## Staggered without damage (a blocked blow): the swing is lost, not the recovery.
static func stagger_foe(f: Foe, stun: float) -> void:
	if f.routed:
		return
	f.stun = maxf(f.stun, stun)
	f.windup = 0.0
	f.cooldown = maxf(f.cooldown, C.FOE_COOLDOWN - C.FOE_RECOVER)


## One step of a foe's swing, `dist` tiles from Zampanò: "windup" when it raises its arm, "strike"
## when the blow comes down (the caller checks reach and the shield), else "none".
static func step_foe(f: Foe, dt: float, dist: float) -> String:
	if f.routed:
		return "none"
	f.cooldown = maxf(0.0, f.cooldown - dt)
	if f.stun > 0.0:
		f.stun = maxf(0.0, f.stun - dt)
		f.windup = 0.0
		return "none"
	if f.windup > 0.0:
		f.windup -= dt
		if f.windup > 0.0:
			return "none"
		f.windup = 0.0
		f.cooldown = C.FOE_COOLDOWN
		return "strike"
	if dist <= C.FOE_ATTACK_RANGE and f.cooldown <= 0.0:
		f.windup = C.FOE_WINDUP
		return "windup"
	return "none"


## Open to a sword blow: staggered, mid-swing (the blow interrupts it) or just after a swing. A foe
## who parries takes no damage from the sword otherwise.
static func is_open(f: Foe) -> bool:
	if f.routed:
		return false
	return f.stun > 0.0 or f.windup > 0.0 or f.cooldown > C.FOE_COOLDOWN - C.FOE_RECOVER


## Does the raised shield (facing fx, fy) take a blow coming from (ax, ay)?
static func shield_blocks(px: float, py: float, fx: float, fy: float, ax: float, ay: float) -> bool:
	return in_arc(px, py, fx, fy, ax, ay, INF, C.SHIELD_HALF_ARC)
