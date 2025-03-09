extends GagSquirt
class_name SquirtGun

func action():
	# Start
	manager.s_focus_char.emit(user)
	var target = targets[0]
	user.set_animation('squirt_gun')
	user.face_position(target.global_position)
	
	# Place gun in hand
	var gun = load('res://models/props/gags/water_gun/water_gun.tscn').instantiate()
	user.toon.right_hand_bone.add_child(gun)
	gun.position = Vector3(-0.214,0.125,-0.025)
	gun.rotation_degrees = Vector3(0,90,90)
	gun.scale*=.85
	
	await manager.sleep(1.8)
	
	# Make the squirt happen
	soak_opponent(target.head_node,gun.get_node('Barrel'),.05)
	
	# Cleanup
	await manager.sleep(0.2)
	manager.s_focus_char.emit(target)
	
	# Accuracy roll
	if manager.roll_for_accuracy(self) or target.lured:
		var was_lured: bool = target.lured
		AudioManager.play_sound(load("res://audio/sfx/battle/gags/squirt/AA_squirt_neonwatergun.ogg"))
		manager.affect_target(target, 'hp', damage, false)
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
		AudioManager.play_sound(load("res://audio/sfx/battle/gags/squirt/AA_squirt_neonwatergun_miss.ogg"))
		target.set_animation('sidestep-left')
		manager.battle_text(target,"MISSED")
		await target.animator.animation_finished
	
	# End
	gun.queue_free()
	user.face_position(manager.battle_node.global_position)
