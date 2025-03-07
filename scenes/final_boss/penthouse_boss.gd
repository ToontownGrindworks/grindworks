extends Node3D
class_name FinalBossScene

const TITLE_SCREEN_SCENE := "res://scenes/title_screen/title_screen.tscn"
const SKY_SPEED := 3.0
const COG_SCENE := preload("res://objects/cog/cog.tscn")

const SFX_CAGE_LOWER := preload("res://audio/sfx/misc/CHQ_SOS_cage_lower.ogg")
const SFX_CAGE_LAND := preload("res://audio/sfx/misc/CHQ_SOS_cage_land.ogg")

var WANT_DEBUG_BOSSES := false
var DEBUG_FORCE_BOSS_ONE: CogDNA = load("res://objects/cog/presets/lawbot/whistleblower.tres")
var DEBUG_FORCE_BOSS_TWO: CogDNA = load("res://objects/cog/presets/bossbot/union_buster.tres")

var MUSIC_TRACK: AudioStream = load("res://audio/music/Bossbot_Entry_v2.ogg")

@export var possible_bosses: Array[CogDNA] = []

@onready var battle: BattleNode = $BattleNode
@onready var caged_toon: Toon = $Grp_animation/toonCage/CagedToon
@onready var boss_cog: Cog = $BattleNode/BossCog
@onready var boss_cog_2: Cog = $BattleNode/BossCog2
@onready var toon_cage: MeshInstance3D = $Grp_animation/toonCage

@onready var scene_animator: AnimationPlayer = $SceneAnimator

## Elevators
@onready var elevator_in: Elevator = $ElevatorEntrance
@onready var elevator_out: Elevator = $ElevatorExit

var unlock_toon := false

## For battle tracking
const COG_LEVEL_RANGE := Vector2i(8, 12)
var boss_one_choice: CogDNA
var boss_two_choice: CogDNA

var boss_one_alive := true
var boss_two_alive := true

var darkened_sky := false

func _ready() -> void:
	set_caged_toon_dna(get_caged_toon_dna())
	AudioManager.set_music(MUSIC_TRACK)
	# Pick the first boss
	var boss_choices := possible_bosses.duplicate()
	if DEBUG_FORCE_BOSS_ONE != null and OS.is_debug_build() and WANT_DEBUG_BOSSES:
		boss_one_choice = DEBUG_FORCE_BOSS_ONE
	else:
		boss_one_choice = RandomService.array_pick_random('base_seed', boss_choices)
	boss_cog.set_dna(boss_one_choice)
	boss_choices.erase(boss_one_choice)

	# Pick the second boss
	if DEBUG_FORCE_BOSS_TWO != null and OS.is_debug_build() and WANT_DEBUG_BOSSES:
		boss_two_choice = DEBUG_FORCE_BOSS_TWO
	else:
		boss_two_choice = RandomService.array_pick_random('base_seed', boss_choices)
	boss_cog_2.set_dna(boss_two_choice)

	# Nerf their damage got damn!!!
	boss_cog.stats.damage = 1.2
	boss_cog_2.stats.damage = 1.2

	# Start the battle
	Util.get_player().state = Player.PlayerState.WALK
	battle.player_entered(Util.get_player())

	if not BattleService.ongoing_battle:
		await BattleService.s_battle_started

	# Every 2 rounds, starting on round 2: Spawn in 2 more cogs
	BattleService.ongoing_battle.s_round_started.connect(try_add_cogs)
	BattleService.ongoing_battle.s_participant_died.connect(participant_died)
	BattleService.ongoing_battle.s_battle_ending.connect(battle_ending)

func try_add_cogs(_actions: Array[BattleAction]) -> void:
	if BattleService.ongoing_battle.current_round % 2 == 0 and (boss_one_alive or boss_two_alive):
		var new_reinforcements := ElevatorReinforcements.new()
		new_reinforcements.user = self
		BattleService.ongoing_battle.round_end_actions.append(new_reinforcements)

func participant_died(who: Node3D) -> void:
	if who == boss_cog:
		boss_one_alive = false
		a_boss_died()
	elif who == boss_cog_2:
		boss_two_alive = false
		a_boss_died()

func battle_ending() -> void:
	Util.get_player().game_timer_tick = false
	Util.get_player().game_timer.become_full_visible()
	var win_time : float = Util.get_player().game_timer.time
	if win_time < SaveFileService.progress_file.best_time or is_equal_approx(0.0, SaveFileService.progress_file.best_time):
		SaveFileService.progress_file.best_time = Util.get_player().game_timer.time

func to_dusk() -> void:
	$WorldEnvironment.environment = $WorldEnvironment.environment.duplicate()
	var env: Environment = $WorldEnvironment.environment
	
	var dusk_tween := create_tween()
	dusk_tween.tween_property(env, "ambient_light_energy", 0.7, 15.0)
	dusk_tween.parallel().tween_property(env, "ambient_light_color", Color("c3a192"), 15.0)
	dusk_tween.finished.connect(dusk_tween.kill)
	
func a_boss_died() -> void:
	if not darkened_sky:
		darkened_sky = true
		to_dusk()
		# to unlock-loop
		AudioManager.set_clip(2)

func set_caged_toon_dna(dna: ToonDNA) -> void:
	caged_toon.construct_toon(dna)
	caged_toon.set_animation('neutral')

func get_caged_toon_dna() -> ToonDNA:
	var unlock_index: int = SaveFileService.progress_file.characters_unlocked
	var can_unlock: bool = Util.get_player().stats.character.character_name == Globals.TOON_UNLOCK_ORDER[unlock_index - 1].character_name
	if Util.get_player().stats.character.character_name == Globals.TOON_UNLOCK_ORDER[5].character_name:
		can_unlock = false
	if not can_unlock:
		var dna := ToonDNA.new()
		dna.randomize_dna()
		return dna
	unlock_toon = true
	return Globals.TOON_UNLOCK_ORDER[unlock_index].dna

func on_battle_finished() -> void:
	if unlock_toon:
		Globals.s_character_unlocked.emit(Globals.TOON_UNLOCK_ORDER[SaveFileService.progress_file.characters_unlocked])
		SaveFileService.progress_file.characters_unlocked += 1
	win_game()

func end_game() -> void:
	SaveFileService.progress_file.win_streak += 1
	for partner in Util.get_player().partners:
		partner.queue_free()
	Util.get_player().queue_free()
	SaveFileService.delete_run_file()
	SceneLoader.load_into_scene(TITLE_SCREEN_SCENE)

func fill_elevator(cog_count: int, dna: CogDNA = null) -> Array[Cog]:
	var roll_for_proxies : bool = SaveFileService.progress_file.proxies_unlocked and not both_bosses_alive()
	var new_cogs: Array[Cog]
	for i in cog_count:
		var cog := COG_SCENE.instantiate()
		cog.custom_level_range = COG_LEVEL_RANGE
		if dna: cog.dna = dna
		elif roll_for_proxies and RandomService.randf_channel('mod_cog_chance') < 0.25:
			cog.use_mod_cogs_pool = true
		battle.add_child(cog)
		cog.global_position = get_char_position("CogPos%d" % (i + 1))
		new_cogs.append(cog)
	return new_cogs

func get_char_position(pos: String) -> Vector3:
	return $CharPositions.get_node(pos).global_position

func both_bosses_alive() -> bool:
	return boss_one_alive and boss_two_alive

#region Final sequence

signal s_player_finished_walking
signal s_caged_toon_finished_walking

const FinalSpd := 3.0

func win_game() -> void:
	AudioManager.set_music(load("res://audio/music/encntr_hall_of_fame.ogg"))
	var player := Util.get_player()
	player.state = Player.PlayerState.STOPPED
	player.set_animation("neutral")
	var scene := create_tween()
	scene.tween_callback(player.set_global_position.bind(get_char_position('PlayerWinPos')))
	scene.tween_callback(player.face_position.bind(caged_toon.global_position))
	scene.tween_callback($CameraAngles.get_node('GameWin').make_current)
	scene.tween_callback(AudioManager.play_snippet.bind(SFX_CAGE_LOWER, 0.0, 1.0))
	scene.tween_property(toon_cage, 'position:y', -3.49, 1.0)
	scene.tween_callback(AudioManager.play_sound.bind(SFX_CAGE_LAND))
	scene.tween_property(toon_cage.get_node('cage_door'), 'rotation_degrees:x', 90.0, 0.5)
	scene.tween_callback(caged_toon.speak.bind("Whew, thanks for the rescue!"))
	
	if unlock_toon and SaveFileService.progress_file.characters_unlocked < 6:
		scene.tween_interval(4.0)
		scene.tween_callback(caged_toon.speak.bind("I think it's time I give the Cogs a little payback."))
		scene.tween_interval(4.0)
		scene.tween_callback(caged_toon.speak.bind("The least I could do is join you in taking them down!"))
	
	scene.tween_interval(4.0)
	scene.tween_callback(caged_toon.speak.bind("We should really get out of here, though."))
	scene.tween_interval(4.0)
	scene.tween_callback(caged_toon.speak.bind("The Cogs will have those big bads rebuilt in no time!"))
	scene.tween_interval(4.0)
	await scene.finished

	CameraTransition.from_current(self, %GameWinElevator, 4.0, Tween.EASE_IN_OUT, Tween.TRANS_QUAD)
	elevator_out.open()
	do_move_player_seq()
	do_move_caged_toon_seq()
	await SignalBarrier.new([s_player_finished_walking, s_caged_toon_finished_walking]).s_complete
	elevator_out.close()
	# Fade out the victory music
	Sequence.new([
		LerpFunc.new(AudioManager.set_music_volume, 3.0, 0.0, -80.0)
	]).as_tween(self)
	await CameraTransition.from_current(self, %PaintingFocus, 3.0).s_done
	await Task.delay(1.0)
	%FadeOutLayer.show()
	await Sequence.new([
		LerpProperty.new(%BlackFade, ^"color:a", 2.0, 1.0).interp(Tween.EASE_IN, Tween.TRANS_QUAD)
	]).as_tween(self).finished
	await Task.delay(1.75)

	AudioManager.stop_music()
	AudioManager.set_music_volume(0.0)
	scene.kill()
	end_game()

func do_move_player_seq() -> void:
	var player: Player = Util.get_player()
	await player.turn_to_position(%InFrontElevatorPos.global_position, 1.0)
	await player.move_to(%InFrontElevatorPos.global_position, FinalSpd).finished
	# player.toon.global_rotation.y += TAU
	await player.turn_to_position(%ElevatorLeftPos.global_position, 1.0)
	await player.move_to(%ElevatorLeftPos.global_position, FinalSpd).finished
	await player.turn_to_position(Vector3.ZERO, 1.5)
	s_player_finished_walking.emit()

func do_move_caged_toon_seq() -> void:
	await Task.delay(0.5)
	await caged_toon.move_to(%PlayerWinPos.global_position, FinalSpd).finished
	await caged_toon.turn_to_position(%InFrontElevatorPos.global_position, 1.0)
	await caged_toon.move_to(%InFrontElevatorPos.global_position, FinalSpd).finished
	await caged_toon.turn_to_position(%ElevatorRightPos.global_position, 1.0)
	await caged_toon.move_to(%ElevatorRightPos.global_position, FinalSpd).finished
	await caged_toon.turn_to_position(Vector3.ZERO, 1.5)
	s_caged_toon_finished_walking.emit()

#endregion
