extends BattleStartMovie
class_name VirtualCogIntro


var openers := [
	"We've caught you red-handed.",
	"Escape is virtually impossible.",
]

const FLASH_COLOR := Color.DARK_RED
const BASE_COLOR := Color.RED
const SPARK_SFX := "res://audio/sfx/battle/cogs/misc/LB_sparks_1.ogg"

func play() -> Tween:
	
	# These all happen instantly, so no need to tween
	start_music()
	AudioManager.play_sound(load(SPARK_SFX))
	for cog in cogs:
		do_flashing_slow(cog)
		cog.set_animation('drop')
		cog.animator.seek(3.0)
	battle_node.battle_cam.position.y = 1.0
	
	## MOVIE START
	movie = create_tween()
	
	# Move camera to floor near Cog
	# And tween it up to the head node
	movie.tween_callback(battle_node.focus_character.bind(focus_cog))
	movie.set_trans(Tween.TRANS_QUAD)
	movie.tween_property(battle_node.battle_cam,'global_position:y',focus_cog.head_node.global_position.y,3.0)
	
	# Make focus cog say a line
	movie.tween_callback(battle_node.focus_character.bind(focus_cog))
	movie.tween_callback(focus_cog.speak.bind(openers[RandomService.randi_channel('true_random') % openers.size()]))
	movie.tween_interval(3.0)
	
	return movie


func do_flashing(cog : Cog) -> void:
	var delay := 0.25
	var color := false
	while delay > 0.005:
		delay*=(9.0/10.0)
		await Task.delay(delay)
		color = !color
		if color:
			set_cog_color(FLASH_COLOR,cog)
		else:
			set_cog_color(BASE_COLOR,cog)
	set_cog_color(BASE_COLOR,cog)
	

func do_flashing_gradual(cog : Cog) -> void:
	var delay := 0.25
	var color := false
	var color_tween := cog.create_tween()
	while delay > 0.005:
		delay*=(9.0/10.0)
		if color:
			color_tween.tween_method(set_cog_color.bind(cog),FLASH_COLOR,BASE_COLOR,delay)
		else:
			color_tween.tween_method(set_cog_color.bind(cog),BASE_COLOR,FLASH_COLOR,delay)
	await color_tween.finished
	color_tween.kill()
	set_cog_color(BASE_COLOR,cog)

func do_flashing_slow(cog : Cog) -> void:
	var color := false
	var color_tween := cog.create_tween()
	for i in 3:
		color = !color
		if color:
			color_tween.tween_method(set_cog_color.bind(cog),FLASH_COLOR,BASE_COLOR,0.75)
		else:
			color_tween.tween_method(set_cog_color.bind(cog),BASE_COLOR,FLASH_COLOR,0.75)
	await color_tween.finished
	color_tween.kill()
	set_cog_color(BASE_COLOR,cog)

func set_cog_color(color : Color,cog : Cog) -> void:
	for child in cog.skeleton.get_children():
		if child is MeshInstance3D:
			for i in child.mesh.get_surface_count():
				child.get_surface_override_material(i).albedo_color = color
				child.get_surface_override_material(i).albedo_color.a = 0.8
