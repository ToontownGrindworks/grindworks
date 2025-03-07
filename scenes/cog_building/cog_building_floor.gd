extends Node3D

@onready var elevator_in := $suit_interior/elevator_in/sellbot_elevator
@onready var elevator_out := $suit_interior/elevator_out/sellbot_elevator
@onready var elevator_cam := $ElevatorCam
@onready var battle := $BattleNode

func _ready() -> void:
	
	AudioManager.set_music(load('res://audio/music/tt_elevator.ogg'))
	elevator_cam.current = true
	Util.get_player().global_position = elevator_in.player_pos.global_position
	Util.get_player().face_position(battle.global_position)
	await Task.delay(5.0)
	elevator_in.open()
	await elevator_in.animator.animation_finished
	Util.get_player().state = Player.PlayerState.WALK
	battle.player_entered(Util.get_player())
	BattleService.s_battle_started.connect(battle_started)
	AudioManager.set_default_music(load('res://audio/music/encntr_toon_winning_indoor.ogg'))

func battle_started(battle_manager : BattleManager) -> void:
	battle_manager.s_battle_ending.connect(open_exit)

func open_exit() -> void:
	elevator_in.close()
	elevator_out.open()
