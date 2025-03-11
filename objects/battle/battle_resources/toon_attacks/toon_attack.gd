extends ActionScript
class_name ToonAttack

@export var icon: Texture2D
@export var damage: int
@export var crit_chance_mod := 1.0

# Used in the UI to temporarily store the price of a gag
var price: int

signal s_hit
signal s_missed


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
	
	return string

func get_true_damage(dmg_mod := 1.0, base_dmg: int = 0) -> String:
	var true_dmg: float
	if base_dmg == 0:
		true_dmg = float(damage)
	else:
		true_dmg = float(base_dmg)
	if not is_equal_approx(dmg_mod, 1.0):
		true_dmg *= dmg_mod
	var player_stats: PlayerStats
	if is_instance_valid(BattleService.ongoing_battle):
		player_stats = BattleService.ongoing_battle.battle_stats[Util.get_player()]
	else:
		player_stats = Util.get_player().stats
	
	var base_boost: float = player_stats.get_stat('damage')
	true_dmg *= base_boost
	
	var effectiveness := 1.0
	if self is GagTrap:
		effectiveness = player_stats.gag_effectiveness['Trap']
	elif self is GagSound:
		effectiveness = player_stats.gag_effectiveness['Sound']
	elif self is GagThrow:
		effectiveness = player_stats.gag_effectiveness['Throw']
	elif self is GagSquirt:
		effectiveness = player_stats.gag_effectiveness['Squirt']
	elif self is DropBig or self is DropSmall:
		effectiveness = player_stats.gag_effectiveness['Drop']
	return str(roundi(float(true_dmg) * effectiveness))

#region MOVIE SCRIPTS

const BUTTON_PROP := 'res://models/props/gags/button/toon_button.tscn'
const PRESS_SFX := 'res://audio/sfx/battle/gags/AA_trigger_box.ogg'
func press_button() -> void:
	var button : Node3D = load(BUTTON_PROP).instantiate()
	user.toon.left_hand_bone.add_child(button)
	user.set_animation('button_press')
	Task.delay(2.3).connect(AudioManager.play_sound.bind(load(PRESS_SFX)))
	Task.delay(3.5).connect(button.queue_free)

#endregion

func get_immunity(cog : Cog) -> bool:
	#return true
	
	var effects := manager.get_statuses_for_target(cog)
	
	for effect in effects:
		if effect is StatusEffectGagImmunity:
			if effect.track:
				for gag : ToonAttack in effect.track.gags:
					if gag.action_name == action_name:
						return true
	return false
