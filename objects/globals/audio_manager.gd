extends Node

# For music playing
var current_music: AudioStream:
	set(x):
		music_player.stream = x
	get:
		return music_player.stream
var default_music: AudioStream
var music_player: AudioStreamPlayer

# For music effects
@onready var MusicFilter: AudioEffectLowPassFilter = AudioServer.get_bus_effect(AudioServer.get_bus_index("Music"), 0)
@export var MusicLPFCutoff: float = 1200

var fx_tweens = []

var tween: Tween:
	set(x):
		if tween and tween.is_valid():
			tween.kill()
		tween = x

@onready var music_pitch_tween: Tween:
	set(x):
		if music_pitch_tween and music_pitch_tween.is_valid():
			music_pitch_tween.kill()
		music_pitch_tween = x

# For SFX
var sound_effects: Array[AudioStreamPlayer] = []

# Signals
signal s_music_looped(music: AudioStream)
signal s_sound_effect_played(sfx: AudioStream)
signal s_sound_effect_finished(sfx: AudioStream)


func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	music_player.bus = "Music"
	music_player.set_process_mode(Node.PROCESS_MODE_ALWAYS)
	set_process_mode(Node.PROCESS_MODE_ALWAYS)
	# populate tweens
	for i in range(AudioServer.get_bus_effect_count(AudioServer.get_bus_index("Music"))):
		fx_tweens.append(null)

	BattleService.s_battle_initialized.connect(battle_started.unbind(1))
	BattleService.s_battle_ended.connect(battle_ended)
	Util.s_player_died.connect(player_died)

func get_bus_index(bus: String) -> int:
	for i in AudioServer.bus_count:
		if AudioServer.get_bus_name(i) == bus:
			return i
	return -1

func battle_started() -> void:
	if SaveFileService.settings_file.ambient_sfx_enabled:
		AudioServer.set_bus_volume_db(get_bus_index("Ambient"), linear_to_db(0.3))

func battle_ended() -> void:
	if SaveFileService.settings_file.ambient_sfx_enabled:
		AudioServer.set_bus_volume_db(get_bus_index("Ambient"), linear_to_db(1.0))

func player_died() -> void:
	if SaveFileService.settings_file.ambient_sfx_enabled:
		AudioServer.set_bus_volume_db(get_bus_index("Ambient"), linear_to_db(1.0))

func set_music(music: AudioStream) -> void:
	if current_music:
		music_player.stop()
	current_music = music
	music_player.play()

func set_clip(clip: int) -> void:
	var playback = music_player.get_stream_playback()
	if playback is AudioStreamPlaybackInteractive:
		playback.switch_to_clip(clip)

func set_default_music(music: AudioStream) -> void:
	if not music_player.playing or music_player.stream == default_music:
		set_music(music)
	default_music = music

func stop_music(stop_all := false) -> void:
	music_player.stop()
	if stop_all:
		default_music = null
	elif default_music and not stop_all:
		set_music(default_music)
		
func set_fx_music_lpfilter(duration: float = 1, value: float = MusicLPFCutoff) -> void:
	# how can we get the ID of an effect on runtime?
	var id = 0
	fx_tweens[id] = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fx_tweens[id].tween_property(MusicFilter, "cutoff_hz", value, duration)
	#print("WE FILTERIN: " + str(duration) + str(value))
	
func reset_fx_music_lpfilter() -> void:
	set_fx_music_lpfilter(1, 20000)

func tween_music_pitch(duration: float = 2.0, value: float = 0.2) -> void:
	music_pitch_tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	music_pitch_tween.tween_property(music_player, "pitch_scale", value, duration)

func reset_music_pitch() -> void:
	tween_music_pitch(0.5, 1)

func play_sound(sfx: AudioStream, volume_db: float = 0.0, bus: String = "SFX") -> AudioStreamPlayer:
	var sfx_player := AudioStreamPlayer.new()
	add_child(sfx_player)
	sound_effects.append(sfx_player)
	sfx_player.bus = bus
	sfx_player.stream = sfx
	sfx_player.volume_db = volume_db
	sfx_player.play()
	sfx_player.finished.connect(sound_finished.bind(sfx_player))
	return sfx_player

func play_snippet(sfx: AudioStream, start: float = 0.0, end: float = -1.0, volume_db: float = 1.0) -> AudioStreamPlayer:
	if is_equal_approx(end,-1.0):
		end = sfx.get_length()
	
	if start > end:
		print("Invalid arguments for play_snippet")
		return
	
	var sfx_player := play_sound(sfx,volume_db)
	sfx_player.finished.disconnect(sound_finished)
	sfx_player.seek(start)
	get_tree().create_timer(end-start).timeout.connect(sound_finished.bind(sfx_player))
	return sfx_player


func is_audio_playing(sound: AudioStream) -> bool:
	# First, check music
	if sound == music_player.stream:
		return true
	# Check SFX
	for sfx in sound_effects:
		if sfx == sound:
			return true
	# Nop
	return false

func sound_finished(sfx_player: AudioStreamPlayer) -> void:
	sound_effects.erase(sfx_player)
	if is_instance_valid(sfx_player) and sfx_player.is_inside_tree():
		sfx_player.queue_free()

func set_music_volume(volume: float) -> void:
	music_player.volume_db = volume

func queue_audio(queue: Array[AudioStream]) -> void:
	for stream: AudioStream in queue:
		await play_sound(stream).finished
