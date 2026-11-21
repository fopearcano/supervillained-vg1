class_name NeedsSystem
extends RefCounted
## Zampanò's bodily needs (port of src/systems/needs.ts). Pure logic: hunger, digestion, bladder
## and running energy. Activities are "idle", "walk" or "run".


class Hunger:
	extends RefCounted
	var value: float = GameConfig.Hunger.START

	## Drains hunger. Returns true when it just reached zero (starving).
	func update(dt: float, activity: String) -> bool:
		if value <= 0.0:
			return false
		var rate := GameConfig.Hunger.DRAIN_IDLE
		if activity == "run":
			rate = GameConfig.Hunger.DRAIN_RUN
		elif activity == "walk":
			rate = GameConfig.Hunger.DRAIN_WALK
		value = maxf(0.0, value - rate * dt)
		return value == 0.0

	func feed(amount: float) -> void:
		value = minf(GameConfig.Hunger.MAX, value + amount)

	func lose(amount: float) -> bool:
		if value <= 0.0:
			return false
		value = maxf(0.0, value - amount)
		return value == 0.0

	func fraction() -> float:
		return value / GameConfig.Hunger.MAX


## Hidden digestion meter: treats fill it; when full a warning starts, and when the warning
## expires a poop is due (the caller may postpone it while the dog is busy).
class Digestion:
	extends RefCounted
	var meter := 0.0
	var warning := false
	var warning_left := 0.0
	var due := false

	## Returns "warning" or "".
	func add(amount: float) -> String:
		if warning or due:
			meter = minf(GameConfig.Digestion.MAX * 2.0, meter + amount)
			return ""
		meter += amount
		if meter >= GameConfig.Digestion.MAX:
			warning = true
			warning_left = GameConfig.Digestion.WARNING_TIME
			return "warning"
		return ""

	## Returns "poop" when the warning expires, else "".
	func update(dt: float) -> String:
		if not warning:
			return ""
		warning_left -= dt
		if warning_left <= 0.0:
			warning = false
			due = true
			return "poop"
		return ""

	## The poop happened. Overflow carries over to the next one.
	func done() -> String:
		due = false
		meter = maxf(0.0, meter - GameConfig.Digestion.MAX)
		if meter >= GameConfig.Digestion.MAX:
			warning = true
			warning_left = GameConfig.Digestion.WARNING_TIME
			return "warning"
		return ""


## Pee charges that regenerate slowly and refill instantly when drinking.
class Bladder:
	extends RefCounted
	var charges: int = GameConfig.Bladder.START_CHARGES
	var max_charges: int = GameConfig.Bladder.MAX_CHARGES
	var _regen := 0.0
	var _drink_cooldown := 0.0

	func update(dt: float) -> void:
		if _drink_cooldown > 0.0:
			_drink_cooldown -= dt
		if charges >= max_charges:
			_regen = 0.0
			return
		_regen += dt
		if _regen >= GameConfig.Bladder.REGEN_TIME:
			_regen -= GameConfig.Bladder.REGEN_TIME
			charges += 1

	func can_pee() -> bool:
		return charges > 0

	func use() -> bool:
		if charges <= 0:
			return false
		charges -= 1
		return true

	func regen_fraction() -> float:
		return 0.0 if charges >= max_charges else _regen / GameConfig.Bladder.REGEN_TIME

	func can_drink() -> bool:
		return charges < max_charges and _drink_cooldown <= 0.0

	func drink() -> bool:
		if not can_drink():
			return false
		charges = max_charges
		_regen = 0.0
		_drink_cooldown = GameConfig.Bladder.DRINK_COOLDOWN
		return true


## Energy for running: spent while running, recovered walking or standing. Emptied, running stays
## off until it recovers to MIN_TO_RUN.
class Energy:
	extends RefCounted
	var value: float = GameConfig.Energy.MAX
	var exhausted := false
	## Recovery multiplier (the arcade halves it while hungry).
	var recovery := 1.0

	## Returns "empty", "ready" or "".
	func update(dt: float, activity: String) -> String:
		if activity == "run":
			value = maxf(0.0, value - GameConfig.Energy.DRAIN_RUN * dt)
			if value == 0.0 and not exhausted:
				exhausted = true
				return "empty"
			return ""
		var rate := (GameConfig.Energy.RECOVER_WALK if activity == "walk" else GameConfig.Energy.RECOVER_IDLE) * recovery
		value = minf(GameConfig.Energy.MAX, value + rate * dt)
		if exhausted and value >= GameConfig.Energy.MIN_TO_RUN:
			exhausted = false
			return "ready"
		return ""

	func can_run() -> bool:
		return not exhausted and value > 0.0

	func fraction() -> float:
		return value / GameConfig.Energy.MAX

	func refill() -> void:
		value = GameConfig.Energy.MAX
		exhausted = false
