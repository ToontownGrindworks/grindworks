extends GagTrap
class_name TrapToss

const SLIP_SFX := preload("res://audio/sfx/battle/gags/throw/AA_pie_throw_only.ogg")
const HIT_GROUND_SFX := preload("res://audio/sfx/battle/gags/trap/Toon_bodyfall_synergy.ogg")

@export var model : PackedScene
@export var toss_time := 1.5
enum ActiveMovie {
	BANANA,
	RAKE,
	TNT
}
@export var animation := ActiveMovie.BANANA
@export var toss_sfx : AudioStream

# Locals
var path : Path3D
var prop : Node3D


func action():
	var target = targets[0]
	user = Util.get_player()
	
	if target.trap or (target.lured and user.trap_needs_lure):
		return
	
	manager.s_focus_char.emit(user)
	user.set_animation('toss')
	user.face_position(target.global_position)
	
	# Add the prop to the hand
	prop = model.instantiate()
	user.toon.right_hand_bone.add_child(prop)
	prop.get_node('AnimationPlayer').play('toss')
	
	# Wait for throw
	match user.toon.toon_dna.body_type:
		ToonDNA.BodyType.SMALL:
			await manager.sleep(2.1)
		_:
			await manager.sleep(2.65)
	
	# Play toss sfx if one exists
	if toss_sfx:
		AudioManager.play_sound(toss_sfx)
	
	set_camera_angle(camera_angles.SIDE_RIGHT)
	
	if action_name == "Marbles":
		prop.reparent(target)
		prop.rotation_degrees = Vector3(0, -94, 0)
		prop.scale *= 1.25

		var toss_tween := manager.create_tween()
		toss_tween.tween_property(prop, ^"position", Vector3(0, 0, Globals.SUIT_LURE_DISTANCE + 2.0), 0.2)
		await toss_tween.finished
		toss_tween.kill()

		var roll_tween := manager.create_tween()
		roll_tween.tween_property(prop, ^"position", Vector3(0, 0, Globals.SUIT_LURE_DISTANCE), 1.0)
		await roll_tween.finished
		roll_tween.kill()
	else:
		# Create a Curve3D that follows where the prop should go
		path = Path3D.new()
		var curve := Curve3D.new()
		var follower = PathFollow3D.new()
		target.add_child(path)
		path.curve = curve
		curve.bake_interval = 2.0
		path.add_child(follower)
		follower.rotation_mode = PathFollow3D.ROTATION_NONE
		
		# First path point should be the prop's current global position
		prop.reparent(path)
		var first_pos: Vector3 = prop.position
		# The final position is always 0,0,2
		var final_pos = Vector3(0, 0, Globals.SUIT_LURE_DISTANCE)
		if action_name == "Rake":
			final_pos += Vector3(0, -0.25, 0.5)
		# The midpoint is the position between the two points
		# With a higher y position
		var midpt: Vector3
		midpt = first_pos.move_toward(final_pos,first_pos.distance_to(final_pos) / 2.0)
		midpt.y += 2.0
		# Add all points to the curve
		curve.add_point(first_pos)
		curve.add_point(midpt)
		curve.add_point(final_pos)
		
		# Reparent the prop to the follower
		prop.reparent(follower)
		prop.position = Vector3.ZERO
		prop.rotation = Vector3.ZERO
		if action_name == "Rake":
			prop.rotation_degrees.x = -2.6
		prop.scale *= 1.25
		
		# Make a tween that follows the path
		var toss_tween := manager.create_tween()
		toss_tween.tween_property(follower, 'progress_ratio', 1.0, toss_time)
		await toss_tween.finished
		toss_tween.kill()

	# Await animation finish
	await user.animator.animation_finished
	
	# Apply trap to the target
	target.trap = self
	baked_crit_chance = manager.get_crit_chance(self)
	print("Trap: Baking crit chance to %s" % baked_crit_chance)

	apply_trap_effect(target)

	# For detective hat item
	if not user.trap_needs_lure and target.lured:
		manager.force_unlure(target)
		await activate()

func activate():
	s_activate.emit()
	# Make the cog stand at the trap position
	var target = targets[0]
	target.get_node('Body').position = Vector3(0,0,Globals.SUIT_LURE_DISTANCE)
	
	set_camera_angle(camera_angles['SIDE_RIGHT'])
	
	match animation:
		ActiveMovie.BANANA:
			await banana()
		ActiveMovie.RAKE:
			await rake()
		ActiveMovie.TNT:
			await tnt()
	
	# Make the cog walk back to the proper position after the trap has finished
	target.set_animation('walk')
	var walk_tween : Tween = manager.create_tween()
	walk_tween.tween_property(target.get_node('Body'),'position:z',0.0,0.5)
	await walk_tween.finished
	target.set_animation('neutral')
	walk_tween.kill()
	
	# Check if target is alive
	await manager.check_pulses(targets)
	
	# Take the trap value away from the cog.
	target.trap = null
	
	# Delete trap tree if it still exists
	if path:
		path.queue_free()
	
	s_trap.emit()

func banana():
	AudioManager.play_sound(SLIP_SFX)
	var target = targets[0]
	target.set_animation('slip-backward')
	if action_name == "Marbles":
		prop.get_node("AnimationPlayer").play("toss")
	var shrink_tween := manager.create_tween()
	shrink_tween.tween_property(path if path else prop, 'scale', Vector3(.001, .001, .001), 0.75)
	await Task.delay(0.55)
	AudioManager.play_sound(HIT_GROUND_SFX)
	await Task.delay(0.45)
	shrink_tween.kill()
	if activating_lure:
		activating_lure.current_activating_trap = self
	if not get_immunity(target):
		manager.affect_target(target, 'hp', damage, false)
	else:
		manager.battle_text(target, "IMMUNE")
	if activating_lure:
		activating_lure.current_activating_trap = null
	await target.animator.animation_finished

func rake():
	var target = targets[0]
	target.set_animation('rake')
	await manager.sleep(0.3)
	prop.get_node('AnimationPlayer').play('spring')
	AudioManager.play_sound(load('res://audio/sfx/battle/gags/trap/TL_step_on_rake.ogg'))
	prop.get_node('AnimationPlayer').seek(2.5)
	prop.get_node('AnimationPlayer').speed_scale = 2.0
	await manager.sleep(0.2)
	if activating_lure:
		activating_lure.current_activating_trap = self
	if not get_immunity(target):
		manager.affect_target(target, 'hp', damage, false)
	else:
		manager.battle_text(target, "IMMUNE")
	if activating_lure:
		activating_lure.current_activating_trap = null
	await target.animator.animation_finished
	prop.hide()

func tnt():
	var target = targets[0]
	await look_down(target)
	if activating_lure:
		activating_lure.current_activating_trap = self
	if not get_immunity(target):
		manager.affect_target(target, 'hp', damage, false)
	else:
		manager.battle_text(target, "IMMUNE")
	if activating_lure:
		activating_lure.current_activating_trap = null
	
	prop.get_node('tnt').hide()
	AudioManager.play_sound(load('res://audio/sfx/battle/cogs/ENC_cogfall_apart.ogg'),-4.0)
	
	do_kaboom()
	
	await target.do_knockback()

# Works in tandem with trap door to create an animation effect
func look_down(target: Cog):
	target.set_animation('flailing')
	var look_tween: Tween = target.create_tween()
	look_tween.tween_method(target.animator.seek, 0.0, 0.6, 0.6)
	look_tween.tween_method(target.animator.seek, 0.6, 0.0, 0.6)
	await look_tween.finished
	look_tween.kill()
	target.animator.pause()

func do_kaboom():
	var kaboom: Sprite3D = prop.get_node('Kaboom')
	kaboom.visible = true
	var kaboom_tween: Tween = prop.create_tween()
	kaboom_tween.tween_property(kaboom, 'pixel_size', .05, 0.25)
	await kaboom_tween.finished
	kaboom_tween.kill()
	kaboom.hide()
