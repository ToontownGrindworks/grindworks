extends CogAttack
class_name PopQuizAttack

const COG_LAUGH := preload('res://audio/sfx/battle/cogs/COG_VO_laugh.ogg')
const SFX_BUILDUP := preload("res://audio/sfx/misc/Golf_Crowd_Buildup.ogg")
const SFX_CORRECT := preload("res://audio/sfx/misc/Golf_Crowd_Applause.ogg")
const SFX_INCORRECT := preload("res://audio/sfx/misc/Golf_Crowd_Miss.ogg")

@export var question_time := 5.0
@export var lose_sfx : AudioSnippet
@export var win_sfx : AudioSnippet


func action() -> void:
	# Start:
	manager.revert_battle_speed()
	var player : Player = targets[0]
	user.face_position(player.global_position)
	battle_node.focus_character(user)
	await manager.sleep(3.0)
	
	# Cog presents the question
	var question := get_question()
	user.speak(".")
	user.speak(question[0])
	await Task.delay(4.0)
	battle_node.focus_character(player)
	
	# Create the panel 
	var panel : Control = load('res://objects/battle/misc_battle_objects/pop_quiz/pop_quiz.tscn').instantiate()
	manager.get_tree().get_root().add_child(panel)
	
	# Extract the question from the front of the array
	panel.question = question.pop_front()
	
	# Get the true answer, and then shuffle the array
	var true_answer := question[0]
	question.shuffle()
	panel.answers = question
	
	# Create a timer that fails the question if it runs out
	var timer := Util.run_timer(question_time)
	timer.timer.timeout.connect(func(): panel.s_answer_selected.emit("WRONG ANSWER!!!!"))
	
	# Await the player's answer
	var answer : String = await panel.s_answer_selected
	
	# Free whichever element did not expire
	if is_instance_valid(timer):
		timer.queue_free()
	if is_instance_valid(panel):
		panel.queue_free()
	
	# Cog reaction
	battle_node.focus_character(user)
	user.speak("That answer...")
	AudioManager.play_sound(SFX_BUILDUP, -5.0)
	await manager.sleep(3.0)
	if answer == true_answer:
		user.speak("...is CORRECT!")
		user.set_animation('clap')
		AudioManager.play_sound(SFX_CORRECT, -5.0)
	else:
		user.speak("...is INCORRECT!", false)
		AudioManager.play_sound(COG_LAUGH, 3.0)
		user.set_animation('laugh')
		AudioManager.play_sound(SFX_INCORRECT, -5.0)
	await manager.sleep(2.0)
	
	# Player reaction
	set_camera_angle(camera_angles.SIDE_LEFT)
	if answer == true_answer:
		player.toon.set_emotion(Toon.Emotion.LAUGH)
		player.set_animation('happy')
		if win_sfx:
			win_sfx.play()
	else:
		player.last_damage_source = "Hubris"
		manager.affect_target(player, 'hp', damage, false)
		player.toon.set_emotion(Toon.Emotion.SAD)
		player.set_animation("slip_backward")
		if lose_sfx:
			lose_sfx.play()
	
	await player.animator.animation_finished
	player.toon.set_emotion(Toon.Emotion.NEUTRAL)
	
	manager.apply_battle_speed()
	await manager.check_pulses(targets)

## Overwrite this for other quiz types
## Default is Math
## Prompt format: [Question, Correct Answer, Incorrect, Incorrect,...]
func get_question() -> Array[String]:
	# The full quiz question to return
	var prompt : Array[String] = []
	
	# Get the variable & operator
	var x := RandomService.randi_channel('true_random') % 20
	var y := RandomService.randi_channel('true_random') % 15
	var op := RandomService.randi_channel('true_random') % 2
	var answer : int 
	
	# Form the question
	var question := "What is " + str(x) + " "
	match op:
		0:
			answer = x + y
			question += "+ "
		1:
			answer = x - y
			question += "- "
		2:
			answer = x * y
			question += "x "
	question += str(y) + "?"
	
	# Append question and answer to prompt
	prompt.append_array([question,str(answer)])
	
	# Append incorrect answers
	# 2-4 wrong answers
	for i in RandomService.randi_channel('true_random') % 2 + 2:
		var incorrect_answer := answer
		while str(incorrect_answer) in prompt:
			incorrect_answer = answer + RandomService.randi_range_channel('true_random', -5, 5)
		prompt.append(str(incorrect_answer))
	
	# Return the full prompt
	return prompt
