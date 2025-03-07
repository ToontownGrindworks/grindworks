@tool
extends StatusEffect


func apply() -> void:
	var cog: Cog = target
	
	cog.stats.damage *= 1.1
	manager.s_action_started.connect(on_action_start)

func on_action_start(action : BattleAction) -> void:
	if action.user == target:
		action.accuracy = Globals.ACCURACY_GUARANTEE_HIT

func cleanup() -> void:
	manager.s_action_started.disconnect(on_action_start)

func get_status_name() -> String:
	return "Pinpoint"

func get_icon() -> Texture2D:
	return load("res://ui_assets/battle/statuses/pinpoint_accuracy.png")
