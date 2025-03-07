extends Node3D

const LEFT_OPEN_POS := -7.25
const RIGHT_OPEN_POS := 7.0

const SFX_OPEN := preload("res://audio/sfx/objects/facility_door/CHQ_FACT_door_unlock.ogg")

@onready var puzzle : LawbotPuzzleGrid = %ButtonPuzzle
@onready var skull_bounce : PuzzleSkullBounce = %LawbotSkullBounce

var correct_order: Array[CogButton] = []
var next_button: CogButton


func _ready() -> void:
	correct_order.assign(%Buttons.get_children())
	correct_order.shuffle()
	next_button = correct_order[0]
	sync_puzzle()
	for button in correct_order:
		button.s_pressed.connect(button_pressed)
	randomize_buttons()

func sync_puzzle() -> void:
	var index := 0
	for i in range(puzzle.grid.size() - 1, -1, -1):
		for j in puzzle.grid[i].size():
			var panel: PuzzlePanel = puzzle.grid[i][j]
			match index:
				0: panel.panel_shape = PuzzlePanel.PanelShape.ONE
				1: panel.panel_shape = PuzzlePanel.PanelShape.TWO
				2: panel.panel_shape = PuzzlePanel.PanelShape.THREE
			panel.set_color(correct_order[index].up_color)
			panel.s_shape_changed.emit(panel, panel.panel_shape)
			index += 1

func button_pressed(button: CogButton) -> void:
	if button == next_button:
		var index := correct_order.find(button)
		if index == correct_order.size() - 1:
			win()
		else:
			next_button = correct_order[index + 1]
	else:
		next_button = correct_order[0]
		for button_ in correct_order:
			if button_ == button:
				continue
			else:
				button_.retract()
		await Task.delay(1.0)
		button.retract()

func win() -> void:
	if is_instance_valid(Util.get_player()):
		Util.get_player().state = Player.PlayerState.STOPPED

	AudioManager.play_sound(SFX_OPEN)

	var open_tween := create_tween()
	open_tween.tween_callback(%PuzzleCam.make_current)
	open_tween.set_trans(Tween.TRANS_QUAD)
	open_tween.tween_property(%ShelfLeft, 'position:x', LEFT_OPEN_POS, 2.0)
	open_tween.parallel().tween_property(%ShelfRight, 'position:x', RIGHT_OPEN_POS, 2.0)
	open_tween.tween_interval(1.0)
	
	open_tween.finished.connect(
		func():
			if is_instance_valid(Util.get_player()):
				Util.get_player().state = Player.PlayerState.WALK
				Util.get_player().camera.make_current()
			open_tween.kill()
	)
	
	if is_instance_valid(puzzle):
		puzzle.win_game()
	if is_instance_valid(skull_bounce):
		skull_bounce.win_game()

func randomize_buttons() -> void:
	var placements := %ButtonPlacements.get_children()
	placements.shuffle()
	for button in %Buttons.get_children():
		button.global_position = placements.pop_back().global_position
