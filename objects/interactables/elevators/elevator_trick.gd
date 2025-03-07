extends BuildingElevator

@onready var elevator_floor := $suit_elevator_1/ground

func player_entered(player : Player):
	elevator_cam.current = true
	player.state = Player.PlayerState.STOPPED
	player.set_animation('run')
	var move_tween := player.move_to(player_pos.global_position)
	await move_tween.finished
	move_tween.kill()
	
	var toon_scale = player.toon.scale
	player.toon.global_rotation.y = player_pos.global_rotation.y
	player.toon.scale = toon_scale
	
	var floor_tween := create_tween()
	floor_tween.set_trans(Tween.TRANS_QUART)
	floor_tween.tween_property(elevator_floor,'rotation_degrees:x',-90,0.25)
	AudioManager.play_sound(load("res://audio/sfx/sequences/elevator_trick/elevator_trick_open.ogg"))
	AudioManager.tween_music_pitch()
	#AudioManager.stop_music(true)
	await Task.delay(0.2)
	
	AudioManager.play_snippet(load("res://audio/sfx/sequences/elevator_trick/elevator_trick_riser.ogg"))
	player.toon.set_animation('melt_nosink')
	await Task.delay(1.0)
	AudioManager.play_sound(load("res://audio/sfx/sequences/elevator_trick/elevator_trick_react.ogg"))
	player.animator.speed_scale = -1.0
	player.toon.set_emotion(Toon.Emotion.SAD)
	await Task.delay(1.0)
	player.animator.speed_scale = 1.0
	player.animator.stop()
	AudioManager.stop_music(true)
	AudioManager.reset_music_pitch()
	await Task.delay(1.0)
	AudioManager.play_snippet(load("res://audio/sfx/sequences/elevator_trick/elevator_trick_fall.ogg"))
	player.set_animation('melt_nosink')
	player.animator.seek(2.0)
	var fall_tween := create_tween()
	fall_tween.tween_property(player,'position:y',-10,0.6)
	await fall_tween.finished
	fall_tween.kill()
	floor_tween.kill()
	player.toon.set_emotion(Toon.Emotion.NEUTRAL)
	SceneLoader.change_scene_to_packed(load('res://scenes/falling_scene/falling_scene.tscn'))
