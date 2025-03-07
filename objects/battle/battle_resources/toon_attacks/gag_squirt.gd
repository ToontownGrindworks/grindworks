extends ToonAttack
class_name GagSquirt

const DEBUFF := preload("res://objects/battle/battle_resources/status_effects/resources/status_effect_drenched.tres")
const POISON_COLOR := Color(0, 0.43, 0.151)


func soak_opponent(who: Node3D, from: Node3D, time: float) -> void:
	var splash: Node3D = load('res://models/props/gags/water_splash/water_splash_untextured.tscn').instantiate()
	user.add_child(splash)
	if Util.get_player().stats.has_item('Witch Hat'):
		splash.set_color(POISON_COLOR)
	splash.global_position = from.global_position
	await splash.spray(who.global_position,time)
	splash.queue_free()

func apply_debuff(target: Cog) -> void:
	var new_effect: StatBoost = DEBUFF.duplicate()
	new_effect.target = target
	new_effect.boost = get_player_stats().get_stat('squirt_defense_boost')
	manager.add_status_effect(new_effect)

func get_player_stats() -> PlayerStats:
	if is_instance_valid(BattleService.ongoing_battle):
		return BattleService.ongoing_battle.battle_stats[Util.get_player()]
	else:
		return Util.get_player().stats

func get_stats() -> String:
	var string := "Damage: " + get_true_damage() + "\n"\
	+ "Affects: "
	match target_type:
		ActionTarget.SELF:
			string += "Self"
		ActionTarget.ENEMIES:
			string += "All Cogs"
		ActionTarget.ENEMY:
			string += "One Cog"
		ActionTarget.ENEMY_SPLASH:
			string += "Three Cogs"
		
	string += "\nDrenched: %s%%" % roundi((1.0 - get_player_stats().get_stat('squirt_defense_boost')) * 100)
	
	if Util.get_player().stats.has_item('Witch Hat'):
		string += "\nApplies: Poison"
	
	return string
