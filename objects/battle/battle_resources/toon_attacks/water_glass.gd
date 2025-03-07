extends GagSquirt
class_name WaterGlass

func action():
	# Start
	manager.s_focus_char.emit(user)
	var target = targets[0]
	user.set_animation('spit')
	user.face_position(target.global_position)
	
	# Place glass in hand
	var glass = load('res://models/props/gags/water_glass/water_glass.tscn').instantiate()
	user.toon.right_hand_bone.add_child(glass)
	glass.get_node('AnimationPlayer').play('water_glass')
	
	await manager.sleep(1.95)
	
	var hit := manager.roll_for_accuracy(self)
	if hit or target.lured:
		AudioManager.play_sound(load("res://audio/sfx/battle/gags/squirt/AA_squirt_glasswater.ogg"))
	else:
		AudioManager.play_sound(load("res://audio/sfx/battle/gags/squirt/AA_squirt_glasswater_miss.ogg"))
	
	await manager.sleep(1.5)
	
	# Make the squirt happen
	soak_opponent(target.head_node, user.toon.glasses_bone, .05)
	
	# Watch target get hit
	await manager.sleep(0.2)
	manager.s_focus_char.emit(target)
	
	# Accuracy roll
	if hit or target.lured:
		var was_lured: bool = target.lured
		if not get_immunity(target):
			s_hit.emit()
			manager.affect_target(target, 'hp', damage, false)
			var splat = load("res://objects/battle/effects/splat/splat.tscn").instantiate()
			if Util.get_player().stats.has_item('Witch Hat'):
				splat.modulate = POISON_COLOR
			else:
				splat.modulate = Globals.SQUIRT_COLOR
			splat.set_text("SPLASH!")
			target.head_node.add_child(splat)
			if target.lured:
				manager.knockback_cog(target)
			else:
				target.set_animation('squirt-small')
			apply_debuff(target)
			await Task.delay(0.5 * (2 if was_lured else 1))
			manager.battle_text(target, "Drenched!", BattleText.colors.orange[0], BattleText.colors.orange[1])
		else:
			manager.battle_text(target, "IMMUNE")
		await manager.barrier(target.animator.animation_finished, 5.0)
		await manager.check_pulses(targets)
	else:
		target.set_animation('sidestep-left')
		manager.battle_text(target,"MISSED")
		await target.animator.animation_finished
	
	# Cleanup glass
	glass.queue_free()
	
	# End
	user.face_position(manager.battle_node.global_position)
