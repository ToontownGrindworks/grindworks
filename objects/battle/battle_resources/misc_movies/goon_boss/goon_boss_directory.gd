extends Node3D

const PHASE_SWAP_MOVIE := preload("res://objects/battle/battle_resources/misc_movies/goon_boss/goon_boss_phase_swap.tres")
const GAG_IMMUNITY_EFFECT := preload("res://objects/battle/battle_resources/status_effects/resources/status_effect_gag_immunity.tres")

@export var goon : Goon
@export var goon_eye_mat : StandardMaterial3D
@export var goon_cam : Camera3D
@export var elevator : Elevator

@onready var battle_node : BattleNode = $BattleNode


func _ready() -> void:
	await Task.delay(0.25)
	
	# Assign the initial gag immunities of the Cogs
	assign_gag_immunities(battle_node.cogs)
	
	# Put Goon in proper state
	goon.set_animation('collapse')
	goon.animator.seek(1.9, true)
	goon.animator.pause()
	
	# Await the battle's start
	await battle_node.s_battle_initialized
	var manager : BattleManager = await BattleService.s_battle_started
	manager.s_participant_died.connect(on_participant_died)
	
	# Connect the round start signal to the method
	manager.s_round_started.connect(on_round_start.bind(manager))
	
	# Create the battle end movie
	var end_movie := GoonBossEnd.new()
	end_movie.user = goon
	manager.battle_win_movie = end_movie

## Insert the goon action at the beginning of each round
func on_round_start(_actions : Array[BattleAction], manager : BattleManager) -> void:
	var attack := GoonAttack.new()
	attack.user = goon
	attack.targets = manager.cogs.duplicate()
	manager.round_end_actions.append(attack)

func on_participant_died(_who) -> void:
	if BattleService.ongoing_battle.cogs.is_empty():
		var phase_movie := PHASE_SWAP_MOVIE.duplicate()
		phase_movie.user = goon
		BattleService.ongoing_battle.round_end_actions.append(phase_movie)
		BattleService.ongoing_battle.s_participant_died.disconnect(on_participant_died)

## For intro cutscene
func get_camera_angle(angle : String) -> Transform3D:
	return $CameraAngles.find_child(angle).global_transform

func get_char_position(pos : String) -> Vector3:
	return $CharPositions.find_child(pos).global_position

func assign_gag_immunities(cogs : Array[Cog]) -> Array[StatusEffectGagImmunity]:
	var effects : Array[StatusEffectGagImmunity] = []
	var loadout : Array[Track] = Util.get_player().stats.character.gag_loadout.loadout
	
	# Assign a random gag immunity to each Cog
	for cog in cogs:
		var new_status := GAG_IMMUNITY_EFFECT.duplicate()
		new_status.target = cog
		new_status.rounds = -1
		new_status.set_track(loadout[RandomService.randi_channel('true_random') % loadout.size()])
		cog.dna.status_effects.append(new_status)
		cog.body.set_color(Color(new_status.track.track_color, 0.8))
	
	return effects
