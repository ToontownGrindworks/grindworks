@tool
extends StatusEffect
class_name StatusAutoSound

@export var sound_gag: GagSound

func apply() -> void:
	manager.s_round_started.connect(round_started)

func cleanup() -> void:
	if manager.s_round_started.is_connected(round_started):
		manager.s_round_started.disconnect(round_started)

func round_started(_actions: Array[BattleAction]) -> void:
	var new_sound: GagSound = sound_gag.duplicate()
	new_sound.main_target = target
	new_sound.targets = Util.get_splash_targets(manager.cogs.find(target), manager)
	new_sound.user = Util.get_player()
	#TODO: Make this into toon summons with sound
	#new_sound.special_action_exclude = true
	#new_sound.skip_button_movie = true
	manager.inject_battle_action(new_sound, 0)

func get_icon() -> Texture2D:
	return sound_gag.icon

func get_status_name() -> String:
	return "Incoming Sound"

func get_description() -> String:
	return "Will be hit by %s\nDamage: %s" % [sound_gag.action_name, sound_gag.get_true_damage()]
