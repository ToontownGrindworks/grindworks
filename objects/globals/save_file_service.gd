extends Node

## MANAGES THE USER FILES
## Includes:
## - Settings File
## - Progress File
## - Current Run File

const SAVE_FILE_PATH := 'user://save/'
const RUN_FILE_NAME := 'current_save.tres'
const GLOBALSAVE_FILE_NAME := 'progress.tres'
const SETTINGS_FILE_NAME := 'settings.tres'
const ACHIEVEMENT_UI := preload("res://objects/general_ui/achievement_notification/achievement_ui.tscn")
const SAVE_GAME_TEXT := preload("res://objects/save_file/save_game_text.tscn")

var run_file: SaveFile
var progress_file: ProgressFile
var settings_file: SettingsFile

var achievement_ui: Control

signal s_game_loaded
signal s_reset


func save():
	_save_run()
	_save_progress()
	_show_save_text()

func _save_run() -> void:
	if not run_file:
		run_file = SaveFile.new()
	run_file.get_run_info()
	run_file.save_to(RUN_FILE_NAME)
	print("Run file saved")


func _save_progress() -> void:
	progress_file.save_to(GLOBALSAVE_FILE_NAME)
	print("Progress file saved")

func save_settings() -> void:
	settings_file.save_to(SETTINGS_FILE_NAME)
	print("Settings file saved")

func get_player_state() -> PlayerStats:
	if Util.get_player() and is_instance_valid(Util.get_player()):
		return Util.get_player().stats
	else:
		return null

func delete_run_file() -> void:
	if FileAccess.file_exists(SAVE_FILE_PATH+RUN_FILE_NAME):
		DirAccess.remove_absolute(SAVE_FILE_PATH+RUN_FILE_NAME)
	
	run_file = null
	s_reset.emit()

func _ready():
	if not DirAccess.dir_exists_absolute(SAVE_FILE_PATH):
		DirAccess.make_dir_absolute(SAVE_FILE_PATH)
	
	# Look for the global progress file
	if FileAccess.file_exists(SAVE_FILE_PATH + GLOBALSAVE_FILE_NAME):
		var file = load(SAVE_FILE_PATH + GLOBALSAVE_FILE_NAME)
		if file is ProgressFile:
			progress_file = file
	# Should create the file
	if not progress_file:
		progress_file = ProgressFile.new()
	
	# Set up our achievement listener
	achievement_ui = ACHIEVEMENT_UI.instantiate()
	add_child(achievement_ui)
	
	# Let progress file start listening
	progress_file.start_listening()
	
	# Get the user settings
	if FileAccess.file_exists(SAVE_FILE_PATH + SETTINGS_FILE_NAME):
		var file = load(SAVE_FILE_PATH + SETTINGS_FILE_NAME)
		if file is SettingsFile:
			settings_file = file
		else:
			printerr("Invalid settings file found. Deleting.")
			DirAccess.remove_absolute(SAVE_FILE_PATH+SETTINGS_FILE_NAME)
	if not settings_file:
		settings_file = SettingsFile.new()
	
	settings_file.sync_settings()
	load_run()

func load_run() -> void:
	# Try to get the current run
	if FileAccess.file_exists(SAVE_FILE_PATH+RUN_FILE_NAME):
		var file = ResourceLoader.load(SAVE_FILE_PATH+RUN_FILE_NAME, "", ResourceLoader.CacheMode.CACHE_MODE_IGNORE).duplicate()
		if file is SaveFile:
			run_file = file
			s_game_loaded.emit()
		else:
			printerr('Attempted to load invalid save file. Deleting.')
			DirAccess.remove_absolute(SAVE_FILE_PATH+RUN_FILE_NAME)
	if not run_file:
		return
	RandomService.base_seed = (run_file.current_seed)
	RandomService.channels = run_file.seed_channels
	Util.floor_number = run_file.floor_number
	ItemService.seen_items = run_file.seen_items
	ItemService.items_in_play = run_file.items_in_play

func on_game_over() -> void:
	delete_run_file()
	run_file = null

func _process(delta : float) -> void:
	progress_file.total_playtime += delta
	
	#if Input.is_action_just_pressed('save'):
	#	save()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_progress()

func make_progress(property : String, value : Variant) -> void:
	if property in progress_file:
		progress_file.set(property, value)

func _show_save_text() -> void:
	var save_text_instance = SAVE_GAME_TEXT.instantiate()
	add_child(save_text_instance)

	var label = save_text_instance.get_node("Label")
	var tween = create_tween()

	tween.tween_property(label, "modulate:a", 1, 1.0)
	tween.tween_property(label, "modulate:a", 1, 2.0)
	tween.tween_property(label, "modulate:a", 0, 1.0)
	tween.finished.connect(_on_tween_all_completed.bind(save_text_instance))

func _on_tween_all_completed(save_text_instance):
	save_text_instance.queue_free()
