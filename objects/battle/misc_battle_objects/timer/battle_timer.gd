extends Control
class_name GameTimer

var timer: Timer

signal s_timeout

var tween: Tween:
	set(x):
		if tween and tween.is_valid():
			tween.kill()
		tween = x

func start(time: float) -> void:
	timer = Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.start(time)
	timer.timeout.connect(
	func(): 
		s_timeout.emit()
		queue_free()
	)

func _process(_delta) -> void:
	if timer:
		$TimeLabel.set_text(str(int(floor(timer.time_left))))
		%TimeLabel.label_settings.font_color = Color.RED if timer.time_left <= 6 else Color.BLACK

func scale_pop() -> void:
	tween = Sequence.new([
		LerpProperty.new(self, ^"scale", 0.2, Vector2.ONE * 1.2).interp(Tween.EASE_OUT),
		LerpProperty.new(self, ^"scale", 0.2, Vector2.ONE * 1.0).interp(Tween.EASE_IN),
	]).as_tween(self)
