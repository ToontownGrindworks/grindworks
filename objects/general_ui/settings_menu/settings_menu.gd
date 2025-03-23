@tool
extends UIPanel

const ENABLED_TEXT := "On"
const DISABLED_TEXT := "Off"

var prev_file: SettingsFile


func _ready() -> void:
	super()
	if not Engine.is_editor_hint():
		_sync_settings()
	backup_prev_settings()

func _sync_settings() -> void:
	_sync_video_settings()
	_sync_audio_settings()
	_sync_gameplay_settings()
	_sync_controls()

func backup_prev_settings() -> void:
	prev_file = SaveFileService.settings_file.duplicate()

## VIDEO SETTINGS

@onready var fullscreen_button: GeneralButton = %FullscreenButton
@onready var fps_button: GeneralButton = %FPSButton
@onready var alias_button: GeneralButton = %AliasButton
const FPSOptionText: Dictionary = {
	0: "60",
	1: "90",
	2: "120",
	3: "144",
	4: "165",
	5: "240",
	6: "360",
	7: "Unlimited",
}
const SpeedOptionText: Dictionary = {
	0: "x1.0",
	1: "x1.25",
	2: "x1.5",
	3: "x1.75",
}

func _sync_video_settings() -> void:
	fullscreen_button.text = get_toggle_text(get_setting('fullscreen'))
	Util.s_fullscreen_toggled.connect(func(_fullscreen: bool): fullscreen_button.text = get_toggle_text(get_setting('fullscreen')))
	fps_button.text = FPSOptionText[get_setting('fps_idx')]
	alias_button.text = get_toggle_text(get_setting('anti_aliasing'))
	
func toggle_full_screen() -> void:
	toggle_setting('fullscreen')
	if get_setting('fullscreen'):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	Util.s_fullscreen_toggled.emit(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)

func change_fps() -> void:
	var curr_idx: int = get_setting('fps_idx')
	curr_idx += 1
	if curr_idx >= SettingsFile.FPSOptions.size():
		curr_idx = 0
	update_setting('fps_idx', curr_idx)
	Engine.max_fps = SettingsFile.FPSOptions[curr_idx]
	fps_button.text = FPSOptionText[get_setting('fps_idx')]

func toggle_anti_aliasing() -> void:
	toggle_setting('anti_aliasing')
	alias_button.text = get_toggle_text(get_setting('anti_aliasing'))
	RenderingServer.viewport_set_msaa_3d(SaveFileService.get_viewport().get_viewport_rid(),
				RenderingServer.VIEWPORT_MSAA_4X if get_setting('anti_aliasing') else RenderingServer.VIEWPORT_MSAA_DISABLED)

## AUDIO SETTINGS

@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SFXSlider
@onready var ambient_button: GeneralButton = %AmbientButton

func _sync_audio_settings() -> void:
	master_slider.value = get_setting("master_volume")
	music_slider.value = get_setting("music_volume")
	sfx_slider.value = get_setting("sfx_volume")
	ambient_button.text = get_toggle_text(get_setting('ambient_sfx_enabled'))

func set_bus_volume(volume: float, bus: String) -> void:
	AudioServer.set_bus_volume_db(get_bus_index(bus), linear_to_db(volume))
	if OS.has_feature('debug'):
		print(bus + " volume set to: " + str(AudioServer.get_bus_volume_db(get_bus_index(bus))))
	update_setting(bus.to_lower() + '_volume', volume)

func get_bus_index(bus : String) -> int:
	for i in AudioServer.bus_count:
		if AudioServer.get_bus_name(i) == bus:
			return i
	return -1

func toggle_ambient_sfx() -> void:
	toggle_setting('ambient_sfx_enabled')
	ambient_button.text = get_toggle_text(get_setting('ambient_sfx_enabled'))
	AudioServer.set_bus_volume_db(get_bus_index("Ambient"), linear_to_db(1.0 if get_setting('ambient_sfx_enabled') else 0.0))

## GAMEPLAY SETTINGS

@onready var speed_button: GeneralButton = %SpeedButton
@onready var reaction_button: GeneralButton = %ReactionButton
@onready var auto_sprint_button: GeneralButton = %AutoSprintButton
@onready var control_style_button: GeneralButton = %ControlStyleButton
@onready var cam_sens_slider: HSlider = %CamSensSlider
@onready var timer_button : GeneralButton = %TimerButton
@onready var stuck_element : HBoxContainer = %ImStuck
@onready var intro_skip_button : GeneralButton = %IntroSkipButton
@onready var intro_skip_element : HBoxContainer = %IntroSkip
@onready var custom_cogs_button : GeneralButton = %CustomCogsButton
@onready var discord_rpc_element: HBoxContainer = %DiscordRPC
@onready var discord_rpc_button: GeneralButton = %DiscordRPCButton

func _sync_gameplay_settings() -> void:
	speed_button.text = SpeedOptionText[get_setting('battle_speed_idx')]
	reaction_button.text = get_toggle_text(get_setting('item_reactions'))
	auto_sprint_button.text = get_toggle_text(get_setting('auto_sprint'))
	control_style_button.text = get_control_style(get_setting('control_style'))
	cam_sens_slider.value = get_setting("camera_sensitivity")
	timer_button.text = get_toggle_text(get_setting('show_timer'))
	intro_skip_button.text = get_toggle_text(get_setting('skip_intro'))
	custom_cogs_button.text = get_toggle_text(get_setting('use_custom_cogs'))
	if not is_instance_valid(Util.floor_manager) or Util.stuck_lock:
		stuck_element.queue_free()
	if not SaveFileService.progress_file.characters_unlocked > 1:
		intro_skip_element.queue_free()
	discord_rpc_button.text = get_toggle_text(get_setting('discord_rpc'))

func change_speed() -> void:
	var curr_idx: int = get_setting('battle_speed_idx')
	curr_idx += 1
	if curr_idx >= SettingsFile.SpeedOptions.size():
		curr_idx = 0
	update_setting('battle_speed_idx', curr_idx)
	speed_button.text = SpeedOptionText[get_setting('battle_speed_idx')]

func toggle_item_reactions() -> void:
	toggle_setting('item_reactions')
	reaction_button.text = get_toggle_text(get_setting('item_reactions'))

func toggle_auto_sprint() -> void:
	toggle_setting('auto_sprint')
	auto_sprint_button.text = get_toggle_text(get_setting('auto_sprint'))

func toggle_control_style() -> void:
	toggle_setting('control_style')
	control_style_button.text = get_control_style(get_setting('control_style'))

func set_cam_sens(value: float) -> void:
	update_setting('camera_sensitivity', value)

func toggle_timer() -> void:
	toggle_setting('show_timer')
	timer_button.text = get_toggle_text(get_setting('show_timer'))
	if is_instance_valid(Util.get_player()):
		Util.get_player().game_timer.visible = get_setting('show_timer')

func toggle_intro_skip() -> void:
	toggle_setting('skip_intro')
	intro_skip_button.text = get_toggle_text(get_setting('skip_intro'))

func toggle_custom_cogs() -> void:
	toggle_setting('use_custom_cogs')
	custom_cogs_button.text = get_toggle_text(get_setting('use_custom_cogs'))
	Globals.import_custom_cogs()
func toggle_discord_rpc() -> void:
	toggle_setting('discord_rpc')
	discord_rpc_button.text = get_toggle_text(get_setting('discord_rpc'))
	if get_setting('discord_rpc'):
		DiscordManager.menu()
	else:
		DiscordManager.stop()

# It's for the I'm stuck button
func cry_for_help() -> void:
	close()
	if get_tree().get_root().get_node_or_null('PauseMenu'):
		get_tree().get_root().get_node('PauseMenu').resume()
	if is_instance_valid(Util.floor_manager) and is_instance_valid(Util.player):
		Util.floor_manager.player_out_of_bounds(Util.get_player())

func get_control_style(style : bool) -> String:
	if style:
		return "Default"
	return "Classic"

## Controls

@onready var control_template := %ControlTemplate
@onready var control_settings: VBoxContainer = %ControlSettings

signal s_input_pressed(input: InputEvent)

func _sync_controls() -> void:
	for action in SaveFileService.settings_file.controls.keys():
		add_setting(get_action_title(action), action)

func add_setting(action_title : String, action_name : String) -> void:
	var new_setting := control_template.duplicate()
	control_settings.add_child(new_setting)
	update_control_setting(new_setting, action_title, action_name)
	new_setting.show()
	new_setting.get_node('GeneralButton').pressed.connect(await_input.bind(new_setting, action_title, action_name))

func update_control_setting(element: Control, action_title: String, action_name: String) -> void:
	element.set_name(action_name)
	element.get_node('Label').set_text(action_title + ":")
	element.get_node('GeneralButton').text = input_to_text(get_keybind(action_name))

func get_keybind(action_name : String) -> InputEvent:
	var inputs := InputMap.action_get_events(action_name)
	if inputs.is_empty():
		return null
	for input in inputs:
		if input is InputEventKey:
			return input
	return inputs[0]

func input_to_text(input : InputEvent) -> String:
	if not input: 
		return "<UNBOUND>"
	var base_string := input.as_text()
	if base_string.ends_with(" (Physical)"):
		base_string = base_string.trim_suffix(" (Physical)")
	return base_string

func set_keybind(action_name: String, input: InputEvent) -> void:
	for action in InputMap.action_get_events(action_name):
		if action is InputEventKey:
			InputMap.action_erase_event(action_name, action)
	InputMap.action_add_event(action_name, input)
	SaveFileService.settings_file.controls[action_name] = input
	SaveFileService.settings_file.saved_controls[action_name] = input

func get_action_title(action_name: String) -> String:
	if action_name.begins_with("move_"):
		action_name = action_name.trim_prefix("move_")
	action_name[0] = action_name[0].to_upper()
	return action_name

func action_get_key(action_name: String) -> String:
	return SaveFileService.settings_file.controls.find_key(action_name)

func await_input(element: Control, action_title: String, action_name: String) -> void:
	s_input_pressed.emit(null)
	
	# Set button text
	element.get_node('GeneralButton').text = "<PRESS A KEY>"
	
	var input: InputEvent
	
	while not input:
		input = await s_input_pressed
		if not input is InputEventKey and not input is InputEventMouseButton:
			input = null
	
	if input is InputEventKey:
		set_keybind(action_name, input)
	
	update_control_setting(element, action_title, action_name)
	element.get_node('GeneralButton').release_focus()

func _input(event) -> void:
	s_input_pressed.emit(event)

## For save file editing

func update_setting(setting: String, value: Variant) -> void:
	SaveFileService.settings_file.set(setting, value)

func get_setting(setting: String) -> Variant:
	return SaveFileService.settings_file.get(setting)

func toggle_setting(setting: String) -> void:
	if SaveFileService.settings_file.get(setting) is bool:
		SaveFileService.settings_file.set(setting, not SaveFileService.settings_file.get(setting))

func get_toggle_text(toggled: bool) -> String:
	if toggled: return ENABLED_TEXT
	else: return DISABLED_TEXT

func close(save := false) -> void:
	if prev_file and not save:
		SaveFileService.settings_file = prev_file
		prev_file.sync_settings()
	else:
		SaveFileService.save_settings()
	super()
