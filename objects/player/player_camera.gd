extends SpringArm3D
class_name PlayerCamera

@export var y_offset: float = 1.061

@onready var player: Player = NodeGlobals.get_ancestor_of_type(self, Player)
@onready var camera: Camera3D = %Camera

var fov: float:
	get: return camera.fov
	set(x): camera.fov = x

func _unhandled_input(event) -> void:
	if not player.control_style:
		return
	
	# Orbital Camera
	if event is InputEventMouseMotion and player.state == Player.PlayerState.WALK and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * Globals.SENSITIVITY * SaveFileService.settings_file.camera_sensitivity)
		rotation.x -= event.relative.y * Globals.SENSITIVITY * SaveFileService.settings_file.camera_sensitivity
		rotation.x = clamp(rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _process(_delta: float) -> void:
	global_position = player.get_global_transform_interpolated().origin + Vector3(0, y_offset, 0)

func make_current() -> void:
	camera.make_current()
