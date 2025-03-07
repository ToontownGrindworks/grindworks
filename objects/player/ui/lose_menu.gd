extends CanvasLayer
class_name LoseMenu

const SFX_LOSE := preload("res://audio/sfx/misc/MG_lose.ogg")

enum MenuChoice { PLAY_AGAIN, BACK_TO_MENU }

signal s_choice_made(menu_choice: MenuChoice)

@onready var root: Control = %Root
@onready var node_viewer: TextureRect = %NodeViewer

var toon: Toon

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	%DefeatedBy.text = "Defeated by %s" % Util.get_player().last_damage_source
	Engine.time_scale = 1.0
	get_tree().paused = true
	root.modulate.a = 0.0

	toon = load("res://objects/toon/toon.tscn").instantiate()
	node_viewer.add_child(toon)
	toon.drop_shadow.queue_free()
	var dna: ToonDNA
	if not is_instance_valid(Util.get_player()):
		dna = ToonDNA.new()
		dna.randomize_dna()
	else:
		dna = Util.get_player().toon.toon_dna
		Util.get_player().hide()

	toon.construct_toon(dna)
	toon.set_animation('lose')
	toon.rotation_degrees.y = 210.0
	toon.body.animator.seek(3.73, true)
	toon.body.animator.pause()
	toon.set_eyes(Toon.Emotion.SAD)
	toon.reset_physics_interpolation()

	Sequence.new([
		LerpProperty.new(root, ^"modulate:a", 1.0, 1.0).interp(Tween.EASE_IN, Tween.TRANS_QUAD)
	]).as_tween(self)
	# Pitch scale doesn't work on interactives for some reason!!! Improvised replacement!!!
	if AudioManager.current_music is AudioStreamInteractive:
		AudioManager.stop_music()
		AudioManager.play_sound(load("res://audio/music/boss_lost.ogg"))
	else:
		AudioManager.tween_music_pitch(2.0, 0.4)
		AudioManager.play_sound(SFX_LOSE)

	await get_tree().process_frame
	node_viewer.remove_child(toon)
	await get_tree().process_frame
	node_viewer.node = toon

func play_again() -> void:
	s_choice_made.emit(MenuChoice.PLAY_AGAIN)

func exit() -> void:
	s_choice_made.emit(MenuChoice.BACK_TO_MENU)

func _exit_tree() -> void:
	get_tree().paused = false
	AudioManager.reset_music_pitch()
