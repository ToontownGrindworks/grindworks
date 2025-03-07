extends GagSquirt
class_name FireHose

func action():
	# Start
	manager.s_focus_char.emit(user)
	var target = targets[0]
	
	# Place hose in hand
	var hose = load('res://models/props/gags/firehose/hose.tscn').instantiate()
	user.toon.add_child(hose)
	
	var dna: ToonDNA = user.toon.toon_dna
	if dna.body_type == ToonDNA.BodyType.LARGE:
		hose.scale *= 0.3
		hose.position = Vector3(0.075, 0.055, -0.145)
	else:
		hose.scale *= 0.2
	
	# Play hose anim
	hose.get_node('AnimationPlayer').play('spray')
	await Task.delay(0.05)
	user.set_animation('fire_hose')
	user.face_position(target.global_position)
	
	await Task.delay(1.95)
	# Soak the Cog
	soak_opponent(target.head_node, hose.get_node('firehose/Skeleton3D/NozzleAttach'), 1.0)
	
	# Play sfx
	AudioManager.play_sound(load("res://audio/sfx/battle/gags/squirt/firehose_spray.ogg"))
	
	await Task.delay(0.1)
	manager.s_focus_char.emit(target)
	
	# Accuracy roll
	if manager.roll_for_accuracy(self) or target.lured:
		var was_lured: bool = target.lured
		manager.affect_target(target, 'hp', damage,false)
		var splat = load("res://objects/battle/effects/splat/splat.tscn").instantiate()
		if Util.get_player().stats.has_item('Witch Hat'):
			splat.modulate = POISON_COLOR
		else:
			splat.modulate = Globals.SQUIRT_COLOR
		splat.set_text("SPLASH!")
		target.head_node.add_child(splat)
		if not get_immunity(target):
			if target.lured:
				manager.knockback_cog(target)
			else:
				target.set_animation('squirt-small')
			apply_debuff(target)
			s_hit.emit()
			await Task.delay(0.5 * (2 if was_lured else 1))
			manager.battle_text(target, "Drenched!", BattleText.colors.orange[0], BattleText.colors.orange[1])
		else:
			manager.battle_text(target, "IMMUNE")
		await manager.barrier(target.animator.animation_finished, 5.0)
		await manager.check_pulses(targets)
	else:
		target.set_animation('sidestep-left')
		manager.battle_text(target, "MISSED")
		await manager.barrier(target.animator.animation_finished, 5.0)
	
	# End
	hose.queue_free()
	user.face_position(manager.battle_node.global_position)
