extends TestCase
## M6-A: the pure fight rules (CombatRules, port of src/systems/combat.ts) — arcs in all eight
## directions, a bark's and a blow's effect on a foe, a foe's swing cycle, the opening a blow
## consumes, the stagger of a blocked blow and the shield's front arc.

const C := GameConfig.Combat
const DIRS := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]


func _vec(dir: String) -> Vector2:
	var g := IsoGrid.dir_to_grid_xy(dir)
	return Vector2(g[0], g[1]).normalized()


## The sword's arc and the shield's front arc around each of the eight facings: in front (and up to
## the half-angle) in; beyond it out; behind always out. Nearly on top counts as in front.
func test_COM_eight_directions_sword_and_shield_arcs() -> void:
	for dir: String in DIRS:
		var f := _vec(dir)
		var front := f * 1.0
		assert_true(CombatRules.in_arc(0, 0, f.x, f.y, front.x, front.y, C.SWORD_RANGE, C.SWORD_HALF_ARC), dir + ": in front is in the sword arc")
		var edge := f.rotated(C.SWORD_HALF_ARC - 0.05) * 1.2
		assert_true(CombatRules.in_arc(0, 0, f.x, f.y, edge.x, edge.y, C.SWORD_RANGE, C.SWORD_HALF_ARC), dir + ": just inside the sword's half-arc")
		var past := f.rotated(C.SWORD_HALF_ARC + 0.1) * 1.2
		assert_false(CombatRules.in_arc(0, 0, f.x, f.y, past.x, past.y, C.SWORD_RANGE, C.SWORD_HALF_ARC), dir + ": past the sword's half-arc")
		var far := f * (C.SWORD_RANGE + 0.05)
		assert_false(CombatRules.in_arc(0, 0, f.x, f.y, far.x, far.y, C.SWORD_RANGE, C.SWORD_HALF_ARC), dir + ": beyond the sword's range")
		var behind := -f * 1.0
		assert_false(CombatRules.in_arc(0, 0, f.x, f.y, behind.x, behind.y, C.SWORD_RANGE, C.SWORD_HALF_ARC), dir + ": behind is out")
		# The shield's arc is wider than the sword's and has no range limit; the rear is open.
		var wide := f.rotated(C.SHIELD_HALF_ARC - 0.05) * 3.0
		assert_true(CombatRules.shield_blocks(0, 0, f.x, f.y, wide.x, wide.y), dir + ": the shield takes a blow from its edge")
		assert_false(CombatRules.shield_blocks(0, 0, f.x, f.y, behind.x, behind.y), dir + ": the shield never covers the rear")
		var side := f.rotated(PI / 2.0) * 1.0
		assert_false(CombatRules.shield_blocks(0, 0, f.x, f.y, side.x, side.y), dir + ": a blow from the side (90°) is not blocked")
	assert_true(CombatRules.in_arc(0, 0, 1, 0, -0.1, 0.1, C.SWORD_RANGE, C.SWORD_HALF_ARC), "nearly on top counts as in front")


## COM-001–004 (rules part): a bark wounds by half a heart and staggers briefly without
## interrupting a swing already coming; a blow interrupts and staggers.
func test_COM_001_004_bark_damage_and_small_stagger() -> void:
	var f := CombatRules.new_foe(2.0)
	assert_eq([f.hp, f.max_hp, f.cooldown, f.windup, f.routed], [2.0, 2.0, C.FOE_COOLDOWN * 0.5, 0.0, false], "a new foe")
	assert_eq(CombatRules.damage_foe(f, C.BARK_DAMAGE, C.BARK_STUN, false), "hit", "a bark hits")
	assert_eq([f.hp, f.stun], [1.5, C.BARK_STUN], "half a heart, a small stagger")
	var g := CombatRules.new_foe(2.0)
	g.windup = 0.3
	CombatRules.damage_foe(g, C.BARK_DAMAGE, C.BARK_STUN, false)
	assert_eq([g.windup, g.stun], [0.3, 0.0], "a bark does not stop a swing already coming")
	var h := CombatRules.new_foe(0.5)
	assert_eq(CombatRules.damage_foe(h, C.BARK_DAMAGE, C.BARK_STUN, false), "routed", "the last half heart routs")
	assert_eq(CombatRules.damage_foe(h, 1.0, 0.1), "none", "a routed foe takes nothing more")


## COM-005–008 (rules part): the swing cycle (wind-up within attack range, the blow after WINDUP,
## the cooldown), a blow that interrupts the wind-up and consumes the opening, the openings
## (stagger, mid-swing, just after a swing) and a stagger's duration.
func test_COM_005_008_swing_cycle_opening_and_stagger() -> void:
	var f := CombatRules.new_foe()
	f.cooldown = 0.0
	assert_eq(CombatRules.step_foe(f, 0.1, C.FOE_ATTACK_RANGE + 0.1), "none", "out of range: no swing")
	assert_eq(CombatRules.step_foe(f, 0.1, C.FOE_ATTACK_RANGE), "windup", "in range, cooled down: the arm goes up")
	assert_eq(f.windup, C.FOE_WINDUP, "the ring fills for WINDUP seconds")
	assert_true(CombatRules.is_open(f), "mid-swing he is open")
	var ticks := 0
	var ev := "none"
	while ev == "none" and ticks < 100:
		ev = CombatRules.step_foe(f, 0.05, 0.5)
		ticks += 1
	assert_eq(ev, "strike", "the blow comes down")
	assert_true(ticks >= 10 and ticks <= 11, "after WINDUP (10 × 0.05 s, float rounding: %d)" % ticks)
	assert_eq(f.cooldown, C.FOE_COOLDOWN, "then the cooldown")
	assert_true(CombatRules.is_open(f), "just after a swing he is open")
	CombatRules.step_foe(f, C.FOE_RECOVER + 0.01, 0.5)
	assert_false(CombatRules.is_open(f), "after RECOVER he is closed again (parries)")
	# A blow mid-swing interrupts it and consumes the opening.
	var g := CombatRules.new_foe()
	g.cooldown = 0.0
	CombatRules.step_foe(g, 0.01, 0.5)
	assert_eq(CombatRules.damage_foe(g, C.SWORD_DAMAGE, C.SWORD_STUN), "hit", "a blow mid-swing lands")
	assert_eq([g.windup, g.stun, g.cooldown, g.hp], [0.0, C.SWORD_STUN, C.FOE_COOLDOWN - C.FOE_RECOVER, 1.0], "interrupted, staggered, the opening used up")
	CombatRules.step_foe(g, C.SWORD_STUN + 0.01, 0.5)
	assert_eq(g.stun, 0.0, "the stagger lasts SWORD_STUN")
	assert_false(CombatRules.is_open(g), "one opening, one blow: no chain")
	# A blocked blow: staggered longer, the swing lost, no damage.
	var b := CombatRules.new_foe()
	b.windup = 0.2
	CombatRules.stagger_foe(b, C.SHIELD_BLOCK_STUN)
	assert_eq([b.stun, b.windup, b.hp], [C.SHIELD_BLOCK_STUN, 0.0, C.FOE_HP], "a blocked attacker is staggered, unhurt")
	assert_true(CombatRules.is_open(b), "and open while staggered")
