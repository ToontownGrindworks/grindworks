extends Node3D

const SMASH_ROTATION := 80.0
const SFX_DECOMPRESS := preload("res://audio/sfx/objects/stomper/toon_decompress.ogg")

@export var rotations : Array[float] = []
@export var speed := 1.0
@export var handle_damage := -1
@export var head_damage := -4
## Seconds to delay tween start
@export var delay := 0.0

var can_crush := false

func _ready() -> void:
	if rotations.is_empty():
		rotations.append(rotation_degrees.y)
	if delay > 0.0:
		%Timer.wait_time = delay
		%Timer.start()
		await %Timer.timeout
	start_tween()
	%HitSpot.hide()

func start_tween() -> void:
	var smash_tween := create_tween()
	smash_tween.set_loops()
	for rot in rotations:
		smash_tween.tween_property(self, 'rotation_degrees:y', rot, 1.0)
		smash_tween.tween_callback(func(): can_crush = true)
		smash_tween.tween_property(self, 'rotation_degrees:x', SMASH_ROTATION, 0.25)
		smash_tween.tween_callback(%SFXSmash.play)
		smash_tween.tween_interval(0.5)
		smash_tween.tween_callback(func(): can_crush = false)
		smash_tween.tween_interval(1.0)
		smash_tween.tween_property(self,'rotation_degrees:x', 0.0, 4.0)
		smash_tween.tween_interval(1.0)
	smash_tween.set_speed_scale(speed)

func body_entered_head(body: Node3D) -> void:
	if body is Player:
		if body.state == Player.PlayerState.WALK:
			var player: Player = body
			player.quick_heal(Util.get_hazard_damage(head_damage))
			if player.stats.hp <= 0:
				return
			if can_crush:
				squash_player(player)
			else:
				slip_player(player)
			player.last_damage_source = "a Gavel"

func body_entered_handle(body: Node3D) -> void:
	if body is Player:
		if body.state == Player.PlayerState.WALK:
			var player: Player = body
			player.quick_heal(Util.get_hazard_damage(handle_damage))
			if player.stats.hp <= 0:
				return
			slip_player(player)
			player.last_damage_source = "a Gavel"

func squash_player(player: Player) -> void:
	player.global_position.y = global_position.y
	# Squash them.
	var base_scale: float = player.toon.scale.y
	var tween := create_tween()
	tween.tween_callback(player.set_animation.bind('neutral'))
	tween.tween_callback(func(): player.state = Player.PlayerState.STOPPED)
	tween.tween_property(player.toon, 'scale:y', 0.05, 0.05)
	tween.tween_interval(2.0)
	tween.tween_callback(AudioManager.play_sound.bind(SFX_DECOMPRESS))
	tween.tween_callback(player.set_animation.bind('happy'))
	tween.tween_property(player.toon, 'scale:y', base_scale, 0.25)
	tween.tween_interval(1.0)
	tween.finished.connect(
	func():
		tween.kill()
		player.state = Player.PlayerState.WALK
	)
	player.do_invincibility_frames()

func slip_player(player: Player) -> void:
	player.state = Player.PlayerState.STOPPED
	player.set_animation('slip_backward')
	await Task.delay(2.75)
	player.state = Player.PlayerState.WALK
	player.do_invincibility_frames()
