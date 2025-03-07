extends GagDrop
class_name DropSmall

@export var model: PackedScene
@export var shadow_scale: float = 2.0
@export var sfx_hit: AudioStream
@export var sfx_miss: AudioStream

func action():
	# Start
	var target = targets[0]
	var button: Node3D
	if not skip_button_movie:
		manager.s_focus_char.emit(user)
		user.set_animation('button_press')
		user.face_position(target.global_position)
		# Place button in hand
		button = load('res://models/props/gags/button/toon_button.tscn').instantiate()
		user.toon.left_hand_bone.add_child(button)
		
		# Wait for button press
		await manager.sleep(2.3)
		AudioManager.play_sound(load('res://audio/sfx/battle/gags/AA_trigger_box.ogg'))
		await manager.sleep(0.2)
	
	# Shadow
	manager.s_focus_char.emit(target)
	var shadow = load('res://objects/misc/drop_shadow/drop_shadow.tscn').instantiate()
	target.body.add_child(shadow)
	var shadow_tween : Tween = shadow.create_tween()
	shadow.position.y += 0.05
	shadow.scale = Vector3(0.1, 0.1, 0.1)
	shadow_tween.tween_property(shadow, 'scale', Vector3(1, 1, 1) * shadow_scale, 2.0)
	
	# Roll for accuracy
	var hit: bool = manager.roll_for_accuracy(self)
	
	# Play incoming whistle
	AudioManager.play_snippet(load('res://audio/sfx/battle/gags/drop/incoming_whistleALT.ogg'), 0.0, 2.0)
	
	if not hit:
		await manager.sleep(0.5)
		target.set_animation('sidestep-left')
	
	# Await shadow finish
	await shadow_tween.finished
	shadow_tween.kill()
	shadow.queue_free()
	
	# Drop the gag
	var gag = model.instantiate()
	if hit:
		target.body.add_child(gag)
		gag.global_position = target.body.head_bone.global_position
		gag.position.y -= (1.0 if target.dna.suit == CogDNA.SuitType.SUIT_C else 2.0)
	else:
		target.add_child(gag)
	gag.get_node('AnimationPlayer').play('drop')
	
	# React to hit or not hit
	if hit:
		AudioManager.play_sound(sfx_hit)
		# Scale down head
		target.set_animation('anvil-drop')
		if not get_immunity(target):
			var damage_dealt: int = manager.affect_target(target, 'hp', damage, false)
			apply_debuff(target, damage_dealt)
			await Task.delay(0.5)
			manager.battle_text(target, "Aftershock!", BattleText.colors.orange[0], BattleText.colors.orange[1])
		else:
			manager.battle_text(target, "IMMUNE")
		await manager.barrier(target.animator.animation_finished, 4.0)
		gag.queue_free()
		await manager.check_pulses(targets)
	else:
		gag.scale /= 2.0
		AudioManager.play_sound(sfx_miss)
		manager.battle_text(target, "MISSED")
		await target.animator.animation_finished
	
	if is_instance_valid(gag):
		gag.queue_free()
	if button:
		button.queue_free()
