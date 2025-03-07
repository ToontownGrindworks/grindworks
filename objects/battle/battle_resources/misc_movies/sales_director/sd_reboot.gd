extends CogAttack
class_name SalesDirectorReboot

const COG_OBJECT := preload('res://objects/cog/cog.tscn')

@export_range(1, 2) var cog_amount := 2

var elevator: Elevator
var elevator_cam: Camera3D
var elevator_pos_1: Node3D
var elevator_pos_2: Node3D
var end_pos_1: Node3D
var end_pos_2: Node3D
var suit_walk_cam: Camera3D


func action() -> void:
	var user_cog: Cog = user
	
	user_cog.speak("I'm ordering a reboot of this franchise.")
	battle_node.focus_character(user_cog)
	battle_node.battle_cam.position.y += 1
	await manager.sleep(2.0)

	var new_cogs: Array[Cog] = []
	
	# Create our new Cog objects
	for i in cog_amount:
		var new_cog := COG_OBJECT.instantiate()
		new_cogs.append(new_cog)
		new_cog.hide()
		battle_node.add_child(new_cog)
		if i == 0:
			new_cog.global_transform = elevator_pos_2.global_transform
		else:
			new_cog.global_transform = elevator_pos_1.global_transform
		new_cog.battle_start()
		BattleService.ongoing_battle.add_cog(new_cog)
		new_cog.show()

	elevator_cam.make_current()
	elevator.open()
	await Task.delay(1.5)

	var move_tween: Tween
	for cog: Cog in battle_node.cogs:
		if cog in new_cogs:
			move_tween = cog.move_to([end_pos_2, end_pos_1][new_cogs.find(cog)].global_position)

	await Task.delay(1.0)
	elevator.close()
	suit_walk_cam.make_current()
	await move_tween.finished
	battle_node.battle_cam.make_current()
