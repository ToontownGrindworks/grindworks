extends FreeCamTool
class_name PlayerFreeCam

var LABEL := LazyLoader.defer("res://objects/interactables/lawbot_puzzles/puzzle_label.tscn")

var player : Player

func _init(_player : Player) -> void:
	player = _player

func _ready() -> void:
	super()
	if player:
		player.state = Player.PlayerState.STOPPED
	var label = LABEL.load().instantiate()
	add_child(label)
	label.set_text("Press F6 to disable freecam.")

var just_made := true
func _physics_process(delta: float) -> void:
	super(delta)
	
	if Input.is_action_just_pressed('toggle_freecam') and not just_made:
		if player:
			player.camera.make_current()
			player.state = Player.PlayerState.WALK
			queue_free()
	just_made = false
