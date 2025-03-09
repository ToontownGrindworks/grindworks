extends FloorModifier

## Factory ends up 
const FACTORY_RENDER_REQUIREMENT := 7

var skybox: Node3D


func modify_floor() -> void:
	skybox = load('res://models/props/sky_boxes/sbhq/skybox.fbx').instantiate()
	var player: Player
	if not Util.get_player():
		player = await Util.s_player_assigned
	else:
		player = Util.get_player()
	player.add_child(skybox)
	skybox.scale *= 3.0
	skybox.position.y -= 25
	var ground: Node3D = load("res://objects/props/factory/factory_ground.tscn").instantiate()
	add_child(ground)
	ground.position.y -= 30
	game_floor.s_floor_ended.connect(func(): skybox.queue_free(); skybox = null; ground.queue_free())
	game_floor.render_rooms = FACTORY_RENDER_REQUIREMENT

func get_mod_name() -> String:
	return "Sellbot Skybox"

func _process(_delta: float):
	if skybox and is_instance_valid(skybox):
		skybox.global_position.y = -25
