extends Node

## Used for UI. Only applies to items with "remember_item" true
signal s_item_applied(item: Item)

var seen_items: Array[Item] = []
# Items currently available for collection in any way
var items_in_play: Array[Item] = []

## Certain items cannot be seen if the other has been seen on this run.
var linked_items: Array = [
	# Gag pack and goggles binding
	[
		load("res://objects/items/resources/accessories/backpacks/gag_pack.tres"),
		load("res://objects/items/resources/accessories/glasses/goggles.tres"),
	]
]

func _ready() -> void:
	# Clear out temp seen items upon every floor start
	Util.s_floor_ended.connect(on_floor_end)
	SaveFileService.s_reset.connect(reset)

func reset() -> void:
	seen_items.clear()
	items_in_play.clear()

func get_random_item(pool: ItemPool, override_rolls := false) -> Item:
	
	## Rolls to force progression items when they're needed:
	if not override_rolls:
		
		# Gag roll
		var gag_roll := RandomService.randf_channel("gag_rolls")
		print('gag rate is '+str(get_gag_rate())+' gag roll is '+str(gag_roll))
		if gag_roll < get_gag_rate():
			print('forcing gag spawn')
			return load('res://objects/items/resources/passive/track_frame.tres')
		# Laff roll
		var laff_roll := RandomService.randf_channel("laff_rolls")
		print('laff rate is %f, and laff roll is %f' % [get_laff_rate(), laff_roll])
		if laff_roll < get_laff_rate():
			print('forcing laff spawn')
			return load('res://objects/items/resources/passive/laff_boost.tres')
		var bean_roll := RandomService.randf_channel("bean_rolls")
		print('bean rate is %f and bean roll is %f' % [get_bean_rate(), bean_roll])
		if bean_roll < get_bean_rate():
			print('forcing bean spawn')
			return get_random_item(BEAN_POOL, true)
	
	# Trim out all seen items from pool
	var trimmed_pool: Array[Item] = []
	for item in pool.items:
		if not item in seen_items:
			trimmed_pool.append(item)
	
	# If no item can be given to the player, just give them treasure
	if trimmed_pool.size() == 0:
		return load('res://objects/items/resources/passive/ice_cream_treasure.tres')
	
	# Quality-scaled rarities
	var quality_trimmed_pool : Array[Item] = []
	var qualitoon_goal := 0
	while RandomService.randi_channel('item_quality_roll')%100 < 85 and qualitoon_goal < 5:
		qualitoon_goal+=1
	for item in trimmed_pool:
		var qualitoon := int(item.qualitoon_rarity)
		if qualitoon == Item.QualitoonRating.NIL:
			qualitoon = int(item.qualitoon)
		if qualitoon <= qualitoon_goal:
			quality_trimmed_pool.append(item)
	
	if quality_trimmed_pool.is_empty():
		return load('res://objects/items/resources/passive/ice_cream_treasure.tres')
	else:
		return quality_trimmed_pool[RandomService.randi_channel(pool.resource_name)%quality_trimmed_pool.size()]

func seen_item(item: Item):
	if not item in seen_items:
		seen_items.append(item)
		var _linked_items: Array[Item] = get_linked_items(item)
		if _linked_items:
			for _li: Item in _linked_items:
				if not _li in seen_items:
					print("Adding linked seen item: %s" % _li.item_name)
					seen_items.append(item)

# For reactions/descriptions
var items_in_proximity: Array[WorldItem]

func item_in_proximity(item: WorldItem):
	if items_in_proximity.find(item) == -1:
		items_in_proximity.append(item)

func item_left_proximity(item: WorldItem):
	var place := items_in_proximity.find(item)
	if place != -1:
		items_in_proximity.remove_at(place)

func apply_inventory() -> void:
	var player := Util.get_player()
	var items: Array[Item] = player.stats.items
	var hat: ItemAccessory
	var glasses: ItemAccessory
	var backpack: ItemAccessory
	
	# Iterate through items to find accessories
	# As well as any special items
	# Setting values like this ensures only the newest items are applied
	for item in items:
		match item.slot:
			Item.ItemSlot.HAT:
				hat = item
			Item.ItemSlot.GLASSES:
				glasses = item
			Item.ItemSlot.BACKPACK:
				backpack = item
		for value in item.player_values.keys():
			player.set(value, item.player_values[value])
	
		# If a script item is found, run the load method
		if item.item_script:
			var item_node := ItemScript.add_item_script(Util.get_player(), item.item_script)
			if item_node is ItemScript:
				item_node.on_load(item)
	
	# Place accessory items on player
	var accessories: Array[ItemAccessory] = [hat, glasses, backpack]
	for accessory in accessories:
		if not accessory:
			continue
		var bone : BoneAttachment3D
		match accessory.slot:
			Item.ItemSlot.HAT:
				bone = player.toon.hat_bone
			Item.ItemSlot.GLASSES:
				bone = player.toon.glasses_bone
			Item.ItemSlot.BACKPACK:
				bone = player.toon.backpack_bone
		if not bone:
			continue
		var model: Node3D = accessory.model.instantiate()
		bone.add_child(model)
		var accessory_placement : AccessoryPlacement = ItemAccessory.get_placement(accessory,Util.get_player().character.dna)
		if not accessory_placement:
			model.queue_free()
			push_warning(accessory.item_name + " has no placement specified for this Toon's DNA!")
			continue
		model.position = accessory_placement.position
		model.rotation_degrees = accessory_placement.rotation
		model.scale = accessory_placement.scale

const GagGoals: Dictionary = {
	1: 0.2,
	2: 0.35,
	3: 0.5,
	4: 0.7,
	5: 0.9,
	6: 1.0,
}

func get_gag_rate() -> float:
	if not Util.get_player():
		return 0
	
	var floor_num := Util.floor_number + 1
	
	var stats := Util.get_player().stats
	var total_gags := 0
	var collected_gags := 0
	
	# Find the base amount of gags the player has
	for key in stats.gags_unlocked.keys():
		for track: Track in stats.character.gag_loadout.loadout:
			if track.track_name == key:
				total_gags += track.gags.size()
		collected_gags += stats.gags_unlocked[key]
	
	# Now, find the track frames currently in play and add those to the total
	for item: Item in items_in_play:
		if item.arbitrary_data.has('track'):
			collected_gags += 1
	
	# Don't allow track frames to spawn when all gags have been acquired
	if collected_gags >= total_gags:
		return 0.0
	
	var gag_percent: float = float(collected_gags) / float(total_gags)
	# We aim for the player to have collected all of their gags by the end of Floor 5. (Considered floor 6 by this code)
	# Floor 0: 20% of all gags collected
	# Floor 1: 35% of all gags collected
	# Floor 2: 50% of all gags collected
	# Floor 3: 70% of all gags collected
	# Floor 4: 90% of all gags collected
	# Floor 5: 100% of all gags collected
	var goal_percent := minf(GagGoals[floor_num], 1.0)
	
	var chance := (1.0 - (gag_percent / goal_percent)) * 1.35
	
	return chance

const STARTING_LAFF := 30
const FLOOR_LAFF_INCREMENT := 14
const LIKELIHOOD_PER_POINT := 0.1
func get_laff_rate() -> float:
	if not is_instance_valid(Util.get_player()):
		return 0.0
	
	# Get the current laff total
	# Take player's max hp + all the other laff boost items in play
	var laff_total := Util.get_player().stats.max_hp
	for laff_boost : Item in get_items_in_play("Laff Boost"):
		if laff_boost.stats_add.has('max_hp'):
			laff_total += laff_boost.stats_add['max_hp']
	
	# Get the laff goal
	var laff_goal := STARTING_LAFF + (FLOOR_LAFF_INCREMENT * Util.floor_number + 1)
	
	var goal_diff : = laff_goal - laff_total
	
	var laff_rate := clampf(goal_diff * LIKELIHOOD_PER_POINT, 0.0, 0.5)
	
	return laff_rate

const BEAN_GOAL := 30
const LIKELIHOOD_PER_BEAN := 0.05
const BEAN_POOL := preload('res://objects/items/pools/jellybeans.tres')
func get_bean_rate() -> float:
	if not is_instance_valid(Util.get_player()):
		return 0.0
	
	var bean_total := Util.get_player().stats.money
	
	for item: Item in items_in_play:
		if item.item_name.to_lower().contains('jellybean'):
			bean_total += item.stats_add['money']
	
	var goal_diff := BEAN_GOAL - bean_total
	
	var bean_rate := clampf(goal_diff * LIKELIHOOD_PER_BEAN, 0.0, 0.25)
	
	return bean_rate

func on_floor_end() -> void:
	return

func item_created(item: Item) -> void:
	items_in_play.append(item)

func item_removed(item: Item) -> void:
	items_in_play.erase(item)

func get_items_in_play(item_name: String) -> Array[Item]:
	var return_array: Array[Item] = []
	for item: Item in items_in_play:
		if item.item_name == item_name:
			return_array.append(item)
	return return_array

func get_linked_items(item: Item) -> Array[Item]:
	var final_linked_items: Array[Item] = []
	for _ll: Array in linked_items:
		if item in _ll:
			final_linked_items.assign(_ll.filter(func(x: Item): return x != item))
			return final_linked_items

	return final_linked_items
