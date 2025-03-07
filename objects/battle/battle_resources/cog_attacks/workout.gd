extends CogAttack
class_name CogAttackWorkout

const BOOST_AMT := 1.25


func action() -> void:
	var cog: Cog = user
	apply_boost(cog)
	
	var peak: float
	var length: float
	
	match cog.dna.suit:
		CogDNA.SuitType.SUIT_A:
			peak = 1.75
			length = 0.45
		CogDNA.SuitType.SUIT_B:
			peak = 1.55
			length = 0.4
		_:
			peak = 1.9
			length = 0.5
	
	var tween := manager.create_tween()
	tween.tween_callback(battle_node.focus_character.bind(cog))
	tween.tween_interval(2.0)
	tween.tween_callback(cog.set_animation.bind('slip-forward'))
	tween.tween_callback(func(): await Task.delay(0.55); AudioManager.play_sound(load("res://audio/sfx/battle/gags/trap/Toon_bodyfall_synergy.ogg")))
	tween.tween_interval(peak)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(battle_node.battle_cam, 'global_position:y', (cog.global_position.y + cog.head_node.global_position.y) / 2.0, 0.5)
	tween.set_trans(Tween.TRANS_LINEAR)
	
	for i in 3:
		tween.tween_callback(cog.animator.set_speed_scale.bind(-1.0))
		tween.tween_interval(length)
		tween.tween_callback(cog.animator.set_speed_scale.bind(1.0))
		tween.tween_interval(length)
	
	tween.tween_callback(manager.battle_text.bind(cog, "Damage Up!", BattleText.colors.orange[0], BattleText.colors.orange[1]))
	tween.tween_interval(3.0)
	
	await tween.finished
	tween.kill()

func apply_boost(cog : Cog) -> void:
	if manager.battle_stats.has(cog):
		manager.battle_stats[cog].damage *= BOOST_AMT
