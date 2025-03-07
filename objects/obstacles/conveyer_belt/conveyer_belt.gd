@tool
extends StaticBody3D
class_name ConveyerBelt

const BASE_COLLISION_SIZE := Vector3(3.05, 0.15, 3.05)

@export var size := Vector3(1,1,1):
	set(x):
		size = x
		set_size()
@export var platform_mat : StandardMaterial3D:
	set(x):
		platform_mat = x
		set_platform_mat(x)
@export var speed := 1.0

@onready var platform: Node3D = $platform2
@onready var collision: BoxShape3D = $CollisionShape3D.shape
@onready var platform_mesh: MeshInstance3D = $platform2/platform

func _ready() -> void:
	if platform_mat:
		platform_mat = platform_mat.duplicate()
	set_size()

func set_size() -> void:
	if not platform:
		return
	
	platform.scale = size
	collision.size = BASE_COLLISION_SIZE * size
	
	if platform_mat:
		platform_mat.uv1_scale.y = size.z

func set_platform_mat(material: StandardMaterial3D) -> void:
	if not platform:
		return
	platform_mesh.set_surface_override_material(1, material)
	platform_mesh.set_surface_override_material(2, material)

func _process(delta: float) -> void:
	# UV scroll
	platform_mat.uv1_offset.y -= (speed / 3.0) * delta
	if ceil(abs(platform_mat.uv1_offset.y)) - abs(platform_mat.uv1_offset.y) < 0.01:
		platform_mat.uv1_offset.y = 0.0

func _physics_process(_delta: float) -> void:
	# Set the constant velocity based on the object's rotation
	var rot := global_rotation.y
	var base_velocity := Vector3(0.0, 0.0, speed)
	constant_linear_velocity = base_velocity.rotated((Vector3(0, 1, 0)), rot)
