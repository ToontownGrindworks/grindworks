extends Node3D
class_name Goon

## Resource References
const SFX_ALERT := preload("res://audio/sfx/objects/goon/CHQ_GOON_tractor_beam_alarmed.ogg")
const SFX_HUNKER := preload("res://audio/sfx/objects/goon/CHQ_GOON_hunker_down.ogg")
const SFX_RECOVER := preload("res://audio/sfx/objects/goon/CHQ_GOON_rattle_shake.ogg")
const SFX_EXPLODE := preload("res://audio/sfx/battle/cogs/ENC_cogfall_apart.ogg")
const EXPLOSION_SCENE := preload("res://models/cogs/misc/explosion/cog_explosion.tscn")

## Config
enum GoonType {
	SECURITY,
	HELMET
}
@export var goon_type := GoonType.SECURITY
@export var helmet_color := Color.WHITE
@export var eye_color := Color("ffff44")

enum GoonState {
	WALK,
	STOMPED,
	TURNING,
	STOPPED,
}
@export var state := GoonState.WALK:
	set(x):
		prev_state = state
		state = x
		assess_state()
@export var recovery_time := 5.0
@export var base_damage := -2
@export var path: Path3D
@export var speed: float = 1.0 # Speed Modifier
@export var stomp_time := 10.0
@export var alert_time := 9.0
@export var beam_length_mult := 1.0
@export var light_mat: StandardMaterial3D
@export var head_light_meshes: Array[MeshInstance3D]
@export var eye_mesh: MeshInstance3D

## Child References
@onready var path_follow: PathFollow3D = $PathFollower
@onready var skeleton := $Skeleton3D
@onready var animator: AnimationPlayer = $AnimationPlayer
@onready var starting_pos := position
@onready var starting_pos_global := global_position
@onready var state_timer := $StateTimer
@onready var hard_hat := $Skeleton3D/hardHat
@onready var security_hat := $Skeleton3D/security_hat
@onready var security_badge := $Skeleton3D/badge
@onready var head_light := $Skeleton3D/LightBone/goon_light
@onready var player_detection := $DetectionArea
@onready var audio_player := $SFX

## Locals
var spd := 1.0 # Actual speed value
var path_positions := {}
var prev_state: GoonState
var next_point := 1
var turn_tween: Tween
var damage: int
var eye_mat: StandardMaterial3D
var alert_tween: Tween


func _ready() -> void:
	# Set up path
	if path:
		set_path(path)
		set_animation('walk')
	
	# Set up the goon's appearance
	if goon_type == GoonType.SECURITY:
		hard_hat.hide()
	else:
		security_badge.hide()
		security_hat.hide()
		# Apply hat color
		var hard_hat_mat: StandardMaterial3D = hard_hat.mesh.surface_get_material(0).duplicate()
		hard_hat_mat.albedo_color = helmet_color
		hard_hat.set_surface_override_material(0, hard_hat_mat)
	
	# Set up damage
	damage = Util.get_hazard_damage() + base_damage
	
	# Set up the headlight material
	if light_mat:
		light_mat = light_mat.duplicate()
		for mesh in head_light_meshes:
			mesh.set_surface_override_material(0,light_mat)
	
	# Set up the eye mat
	eye_mat = eye_mesh.get_surface_override_material(0).duplicate()
	eye_mesh.set_surface_override_material(0,eye_mat)
	set_eye_color(eye_color)

	head_light.scale.z *= beam_length_mult
	player_detection.position.z *= beam_length_mult
	player_detection.scale.z *= beam_length_mult

	if state == GoonState.STOMPED:
		head_light.hide()

func _physics_process(delta) -> void:
	match state:
		GoonState.WALK:
			# Follow path
			path_follow.progress_ratio += spd * delta
			position = starting_pos + (path_follow.position)
			
			# Detect when a point is reached
			if not next_point == 0:
				if path_follow.progress_ratio > path_positions.keys()[next_point]:
					point_reached()
			else:
				if path_follow.progress_ratio < path_positions.keys()[1]:
					point_reached()

func set_path(new_path: Path3D) -> void:
	# Set the new path to the path variable
	path = new_path
	
	# Add the path follower as a child to the path
	path_follow.reparent(path)
	
	# Gather path info
	var path_length := 0.0
	var curve := path.curve
	var line_lengths: Array[float] = []
	
	for i in curve.point_count:
		# Get the point in the curve
		var point := curve.get_point_position(i)
		
		# Get the length from the previous point
		var length: float
		if i > 0:
			length = abs(point.distance_to(curve.get_point_position(i - 1)))
		else:
			length = 0.0
		path_length += length
		line_lengths.append(path_length)
	
	# Get the progress ratios for each point
	for length in line_lengths:
		path_positions[length / path_length] =  curve.get_point_position(line_lengths.find(length))
	
	# Get the calculated speed 
	spd *= speed / path_length
	
	rotation.y = get_rotation_to(curve.get_point_position(next_point))

func point_reached() -> void:
	# Increment point
	next_point += 1
	if next_point == path_positions.keys().size() - 1:
		next_point = 0
	
	# Change state to turning
	state = GoonState.TURNING
	
	# Turn to face the next position
	turn_tween = create_tween()
	turn_tween.tween_property(self, 'rotation:y', get_rotation_to(path.curve.get_point_position(next_point)), 2.0)
	
	# After tween is finished, go back to walk state
	await turn_tween.finished
	turn_tween.kill()
	state = GoonState.WALK

func get_rotation_to(point: Vector3) -> float:
	path_follow.position = point
	var prev_rot := rotation
	look_at(path_follow.global_position)
	var rot := rotation.y + deg_to_rad(180.0)
	rotation = prev_rot
	return rot

func set_animation(anim: String) -> void:
	skeleton.reset_bone_poses()
	if animator.has_animation(anim):
		animator.play(anim)

func stomp() -> void:
	# Hide the headlight and stop detection
	head_light.hide()
	
	# Remember current state
	var test_state := prev_state
	state = GoonState.STOMPED
	if prev_state == GoonState.STOPPED:
		prev_state = test_state
	
	# Collapse
	await collapse()
	
	# Wait out the stomp timer
	state_timer.wait_time = stomp_time
	state_timer.start()
	await state_timer.timeout
	
	# Only continue if state hasn't changed
	if not state == GoonState.STOMPED:
		return
	
	# Recover
	await recover()
	set_animation('walk')
	
	# Show headlight
	head_light.show()
	
	# Reset to previous state
	state = prev_state

func body_entered(body: Node3D) -> void:
	if body is not Player:
		return
	handle_potential_stomp()

func handle_potential_stomp() -> void:
	if state == GoonState.STOMPED:
		return
	stomp()

func body_detected(body: Node3D) -> void:
	if body is Player and is_walking():
		if body.immune_to_light_damage:
			Util.do_3d_text(body, "Undetected!", BattleText.colors.orange[0], BattleText.colors.orange[1])
		else:
			player_detected(body)

## Assesses state changes made
func assess_state() -> void:
	if prev_state == GoonState.TURNING:
		turn_tween.pause()
	if state == GoonState.TURNING:
		if turn_tween and turn_tween.is_valid():
			turn_tween.play()

func player_detected(player: Player) -> void:
	# Damage the player
	if player.toon.yelp:
		AudioManager.play_sound(player.toon.yelp)
	player.last_damage_source = "a Goon"
	player.quick_heal(damage)
	
	# Stop Goon, remember its movement state
	animator.pause()
	state = GoonState.STOPPED
	
	# Do the alert tween
	do_alert()
	
	# Start the state timer
	state_timer.wait_time = alert_time
	state_timer.start()
	await state_timer.timeout
	
	# Only continue if state hasn't changed
	if not state == GoonState.STOPPED:
		return
	
	# Unpause animator
	animator.play()
	
	# Reset to previous state
	state = prev_state

func play_sfx(sfx: AudioStream) -> void:
	if audio_player.playing:
		audio_player.stop()
	audio_player.set_stream(sfx)
	audio_player.play()

func is_walking() -> bool:
	return state == GoonState.WALK or state == GoonState.TURNING

func set_light_visible(light_visible: bool) -> void:
	head_light.visible = light_visible

func set_light_color(color: Color) -> void:
	light_mat.albedo_color = color

func collapse() -> void:
	play_sfx(SFX_HUNKER)
	set_animation('collapse')
	await animator.animation_finished

func recover() -> void:
	set_animation('recover')
	play_sfx(SFX_RECOVER)
	await animator.animation_finished

func face_position(pos: Vector3) -> void:
	var face_pos := Vector3(pos.x, global_position.y, pos.z)
	if global_position != face_pos:
		look_at(face_pos)

func do_alert() -> void:
	# Play the detection sfx
	play_sfx(SFX_ALERT)
	
	# Tween the color of the headlight
	if light_mat:
		alert_tween = create_tween()
		alert_tween.tween_property(light_mat, 'albedo_color', Color.RED, 1.5)
		alert_tween.tween_property(light_mat, 'albedo_color', Color.BLUE, 1.5)
		alert_tween.set_loops(2)
		alert_tween.finished.connect(
		func(): 
			light_mat.albedo_color = Color.WHITE
			audio_player.stop()
		)

func set_eye_color(color: Color) -> void:
	eye_mat.albedo_color = color

func explode() -> void:
	play_sfx(SFX_EXPLODE)
	var explosion := EXPLOSION_SCENE.instantiate()
	add_child(explosion)
	explosion.play()
	explosion.position.y = 0.5
	explosion.scale *= 4.0
	await Task.delay(0.25)
	skeleton.hide()
	await Task.delay(0.2)
	explosion.hide()
	await audio_player.finished
	queue_free()
