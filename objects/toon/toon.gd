extends Node3D
class_name Toon

@export var toon_dna: ToonDNA
@export var randomize_dna := false
@export var auto_build := false

## Child References
@onready var body_node := $Body
@onready var drop_shadow: RayCast3D = %DropShadow

## Locals
var body: ToonBody
var head: Node3D
var animator: AnimationPlayer
var body_node_zero := 0.0

## For emotion displaying
enum Emotion {
	SAD,
	ANGRY,
	NEUTRAL,
	LAUGH,
	SURPRISE,
	DELIGHTED,
	CURIOUS,
}
var face_emotion := Emotion.NEUTRAL
var eyes_emotion := Emotion.NEUTRAL
var eyes_open := true
var mouths: Node3D
var eyes: Node3D
var eye_mat: StandardMaterial3D
var blink := false
var eyelashes: Node3D
var eyelash_meshes: Array[Node] = []

# Bones
var head_bone: BoneAttachment3D
var hat_bone: BoneAttachment3D
var glasses_bone: BoneAttachment3D
var backpack_bone: BoneAttachment3D
var right_hand_bone: BoneAttachment3D
var left_hand_bone: BoneAttachment3D
var flower_bone: BoneAttachment3D
var hip_bone: BoneAttachment3D


## Speech Values
var speech_bubble_node: Node3D
var yelp: AudioStream:
	get: return Globals.get_species_sfx(Globals.ToonDial.YELP, toon_dna)
var howl: AudioStream:
	get: return Globals.get_species_sfx(Globals.ToonDial.HOWL, toon_dna)
var speak_long: AudioStream:
	get: return Globals.get_species_sfx(Globals.ToonDial.SPEAK_LONG, toon_dna)
var speak_med: AudioStream:
	get: return Globals.get_species_sfx(Globals.ToonDial.SPEAK_MED, toon_dna)
var speak_short: AudioStream:
	get: return Globals.get_species_sfx(Globals.ToonDial.SPEAK_SHORT, toon_dna)
var question: AudioStream:
	get: return Globals.get_species_sfx(Globals.ToonDial.QUESTION, toon_dna)

var EYE_TEXTURES := LazyLoader.defer_dict({
	NEUTRAL_OPEN = "res://models/toon/textures/eyes/neutral.png",
	NEUTRAL_CLOSED = "res://models/toon/textures/eyes/neutral_closed.png",
	ANGRY_OPEN = "res://models/toon/textures/eyes/angry.png",
	ANGRY_CLOSED = "res://models/toon/textures/eyes/angry_closed.png",
	CURIOUS_OPEN = "res://models/toon/textures/eyes/curious.png",
	CURIOUS_CLOSED = "res://models/toon/textures/eyes/curious_closed.png",
	SAD_OPEN = "res://models/toon/textures/eyes/sad.png",
	SAD_CLOSED = "res://models/toon/textures/eyes/sad_closed.png",
	SURPRISE_OPEN = "res://models/toon/textures/eyes/surprise.png",
})

func _ready() -> void:
	if randomize_dna:
		toon_dna = ToonDNA.new()
		toon_dna.randomize_dna()
	if auto_build: construct_toon(toon_dna)

func construct_toon(dna: ToonDNA = ToonDNA.new()):
	if not dna:
		dna = ToonDNA.new()
	toon_dna = dna
	if body:
		body.queue_free()
	
	var body_type: String = dna.BodyType.keys()[dna.body_type].to_lower()
	if dna.skirt: body_type += '_skirt'
	body = Globals.ToonBodies.load()[body_type].instantiate()
	body_node.add_child(body)
	
	# Grab a reference to the body's animator
	animator = body.animator
	
	# Get the body bones
	hat_bone = body.hat_bone
	glasses_bone = body.glasses_bone
	backpack_bone = body.backpack_bone
	right_hand_bone = body.right_hand_bone
	left_hand_bone = body.left_hand_bone
	flower_bone = body.flower_bone
	hip_bone = body.hip_bone
	head_bone = body.head_bone
	
	# Texture the clothing
	var shirt_mat: StandardMaterial3D = body.shirt.mesh.surface_get_material(0).duplicate()
	if dna.shirt:
		if dna.shirt.shirt_texture: shirt_mat.albedo_texture = dna.shirt.shirt_texture
		shirt_mat.albedo_color = dna.shirt.base_color
	body.shirt.set_surface_override_material(0, shirt_mat)
	
	var sleeve_mat: StandardMaterial3D = body.sleeve_left.mesh.surface_get_material(0).duplicate()
	if dna.shirt:
		if dna.shirt.sleeve_texture: sleeve_mat.albedo_texture = dna.shirt.sleeve_texture
		sleeve_mat.albedo_color = dna.shirt.sleeve_color
	body.sleeve_left.set_surface_override_material(0, sleeve_mat)
	body.sleeve_right.set_surface_override_material(0, sleeve_mat)
	
	var bottoms_mat: StandardMaterial3D = body.bottoms.mesh.surface_get_material(0).duplicate()
	if dna.bottoms:
		if dna.bottoms.texture: bottoms_mat.albedo_texture = dna.bottoms.texture
		bottoms_mat.albedo_color = dna.bottoms.base_color
	body.bottoms.set_surface_override_material(0, bottoms_mat)

	# Color the body
	var neck_mat: StandardMaterial3D = body.neck.mesh.surface_get_material(0).duplicate()
	var arm_mat: StandardMaterial3D = body.arm_left.mesh.surface_get_material(0).duplicate()
	var leg_mat: StandardMaterial3D = arm_mat.duplicate()
	var foot_mat: StandardMaterial3D = body.foot_left.mesh.surface_get_material(0).duplicate()
	neck_mat.albedo_color = dna.head_color
	arm_mat.albedo_color = dna.torso_color
	leg_mat.albedo_color = dna.leg_color
	foot_mat.albedo_color = dna.leg_color
	body.neck.set_surface_override_material(0, neck_mat)
	body.arm_left.set_surface_override_material(0, arm_mat)
	body.arm_right.set_surface_override_material(0, arm_mat)
	body.leg_left.set_surface_override_material(0, leg_mat)
	body.leg_right.set_surface_override_material(0, leg_mat)
	body.foot_left.set_surface_override_material(0, foot_mat)
	body.foot_right.set_surface_override_material(0, foot_mat)
	
	# Create head
	var species: String = dna.ToonSpecies.keys()[dna.species].to_lower()
	var toonhead = Globals.ToonHeads.load()[species].instantiate()
	head_bone.add_child(toonhead)
	dna.head_index = clamp(dna.head_index, 0, toonhead.get_child_count() - 1)
	for i in toonhead.get_child_count():
		if i == dna.head_index:
			toonhead.get_child(i).show()
			head = toonhead.get_child(i)
		else:
			toonhead.get_child(i).hide()
	
	# Color head
	var colored_meshes: Node3D = head.find_child('colored_meshes')
	for mesh in colored_meshes.get_children():
		color_mesh(mesh,dna.head_color)
	
	# Get the mouths if they exist
	mouths = head.get_node_or_null('mouths')
	# Get the eyes if they exist
	# And create an override material for them
	eyes = head.get_node_or_null('eyes')
	if eyes:
		if eyes.get_child_count() > 0:
			var eye_mesh: MeshInstance3D = eyes.get_child(0)
			eye_mat = eye_mesh.mesh.surface_get_material(0).duplicate()
			eye_mesh.set_surface_override_material(0,eye_mat)
			if dna.species == ToonDNA.ToonSpecies.RABBIT:
				eyes.get_child(1).set_surface_override_material(0,eye_mat)
	# Turn on eyelashes
	eyelashes = head.get_node_or_null('eyelashes')
	if eyelashes:
		eyelash_meshes = eyelashes.get_children()
		if dna.eyelashes:
			eyelashes.show()
		else:
			eyelashes.hide()
	
	# Hide the ears when not dog
	if not dna.species == ToonDNA.ToonSpecies.DOG:
		body.ear_left.hide()
		body.ear_right.hide()
	
	# Get speech bubble node
	if body.get_node_or_null('SpeechBubbleNode'):
		speech_bubble_node = body.get_node('SpeechBubbleNode')
	
	# Start blinking
	do_blink()
	
	# Scale as per species specification
	scale = Vector3(1, 1, 1) * (ToonDNA.SPECIES_SCALE.get(dna.species) * ToonDNA.BASE_SCALE)
	
	body_node_zero = NodeGlobals.calculate_spatial_bounds(body.skeleton, false).get_center().y
	body.position.y = -body_node_zero
	body_node.position.y = body_node_zero

func color_mesh(mesh: MeshInstance3D, color: Color) -> void:
	var surface_count: int = mesh.mesh.get_surface_count()
	for i in surface_count:
		var newmat: StandardMaterial3D = mesh.mesh.surface_get_material(i).duplicate()
		newmat.albedo_color = color
		mesh.set_surface_override_material(i,newmat)

func speak(phrase: String):
	if not speech_bubble_node:
		print('ERR: No speech bubble node found!')
		return
	
	# Remove existing speech bubble(s) if they exist
	for child in speech_bubble_node.get_children():
		if child is SpeechBubble:
			child.finished.emit()
	
	# Create a new speech bubble
	var bubble: SpeechBubble = load('res://objects/misc/speech_bubble/speech_bubble.tscn').instantiate()
	bubble.target = speech_bubble_node
	speech_bubble_node.add_child(bubble)
	bubble.set_text(phrase)
	
	# Play appropriate speech sfx
	var sfx: AudioStream
	if phrase.to_lower().contains('ooo'):
		sfx = howl
	if phrase.contains('!'):
		sfx = yelp
	elif phrase.contains('?'):
		sfx = question
	elif phrase.length() > 15:
		sfx = speak_long
	elif phrase.length() > 5:
		sfx = speak_med
	else:
		sfx = speak_short
	if sfx:
		AudioManager.play_sound(sfx)

func set_animation(anim: String) -> void:
	if body:
		body.set_animation(anim)

func run_to(global_pos: Vector3, time: float, anim := "run") -> Tween:
	var run_tween := create_tween()
	run_tween.tween_callback(face_position.bind(global_pos))
	run_tween.tween_callback(set_animation.bind(anim))
	run_tween.tween_property(self, 'global_position', global_pos, time)
	run_tween.tween_callback(set_animation.bind('neutral'))
	run_tween.finished.connect(run_tween.kill)
	return run_tween

func face_position(pos: Vector3) -> void:
	look_at(Vector3(pos.x, global_position.y, pos.z), Vector3.UP, true)

## Sets the mouth and eyes to the same expression
func set_emotion(expression : Emotion) -> void:
	set_mouth(expression)
	set_eyes(expression)

func set_mouth(expression : Emotion):
	if not mouths: 
		return
	face_emotion = expression
	var face = Emotion.keys()[expression].to_lower()
	for mouth in mouths.get_children():
		if mouth.name == face:
			mouth.show()
		else:
			mouth.hide()

func set_eyes(expression: Emotion) -> void:
	if not eyes: 
		return
	eyes_emotion = expression
	var face : String = Emotion.keys()[expression].to_upper() + "_OPEN"
	var eye_textures: Dictionary = EYE_TEXTURES.load()
	if eye_textures.keys().has(face):
		eye_mat.albedo_texture = eye_textures[face]

func close_eyes() -> void:
	eyes_open = false
	var face : String = Emotion.keys()[eyes_emotion as int].to_upper() + "_CLOSED"
	var eye_textures: Dictionary = EYE_TEXTURES.load()
	if eye_textures.keys().has(face):
		eye_mat.albedo_texture = eye_textures[face]
	
	# Also hide pupils / eyelashes
	if eyes and eyes.get_child_count() > 2:
		for i in range(eyes.get_child_count()-1,eyes.get_child_count()-3,-1):
			eyes.get_child(i).hide()
	if eyelashes and toon_dna.eyelashes:
		for lash in eyelash_meshes:
				if lash.name.begins_with('Close') : lash.show()
				else: lash.hide()

func open_eyes() -> void:
	eyes_open = true
	var face : String = Emotion.keys()[eyes_emotion as int].to_upper() + "_OPEN"
	var eye_textures: Dictionary = EYE_TEXTURES.load()
	if eye_textures.keys().has(face):
		eye_mat.albedo_texture = eye_textures[face]
	
	# Show pupils and eyelashes
	if eyes and eyes.get_child_count() > 2:
		for i in range(eyes.get_child_count()-1,eyes.get_child_count()-3,-1):
			eyes.get_child(i).show()
	if eyelashes and toon_dna.eyelashes:
		for lash in eyelash_meshes:
			if lash.name.begins_with('Open') : lash.show()
			else: lash.hide()

func do_blink() -> void:
	var blink_timer := Timer.new()
	body.add_child(blink_timer)
	blink_timer.one_shot = true
	while is_instance_valid(blink_timer):
		blink_timer.wait_time = randf() * 5.0 + 15.0
		blink_timer.start()
		await blink_timer.timeout
		# Only blink if eyes are open right now
		if eyes_open:
			close_eyes()
			await Task.delay(0.1)
			open_eyes()

#region ANIMATIONS

func teleport_in() -> void:
	if not body:
		push_warning("Toon can't teleport in because it has no body!")
		return
	body.position.y -= 10.0
	var hole : Node3D = load('res://objects/misc/teleport_hole/teleport_hole.tscn').instantiate()
	add_child(hole)
	hole.position.y = 0.01
	hole.scale *= 0.4
	hole.get_node('AnimationPlayer').play('grow')
	await hole.get_node('AnimationPlayer').animation_finished
	var meshes: Array[MeshInstance3D] = [
		body.shirt, body.bottoms, body.neck, body.arm_left, body.arm_right,
		body.sleeve_left, body.sleeve_right, body.hand_left, body.hand_right,
		body.leg_left, body.leg_right, body.foot_left, body.foot_right,
		body.ear_left, body.ear_right
	]
	hole.get_node('ClipPlane').apply_to_mesh_instances(meshes)
	set_animation('happy')
	body.animator.seek(0.4)
	var jump_tween := create_tween()
	jump_tween.set_trans(Tween.TRANS_QUAD)
	jump_tween.tween_property(body,'position:y',-body_node_zero,0.25)
	await jump_tween.finished
	hole.get_node('AnimationPlayer').play('shrink')
	await body.animator.animation_finished
	hole.get_node('ClipPlane').unapply_from_mesh_instances(meshes)
	hole.queue_free()

func teleport_out() -> void:
	if not body:
		push_warning("Toon can't teleport out because it has no body!")
		return
	var hole : Node3D = load('res://objects/misc/teleport_hole/teleport_hole.tscn').instantiate()
	right_hand_bone.add_child(hole)
	hole.position = Vector3(-0.2,1.0,0.25)
	hole.rotation_degrees.z = 90.0
	set_animation('teleport')
	AudioManager.play_sound(load("res://audio/sfx/toon/AV_teleport.ogg"))
	await Task.delay(1.6)
	hole.reparent(self)
	var throw_tween := create_tween()
	throw_tween.set_parallel(true)
	throw_tween.tween_property(hole,'scale',Vector3(0.4,0.4,0.4),0.05)
	throw_tween.tween_property(hole,'position',Vector3(0,0.1,0.5),0.05)
	throw_tween.tween_property(hole,'rotation',Vector3(0,0,0),0.05)
	await throw_tween.finished
	throw_tween.kill()
	await body.animator.animation_finished
	hole.get_node('AnimationPlayer').play('shrink')
	await hole.get_node('AnimationPlayer').animation_finished
	hole.queue_free()

var duck_tween : Tween
func duck_and_cover() -> void:
	# Create the duck tween
	if duck_tween and duck_tween.is_valid():
		duck_tween.kill()
	duck_tween = create_tween()
	
	# Make toon duck
	duck_tween.tween_callback(set_animation.bind('duck'))
	duck_tween.tween_interval(3.5)
	duck_tween.tween_callback(animator.set_speed_scale.bind(-1.0))
	duck_tween.tween_interval(1.8)
	duck_tween.tween_callback(animator.set_speed_scale.bind(1.0))
	duck_tween.finished.connect(duck_tween.kill)

#endregion

#region Interval helpers

var run_speed := 8.0

func move_to(new_pos: Vector3, spd: float = run_speed, override_anim := "") -> Tween:
	# Calculate move time
	var time = new_pos.distance_to(global_position) / spd
	# Set movement anim
	if time > 0.5:
		set_animation('run')
	else:
		set_animation('walk')
	if override_anim != "":
		set_animation(override_anim)
	# Look at new position
	face_position(new_pos)
	# Use tween to move
	var move_tween = create_tween()
	move_tween.tween_property(self, 'global_position', new_pos,time)
	move_tween.finished.connect(move_tween_finished.bind(move_tween))
	return move_tween

func move_tween_finished(tween: Tween):
	set_animation('neutral')
	tween.kill()

func turn_to_position(pos: Vector3, time: float):
	set_animation('walk')
	var toon_scale: Vector3 = scale
	var cur_rot: Vector3 = global_rotation
	face_position(pos)
	var new_rot: Vector3 = global_rotation
	global_rotation = cur_rot
	
	var turn_tween := create_tween()
	turn_tween.set_parallel(true)
	turn_tween.tween_method(toon_lerp_angle.bind(cur_rot.y, new_rot.y, toon_scale), 0.0, 1.0, time)
	await turn_tween.finished
	turn_tween.kill()
	set_animation('neutral')

func toon_lerp_angle(weight: float, start_angle: float, end_angle: float, toon_scale: Vector3) -> void:
	rotation.y = lerp_angle(start_angle, end_angle, weight)
	set_scale(toon_scale)

#endregion
