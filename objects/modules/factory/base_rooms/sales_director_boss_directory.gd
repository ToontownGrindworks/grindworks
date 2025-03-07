extends Node3D

@onready var first_cam: Camera3D = %FirstCam
@onready var second_cam: Camera3D = %SecondCam
@onready var cog: Cog = %SalesDirector
@onready var first_pos: Node3D = %FirstPos
@onready var second_pos: Node3D = %SecondPos
@onready var battle_node: BattleNode = %BattleNode
@onready var elevator: Elevator = %SellbotElevator
@onready var elevator_cam: Camera3D = %ElevatorCam

var manager: BattleManager = null

func _ready() -> void:
	await Task.delay(0.25)
	await battle_node.s_battle_initialized
	manager = await BattleService.s_battle_started

	# Connect the round start signal to the method
	manager.s_round_started.connect(on_round_start.bind(manager))

## Insert the boss's relevant actions at the beginning of each round
func on_round_start(_actions: Array[BattleAction], _manager: BattleManager) -> void:
	if (not is_instance_valid(cog)) or cog.stats.hp <= 0:
		return

	var attack: CogAttack
	if manager.current_round % 3 == 1:
		# Insert Rebrand
		attack = load("res://objects/battle/battle_resources/misc_movies/sales_director/sd_rebrand.tres").duplicate()
		attack.targets = [self]
		attack.user = cog
		manager.round_end_actions.append(attack)
	if manager.current_round % 4 == 0 and manager.cogs.size() < 4:
		# Insert reboot
		attack = load("res://objects/battle/battle_resources/misc_movies/sales_director/sd_reboot.tres").duplicate()
		attack.elevator = elevator
		attack.elevator_cam = elevator_cam
		attack.cog_amount = min(4 - manager.cogs.size(), 2)
		attack.elevator_pos_1 = %ElevatorPos1
		attack.elevator_pos_2 = %ElevatorPos2
		attack.end_pos_1 = %ElevatorPos1End
		attack.end_pos_2 = %ElevatorPos2End
		attack.suit_walk_cam = %SuitWalkCam
		attack.user = cog
		manager.round_end_actions.append(attack)
