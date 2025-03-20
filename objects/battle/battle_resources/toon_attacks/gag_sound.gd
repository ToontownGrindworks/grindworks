extends ToonAttack
class_name GagSound

@export var model: PackedScene
@export var position: Vector3
@export var rotation: Vector3
@export var scale := Vector3(1,1,1)

@export var anim_delay := 1.9

@export var sfx_windup: AudioStream
@export var sfx_blast: AudioStream

var do_knockback := false

func action():
	# Play the movie's sfx
	sfx_track()
	
	# Begin
	var cog: Cog = main_target
	if is_instance_valid(cog):
		user.face_position(cog.global_position)
	else:
		user.face_position(manager.battle_node.global_position)
	user.set_animation('shout')
	manager.s_focus_char.emit(user)
	
	# Add the megaphone
	var megaphone = load("res://models/props/gags/megaphone/megaphone.tscn").instantiate()
	user.toon.right_hand_bone.add_child(megaphone)
	
	# Add gag to megaphone
	var gag = model.instantiate()
	megaphone.add_child(gag)
	# Transform the model
	gag.position = position
	gag.rotation_degrees = rotation
	gag.scale = scale
	
	# Wait until sound plays
	await manager.sleep(anim_delay)
	gag.get_node('AnimationPlayer').play('sound')
	
	# Wait until sound plays
	await manager.sleep(2.4 - anim_delay)
	manager.battle_node.focus_cogs()
	
	var hit := manager.roll_for_accuracy(self)
	
	if hit:
		# If we're doing knockback and any of our targets are lured,
		# give the funny special text
		if do_knockback and targets.filter(func(x: Cog): return x.lured and not get_immunity(x)).size() > 0:
			store_boost_text("Rude Awakening!", Color(0.328, 0.4, 0.96))

		var animator_target: Cog = null
		for target: Cog in targets:
			if not is_instance_valid(target):
				continue
			animator_target = target
			var real_damage = damage
			if target != main_target:
				real_damage *= 0.5
			if get_immunity(target):
				manager.battle_text(target, 'IMMUNE')
			else:
				manager.affect_target(target, real_damage)
			if not target.lured or not do_knockback:
				target.set_animation('squirt-small')
			elif not get_immunity(target):
				manager.knockback_cog(target)
		
		if animator_target:
			await manager.barrier(animator_target.animator.animation_finished, 5.0)
		
		# Check if any cogs are lured, and unlure them
		var lured_targets: Array[Cog] = []
		for target in targets:
			if target.lured:
				lured_targets.append(target)
		if not lured_targets.is_empty():
			var unlure_tween: Tween = manager.create_tween()
			unlure_tween.set_parallel(true)
			for target in lured_targets:
				target.set_animation('walk')
				unlure_tween.tween_property(target.get_node('Body'),'position:z',0,1.0)
				manager.force_unlure(target)
			await unlure_tween.finished
			for target in lured_targets:
				target.set_animation('neutral')
		await manager.check_pulses(targets)
	else:
		for target in targets:
			manager.battle_text(target,"MISSED")
		await manager.sleep(1.0)
	
	if user.get_animation() == 'shout':
		await user.animator.animation_finished
	
	megaphone.queue_free()

func sfx_track():
	await manager.sleep(1.0)
	if sfx_windup:
		AudioManager.play_sound(sfx_windup)
	await manager.sleep(1.4)
	if sfx_blast:
		AudioManager.play_sound(sfx_blast)

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

	string += "\nSplash: %s" % get_true_damage(0.5)

	return string
