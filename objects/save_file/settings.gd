extends Resource
class_name SettingsFile


## VIDEO SETTINGS
const FPSOptions = [60, 90, 120, 144, 165, 240, 360, 0]
const SpeedOptions = [1.0, 1.25, 1.5, 1.75]

@export var fullscreen := false
@export var fps_idx := 0:
	set(x):
		fps_idx = x
		if fps_idx < 0:
			fps_idx = 0
		elif fps_idx >= FPSOptions.size():
			fps_idx = FPSOptions.size() - 1
@export var anti_aliasing := false

## AUDIO SETTINGS
@export var master_volume := 0.5
@export var music_volume := 1.0
@export var sfx_volume := 1.0
@export var ambient_sfx_enabled := true

## GAMEPLAY SETTINGS
@export var battle_speed_idx := 0:
	set(x):
		battle_speed_idx = x
		if battle_speed_idx < 0:
			battle_speed_idx = 0
		elif battle_speed_idx >= SpeedOptions.size():
			battle_speed_idx = SpeedOptions.size() - 1
@export var control_style := true
@export var camera_sensitivity := 1.0:
	set(x):
		camera_sensitivity = clampf(x, 0.5, 1.5)
@export var item_reactions := false
@export var auto_sprint := true
@export var show_timer := false
@export var skip_intro := false
@export var dev_tools := false

## CONTROLS
# To preserve the ordering of controls, we must have two dictionaries
# And the array for the order to display controls in
const REMAPPABLE_CONTROLS := [
	"move_forward",
	"move_back",
	"move_left",
	"move_right",
	"jump",
	"sprint",
	"pause"
]
@export var saved_controls := {}
var controls := {}

func save_to(file_name: String):
	ResourceSaver.save(self, SaveFileService.SAVE_FILE_PATH + file_name)

func sync_settings() -> void:
	# Video
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	Engine.max_fps = FPSOptions[fps_idx]
	if OS.has_feature('debug'):
		print('FPS Limit set to: %s' % FPSOptions[fps_idx])
	RenderingServer.viewport_set_msaa_3d(SaveFileService.get_viewport().get_viewport_rid(),
				RenderingServer.VIEWPORT_MSAA_4X if anti_aliasing else RenderingServer.VIEWPORT_MSAA_DISABLED)
	
	# Audio
	set_bus_volume('Master', linear_to_db(master_volume))
	set_bus_volume('Music', linear_to_db(music_volume))
	set_bus_volume('SFX', linear_to_db(sfx_volume))
	set_bus_volume('Ambient', linear_to_db(1.0 if ambient_sfx_enabled else 0.0))
	
	# Controls
	for action in REMAPPABLE_CONTROLS:
		if InputMap.has_action(action):
			if saved_controls.has(action):
				for event in InputMap.action_get_events(action):
					if event is InputEventKey:
						InputMap.action_erase_event(action, event)
				InputMap.action_add_event(action, saved_controls[action])
				controls[action] = saved_controls[action]
			else:
				controls[action] = InputMap.action_get_events(action)[0]
				saved_controls[action] = controls[action]

func get_bus_index(bus: String) -> int:
	for i in AudioServer.bus_count:
		if AudioServer.get_bus_name(i) == bus:
			return i
	return -1

func set_bus_volume(bus: String, volume_db: float) -> void:
	AudioServer.set_bus_volume_db(get_bus_index(bus), volume_db)
	if OS.has_feature('debug'):
		print(bus + " volume set to: " + str(AudioServer.get_bus_volume_db(get_bus_index(bus))))
