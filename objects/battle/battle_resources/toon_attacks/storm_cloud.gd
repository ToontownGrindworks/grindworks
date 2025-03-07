extends GagSquirt
class_name StormCloud


func action():
	# Start
	manager.s_focus_char.emit(user)
	var target = targets[0]
	user.set_animation('button_press')
	user.face_position(target.global_position)
	
	# Place button in hand
	var button = load('res://models/props/gags/button/toon_button.tscn').instantiate()
	user.toon.left_hand_bone.add_child(button)
	
	# Place a storm cloud above the cog
	var cloud = load('res://models/props/gags/storm_cloud/storm_cloud.tscn').instantiate()
	manager.get_tree().get_root().add_child(cloud)
	cloud.reparent(target.head_node)
	cloud.position = Vector3(0,3.0,0)
	cloud.rotation = Vector3(0,0,0)
	
	# Activate cloud after button press
	await manager.sleep(2.3)
	cloud.get_node('AnimationPlayer').play('rain')
	cloud.get_node('RainDrops').emitting = true
	manager.s_focus_char.emit(target)
	shrink_cloud(cloud)
	
	# Roll for accuracy
	var hit := manager.roll_for_accuracy(self)
	
	# Do hit or not do hit
	if hit or target.lured:
		var was_lured: bool = target.lured
		if not get_immunity(target):
			s_hit.emit()
			AudioManager.play_sound(load("res://audio/sfx/battle/gags/squirt/AA_throw_stormcloud.ogg"))
			manager.affect_target(target, 'hp', damage, false)
			if target.lured:
				manager.knockback_cog(target)
			else:
				target.set_animation('soak')
			apply_debuff(target)
			await Task.delay(0.5 * (2 if was_lured else 1))
			manager.battle_text(target, "Drenched!", BattleText.colors.orange[0], BattleText.colors.orange[1])
		else:
			manager.battle_text(target, "IMMUNE")
		await manager.barrier(target.animator.animation_finished, 5.0)
		await manager.check_pulses(targets)
	else:
		AudioManager.play_sound(load("res://audio/sfx/battle/gags/squirt/AA_throw_stormcloud_miss.ogg"))
		target.set_animation('sidestep-left')
		manager.battle_text(target,"MISSED")
		await target.animator.animation_finished
	
	# Cleanup
	button.queue_free()

func shrink_cloud(cloud : Node3D):
	var shrink_tween = cloud.create_tween()
	shrink_tween.tween_callback(cloud.get_node('RainDrops').set_emitting.bind(false))
	shrink_tween.tween_interval(3.0)
	shrink_tween.tween_property(cloud, 'scale', Vector3(0.01, 0.01, 0.01), 1.0)
	shrink_tween.finished.connect(cloud.queue_free)
