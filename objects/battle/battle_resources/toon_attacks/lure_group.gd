extends GagLure
class_name LureGroup

@export var sfx: AudioStream
signal s_lured

func action():
	# Immediately return if all cogs are lured
	var all_lured := true
	for cog in manager.cogs:
		if not cog.lured:
			all_lured = false
			break
	if all_lured:
		return
	
	var hit := manager.roll_for_accuracy(self)
	
	var sfx_delay := 0.5
	
	# Setup the lure prop/animation
	var prop: Node3D
	var wait_time: float
	var cog_anim: String
	if action_name == "Hypno Goggles":
		prop = load("res://models/props/gags/hypno_goggles/hypno_goggles.tscn").instantiate()
		user.toon.glasses_bone.add_child(prop)
		prop.get_node('AnimationPlayer').play('hypnotize')
		user.set_animation('hypnotize')
		cog_anim = 'hypnotize'
		wait_time = 1.25
	elif action_name.to_lower().contains('magnet'):
		if action_name == "Small Magnet":
			prop = load("res://models/props/gags/magnet/magnet_red.tscn").instantiate()
		else:
			prop = load("res://models/props/gags/magnet/magnet_blue.tscn").instantiate()
		user.toon.left_hand_bone.add_child(prop)
		prop.rotation_degrees = Vector3(-81.8, -132.1, 42.3)
		prop.position = Vector3(-0.21, 0.27, 0.184)
		if action_name == "Small Magnet":
			prop.scale /= 2.0
		user.set_animation('hold_magnet')
		cog_anim = 'landing'
		wait_time = 2.5
	else:
		prop = load("res://models/props/gags/presentation/presentation.fbx").instantiate()
		battle_node.add_child(prop)
		prop.scale.y = 0.01
		prop.position.z += 0.5
		wait_time = 2.5
		cog_anim = 'hypnotize'
		press_button()
		sfx_delay = 2.4
		Task.delay(2.5).connect(animate_presentation.bind(prop))
	
	battle_node.focus_character(user)
	
	# SFX
	await manager.sleep(sfx_delay)
	if sfx:
		AudioManager.play_sound(sfx)
	
	await manager.sleep(wait_time-sfx_delay)
	
	battle_node.focus_cogs()
	
	if hit:
		var hit_cogs := []
		for target in targets:
			# Do not lure cogs an additional time
			if target.lured:
				continue
			elif get_immunity(target):
				manager.battle_text(target, "IMMUNE")
				continue
			manager.battle_text(target, "Damage Down!", BattleText.colors.orange[0], BattleText.colors.orange[1])
			if cog_anim == 'landing':
				animate_magnet_pull(target)
			else:
				target.set_animation('hypnotize')
				animate_hypno(target)
				
			hit_cogs.append(target)
			
		# Wait for lure anim to finish
		var barrier_anim := SignalBarrier.new()
		barrier_anim._barrier_type = SignalBarrier.BarrierType.ALL
		for cog in hit_cogs:
			barrier_anim.append(cog.animator.animation_finished)
		await manager.barrier(barrier_anim.s_complete, 8.0)
		
		# Cleanup Prop
		prop.queue_free()
		user.set_animation('neutral')
		
		# Now await their trap OR just lure the cog
		var barrier_turn := SignalBarrier.new()
		barrier_turn._barrier_type = SignalBarrier.BarrierType.ALL
		for cog in hit_cogs:
			if cog.trap:
				trap_gags.append(cog.trap)
				cog.trap.activating_lure = self
				barrier_turn.append(cog.trap.s_trap)
				cog.trap.activate()
			else:
				apply_lure(cog)
		if not barrier_turn._signal_arr.is_empty():
			await manager.barrier(barrier_turn.s_complete, 15.0)
	else:
		for cog in targets:
			manager.battle_text(cog,"MISSED")
		await manager.barrier(user.animator.animation_finished, 10.0)
		user.set_animation('neutral')
		prop.queue_free()

func animate_magnet_pull(target):
	var animator : AnimationPlayer = target.animator
	target.set_animation('landing')
	var shake_duration := 0.8
	var total_shakes := 3
	
	# Animation tween
	var lure_tween: Tween = manager.create_tween()
	for i in total_shakes:
		lure_tween.tween_method(animator.seek, 1.82, 1.16, shake_duration / total_shakes)
	lure_tween.tween_method(animator.seek, 1.16, 0.7, 0.46)
	lure_tween.tween_callback(animator.play)
	
	await manager.sleep(shake_duration)
	var move_tween: Tween = manager.create_tween()
	move_tween.set_parallel(true)
	move_tween.tween_property(manager.battle_node.battle_cam, 'position:z', manager.battle_node.battle_cam.position.z + Globals.SUIT_LURE_DISTANCE, 1.3)
	move_tween.tween_property(target.get_node('Body'), 'position:z', Globals.SUIT_LURE_DISTANCE, 1.3)
	await move_tween.finished
	move_tween.kill()

func animate_hypno(target: Node3D):
	await manager.sleep(1.0)
	var tween: Tween = target.create_tween()
	tween.set_parallel(true)
	tween.tween_property(manager.battle_node.battle_cam, 'position:z', manager.battle_node.battle_cam.position.z + Globals.SUIT_LURE_DISTANCE, 2.0)
	tween.tween_property(target.get_node('Body'), 'position:z', Globals.SUIT_LURE_DISTANCE, 2.0)
	await tween.finished
	tween.kill()

func animate_presentation(prop: Node3D) -> void:
	var tween := manager.create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(prop, 'scale:y', 1.0, 1.5)
	tween.finished.connect(tween.kill)
