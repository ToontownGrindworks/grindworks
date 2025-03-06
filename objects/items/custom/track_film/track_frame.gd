extends MeshInstance3D

const BASE_ITEM := "res://objects/items/resources/passive/track_frame.tres"

var track : String

var resource : Item


func setup(item : Item):
	resource = item
	
	# Standard behavior
	if not resource.arbitrary_data.has('track'):
		randomize_track()
	else:
		track = resource.arbitrary_data['track']
	# Set name
	resource.item_name = track + " Track Frame"
	
	# Color the mesh
	var mesh_mat : StandardMaterial3D = mesh.surface_get_material(0).duplicate()
	mesh_mat.albedo_color = get_color()
	set_surface_override_material(0,mesh_mat)


func modify(ui : MeshInstance3D) -> void:
	ui.set_surface_override_material(0,ui.mesh.surface_get_material(0).duplicate())
	ui.get_surface_override_material(0).albedo_color = get_color()

# Weighted gag generation
func randomize_track() -> void:
	var hat := get_hat()
	
	if hat.is_empty():
		resource.reroll()
		return
	
	track = hat[RandomService.randi_channel('gag_frames') % hat.size()]
	
	# Store the track in the item resource
	resource.arbitrary_data['track'] = track

func get_color() -> Color:
	if get_track(track):
		return get_track(track).track_color
	else:
		return Color.NAVY_BLUE

func collect() -> void:
	Util.get_player().stats.gags_unlocked[track] += 1

func get_track(track_name : String) -> Track:
	var loadout := Util.get_player().stats.character.gag_loadout
	
	for gag_track in loadout.loadout:
		if gag_track.track_name == track_name:
			return gag_track
	return null

func get_hat() -> Array[String]:
	var loadout : GagLoadout = Util.get_player().character.gag_loadout
	
	# Put all missing gags in a hat
	var hat : Array[String] = []
	for gag_track in loadout.loadout:
		var unlocked : int = Util.get_player().stats.gags_unlocked[gag_track.track_name]
		var remaining := gag_track.gags.size() - unlocked
		for i in remaining:
			hat.append(gag_track.track_name)
	
	# Remove the gags from the floor that have already been spawned
	for item : Item in ItemService.items_in_play:
		if item.arbitrary_data.has('track'):
			hat.erase(item.arbitrary_data['track'])
	
	return hat
