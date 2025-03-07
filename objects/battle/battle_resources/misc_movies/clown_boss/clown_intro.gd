extends BattleStartMovie
class_name ClownBossIntro


const SFX_PIANO_TUNA := preload("res://audio/sfx/misc/Piano_Tuna.ogg")
const SFX_FALL := preload("res://audio/sfx/toon/target_impact_grunt1.ogg")



## WILL ONLY WORK IN THE CLOWN BOSS

func _skip() -> void:
	super()
	await BattleService.s_battle_started
	battle_node.focus_character(battle_node)

func play() -> Tween:
	
	# Get all cog actors for cutscene
	var clown1 : Cog = battle_node.cogs[1]
	var clown2 : Cog = battle_node.cogs[2]
	var cog1 : Cog = battle_node.cogs[0]
	var cog2 : Cog = battle_node.cogs[3]
	
	# Get the player
	var player := Util.get_player()
	
	# Get the boss fight root
	var root : Node3D = battle_node.get_parent()
	
	# Get the elevator
	var elevator : Elevator = root.get_node('Elevator')
	
	# Get memo
	var memo : Node3D = root.get_node('Memo')
	
	# Get the camera angle refs
	var cam_angles : Node3D = root.get_node('CameraAngles')
	
	# Get character postions
	var char_positions := root.get_node('CharPositions')

	# Camera should be parented to the battle node
	if not camera.get_parent() == battle_node:
		camera.reparent(battle_node)
	
	# For boo shot
	var speech_node : Node3D = char_positions.get_node('DialPos')
	
	# Snap player to the floor if possible
	player.global_position.y = battle_node.global_position.y
	
	# Make player look at its first position
	player.face_position(char_positions.get_node('NotePos').global_position)
	
	## MOVIE START
	movie = create_tween()
	
	# Pan camera back
	movie.set_trans(Tween.TRANS_QUAD)
	movie.tween_callback(CameraTransition.from_global_transform.bind(battle_node, Util.get_player().camera.camera.global_transform, cam_angles.get_node('IntroPos'), 6.0))
	
	# Toon walks into room (Parallel)
	movie.set_parallel(true)
	movie.set_trans(Tween.TRANS_LINEAR)
	movie.tween_callback(player.set_animation.bind('walk'))
	movie.tween_property(player, 'global_position', char_positions.get_node('NotePos').global_position, 6.0)
	movie.tween_property(AudioManager.music_player, 'volume_db', -80.0, 3.0)
	movie.set_parallel(false)
	
	# Make player look forwards
	movie.tween_callback(player.set_animation.bind('neutral'))
	movie.tween_interval(1.5)
	
	# Toon reads note
	movie.tween_callback(camera.make_current)
	movie.tween_callback(memo.reparent.bind(player.toon.right_hand_bone))
	movie.tween_callback(memo.set_position.bind(Vector3(0.6,0,0.75)))
	movie.tween_callback(memo.set_rotation_degrees.bind(Vector3(-40.5,-22.5,-80.0)))
	movie.tween_callback(player.set_animation.bind('book_neutral'))
	movie.tween_callback(player.toon.set_eyes.bind(Toon.Emotion.CURIOUS))
	movie.tween_callback(set_camera_angle.bind(cam_angles.get_node('CloseupPos')))
	movie.tween_callback(camera.global_translate.bind(Vector3(0,2,0)))
	movie.tween_callback(face_object_towards.bind(camera,player.toon.head_bone))
	movie.tween_interval(2.0)
	
	# Note Shot
	movie.tween_callback(player.animator.seek.bind(0.0))
	movie.tween_callback(player.toon.set_eyes.bind(Toon.Emotion.NEUTRAL))
	movie.tween_callback(player.toon.head.hide)
	movie.tween_callback(camera.reparent.bind(player.toon.head_bone))
	movie.tween_callback(camera.set_position.bind(Vector3.ZERO))
	movie.tween_callback(camera.set_rotation_degrees.bind(Vector3(0,180,0)))
	movie.tween_interval(6.0)
	movie.tween_callback(player.toon.head.show)
	movie.tween_callback(camera.reparent.bind(battle_node))
	movie.tween_callback(player.set_animation.bind('neutral'))

	# Toon turns around
	movie.tween_callback(set_camera_angle.bind(cam_angles.get_node('BooPos')))
	movie.tween_callback(memo.queue_free)
	movie.tween_property(camera, 'position:z', -4.0, 1.5)
	movie.parallel().tween_callback(player.set_animation.bind('walk'))
	movie.parallel().set_trans(Tween.TRANS_LINEAR)
	movie.parallel().tween_property(player.toon,'rotation_degrees:y',-180.0,2.0).as_relative()
	movie.parallel().tween_callback(clown1.show).set_delay(0.5)
	movie.parallel().tween_callback(clown1.set_animation.bind('walknreach')).set_delay(0.5)
	movie.parallel().tween_callback(clown1.pause_animator).set_delay(1.8)
	movie.parallel().tween_callback(player.set_animation.bind('neutral')).set_delay(2.0)
	
	# Manual speak bc the chat node is far from camera
	movie.tween_callback(
		func():
			var bubble: SpeechBubble = load('res://objects/misc/speech_bubble/speech_bubble.tscn').instantiate()
			bubble.target = speech_node
			speech_node.add_child(bubble)
			bubble.set_font(load('res://fonts/vtRemingtonPortable.ttf'))
			bubble.set_text("Boo.")
			bubble.bubble.scale *= 2.0
			bubble.label.scale *= 2.0
			bubble.label.position *= 2.0
			AudioManager.play_sound(clown1.statement)
	)
	movie.tween_callback(player.set_animation.bind('slip_backward'))
	movie.tween_callback(player.toon.set_emotion.bind(Toon.Emotion.SURPRISE))
	movie.tween_interval(0.6)
	movie.tween_callback(AudioManager.play_sound.bind(SFX_FALL))
	movie.tween_interval(0.65)
	
	
	# Player falls backwards
	movie.tween_callback(AudioManager.play_sound.bind(SFX_PIANO_TUNA))
	movie.tween_callback(player.toon.set_emotion.bind(Toon.Emotion.ANGRY))
	movie.tween_callback(battle_node.focus_character.bind(player))
	movie.tween_callback(clown1.set_position.bind(Vector3(-1.632, -0.008, 0)))
	movie.tween_interval(0.6)
	movie.tween_callback(AudioManager.play_sound.bind(SFX_FALL))
	movie.tween_interval(1.4)
	
	# Clowns laugh at player
	movie.tween_callback(clown2.show)
	movie.tween_callback(clown2.face_position.bind(char_positions.get_node('NotePos').global_position))
	movie.tween_callback(clown2.set_animation.bind('laugh'))
	movie.tween_callback(clown1.face_position.bind(char_positions.get_node('NotePos').global_position))
	movie.tween_callback(clown1.set_animation.bind('laugh'))
	movie.tween_callback(set_camera_angle.bind(cam_angles.get_node('LaughPos')))
	movie.tween_interval(1.0)
	movie.tween_callback(battle_node.focus_character.bind(clown2, -4.0, 0))
	movie.tween_callback(clown2.speak.bind("YOU ACTUALLY FELL FOR IT!"))
	movie.tween_interval(2.0)
	movie.tween_callback(battle_node.focus_character.bind(clown1, -4.0, 1))
	movie.tween_callback(clown1.set_animation.bind('laugh'))
	movie.tween_callback(clown1.animator_seek.bind(1.0))
	movie.tween_callback(clown1.speak.bind("THAT WAS PRICELESS!"))
	movie.tween_interval(3.0)
	
	# Open elevator
	movie.tween_callback(cog1.show)
	movie.tween_callback(cog2.show)
	movie.tween_callback(battle_node.focus_character.bind(cog1, 6.0))
	movie.tween_callback(elevator.open)
	movie.tween_interval(3.5)
	
	# Focus Clowns
	movie.tween_callback(battle_node.focus_character.bind(clown1, -4.0))
	movie.tween_callback(clown1.speak.bind("Now, let's see how you handle some REAL funny business..."))
	movie.tween_interval(4.0)
	
	# Start the music
	movie.tween_callback(player.toon.set_emotion.bind(Toon.Emotion.NEUTRAL))
	movie.tween_callback(start_music)
	movie.tween_callback(AudioManager.music_player.set_volume_db.bind(0.0))
	return movie


func set_camera_angle(node : Node3D) -> void:
	battle_node.battle_cam.global_transform = node.global_transform
