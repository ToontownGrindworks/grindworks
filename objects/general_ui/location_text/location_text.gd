extends Control


func _ready() -> void:
	await Task.delay(5.0)
	var fade_tween := create_tween()
	fade_tween.tween_property(self, 'modulate:a', 0.0, 3.0)
	fade_tween.finished.connect(func():
		fade_tween.kill()
		queue_free()
	)


func set_text(text : String) -> void:
	$Label.set_text(text)
