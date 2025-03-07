extends Node

var ongoing_battle : BattleManager
var battle_node : BattleNode:
	set(x):
		battle_node = x
		s_battle_initialized.emit(x)

signal s_battle_started(manager: BattleManager)
signal s_battle_initialized(battle_node: BattleNode)
signal s_round_started(turn_array: Array[BattleAction])
signal s_round_ended(manager: BattleManager)
signal s_battle_participant_died(participant: Node3D)
## A cog died above 0 HP due to an item
signal s_cog_died_early(cog: Cog)
signal s_cog_died(cog: Cog)
signal s_boss_died(cog: Cog)
signal s_battle_ending
signal s_battle_ended
signal s_refresh_statuses
signal s_toon_crit
signal s_toon_didnt_crit
signal s_toon_dealt_damage(action: BattleAction, target: Node3D, amount: int)
signal s_action_started(action: BattleAction)
signal s_action_finished(action: BattleAction)

func battle_started(manager : BattleManager):
	ongoing_battle = manager
	ongoing_battle.s_battle_ending.connect(func(): s_battle_ending.emit())
	ongoing_battle.s_battle_ended.connect(battle_ended)
	ongoing_battle.s_round_started.connect(func(turn_array : Array[BattleAction]): s_round_started.emit(turn_array))
	ongoing_battle.s_round_ended.connect(func(): s_round_ended.emit(ongoing_battle))
	ongoing_battle.s_participant_died.connect(battle_participant_died)
	s_battle_started.emit(manager)

const BOSS_COG_POOL := 'res://objects/cog/presets/pools/boss_cogs.tres'

var BOSS_COG_NAMES: Array[String] = []

func _ready() -> void:
	for dna: CogDNA in load(BOSS_COG_POOL).cogs:
		BOSS_COG_NAMES.append(dna.cog_name)

func battle_participant_died(participant : Node3D) -> void:
	s_battle_participant_died.emit(participant)
	if participant is Cog:
		s_cog_died.emit(participant)
		if participant.dna.cog_name in BOSS_COG_NAMES:
			s_boss_died.emit(participant)

func battle_ended():
	ongoing_battle = null
	battle_node = null
	s_battle_ended.emit()
