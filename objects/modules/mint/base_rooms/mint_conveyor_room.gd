extends Node3D

const REGULAR_OBJS: Array[PackedScene] = [
	preload("res://objects/props/mint/cog_nation_crate.tscn"),
	preload("res://objects/props/mint/mint_crate.tscn"),
]

const SFX_SWAP := preload("res://audio/sfx/objects/facility_door/CHQ_FACT_door_unlock.ogg")
const SFX_LAND := preload("res://audio/sfx/misc/CHQ_SOS_cage_land.ogg")

@onready var cb_lower: ConveyerBelt = %CBLower
@onready var cb_upper: ConveyerBelt = %CBUpper

var objs_a: Array[Node3D] = []
var objs_b: Array[Node3D] = []
var obj_task: Task
var ramp_seq: Tween:
	set(x):
		if ramp_seq and ramp_seq.is_valid():
			ramp_seq.kill()
		ramp_seq = x

func _enter_tree() -> void:
	setup_obj_task()

func get_random_object_time() -> float:
	return RandomService.randf_range_channel('mint_conveyor', 0.6, 0.9)

func setup_obj_task() -> void:
	spawn_both_objects(false)

func spawn_both_objects(instant := true) -> void:
	if instant:
		spawn_random_obj("a")
		spawn_random_obj("b")
	obj_task = Task.delayed_call(self, get_random_object_time(), spawn_both_objects)

func spawn_random_obj(side: String) -> void:
	var spawn_point: Node3D
	var obj_arr: Array[Node3D]
	var holder_node: Node3D
	if side == "a":
		spawn_point = RandomService.array_pick_random('mint_conveyor', [%SpawnPointA, %SpawnPointA2])
		obj_arr = objs_a
		holder_node = %ObjsA
	else:
		spawn_point = RandomService.array_pick_random('mint_conveyor', [%SpawnPointB, %SpawnPointB2])
		obj_arr = objs_b
		holder_node = %ObjsB

	var obj_holder := Node3D.new()
	var new_animatable_obj := AnimatableBody3D.new()
	new_animatable_obj.sync_to_physics = false
	obj_holder.add_child(new_animatable_obj)
	var new_obj: Node3D = RandomService.array_pick_random('mint_conveyor', REGULAR_OBJS).instantiate()
	new_animatable_obj.add_child(new_obj)
	holder_node.add_child(obj_holder)
	for coll: CollisionShape3D in NodeGlobals.get_children_of_type(new_obj, CollisionShape3D, true):
		coll.owner = null
		coll.reparent(new_animatable_obj)
	obj_holder.global_position = spawn_point.global_position
	obj_holder.global_rotation_degrees.y = RandomService.randf_range_channel('mint_conveyor', 20.0, 70.0)
	obj_holder.scale = Vector3(1.0, 1.666, 1.0)
	obj_arr.append(obj_holder)

func _physics_process(delta: float) -> void:
	var free_objs_a: Array = []
	var free_objs_b: Array = []
	# Move all existing objects
	for obj: Node3D in objs_a:
		obj.position.z -= cb_lower.speed * delta
		if obj.position.z <= -29.0:
			free_objs_a.append(obj)
	for obj: Node3D in objs_b:
		obj.position.x += cb_upper.speed * delta
		if obj.position.x >= 25.0:
			free_objs_b.append(obj)

	for obj: Node3D in free_objs_a:
		obj.queue_free()
		objs_a.erase(obj)
	for obj: Node3D in free_objs_b:
		obj.queue_free()
		objs_b.erase(obj)

func lower_ramp(_x=null) -> void:
	ramp_seq = Sequence.new([
		LerpProperty.new(%RampRotator, ^"rotation_degrees:x", 3.0, -30.2).interp(Tween.EASE_OUT, Tween.TRANS_BOUNCE),
	]).as_tween(self)
	AudioManager.play_sound(SFX_SWAP)
	await Task.delay(1.1)
	AudioManager.play_sound(SFX_LAND)

func _exit_tree() -> void:
	if obj_task:
		obj_task = obj_task.cancel()

func reset() -> void:
	if Util.get_player().stats.hp > 0:
		Util.circle_in(1.0)
		
		Util.get_player().global_position = %PlayerStartPos.global_position
		await Util.get_player().teleport_in(true)
		if Util.get_player().stats.hp <= 0:
			Util.get_player().lose()
