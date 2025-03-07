extends DoodleAction
class_name DoodleRollover

const SFX := preload('res://audio/sfx/doodle/rollover.ogg')


func action():
	# Setup
	var target : Player = targets[0] # Player
	
	# Begin (await an additional half second for pacing)
	await begin_trick()
	await manager.sleep(0.5)
	
	# Show the move's effect
	manager.show_action_name("Evasiveness Boost!")
	
	# Do roll over anim
	user.set_animation('rollover')
	AudioManager.play_sound(SFX)
	await Task.delay(3.9583 * 2.0)
	
	
	# Apply the 1 round status effect
	var stat_effect := create_stat_boost('evasiveness', 1.5, 1)
	manager.add_status_effect(stat_effect)
	
	# Focus player
	manager.s_focus_char.emit(target)
	target.toon.speak("Ha Ha Ha!")
	
	# End
	await end_trick()
