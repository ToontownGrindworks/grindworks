extends Control
class_name BoostQueue

const BOOST_TEXT_LABEL := preload("res://objects/player/ui/boost_text_label.tscn")
const STAGGER_TIME := 0.75

var queue: Array = []
var can_queue_text := true


func _do_text(text: String, color: Color) -> void:
	var new_label: Control = BOOST_TEXT_LABEL.instantiate()
	new_label.get_node("Label").modulate = Color.TRANSPARENT
	add_child(new_label)
	new_label.get_node("Label").text = text
	new_label.get_node("Label").label_settings.font_color = color
	new_label.get_node("AnimationPlayer").play("text")
	await new_label.get_node("AnimationPlayer").animation_finished
	new_label.queue_free()

func queue_text(text: String, color: Color) -> void:
	if queue.is_empty() and can_queue_text:
		run_text(text, color)
	else:
		queue.append([text, color])

func run_text(text: String, color: Color) -> void:
	_do_text(text, color)
	can_queue_text = false
	await Task.delay(STAGGER_TIME)
	if queue.is_empty():
		can_queue_text = true
	else:
		run_text.callv(queue.pop_front())
