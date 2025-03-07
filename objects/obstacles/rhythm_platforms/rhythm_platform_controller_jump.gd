extends RhythmPlatformController
class_name RhythmPlatformControllerJump

var player: Player
var change_task: Task

func _ready() -> void:
	super()
	
	change_task = Task.delayed_call(self, 1.5, on_timeout)

func _exit_tree() -> void:
	if change_task:
		change_task = change_task.cancel()

func on_timeout() -> StringName:
	set_group(group_current + 1)
	return Task.AGAIN
