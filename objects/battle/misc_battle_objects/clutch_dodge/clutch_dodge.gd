extends Control

const SFX_OPEN := preload("res://mod_assets/sans/clutch_dodge/snd_laz.wav")
const SFX_CLOSE := {
	true: preload("res://mod_assets/sans/clutch_dodge/snd_power.wav"),
	false: preload("res://mod_assets/sans/clutch_dodge/snd_damage.wav")
}

@export var AnimatePauseMenu: bool = true

func _ready() -> void:
	hide()
	get_tree().paused = true

	AudioManager.set_fx_music_lpfilter()
	AudioManager.play_sound(SFX_OPEN)
	
	$KnifeSlice.play()

	if AnimatePauseMenu:
		$AnimationPlayer.play("pause_on")
		show()

func _exit_tree() -> void:
	AudioManager.reset_fx_music_lpfilter()
	#AudioManager.play_sound(SFX_CLOSE)

func resume() -> void:
	#Util.get_player().quick_heal(Util.get_player().stats.max_hp)
	quit()

func quit() -> void:
	get_tree().paused = false
	queue_free()


func _on_timing_game_game_finished(result):
	AudioManager.play_sound(SFX_CLOSE[result])
	Util.s_clutch_ended.emit(result)
	quit()
