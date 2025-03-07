extends Node3D
class_name MoleHole

const SFX_STOMP := preload('res://audio/sfx/objects/moles/Mole_Stomp.ogg')
const SFX_SURPRISE := preload('res://audio/sfx/objects/moles/Mole_Surprise.ogg')
const SFX_LAND = preload("res://audio/sfx/toon/MG_cannon_hit_dirt.ogg")
const MOLE_CHANCE := 3
const WAKE_TIME := Vector2(3.0, 5.0)
const UP_Y := 1.35

## Config
enum Mole {
	NONE,
	COG,
	NORMAL
}

## Child References
@onready var mole_cog := $Moles/mole_cog
@onready var mole_norm := $Moles/mole_norm
@onready var mole_surprised := $Moles/mole_hit
@onready var sfx_player := $MoleSFX
@onready var player_detection := $PlayerDetection
@onready var timer := $Timer

## Locals
var player_colliding := false:
	set(x):
		player_colliding = x
		try_stomp()

var pop_tween: Tween
var hit_tween: Tween:
	set(x):
		if hit_tween and hit_tween.is_valid():
			hit_tween.kill()
		hit_tween = x
var mole_current := Mole.NONE

var force_launch_node: Node3D
var want_launch := true
var want_cog_moles := true

var force_cog_mole := false
var mole_cog_boost_time: float = 0.0

## Signals
signal s_stomped
signal s_launched
signal s_cog_mole_appear


func try_stomp() -> void:
	if mole_current == Mole.NONE:
		return
	
	if Util.get_player().state == Player.PlayerState.STOPPED:
		return
	
	var mole := mole_current
	
	timer.stop()
	
	var tween := pop_mole(Mole.NONE)
	
	match mole:
		Mole.COG:
			AudioManager.play_sound(SFX_STOMP)
			make_hit_tween()
			s_stomped.emit()
			%CogGears.emitting = true
			await Task.delay(0.35)
			%CogGears.emitting = false
		Mole.NORMAL:
			AudioManager.play_sound(SFX_SURPRISE)
			if want_launch:
				launch_player()
			else:
				slip_player()
			mole_surprised.show()
			mole_norm.hide()
			tween.finished.connect(func():
				mole_surprised.hide()
				mole_norm.show()
			)

func pop_a_mole() -> void:
	# Don't pop a mole if a mole is already popped
	if (not mole_current == Mole.NONE) or (pop_tween and pop_tween.is_running()):
		return
	
	if force_cog_mole or (RandomService.randi_channel('moles') % MOLE_CHANCE == 0 and want_cog_moles):
		pop_mole(Mole.COG)
		force_cog_mole = false
		s_cog_mole_appear.emit()
	else:
		pop_mole(Mole.NORMAL)

func on_timeout() -> void:
	pop_mole(Mole.NONE)

func pop_mole(mole: Mole) -> Tween:
	# If Mole.None is submitted, pop current mole down
	var up := not mole == Mole.NONE
	
	# Get the correct mole model
	var mole_mod: Node3D
	if mole == Mole.NONE:
		mole_mod = get_mole(mole_current)
		mole_current = Mole.NONE
	else:
		mole_mod = get_mole(mole)
		if not mole_mod:
			return
	
	# Return the tween used to move the mole
	var tween := tween_mole(mole_mod, up)
	if up:
		tween.finished.connect(func(): 
			mole_current = mole
			reset_timer()
			if player_colliding: try_stomp()
	)
	return tween

func tween_mole(mole: Node3D, up: bool) -> Tween:
	if pop_tween:
		pop_tween.kill()
	
	pop_tween = create_tween()
	if up:
		pop_tween.tween_property(mole, 'position:y', UP_Y, 1.0)
	else:
		pop_tween.tween_property(mole, 'position:y', -1.0, 1.0)
	return pop_tween

func get_mole(mole : Mole) -> Node3D:
	match mole:
		Mole.COG:
			return mole_cog
		Mole.NORMAL:
			return mole_norm
	return null

func body_entered(body : Node3D) -> void:
	if not body is Player:
		return
	player_colliding = true 

func body_exited(body: Node3D) -> void:
	if not body is Player:
		return
	player_colliding = false

func launch_player() -> void:
	var player := Util.get_player()
	s_launched.emit()
	player.state = Player.PlayerState.STOPPED
	
	# Do launch tween
	var launch_tween := create_tween()
	launch_tween.set_trans(Tween.TRANS_EXPO)
	launch_tween.set_ease(Tween.EASE_OUT)

	var launch_y: float
	var land_y: float
	if force_launch_node:
		launch_y = player.to_local(force_launch_node.global_position).y + 8.0
		land_y = player.to_local(force_launch_node.global_position).y
	else:
		launch_y = player.position.y + 8.0
		land_y = global_position.y

	launch_tween.tween_property(player, 'position:y', launch_y, 1.0)
	launch_tween.set_ease(Tween.EASE_IN)
	launch_tween.tween_property(player, 'global_position:y', land_y, 1.0)
	
	# Do twist tween
	var twist_tween := create_tween()
	twist_tween.tween_property(player.toon.body_node, 'rotation_degrees', player.toon.rotation_degrees + Vector3(720, 0, 720), 2.0)
	
	# Do reposition tween
	var newpos: Vector3
	if force_launch_node:
		newpos = force_launch_node.global_position
	else:
		newpos = player.position + Vector3(RandomService.randf_channel('true_random') * 1.0, 0.0, randf() * 1.0)
	var reposition_tween := create_tween()
	reposition_tween.set_parallel(true)
	reposition_tween.tween_property(player, 'position:x', newpos.x, 2.0)
	reposition_tween.tween_property(player, 'position:z', newpos.z, 2.0)
	
	await launch_tween.finished
	launch_tween.kill()
	twist_tween.kill()
	reposition_tween.kill()
	player.position = newpos
	player.set_animation('slip_backward')
	AudioManager.play_sound(SFX_LAND)
	await Task.delay(2.75)
	player.toon.body_node.rotation_degrees = Vector3.ZERO
	player.state = Player.PlayerState.WALK
	if Util.get_player().stats.hp <= 0:
		Util.get_player().lose()

func slip_player() -> void:
	var player := Util.get_player()
	s_launched.emit()
	player.state = Player.PlayerState.STOPPED
	player.set_animation('slip_backward')
	await Task.delay(2.75)
	player.state = Player.PlayerState.WALK
	if Util.get_player().stats.hp <= 0:
		Util.get_player().lose()

func reset_timer() -> void:
	var new_time: float = RandomService.randf_range_channel('moles', WAKE_TIME.x, WAKE_TIME.y)
	if mole_current == Mole.COG and mole_cog_boost_time > 0.0:
		new_time += mole_cog_boost_time
	timer.wait_time = new_time
	timer.start()

func disable() -> void:
	player_detection.set_monitoring.call_deferred(false)
	if not mole_current == Mole.NONE:
		pop_mole(Mole.NONE)
	timer.stop()

func make_hit_tween() -> void:
	return 
	#var positions: Array[LerpProperty] = []
	#for i in 9:
		#var rand_value: float = RandomService.randf_range_channel('true_random', 0.23, 0.4) * RandomService.array_pick_random('true_random', [1.0, -1.0])
		#var new_pos: Vector3
		#match RandomService.array_pick_random('true_random', ["x", "y", "z"]):
			#"x":
				#new_pos = Vector3(rand_value, 0, 0)
			#"y":
				#new_pos = Vector3(0, rand_value, 0)
			#"z":
				#new_pos = Vector3(0, 0, rand_value)
		#positions.append(LerpProperty.new(%mole_cog, ^"position", 0.05, new_pos))
	#positions.append(LerpProperty.new(%mole_cog, ^"position", 0.05, Vector3.ZERO))
	#hit_tween = Sequence.new(positions).as_tween(self)
