extends BattleStartMovie
class_name SlendercogIntro

const STATIC_VISIBILITY_RANGE := Vector2(0.01,0.4)
const FLICKER_RANGE := Vector2i(15,25)
const FLICKER_DISTANCE_RANGE := Vector2(0.05,0.1)

var directory : Node3D
var slendercog : Cog
var tv_static : TextureRect
var player : Player


func play() -> Tween:
	# Get the necessary references
	# First, the directory
	directory = battle_node.get_parent()
	
	# Then get the rest of the required nodes
	tv_static = directory.cutscene_static
	slendercog = directory.slendercog
	player = Util.get_player()
	var static_meter : Panel = directory.static_meter
	
	# Put player on floor
	player.global_position.y = battle_node.global_position.y
	
	## MOVIE START
	movie = create_tween()
	
	# Player walk into room
	movie.tween_callback(player.face_position.bind(get_character_pos('EnterPos')))
	movie.tween_callback(player.set_animation.bind('walk'))
	movie.tween_callback(set_camera_angle.bind('AngleStart'))
	movie.tween_property(player,'global_position',get_character_pos('EnterPos'),5.0)
	movie.parallel().tween_callback(directory.mute_music)
	movie.parallel().set_trans(Tween.TRANS_QUAD)
	movie.parallel().tween_property(battle_node.battle_cam,'global_transform',get_camera_angle('AngleStart2'),3.0).set_delay(1.0)
	movie.tween_callback(player.set_animation.bind('neutral'))
	movie.tween_callback(player.face_position.bind(battle_node.global_position))
	movie.tween_interval(1.0)
	
	
	# Look Around the room
	movie.tween_callback(set_camera_angle.bind('PanShot'))
	movie.tween_property(battle_node.battle_cam,'global_rotation_degrees:y',90.0,4.0).as_relative()
	movie.parallel().tween_callback(directory.increment_ambience)
	movie.tween_interval(2.0)
	
	# Player reacts to static
	movie.tween_callback(battle_node.focus_character.bind(player))
	movie.tween_callback(player.set_animation.bind('cringe'))
	movie.tween_method(tv_static.set_alpha, 0.0, 1.0, 2.0)
	movie.parallel().tween_method(directory.static_alpha_changed, 0.0, 1.0, 2.0)
	movie.parallel().tween_callback(battle_node.focus_character.bind(slendercog)).set_delay(1.0)
	movie.tween_interval(0.5)
	
	# Fade Slendercog in
	movie.tween_callback(slendercog.show)
	movie.tween_method(tv_static.set_alpha, 1.0, 0.0, 1.5)
	movie.parallel().tween_method(directory.static_alpha_changed, 1.0, 0.0, 2.0)
	movie.tween_interval(2.0)
	
	# Player backs away
	movie.set_trans(Tween.TRANS_LINEAR)
	movie.tween_callback(player.toon.set_emotion.bind(Toon.Emotion.SAD))
	movie.tween_callback(set_camera_angle.bind('AngleStart2'))
	movie.tween_callback(player.animator.set_speed_scale.bind(-1.0))
	movie.tween_callback(player.set_animation.bind('walk'))
	movie.tween_property(player,'global_position',get_character_pos('BackAwayPos'),2.0)
	movie.tween_callback(player.set_animation.bind('neutral'))
	movie.tween_callback(player.animator.set_speed_scale.bind(1.0))
	
	# Static unveils the 3 other Cogs
	movie.tween_callback(tv_static.set_alpha.bind(1.0))
	movie.parallel().tween_callback(directory.static_alpha_changed.bind(1.0))
	movie.tween_interval(1.0)
	for cog in battle_node.cogs:
		if not cog == slendercog:
			movie.tween_callback(cog.show)
	movie.tween_callback(tv_static.set_alpha.bind(0.0))
	movie.parallel().tween_callback(directory.static_alpha_changed.bind(0.0))
	
	# Player runs back to other position
	movie.tween_callback(AudioManager.play_sound.bind(player.toon.howl))
	movie.tween_callback(player.toon.set_eyes.bind(Toon.Emotion.SURPRISE))
	movie.tween_callback(player.set_animation.bind('run'))
	movie.tween_property(player,'global_position',get_character_pos('RunAwayPos'),0.5)
	movie.tween_callback(player.set_animation.bind('neutral'))
	movie.tween_callback(player.toon.set_emotion.bind(Toon.Emotion.NEUTRAL))
	movie.tween_interval(3.0)
	movie.tween_callback(static_meter.show)
	
	return movie

func get_camera_angle(angle : String) -> Transform3D:
	return directory.get_camera_angle(angle)

func set_camera_angle(angle : String) -> void:
	battle_node.battle_cam.global_transform = get_camera_angle(angle)

func get_character_pos(pos : String) -> Vector3:
	return directory.get_character_pos(pos)

func toggle_slender_visible() -> void:
	slendercog.visible = not slendercog.visible
	toggle_static(slendercog.visible)

func randomize_static_alpha() -> void:
	tv_static.set_alpha(RandomService.randf_range_channel('true_random', STATIC_VISIBILITY_RANGE.x,STATIC_VISIBILITY_RANGE.y))

func toggle_static(show := true) -> void:
	tv_static.visible = show
	randomize_static_alpha()	
