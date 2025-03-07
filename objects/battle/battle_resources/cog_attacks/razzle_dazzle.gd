extends CogAttack
class_name RazzleDazzle

func action():
	var hit := manager.roll_for_accuracy(self)
	var target = targets[0]
	user.face_position(target.global_position)
	var teeth: Node3D = load('res://models/props/cog_props/teeth/teeth.tscn').instantiate()
	manager.s_focus_char.emit(user)
	user.body.right_hand_bone.add_child(teeth)
	teeth.scale *= 1.5
	user.set_animation('smile')
	
	# Await for particle timing
	await manager.sleep(1.5)
	AudioManager.play_sound(load('res://audio/sfx/battle/cogs/attacks/SA_razzle_dazzle.ogg'))
	
	# Create particles
	var particles : GPUParticles3D = load('res://objects/battle/effects/razzle_dazzle/razzle_dazzle.tscn').instantiate()
	teeth.add_child(particles)
	particles.position.y+=2.0
	particles.look_at(target.head_node.global_position)
	particles.top_level = true
	particles.scale = Vector3(1,1,1)
	
	# Move particles towards target
	var part_tween : Tween = particles.create_tween()
	part_tween.tween_property(particles,'global_position',target.head_node.global_position,1.75)
	
	# Focus player
	await manager.sleep(0.5)
	manager.s_focus_char.emit(target)
	
	# Dodge if not hit
	if not hit:
		target.set_animation('sidestep_left')
		manager.battle_text(target,"MISSED")
	
	# Destroy particles after they reach player
	await part_tween.finished
	part_tween.kill()
	particles.queue_free()
	
	# Hurt player if hit
	if hit:
		target.set_animation('cringe')
		manager.affect_target(target,'hp',damage,false)
	
	# Cleanup
	await manager.barrier(target.animator.animation_finished, 4.0)
	teeth.queue_free()
	
	
	await manager.check_pulses(targets)
