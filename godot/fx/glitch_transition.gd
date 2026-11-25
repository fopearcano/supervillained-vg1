class_name GlitchTransition
extends GlitchRect
## The glitch transition between scenes (port of src/fx/transition.ts): a burst over the whole
## stage; `mid` runs halfway through (the scene swap). Plays the 'glitch' cue like source
## Flow.glitch. Runs while the game below is paused.

var running := false
var _t := 0.0
var _dur := GameConfig.Fx.TRANSITION_TIME
var _flash_amount := 0.6
var _mid: Callable = Callable()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Starts a burst; a burst already running finishes its pending `mid` first.
func play(mid: Callable = Callable(), duration: float = GameConfig.Fx.TRANSITION_TIME, p_flash: float = 0.6) -> void:
	AudioService.play(&"glitch")
	if running and _mid.is_valid():
		var pending := _mid
		_mid = Callable()
		pending.call()
	_mid = mid
	_t = 0.0
	_dur = duration
	_flash_amount = p_flash
	running = true


func step(dt: float) -> void:
	if not running:
		return
	_t += dt
	var u := minf(1.0, _t / _dur)
	var peak := 1.0 - absf(u * 2.0 - 1.0)
	fx_time = _t
	glitch = peak
	rgb = 1.0 + peak * 3.0
	scanlines = 0.6 * peak
	flash = maxf(0.0, peak - 0.6) * 2.5 * _flash_amount
	if u >= 0.5 and _mid.is_valid():
		var fn := _mid
		_mid = Callable()
		fn.call()
	if u >= 1.0:
		running = false
		glitch = 0.0
		rgb = 0.0
		scanlines = 0.0
		flash = 0.0
	apply()


func _process(delta: float) -> void:
	step(delta)
