extends Node3D

const SFX_DECOMPRESS := preload("res://audio/sfx/objects/stomper/toon_decompress.ogg")
const SFX_HIT := preload("res://audio/sfx/objects/golf/Golf_Hole_In_One.ogg")
const DELAY_TIME := Vector2(0.01, 0.5)
const PLAYER_HIT_DELAY := 3.0

@export var start_off := false
@export var want_evil_ball := false
@export var golf_ball: Area3D
@export var path: Path3D
@export var speed := 1.0

var path_follow: PathFollow3D
var delayed := false
var player_hit := false
var stopped := false


func _ready() -> void:
	if not is_instance_valid(golf_ball) or not is_instance_valid(path):
		return
	if want_evil_ball:
		golf_ball.get_node("golf_ball").hide()
		golf_ball.get_node("EvilBall").show()
	if start_off:
		stopped = true
		delayed = true
		delay_ball(0.0)
	set_path(path)

func set_path(new_path: Path3D) -> void:
	path = new_path
	if path_follow:
		path_follow.reparent(path)
	else:
		path_follow = PathFollow3D.new()
		path.add_child(path_follow)

func _physics_process(delta: float) -> void:
	if path_follow and not delayed:
		var pre_progress := path_follow.progress_ratio
		path_follow.progress_ratio += delta * speed
		golf_ball.position = Vector3(path_follow.position.x, golf_ball.position.y, path_follow.position.z)
		if pre_progress > path_follow.progress_ratio:
			if player_hit:
				delay_ball(PLAYER_HIT_DELAY)
				player_hit = false
			else:
				delay_ball()
			path_follow.progress_ratio = 0.0
			golf_ball.reset_physics_interpolation()

func delay_ball(wait_time := 0.0) -> void:
	delayed = true
	if is_equal_approx(wait_time, 0.0):
		$Timer.wait_time = RandomService.randf_range_channel('true_random', DELAY_TIME.x, DELAY_TIME.y)
	else:
		$Timer.wait_time = wait_time
	$Timer.start()
	await $Timer.timeout
	if stopped:
		golf_ball.hide()
		golf_ball.get_node("SFX").stop()
	else:
		delayed = false
		%SFX.play()

func _process(delta: float) -> void:
	if golf_ball:
		golf_ball.rotation_degrees.x -= delta * 120.0 * speed * 10

func stop_balls() -> void:
	stopped = true

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		if body.state == Player.PlayerState.WALK:
			hit_player(body)

func hit_player(player: Player) -> void:
	player_hit = true
	player.global_position.y = path.global_position.y
	golf_ball.set_monitoring.call_deferred(false)
	player.last_damage_source = "the Fairway Fiend" if want_evil_ball else "a Golf Ball"
	player.quick_heal(Util.get_hazard_damage(-4))
	AudioManager.play_sound(player.toon.yelp)
	if RandomService.randf_channel('true_random') < 0.05:
		AudioManager.play_sound(SFX_HIT)
	
	if player.stats.hp > 0:
		# Squash them.
		var base_scale : float = player.toon.scale.y
		var tween := create_tween()
		tween.tween_callback(player.set_animation.bind('neutral'))
		tween.tween_callback(func(): player.state = Player.PlayerState.STOPPED)
		tween.tween_property(player.toon, 'scale:y', 0.05, 0.05)
		tween.tween_interval(1.0)
		tween.tween_callback(AudioManager.play_sound.bind(SFX_DECOMPRESS))
		tween.tween_callback(player.set_animation.bind('happy'))
		tween.tween_property(player.toon, 'scale:y', base_scale, 0.25)
		tween.tween_interval(1.0)
		tween.finished.connect(
		func():
			tween.kill()
			player.state = Player.PlayerState.WALK
			golf_ball.set_monitoring.call_deferred(true)
		)
