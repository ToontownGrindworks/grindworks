extends ItemScript

@onready var SOUND_GAGS := load("res://objects/battle/battle_resources/gag_loadouts/gag_tracks/sound.tres")
@onready var AUTO_SOUND := load("res://objects/battle/battle_resources/status_effects/resources/auto_sound.tres")
const SFX_VOUCHER := "res://audio/sfx/battle/gags/sound/LB_receive_evidence.ogg"

var player: Player

var manager: BattleManager

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
	
	BattleService.s_battle_started.connect(on_battle_started)
	BattleService.s_battle_ended.connect(on_battle_ended)
	
func on_battle_started(_manager: BattleManager) -> void:
	manager = _manager
	manager.battle_ui.s_special_voucher_used.connect(on_special_voucher_used)
	
func on_battle_ended() -> void:
	manager.battle_ui.s_special_voucher_used.disconnect(on_special_voucher_used)

func on_special_voucher_used(type: String) -> void:
	if type == "Sound":
		try_apply_sound(manager)

func try_apply_sound(manager: BattleManager) -> void:
	# Pick a random cog in the battle and apply the auto-sound status onto them.
	if manager.cogs:
		var cog: Cog = RandomService.array_pick_random('true_random', manager.cogs)
		var new_status := AUTO_SOUND.duplicate()
		new_status.sound_gag = get_random_sound_resource()
		new_status.target = cog
		manager.add_status_effect(new_status)
		manager.battle_ui.repopulate_status_effects()
		AudioManager.play_sound(load(SFX_VOUCHER))

func get_random_sound_resource() -> GagSound:
	var idx: int = RandomService.randi_range_channel('true_random', 0, player.stats.get_highest_gag_level() - 1)
	return SOUND_GAGS.gags[idx].duplicate()
