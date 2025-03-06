extends ItemScript

const SOUND_GAGS := preload("res://objects/battle/battle_resources/gag_loadouts/gag_tracks/sound.tres")
const AUTO_SOUND := preload("res://objects/battle/battle_resources/status_effects/resources/auto_sound.tres")

var player: Player

func on_collect(_item: Item, _object: Node3D) -> void:
	var player: Player
	if not Util.get_player():
		player = await Util.s_player_assigned
	else:
		player = Util.get_player()
	setup(player)

func on_load(item: Item) -> void:
	on_collect(item, null)

func setup(_player: Player) -> void:
	player = _player
	BattleService.s_battle_started.connect(try_apply_sound)
	BattleService.s_round_ended.connect(try_apply_sound)

func try_apply_sound(manager: BattleManager) -> void:
	# Pick a random cog in the battle and apply the auto-sound status onto them.
	if manager.cogs:
		var cog: Cog = RandomService.array_pick_random('true_random', manager.cogs)
		var new_status := AUTO_SOUND.duplicate()
		new_status.sound_gag = get_random_sound_resource()
		new_status.target = cog
		manager.add_status_effect(new_status)

func get_random_sound_resource() -> GagSound:
	var idx: int = RandomService.randi_range_channel('true_random', 0, player.stats.get_highest_gag_level() - 1)
	return SOUND_GAGS.gags[idx].duplicate()
