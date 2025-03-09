extends Node3D

const STOMP_TIME := 0.2
const SFX_DECOMPRESS := preload("res://audio/sfx/objects/stomper/toon_decompress.ogg")
const SFX_RAISE := preload("res://audio/sfx/objects/stomper/CHQ_FACT_stomper_raise.ogg")
const SFX_STOMP_DEFAULT := preload("res://audio/sfx/objects/stomper/CHQ_FACT_stomper_med.ogg")

@export var automatic := true
@export var model: Node3D
@export var collisions: Array[CollisionShape3D]
@export var player_detection: Area3D
@export var raise_position: float
@export var base_damage := -4
@export var raise_time := 1.0
@export var raise_time_offset := 0.0
@export var stomp_sfx: AudioStream

@onready var sfx_player: AudioStreamPlayer3D = %SFXPlayer
@onready var delay_timer : Timer = %DelayTimer

var damage: int
var floor_position: float
var delay_next_stomp := false


func _ready() -> void:
	if not model:
		return
	
	damage = Util.get_hazard_damage() + base_damage
	
	if not stomp_sfx:
		stomp_sfx = SFX_STOMP_DEFAULT
	
	# Get the stomper's current position as the floor pos
	floor_position = model.position.y
	
	if automatic:
		loop_stomp()
	
	# Start the model in the raised position
	model.position.y = raise_position
	
	if player_detection:
		player_detection.body_entered.connect(body_entered)
		player_detection.set_collision_mask_value(3, true)
		player_detection.set_collision_mask_value(2, false)
	
	for collision in collisions:
		if collision.get_parent() is StaticBody3D:
			var body : StaticBody3D = collision.get_parent()
			body.set_collision_layer_value(1, false)
			body.set_collision_layer_value(3, true)

func body_entered(body: Node3D) -> void:
	if body is Player:
		player_entered(body)

func player_entered(player: Player) -> void:
	if player.state == Player.PlayerState.WALK:
		await squash_player(player)

func set_collisions_enabled(enable: bool) -> void:
	for shape in collisions:
		shape.set_disabled.call_deferred(not enable)

func tween_step(step: int, tween : Tween) -> void:
	if not player_detection:
		return
	match step:
		2:
			player_detection.set_monitoring.call_deferred(true)
			if delay_next_stomp:
				tween.pause()
				delay_timer.start()
		0:
			player_detection.set_monitoring.call_deferred(false)

func squash_player(player: Player) -> void:
	# Player yelps
	if player.toon.yelp:
		AudioManager.play_sound(player.toon.yelp)
	player.last_damage_source = "a Stomper"
	
	if automatic:
		delay_next_stomp = true
	
	# Damage player
	player.quick_heal(damage)
	
	# Set player to stopped state
	player.state = Player.PlayerState.STOPPED
	
	# Move player to our y pos
	player.global_position.y = global_position.y

	# Skip special animations if they're already dead
	if player.stats.hp <= 0:
		return
	
	# Squash them.
	player.set_animation('neutral')
	var base_scale: float = player.toon.scale.y
	var tween := create_tween()
	tween.tween_property(player.toon, 'scale:y', 0.05, 0.05)
	tween.tween_interval(0.5)
	tween.tween_callback(AudioManager.play_sound.bind(SFX_DECOMPRESS))
	tween.tween_callback(player.set_animation.bind('happy'))
	tween.tween_callback(func(): player.animator.speed_scale = 1.5)
	tween.tween_property(player.toon, 'scale:y', base_scale * 1.15, 0.2)
	tween.tween_property(player.toon, 'scale:y', base_scale, 0.05)
	await player.animator.animation_finished
	tween.kill()
	player.animator.speed_scale = 1.0
	player.state = Player.PlayerState.WALK
	player.do_invincibility_frames()

func play_sfx(sfx: AudioStream) -> void:
	sfx_player.set_stream(sfx)
	sfx_player.play()

func loop_stomp() -> void:
	var stomp_tween := do_stomp()
	stomp_tween.set_loops()
	
	# If stomped, wait for 2 cycles before continuing.
	delay_timer.wait_time = (raise_time + STOMP_TIME) * 2.0
	delay_timer.timeout.connect(delay_timeout.bind(stomp_tween))
	
	stomp_tween.step_finished.connect(tween_step.bind(stomp_tween))
	if not is_equal_approx(raise_time_offset, 0.0):
		stomp_tween.custom_step(raise_time_offset)

func do_stomp() -> Tween:
	var stomp_tween := create_tween()
	if not automatic:
		stomp_tween.tween_callback(player_detection.set_monitoring.bind(true))
	stomp_tween.tween_property(model, 'position:y', floor_position, STOMP_TIME)
	stomp_tween.tween_callback(play_sfx.bind(stomp_sfx))
	if not automatic:
		stomp_tween.tween_callback(player_detection.set_monitoring.bind(false))
	stomp_tween.tween_property(model, 'position:y', raise_position, raise_time)
	return stomp_tween

func connect_button(button: CogButton) -> void:
	button.s_pressed.connect(func(_button: CogButton):
		var stomp_tween := do_stomp()
		stomp_tween.finished.connect(button.retract)
	)

func delay_timeout(tween: Tween) -> void:
	delay_next_stomp = false
	tween.play()
