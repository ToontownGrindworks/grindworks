extends ItemScript

const DROP_GAGS := preload("res://objects/battle/battle_resources/gag_loadouts/gag_tracks/drop.tres")
const AUTO_DROP := preload("res://objects/battle/battle_resources/status_effects/resources/auto_drop.tres")

var player: Player


func on_collect(_item: Item, _object: Node3D) -> void:
	var _player: Player
	if not Util.get_player():
		_player = await Util.s_player_assigned
	else:
		_player = Util.get_player()
	setup(_player)

func on_load(item: Item) -> void:
	on_collect(item, null)

func setup(_player: Player) -> void:
	player = _player
	BattleService.s_battle_started.connect(try_apply_drop)
	BattleService.s_round_ended.connect(try_apply_drop)

func try_apply_drop(manager: BattleManager) -> void:
	# Pick a random cog in the battle and apply the auto-drop status onto them.
	if manager.cogs:
		var cog: Cog = RandomService.array_pick_random('true_random', manager.cogs)
		var new_status := AUTO_DROP.duplicate()
		new_status.drop_gag = get_random_drop_resource()
		new_status.target = cog
		manager.add_status_effect(new_status)

func get_random_drop_resource() -> GagDrop:
	var idx: int = 0
	# Min drop level works as follows:
	# 1 (flowerpot) on floors 0-2
	# 2 (sandbag) on floor 3
	# 3 (anvil) on floor 4
	# 4 (big weight) on floor 5 and directors
	var min_drop_level: int = max(0, Util.floor_number - 2)
	# Prevent range errors by making sure the max drop level is at least 1 higher than the min drop level
	var max_drop_level: int = max(min_drop_level, player.stats.get_highest_gag_level() - 1)
	idx = RandomService.randi_range_channel('true_random', min_drop_level, max_drop_level)
	return DROP_GAGS.gags[idx].duplicate()
