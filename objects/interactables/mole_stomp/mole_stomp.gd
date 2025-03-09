extends Area3D
class_name MoleStompGame

signal s_endless_hit
signal s_managed_red_hit
signal s_normal_finished

## Constants
const WAIT_TIME := Vector2(0.25,1.0)
const MOLE_SCENE := preload('res://objects/interactables/mole_stomp/mole_hole.tscn')
const UI_SCENE := preload('res://objects/interactables/mole_stomp/mole_display.tscn')
const MG_LOSE = preload("res://audio/sfx/misc/MG_lose.ogg")

enum GameMode { NORMAL, ENDLESS, MANAGED }

## Config
@export var game_mode := GameMode.NORMAL
@export var endless_stop_moles := true
@export var want_launch := true
@export var force_launch_node: Node3D
@export_range(0.01, 8.0, 0.01) var difficulty: float = 1.0
@export var grid_size := Vector2i(6,6)
@export var game_time := 60.0
@export var max_tries := 3
@export var quota := 10
@export var door: CogDoor
@export var base_damage := -10
@export var launch_cam: Camera3D
@export var hole_separation: float = 3.0

## Locals
var grid := []
var moles_stomped := 0
var active := false
var game_over := false
var timer: Timer
var mole_ui: Panel
var game_timer: Control
var damage: int

## Variables only for the "managed" mode
var managed_want_red_mole := false


func _ready() -> void:
	fill_grid()
	
	if door:
		door.add_lock()
	
	body_entered.connect(on_body_entered)
	collision_mask = Globals.PLAYER_COLLISION_LAYER
	
	timer = Timer.new()
	timer.one_shot = true
	timer.timeout.connect(on_timeout)
	add_child(timer)
	
	damage = Util.get_hazard_damage() + base_damage

	if game_mode == GameMode.ENDLESS:
		start_game()

func on_body_entered(body: Node3D) -> void:
	if active or not body is Player or game_over or game_mode == GameMode.ENDLESS:
		return
	start_game()

func start_game() -> void:
	active = true
	reset_timer()

	if game_mode == GameMode.NORMAL:
		mole_ui = UI_SCENE.instantiate()
		add_child(mole_ui)
		update_ui()

		game_timer = Util.run_timer(game_time, Control.PRESET_BOTTOM_RIGHT)
		game_timer.timer.timeout.connect(lose_game)

func reset_timer() -> void:
	timer.wait_time = RandomService.randf_range_channel('moles', WAIT_TIME.x / difficulty, WAIT_TIME.y / difficulty)
	timer.start()

func on_timeout() -> void:
	if active:
		get_random_mole().pop_a_mole()
		reset_timer()

func fill_grid() -> void:
	for i in grid_size.x:
		grid.append([])
		for j in grid_size.y:
			var mole: MoleHole = MOLE_SCENE.instantiate()
			if game_mode in [GameMode.ENDLESS, GameMode.MANAGED]:
				mole.want_cog_moles = false
			mole.want_launch = want_launch
			if force_launch_node:
				mole.force_launch_node = force_launch_node
			add_child(mole)
			mole.position = Vector3(float(i) * hole_separation,0.0, float(j) * hole_separation)
			mole.s_stomped.connect(mole_stomped)
			mole.s_launched.connect(on_player_launched)
			grid[i].append(mole)

func mole_stomped() -> void:
	moles_stomped += 1
	if game_mode == GameMode.NORMAL:
		update_ui()
		if moles_stomped >= quota:
			win_game()
	elif game_mode == GameMode.MANAGED:
		s_managed_red_hit.emit()

func update_ui() -> void:
	if mole_ui:
		mole_ui.get_child(0).set_text('Moles Left: ' + str(quota - moles_stomped))

func get_random_mole() -> MoleHole:
	var row: Array = grid[RandomService.randi_channel('moles') % grid.size()]
	return row[RandomService.randi_channel('moles') % row.size()]

func win_game() -> void:
	if game_mode == GameMode.ENDLESS:
		return

	Util.get_player().quick_heal(-base_damage)
	end_game()

## I know TTO doesn't do this but I don't know if I care
## Cog Golf courses are terrible
func lose_game() -> void:
	if game_mode in [GameMode.ENDLESS, GameMode.MANAGED]:
		return

	if Util.get_player():
		Util.get_player().last_damage_source = "some Moles"
		Util.get_player().quick_heal(damage)
		AudioManager.play_sound(Util.get_player().toon.yelp)
	end_game()

func end_game() -> void:
	if door:
		door.unlock()
	
	active = false
	stop_and_disable_moles()
	mole_ui.queue_free()
	
	if game_timer:
		game_timer.queue_free()
	
	game_over = true
	s_normal_finished.emit()

func disable_moles() -> void:
	for i in grid.size():
		for j in grid[i].size():
			var mole: MoleHole = grid[i][j]
			mole.disable()

func get_all_moles() -> Array[MoleHole]:
	var all_moles: Array[MoleHole] = []
	for i in grid.size():
		for j in grid[i].size():
			all_moles.append(grid[i][j])
	return all_moles

func on_player_launched() -> void:
	if game_mode == GameMode.ENDLESS:
		AudioManager.play_sound(MG_LOSE)
		if endless_stop_moles:
			stop_and_disable_moles()
		s_endless_hit.emit()

	if want_launch:
		if launch_cam:
			launch_cam.global_transform = Util.get_player().camera.camera.global_transform
			launch_cam.make_current()
			await Task.delay(2.0)
			Util.get_player().camera.make_current()

func stop_and_disable_moles() -> void:
	timer.stop()
	disable_moles()

func _process(_delta: float) -> void:
	if launch_cam:
		if is_instance_valid(Util.get_player()):
			launch_cam.look_at(Util.get_player().global_position + Vector3(.01, .01, .01))
