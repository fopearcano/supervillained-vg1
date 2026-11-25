class_name VisorRule
extends ObjectiveRule
## 1.1: the sand bucket slides down over his eyes whenever he lowers his head — standing still for
## a moment or barking — and is pushed back up while he walks (src/campaign/chapters/ch1.ts 1.1,
## STORY.VISOR). The visor is the black bars of StoryHud.

const S := GameConfig.Story


func begin(_ctx: StoryContext, _step: ObjectiveStep, st: Dictionary) -> void:
	st["still_t"] = 0.0
	st["bow"] = 0.0


func on_action(_ctx: StoryContext, _step: ObjectiveStep, st: Dictionary) -> void:
	st["bow"] = 0.8


## Any bark lowers his head (RD-28): the bucket slides down.
func on_bark(ctx: StoryContext, step: ObjectiveStep, st: Dictionary) -> void:
	on_action(ctx, step, st)


func tick(ctx: StoryContext, _step: ObjectiveStep, st: Dictionary, dt: float) -> bool:
	var dog := ctx.player
	var still := Vector2(dog.vx, dog.vy).length() < 0.2
	st["still_t"] = float(st["still_t"]) + dt if still else 0.0
	st["bow"] = maxf(0.0, float(st["bow"]) - dt)
	var down: bool = float(st["still_t"]) > S.VISOR_STILL_AFTER or float(st["bow"]) > 0.0
	ctx.visor = minf(S.VISOR_MAX, ctx.visor + S.VISOR_DOWN_RATE * dt) if down else maxf(0.0, ctx.visor - S.VISOR_UP_RATE * dt)
	return false
