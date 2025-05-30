extends Node3D

var RISE_SPEED : float:
	get:
		if not Util.on_easy_floor(): return 18.0
		return 15.0
const PAINT_SCROLL_SPEED := -3.0
const PAINT_START_POS := 0.0
const PAINT_FINAL_POS := 1800.0
const ELEVATOR_LOWER_POS := -27.49
const ELEVATOR_POS := Vector3(5.783, 63.064, 6.873)
const BOSS_MUSIC := preload('res://audio/music/climb_boss.ogg')

@export var paint_streams: Array[Node3D]
@export var paint_mat: StandardMaterial3D
@export var paint: Node3D

@onready var elevator: FactoryElevator = %FactoryElevator
@onready var hidden_chest : TreasureChest = %HiddenChest

var paint_rising := false

var player: Player
var base_elevator_y: float
var buttons_pressed := 0

func _ready() -> void:
	base_elevator_y = elevator.position.y

func body_entered(body: Node3D) -> void:
	if body is Player and not paint_rising and not game_won:
		player = body
		initialize()

func initialize() -> void:
	Util.stuck_lock = true
	player.state = Player.PlayerState.STOPPED
	player.set_animation('neutral')
	player.global_position = $PlayerSpawn.global_position
	intro_cutscene()
	$CogDoor.monitoring = false
	$CogDoor.add_lock()

func intro_cutscene() -> void:
	Util.get_player().game_timer_tick = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	%SkipButton.show()
	var movie_tween := create_tween()
	movie_tween.tween_callback($FaucetCam.make_current)
	movie_tween.set_trans(Tween.TRANS_QUAD)
	movie_tween.tween_property($FaucetCam,'position:y', 46.0, 4.0)
	movie_tween.set_trans(Tween.TRANS_LINEAR)
	movie_tween.parallel().tween_callback(start_faucets).set_delay(2.0)
	movie_tween.tween_callback($PaintCam.make_current)
	movie_tween.tween_callback(func(): paint_rising = true)
	movie_tween.tween_interval(3.0)
	movie_tween.finished.connect(
	func():
		%SkipButton.hide()
		AudioManager.set_music(BOSS_MUSIC)
		movie_tween.kill()
		begin()
		Util.get_player().game_timer_tick = true
	)
	%SkipButton.pressed.connect(skip_intro.bind(movie_tween))

func skip_intro(tween: Tween) -> void:
	tween.custom_step(10000.0)
	$CogDoor.skip_tween()

func start_faucets() -> void:
	var paint_tween := create_tween()
	paint_tween.set_parallel(true)
	for stream in paint_streams:
		paint_tween.tween_property(stream,'scale:y', 400.0, 2.0)
		stream.get_node('WaterSFX').play()
	paint_tween.finished.connect(paint_tween.kill)

func _process(delta: float) -> void:
	if paint_mat: 
		paint_mat.uv1_offset.y += PAINT_SCROLL_SPEED * delta
	
	if player:
		if player.global_position.y < $Model/RisingPaint/DeathBarrier.global_position.y:
			reset()
	
	if not paint_rising: return
	
	if paint.position.y < PAINT_FINAL_POS:
		paint.position.y = min(paint.position.y + (RISE_SPEED * delta), PAINT_FINAL_POS)

func begin() -> void:
	if player:
		player.state = Player.PlayerState.WALK
		player.camera.make_current()

func button_pressed(_button: CogButton) -> void:
	buttons_pressed += 1
	if buttons_pressed == 3:
		%ElevatorResetTimer.queue_free()
		lower_elevator()

func lower_elevator() -> void:
	elevator.rise(ELEVATOR_LOWER_POS, 5.0)

func reset() -> void:
	paint_rising = false
	player.last_damage_source = "Goopy Paint"
	player.quick_heal(Util.get_hazard_damage(-10))
	
	if player.stats.hp > 0:
		Util.circle_in(1.0)
		paint.position.y = PAINT_START_POS
		if game_won: 
			player.global_position = $PlayerSpawn.global_position
			player.teleport_in(true)
			return
		
		if buttons_pressed == 3:
			if elevator.rise_tween and elevator.rise_tween.is_running():
				elevator.rise_tween.kill()
				elevator.sfx_player.stop()
			elevator.position.y = ELEVATOR_LOWER_POS
			elevator.can_rise = true
		player.global_position = $PlayerSpawn.global_position
		await player.teleport_in(true)
		paint_rising = true

var paint_damage_active := true
func paint_stream_entered(body : Node3D) -> void:
	if body is Player and paint_damage_active:
		player.last_damage_source = "a Paint Stream"
		body.quick_heal(Util.get_hazard_damage(-5))
		paint_damage_active = false
		$PaintDamageTimer.start()
		await $PaintDamageTimer.timeout
		paint_damage_active = true

func elevator_entered() -> void:
	Util.stuck_lock = false

var game_won := false
func win_area_entered(body : Node3D) -> void:
	if body is Player and not game_won:
		game_won = true
		win_game()

func win_game() -> void:
	paint_rising = false
	paint_damage_active = false
	AudioManager.stop_music()
	paint.position.y = PAINT_START_POS
	$CogDoor.monitoring = true
	$CogDoor.unlock()
	for stream in paint_streams:
		stream.hide()
	elevator.mode = FactoryElevator.ElevatorMode.TIMER
	elevator.rise_time = 7.0
	if is_instance_valid(hidden_chest):
		hidden_chest.queue_free()
	Util.get_player().stats.charge_active_item(2)

## Gets called every 3 seconds until all 3 buttons are pressed
## This will for definitely and on real fix the bug with the node
## I have an immense distaste for the AnimatableBody3D Node
func reset_elevator_position() -> void:
	elevator.set_global_transform(%ElevatorOrigin.global_transform)
