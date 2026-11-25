class_name CritterControllers
extends RefCounted
## Behaviour controllers of the Green Zone critters (port of src/entities/critters.ts): small
## state machines in grid space that move on the shared GridKinematicSolver
## (WorldMapModel.move_circle). No nodes: CritterView / BallView present them. The source's
## Math.random in the flee steering is replaced by the threats' seeded critter RNG.


## Animation state mirrored from the source CharacterAnimator.play (restart counter for views).
class Anim:
	extends RefCounted

	var available: Array
	var anim := "idle"
	var dir := "S"
	var restarts := 0

	func _init(p_available: Array) -> void:
		available = p_available

	func play(next: String, p_dir: String = "", restart: bool = false) -> void:
		if not available.has(next):
			next = "idle"
		if next != anim or restart:
			restarts += 1
		anim = next
		if p_dir != "":
			dir = p_dir


## A cat: sits until the dog comes close, then flees around obstacles. Touch it for coins.
class CatController:
	extends RefCounted

	const C := GameConfig.Cat

	var gx: float
	var gy: float
	var tint: Color
	## "idle", "flee", "startled" or "leave".
	var state := "idle"
	var age := 0.0
	var state_time := 0.0
	## Startled hop height in px and alpha while leaving (presentation only).
	var z := 0.0
	var fade := 1.0
	var anim := Anim.new(["idle", "walk", "run"])
	var _dir_x := 0.0
	var _dir_y := 0.0
	var _think := 0.0

	func _init(x: float, y: float, p_tint: Color) -> void:
		gx = x
		gy = y
		tint = p_tint

	func startle() -> void:
		if state == "leave":
			return
		state = "startled"
		state_time = 0.0

	## Returns false once the cat has left.
	func step(dt: float, map: WorldMapModel, px: float, py: float, rng: DeterministicRng) -> bool:
		age += dt
		state_time += dt
		var d := JsMath.hypot(px - gx, py - gy)
		if state != "leave" and age > C.LIFETIME:
			state = "leave"
			state_time = 0.0
		var speed := 0.0
		if state == "idle":
			if d < C.ALERT_DISTANCE:
				state = "flee"
		elif state == "startled":
			if state_time > 0.8:
				state = "flee"
		else:
			_think -= dt
			if _think <= 0.0:
				_think = C.THINK_INTERVAL
				var f := ThreatLogic.flee_direction(map, gx, gy, px, py, _dir_x, _dir_y, C.RADIUS, rng)
				_dir_x = f[0]
				_dir_y = f[1]
			# Relax when far away.
			if state == "leave" or d < C.ALERT_DISTANCE * 1.4:
				speed = C.SPEED
			else:
				speed = C.SPEED * 0.4
		if speed > 0.0 and (_dir_x != 0.0 or _dir_y != 0.0):
			var r := map.move_circle(gx, gy, _dir_x * speed * dt, _dir_y * speed * dt, C.RADIUS)
			gx = r[0]
			gy = r[1]
			anim.play("run" if speed > C.SPEED * 0.6 else "walk", IsoGrid.dir_from_grid_vector(_dir_x, _dir_y, anim.dir))
		else:
			anim.play("idle", IsoGrid.dir_from_grid_vector(px - gx, py - gy) if state == "idle" else anim.dir)
		z = maxf(0.0, sin(minf(1.0, state_time / 0.3) * PI) * 5.0) if state == "startled" else 0.0
		if state == "leave":
			fade = maxf(0.0, 1.0 - state_time / 1.2)
			return state_time < 1.2
		return true


## A tennis ball: pulls the dog in like a magnet until he grabs it (forced fetch) or it expires.
class BallController:
	extends RefCounted

	const B := GameConfig.Ball

	var gx: float
	var gy: float
	var age := 0.0
	var taken := false
	## Bounce clock and alpha (presentation only).
	var t := 0.0
	var fade := 1.0

	func _init(x: float, y: float) -> void:
		gx = x
		gy = y

	## Returns false once taken or faded out.
	func step(dt: float) -> bool:
		age += dt
		t += dt
		if age > B.LIFETIME:
			fade = maxf(0.0, 1.0 - (age - B.LIFETIME) / 0.8)
			return age < B.LIFETIME + 0.8
		return not taken


## Bagnaskiz, the bully pug: heads for the greenest spots, trails pollution, bumps the dog; three
## bark hits make him flee.
class BagnaskizController:
	extends RefCounted

	const G := GameConfig.Bagnaskiz

	var gx: float
	var gy: float
	## "roam", "stunned", "flee" or "gone".
	var state := "roam"
	var hits := 0
	var target_x := 0.0
	var target_y := 0.0
	var state_time := 0.0
	var fade := 1.0
	var anim := Anim.new(["idle", "walk", "run", "hurt", "pee", "poop", "bark", "eat", "fetch", "sniff", "sit"])
	var _retarget := 0.0
	var _trail := 0.0
	var _kx := 0.0
	var _ky := 0.0
	var _bump_cooldown := 0.0
	var _last_x := 0.0
	var _last_y := 0.0

	func _init(x: float, y: float) -> void:
		gx = x
		gy = y

	func is_active() -> bool:
		return state == "roam" or state == "stunned"

	func hit(from_x: float, from_y: float) -> void:
		if not is_active():
			return
		hits += 1
		var dx := gx - from_x
		var dy := gy - from_y
		var length := JsMath.hypot(dx, dy)
		if length == 0.0:
			length = 1.0
		_kx = (dx / length) * G.KNOCKBACK_SPEED
		_ky = (dy / length) * G.KNOCKBACK_SPEED
		state_time = 0.0
		state = "flee" if hits >= G.HITS_TO_FLEE else "stunned"
		anim.play("hurt", anim.dir, true)

	## One step; returns "bump" when he runs into the dog. `pick_target` returns [x, y].
	func step(dt: float, map: WorldMapModel, px: float, py: float, pick_target: Callable, rng: DeterministicRng) -> String:
		state_time += dt
		if _bump_cooldown > 0.0:
			_bump_cooldown -= dt
		var vx := 0.0
		var vy := 0.0
		var next := "walk"
		if state == "roam":
			_retarget -= dt
			var td := JsMath.hypot(target_x - gx, target_y - gy)
			if _retarget <= 0.0 or td < 0.5:
				_retarget = G.RETARGET
				var picked: Array = pick_target.call()
				target_x = picked[0]
				target_y = picked[1]
			var dx := target_x - gx
			var dy := target_y - gy
			var length := JsMath.hypot(dx, dy)
			if length > 0.1:
				vx = (dx / length) * G.SPEED
				vy = (dy / length) * G.SPEED
			_trail -= dt
			if _trail <= 0.0:
				_trail = G.TRAIL_INTERVAL
				map.stamp_dirt(gx, gy, G.TRAIL_RADIUS, G.TRAIL_STRENGTH)
		elif state == "stunned":
			next = "hurt"
			if state_time > G.STUN_TIME:
				state = "roam"
		elif state == "flee":
			next = "hurt" if state_time < 0.4 else "run"
			if state_time >= 0.4:
				var dx := gx - px
				var dy := gy - py
				var dir := ThreatLogic.flee_direction(map, gx, gy, px, py, _last_x, _last_y, G.RADIUS, rng)
				var length := JsMath.hypot(dx, dy)
				if length == 0.0:
					length = 1.0
				var fx: float = dir[0] if dir[0] != 0.0 else dx / length
				var fy: float = dir[1] if dir[1] != 0.0 else dy / length
				vx = fx * G.FLEE_SPEED
				vy = fy * G.FLEE_SPEED
				fade = maxf(0.0, 1.0 - maxf(0.0, state_time - 2.2) / 0.8)
				if state_time > 3.0:
					state = "gone"
		# Knockback.
		var kd := exp(-G.KNOCKBACK_DECAY * dt)
		_kx *= kd
		_ky *= kd
		var mx := (vx + _kx) * dt
		var my := (vy + _ky) * dt
		if mx != 0.0 or my != 0.0:
			var r := map.move_circle(gx, gy, mx, my, G.RADIUS)
			gx = r[0]
			gy = r[1]
		var speed := JsMath.hypot(vx, vy)
		if speed > 0.1:
			_last_x = vx / speed
			_last_y = vy / speed
		if next != "hurt" and speed < 0.1:
			next = "idle"
		var face := IsoGrid.dir_from_grid_vector(vx, vy, anim.dir) if speed > 0.1 else anim.dir
		anim.play(next, face)
		if state == "roam" and _bump_cooldown <= 0.0 and JsMath.hypot(px - gx, py - gy) < G.RADIUS + 0.35:
			_bump_cooldown = G.BUMP_COOLDOWN
			return "bump"
		return ""
