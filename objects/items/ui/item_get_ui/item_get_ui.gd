extends Control

@export var item: Item

# Child References
@onready var banner := $Banner
@onready var label_name := $Banner/Name
@onready var label_description := $Banner/Description

var model: Node3D

func _ready():
	banner.modulate.a = 0.0
	var in_tween := create_tween()
	in_tween.tween_property(banner, 'modulate:a', 1.0, 1.0)
	
	label_name.set_text(item.item_name)
	label_description.set_text("\"%s\"" % item.item_description)
	
	if item.model:
		model = item.model.instantiate()
		%NodeViewer.camera_position_offset = item.ui_cam_offset
		%NodeViewer.node = model
		%NodeViewer.want_spin_tween = item.want_ui_spin
	await Task.delay(4.0)
	
	var leave_tween = create_tween()
	leave_tween.tween_property(banner, 'modulate:a', 0.0, 1.0)
	await leave_tween.finished
	queue_free()
