extends Node3D
class_name GameFloor

const ROOM_REPEAT_DETECTION_SIZE := 3

## The Floor Variant to be loaded into.
@export var floor_variant: FloorVariant
## Override for the amount of rooms to generate on the floor.
## -1 will make the room count based on the FloorVariant's value.
@export var room_count: int = -1
## Cog Level Range for the floor.
@export var level_range := Vector2i(1,12)
## Cog Spawning Pool.
@export var cog_pool: CogPool

# Floor generation tracking
## The amount of rooms to have in the Scene Tree at a time.
@export var render_rooms: int = 5
@onready var room_node := $Rooms
var unloaded_rooms: Node3D
var room_order: Array[StoredRoom] = []
var room_index := 0
var floor_rooms: DepartmentFloor
var battle_ratio: float = 0.5
var rooms_remaining: Array[int] = []
var one_time_room_indexes: Array[int] = []
var previous_rooms : Array[FacilityRoom] = []

class StoredRoom:
	var room: Node3D
	var room_transform: Transform3D

# Signals
signal s_floor_ended

# Misc.
@onready var environment: WorldEnvironment = $WorldEnvironment

var anomalies: Array[FloorModifier] = []


func _ready() -> void:
	unloaded_rooms = Node3D.new()
	Util.floor_manager = self
	# Room count must be an odd number
	if room_count % 2 == 0:
		room_count += 1
	Util.floor_number += 1
	generate_floor()

func generate_floor() -> void:
	if not floor_variant:
		push_error("Failed to generate floor: No floor variant specified.")
		return
	
	# Get floor difficulty values from room variant
	# Setting value to anything else will let you debug custom sizes
	if room_count == -1:
		room_count = floor_variant.room_count
		level_range = floor_variant.level_range
		cog_pool = floor_variant.cog_pool
	
	# Queue reward:
	if floor_variant.reward:
		s_floor_ended.connect(func(): floor_variant.reward.apply_item(Util.get_player()))
	
	# Set up floor modifiers
	for modifier in floor_variant.modifiers:
		var new_mod := Node.new()
		new_mod.set_script(modifier)
		if new_mod is FloorModifier:
			$Modifiers.add_child(new_mod)
			new_mod.initialize(self)
			new_mod.set_name(new_mod.get_mod_name())
			if modifier in floor_variant.anomalies:
				anomalies.append(new_mod)
	
	if not anomalies.is_empty():
		$AnomalyTracker.anomalies = anomalies
		$AnomalyTracker.show()
		$AnomalyTracker.play()
	else:
		$AnomalyTracker.queue_free()

	if Util.floor_number == 0:
		$LocationText.set_text("Ground Floor\n%s" % floor_variant.floor_name)
	else:
		$LocationText.set_text("Floor %d\n%s" % [Util.floor_number, floor_variant.floor_name])
	
	# Some values may be copied over from the floor variant to the floor type
	floor_variant.floor_type = floor_variant.floor_type.duplicate()
	if not floor_variant.end_rooms.is_empty():
		floor_variant.floor_type.final_rooms = floor_variant.end_rooms
	
	# Get the floor room values
	floor_rooms = floor_variant.floor_type
	Util.floor_type = floor_rooms
	# Randomly decide 40% - 60% battle rooms 
	battle_ratio = 0.4 + (0.1 * float(RandomService.randi_channel('battle_ratio') % 3))
	var total_rooms = int((room_count - 2) / 2)
	var total_battles := int(total_rooms * battle_ratio)
	rooms_remaining = [total_battles, total_rooms - total_battles]

	if floor_rooms.special_rooms and RandomService.randf_channel('room_logic') > 0.8:
		# 50% chance to add a "special room" to the pool
		var sr_idx := RandomService.randi_range_channel('room_logic', 1, floor_rooms.special_rooms.size()) - 1
		print('Adding special room: %s' % floor_rooms.special_rooms[sr_idx].room.get_state().get_node_name(0))
		floor_rooms.one_time_rooms.append(floor_rooms.special_rooms[sr_idx].room)

	# Add 2 rooms to the floor per 1 time room
	# And get a room index to slap that room into
	for i in floor_rooms.one_time_rooms.size():
		room_count += 2
		var rand_room := -1
		while rand_room * 2 in one_time_room_indexes or rand_room == -1:
			rand_room = RandomService.randi_channel('room_logic') % (room_count - 1) / 2
			# Ensure 0 cannot be rolled
			rand_room = maxi(rand_room,1)
		one_time_room_indexes.append(rand_room * 2)
	
	# Generate random rooms
	for i in render_rooms:
		if i >= room_count:
			break
		add_random_room()
	
	var entrance = room_node.get_child(0)
	
	var player := Util.get_player()
	if not player:
		player = load("res://objects/player/player.tscn").instantiate()
		SceneLoader.add_persistent_node(player)
	player.s_fell_out_of_world.connect(player_out_of_bounds)
	
	player.global_position = entrance.get_node('SPAWNPOINT').global_position
	player.state = Player.PlayerState.WALK
	player.camera.make_current()
	player.recenter_camera(true)
	player.face_position(entrance.get_node('EXIT').global_position)
	if Util.floor_number == 0:
		player.fall_in(true)
	else:
		player.teleport_in(true)
	if Util.window_focused:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Set the proper default bg music
	if not floor_rooms.background_music.is_empty():
		AudioManager.set_default_music(floor_rooms.background_music[RandomService.randi_channel('true_random') % floor_rooms.background_music.size()])

func get_random_connector_room() -> PackedScene:
	return floor_rooms.connectors[RandomService.randi_channel('true_random') % floor_rooms.connectors.size()]

func add_random_room():
	var index := room_order.size()
	var new_room : PackedScene
	if index == 0:
		new_room = floor_rooms.entrances[RandomService.randi_channel('room_logic') % floor_rooms.entrances.size()]
	elif index in one_time_room_indexes:
		new_room = floor_rooms.one_time_rooms[one_time_room_indexes.find(index)]
	elif index < room_count - 1:
		if index % 2 == 0:
			# Roll a random room type based on the remaining rooms
			var room_roll := RandomService.randi_channel('remaining_rooms') % (rooms_remaining[0] + rooms_remaining[1])
			if room_roll < rooms_remaining[0]:
				new_room = roll_for_room(floor_rooms.battle_rooms, 'battle_rooms')
				rooms_remaining[0] -= 1
			else:
				new_room = roll_for_room(floor_rooms.obstacle_rooms, 'obstacle_rooms')
				rooms_remaining[1] -= 1
		else:
			new_room = get_random_connector_room()
	else:
		if floor_rooms.pre_final_rooms:
			var pre_final_room: PackedScene = roll_for_room(floor_rooms.pre_final_rooms, 'pre_final_rooms')
			append_room(pre_final_room)
			append_room(get_random_connector_room())
		new_room = roll_for_room(floor_rooms.final_rooms, 'boss_rooms')
	append_room(new_room)

func append_room(room: PackedScene):
	var new_module: Node3D = room.instantiate()
	room_node.add_child(new_module)
	new_module.name = str(room_order.size())
	# For all rooms except the entrance, do some tricky math to attach them 
	if not room_order.is_empty():
		var prev_room = room_order[room_order.size() - 1].room
		var prev_exit = prev_room.get_node('EXIT')
		var new_entrance = new_module.get_node('ENTRANCE')
		
		# Failsafe
		if not prev_room.is_inside_tree():
			prev_room.reparent(room_node)
		
		# Rotate the new room
		var rot = prev_room.global_rotation.y
		new_module.rotation.y = rot
		new_module.rotation.y += prev_exit.rotation.y + new_entrance.rotation.y
	
		# Get reference info
		var entrance_pos = new_entrance.position
		var entrance_global_pos = new_entrance.global_position
		
		# Place new entrance on previous exit
		new_entrance.global_position = prev_exit.global_position
		
		# Get difference between entrance's old and new positions
		var pos_diff = new_entrance.global_position - entrance_global_pos
		
		# Apply the difference to the new module
		new_module.global_position += pos_diff
		
		# Reset entrance node pos
		new_entrance.position = entrance_pos
	
	# Connect the body entered signal from the room to adjust the room renders
	new_module.get_node('RoomArea').body_entered.connect(body_entered_room.bind(room_order.size()))
	new_module.get_node('RoomArea').collision_mask = Globals.PLAYER_COLLISION_LAYER
	
	# Add a new stored room to the room_order array
	var storage := StoredRoom.new()
	storage.room = new_module
	storage.room_transform = new_module.transform
	room_order.append(storage)

func body_entered_room(body, index: int):
	if body is Player:
		room_index = index
		adjust_view(room_index)

func roll_for_room(rooms: Array[FacilityRoom], _seed_channel := 'true_random') -> PackedScene:
	rooms = rooms.duplicate()
	for room in previous_rooms:
		if room in rooms:
			rooms.erase(room)
	
	var rng := RandomNumberGenerator.new()
	var weights : Array[float] = []
	for room in rooms:
		weights.append(room.rarity_weight)
	
	var room_idx := rng.rand_weighted(weights)
	if previous_rooms.size() >= ROOM_REPEAT_DETECTION_SIZE:
		previous_rooms.pop_front()
	previous_rooms.append(rooms[room_idx])
	return rooms[room_idx].room

func adjust_view(index: int = 0):
	if room_order.is_empty():
		return
		
	var border := render_rooms / 2
	var lower_bound := maxi(index-border, 0)
	var upper_bound := maxi(index+border, render_rooms)
	
	for i in room_order.size():
		var room = room_order[i].room
		if i < lower_bound or i > upper_bound:
			if room.get_parent() == room_node:
				room.reparent(unloaded_rooms)
		else:
			if not room.is_inside_tree():
				room.reparent(room_node, false)
				room.transform = room_order[i].room_transform
		
	# Check if new rooms are needed
	var t := index
	while t < room_index+render_rooms / 2 and t < room_count - 1:
		if room_order.size() - 1 <= t:
			add_random_room()
		t += 1

func get_current_room() -> Node3D:
	return room_order[room_index].room

func _notification(what):
	# Free unloaded rooms when scene is being freed
	if what == NOTIFICATION_PREDELETE:
		unloaded_rooms.queue_free()

func player_out_of_bounds(player : Player) -> void:
	var entrance_node: Node3D
	if get_current_room().name == '0':
		entrance_node = get_current_room().get_node('SPAWNPOINT')
	else:
		entrance_node = get_current_room().get_node('ENTRANCE')
	player.global_position = entrance_node.global_position
	player.fall_in(true)


#region GAME TRACKING
## Game Signals
signal s_cog_spawned(cog: Cog)
signal s_chest_spawned(chest: TreasureChest)
#endregion
