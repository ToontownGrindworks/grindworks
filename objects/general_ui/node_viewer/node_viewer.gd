@tool
extends TextureRect

@export var camera: Camera3D
@export var camera_position_offset := 0.0
@export var node: Node3D:
	set(x):
		if not is_node_ready():
			await ready
		spin_tween = null
		if node and is_instance_valid(node):
			node.queue_free()
		node = x
		if node:
			sub_viewport.add_child(node)
			node.reset_physics_interpolation()
		adjust_cam()
		setup_tween()
@export var want_spin_tween := false:
	set(x):
		if not is_node_ready():
			await ready
		want_spin_tween = x
		setup_tween()
@export var test := false:
	set(x):
		if x:
			adjust_cam()
		test = false

@onready var sub_viewport: SubViewport = %SubViewport

var spin_tween: Tween:
	set(x):
		if spin_tween and spin_tween.is_valid():
			spin_tween.kill()
		spin_tween = x

func adjust_cam():
	if not node:
		return

	var aabb := NodeGlobals.calculate_spatial_bounds(node, false)

	# Calculate model camera size
	var node_size: Vector3 = aabb.size * node.scale
	var cam_size: float = max(node_size.x, node_size.y) / 2.0
	camera.size = cam_size * 2.0 * (1.1 + camera_position_offset)
	
	# Move camera to model position and then back to avoid clipping
	camera.position = aabb.get_center() * node.scale
	camera.position.z -= 10.0

func setup_tween() -> void:
	spin_tween = null
	if not node:
		return
	if want_spin_tween:
		spin_tween = create_tween()
		spin_tween.tween_property(node, 'rotation_degrees:y', 360.0, 4.0)
		spin_tween.tween_property(node, 'rotation_degrees:y', 0, 0.0)
		spin_tween.set_loops()
