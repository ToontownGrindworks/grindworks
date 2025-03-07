extends GagSquirt
class_name SquirtGeyser

const PROP := preload('res://models/props/gags/geyser/geyser.tscn')
const SFX := preload('res://audio/sfx/battle/gags/squirt/AA_squirt_Geyser.ogg')


func action() -> void:
	var player: Player = user
	var cog: Cog = targets[0]
	var geyser := PROP.instantiate()
	
	# Movie Start
	var movie := manager.create_tween()
	
	# Press button
	movie.tween_callback(battle_node.focus_character.bind(player))
	movie.tween_callback(press_button)
	movie.tween_interval(2.4)
	movie.tween_callback(AudioManager.play_sound.bind(SFX))
	movie.tween_interval(1.0)
	
	# Spawn geyser
	movie.tween_callback(battle_node.add_child.bind(geyser))
	movie.tween_callback(geyser.set_global_position.bind(cog.body_root.global_position))
	movie.tween_callback(battle_node.focus_character.bind(cog))
	movie.tween_callback(geyser.get_node('AnimationPlayer').play.bind('squirt'))
	
	var hit: bool = manager.roll_for_accuracy(self) or cog.lured 
	if hit:
		if not get_immunity(cog):
			movie.tween_callback(s_hit.emit)
			# Play geyser anim, parent cog to cog root
			movie.tween_callback(cog_flyup.bind(cog))
			movie.tween_callback(manager.affect_target.bind(cog, 'hp', damage, false))
			movie.tween_interval(0.01)
			movie.tween_callback(cog.body_root.reparent.bind(geyser.get_node('CogRoot')))
			movie.tween_interval(0.5)
			# Knockback damage here
			if cog.lured:
				var kb_dmg := manager.get_knockback_damage(cog)
				movie.tween_callback(manager.battle_text.bind(cog, '-' + str(kb_dmg), BattleText.colors.orange[0], BattleText.colors.orange[1]))
				movie.tween_callback(func(): cog.stats.hp -= kb_dmg)
			movie.tween_callback(apply_debuff.bind(cog))
			movie.tween_interval(1.75)
			movie.tween_callback(manager.battle_text.bind(cog, "Drenched!", BattleText.colors.orange[0], BattleText.colors.orange[1]))
			movie.tween_callback(cog_slip.bind(cog))
			movie.tween_callback(cog.body_root.reparent.bind(cog))
			movie.tween_callback(func(): cog.body_root.position.y = 0.0)
			movie.tween_interval(2.0)
			if cog.lured:
				movie.tween_callback(manager.force_unlure.bind(cog))
				movie.tween_callback(cog.set_animation.bind('walk'))
				movie.tween_property(cog.body_root, 'position:z', 0.0, 0.5)
				movie.tween_callback(cog.set_animation.bind('neutral'))
		else:
			movie.tween_callback(manager.battle_text.bind(cog, "IMMUNE"))
			movie.tween_interval(4.0)
	else:
		movie.tween_callback(cog.set_animation.bind('sidestep-left'))
		movie.tween_callback(manager.battle_text.bind(cog, "MISSED"))
		movie.tween_interval(5.0)
	
	movie.tween_callback(geyser.queue_free)
	await movie.finished
	await manager.check_pulses(targets)

func cog_flyup(cog : Cog) -> void:
	cog.set_animation('slip-backward')
	Task.delay(1.0).connect(cog.pause_animator)

func cog_slip(cog : Cog) -> void:
	cog.set_animation('slip-backward')
	match cog.dna.suit:
		CogDNA.SuitType.SUIT_A:
			cog.animator_seek(2.43)
		CogDNA.SuitType.SUIT_B:
			cog.animator_seek(1.94)
		CogDNA.SuitType.SUIT_C:
			cog.animator_seek(2.58)

func get_knockback_damage() -> int:
	return 0
