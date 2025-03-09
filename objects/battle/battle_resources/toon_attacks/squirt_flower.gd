extends GagSquirt
class_name SquirtFlower

func action():
	# Start
	manager.s_focus_char.emit(user)
	var target = targets[0]
	user.set_animation('button_press')
	user.face_position(target.global_position)
	
	# Place button in hand
	var button = load('res://models/props/gags/button/toon_button.tscn').instantiate()
	user.toon.left_hand_bone.add_child(button)
	
	# Place squirting flower
	var flower = load('res://models/props/gags/squirt_flower/squirt_flower.glb').instantiate()
	user.toon.flower_bone.add_child(flower)
	
	var is_tall_skirt: bool = (user.toon.toon_dna.body_type == ToonDNA.BodyType.LARGE and user.toon.toon_dna.skirt)
	var is_med_shorts: bool = (user.toon.toon_dna.body_type == ToonDNA.BodyType.MEDIUM and not user.toon.toon_dna.skirt)
	if is_tall_skirt or is_med_shorts:
		flower.rotation_degrees = Vector3(65.5,-88.5,0)
	
	await manager.sleep(2.3)
	var hit := manager.roll_for_accuracy(self)
	if hit or target.lured:
		AudioManager.play_sound(load("res://audio/sfx/battle/gags/squirt/AA_squirt_flowersquirt.ogg"))
	else:
		AudioManager.play_sound(load("res://audio/sfx/battle/gags/squirt/AA_squirt_flowersquirt_miss.ogg"))
	
	await manager.sleep(0.6)
	
	# Make the squirt happen
	soak_opponent(target.head_node, flower, .05)
	
	# Watch target get hit
	await manager.sleep(0.2)
	manager.s_focus_char.emit(target)
	
	# Accuracy roll
	if hit or target.lured:
		var was_lured: bool = target.lured
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
		target.set_animation('sidestep-left')
		manager.battle_text(target,"MISSED")
		await target.animator.animation_finished
	
	button.queue_free()
	flower.queue_free()
	
	# End
	user.face_position(manager.battle_node.global_position)
