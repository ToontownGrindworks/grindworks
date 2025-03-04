extends Control

const SFX_OPEN := preload("res://audio/sfx/ui/GUI_stickerbook_open.ogg")
const SFX_CLOSE := preload("res://audio/sfx/ui/GUI_stickerbook_delete.ogg")

@export var AnimatePauseMenu: bool = true

func _ready() -> void:
	hide()
	get_tree().paused = true

	AudioManager.set_fx_music_lpfilter()
	AudioManager.play_sound(SFX_OPEN)

	if AnimatePauseMenu:
		$AnimationPlayer.play("pause_on")
		show()


func _exit_tree() -> void:
	AudioManager.reset_fx_music_lpfilter()
	AudioManager.play_sound(SFX_CLOSE)

func resume() -> void:
	Util.get_player().quick_heal(Util.get_player().stats.max_hp)
	quit()

func quit() -> void:
	get_tree().paused = false
	queue_free()
