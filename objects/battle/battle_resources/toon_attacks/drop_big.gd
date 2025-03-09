extends GagDrop
class_name DropBig

@export var model: PackedScene
@export var shadow_scale: float = 4.0
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
		
		await manager.sleep(2.3)
		AudioManager.play_sound(load('res://audio/sfx/battle/gags/AA_trigger_box.ogg'))
		
		# Wait for button press
		await manager.sleep(0.2)
	
	# Roll for accuracy
	var hit: bool = manager.roll_for_accuracy(self)
	
	# Play incoming whistle
	AudioManager.play_snippet(load('res://audio/sfx/battle/gags/drop/incoming_whistleALT.ogg'), 0.0, 2.0)
	
	# Shadow
	manager.s_focus_char.emit(target)
	var shadow = load('res://objects/misc/drop_shadow/drop_shadow.tscn').instantiate()
	target.body.add_child(shadow)
	var shadow_tween: Tween = shadow.create_tween()
	shadow.position.y += 0.05
	if not hit:
		shadow.position.z += 4.0
	shadow.scale = Vector3(0.1, 0.1, 0.1)
	shadow_tween.tween_property(shadow, 'scale', Vector3(1, 1, 1) * shadow_scale, 2.0)
	await shadow_tween.finished
	shadow_tween.kill()
	shadow.queue_free()
	
	# Load the gag in
	var gag = model.instantiate()
	
	manager.get_tree().get_root().add_child(gag)
	gag.reparent(target.body)
	gag.position = Vector3(0, 0, 0)
	if not hit:
		gag.position.z += 4.0
	gag.rotation_degrees = Vector3(0, 180, 0)
	gag.scale /= 4.0
	gag.get_node('AnimationPlayer').play('drop')
	
	if hit:
		AudioManager.play_sound(sfx_hit)
		target.set_animation('drop')
		if not get_immunity(target):
			var damage_dealt: int = manager.affect_target(target, 'hp', damage, false)
			apply_debuff(target, damage_dealt)
			await Task.delay(0.5)
			manager.battle_text(target, "Aftershock!", BattleText.colors.orange[0], BattleText.colors.orange[1])
		else:
			manager.battle_text(target, "IMMUNE")
			await manager.sleep(0.5)
		await manager.sleep(2.5)
		shrink_gag(gag)
		await target.animator.animation_finished
		await manager.check_pulses(targets)
	else:
		AudioManager.play_sound(sfx_miss)
		manager.battle_text(target, "MISSED")
		await manager.sleep(1.0)
		await shrink_gag(gag)
	
	# Cleanup
	if button:
		button.queue_free()

func shrink_gag(gag : Node3D):
	var shrink_tween = gag.create_tween()
	shrink_tween.tween_property(gag,'scale',Vector3(.01,.01,.01),1.0)
	await shrink_tween.finished
	shrink_tween.kill()
	gag.queue_free()
