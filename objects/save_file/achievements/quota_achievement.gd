extends SignalAchievement
class_name AchievementQuota


@export var progress_value := ""
@export var quota := 1


func _setup() -> void:
	if get_completed():
		return
	
	if progress_value in SaveFileService.progress_file:
		if SaveFileService.progress_file.get(progress_value) >= quota:
			pass
			unlock()
			return
	else:
		printerr("Progress File value: %s not found." % progress_value)
		return
	
	_hook_up()

func _hook_up() -> void:
	var connected_signal = get_signal()
	if connected_signal is Signal:
		connected_signal.connect(increment_amount)

func increment_amount(_arg1=null,_arg2=null,_arg3=null,_arg4=null) -> void:
	if get_completed(): return
	# Pause briefly to allow progress file to receive the information first
	await Task.delay(0.1)
	if SaveFileService.progress_file.get(progress_value) >= quota:
		if not get_completed():
			unlock()
