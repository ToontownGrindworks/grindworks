extends Area3D
class_name WorldItem

@export var item: Item
@export var pool: ItemPool
@export var override_replacement_rolls := false

# Locals
var model: Node3D
var rotation_tween: Tween
var bob_tween: Tween

# Signals
signal s_collected
signal s_item_assigned


func _ready() -> void:
	if not item:
		roll_for_item()
	spawn_item()
	
	# World items can be either collected or left on the floor
	# Make sure the item get removed in either instance
	s_collected.connect(_remove_item)
	Util.s_floor_ended.connect(_remove_item)
	
	# Await 1 second before monitoring
	await $MonitorTimer.timeout
	monitoring = true

func roll_for_item() -> void:
	item = ItemService.get_random_item(pool, override_replacement_rolls)
	
	# Transcendent Master: Reroll if accessory
	#if !Util.get_player().stats.allow_item_chests:
		#if item in load("res://objects/items/pools/accessories.tres").items:
			#reroll()
	
	if not item:
		printerr("Item pool returned null. Freeing world item instance.")
		queue_free()
		return

	s_item_assigned.emit()

func spawn_item() -> void:
	# Spawn in the model
	model = item.model.instantiate()
	add_child(model)
	
	# Check if the item is evergreen
	if not item.evergreen:
		ItemService.seen_item(item)
	else:
		item = item.duplicate()
	
	# Listen for the item's reroll signal
	item.s_reroll.connect(reroll)
	
	# Scale the item as it's specified
	model.scale *= item.world_scale
	
	# Mark the item as in play
	ItemService.item_created(item)
	
	# Do the fancy little tween
	_tween_model()
	
	# Allow items with custom setups to run those
	if model.has_method('setup'):
		model.setup(item)

func reroll() -> void:
	if model:
		model.queue_free()
	ItemService.item_removed(item)
	item = null
	if bob_tween:
		bob_tween.kill()
		rotation_tween.kill()
	roll_for_item()
	spawn_item()

func _tween_model() -> void:
	rotation_tween = create_tween()
	rotation_tween.tween_property(self, 'rotation:y', deg_to_rad(360), 3.0)
	rotation_tween.tween_property(self, 'rotation:y', 0, 0.0)
	rotation_tween.set_loops()
	
	bob_tween = create_tween()
	bob_tween.set_trans(Tween.TRANS_SINE)
	bob_tween.tween_property(model, 'position:y', 0.1, 1.5)
	bob_tween.tween_property(model, 'position:y', -0.1, 1.5)
	bob_tween.set_loops()

func body_entered(body) -> void:
	if not body is Player:
		return
	
	s_collected.emit()
	
	# Turn of monitoring
	set_deferred('monitoring', false)
	$ReactionArea.set_deferred('monitoring', false)
	body_not_reacting(body)
	
	# Apply the item
	apply_item()
	
	# Show UI
	var ui = load('res://objects/items/ui/item_get_ui/item_get_ui.tscn').instantiate()
	ui.item = item
	get_tree().get_root().add_child(ui)
	
	# Play the item collection sound
	item.play_collection_sound()
	
	if model.has_method('modify'):
		model.modify(ui.model)
	
	if model.has_method('custom_collect'):
		await model.custom_collect()
	else:
		## Default collection animations
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		# Passive Collection
		if not item is ItemAccessory:
			tween.tween_property(model, 'scale', Vector3(0, 0, 0), 1.0)
		# Accessory collection
		else:
			var accessory_placement: AccessoryPlacement = ItemAccessory.get_placement(item, Util.get_player().character.dna)
			## Failsafe for if no item placement 
			if not accessory_placement:
				push_warning(item.item_name + " has no AccessoryPlacement specified for this Toon's DNA!")
				tween.kill()
				model.queue_free()
				queue_free()
				return
			
			bob_tween.kill()
			rotation_tween.kill()
			tween.set_parallel(true)
			tween.tween_property(model, 'position', accessory_placement.position, 1.0)
			tween.tween_property(model, 'scale', accessory_placement.scale, 1.0)
			tween.tween_property(model, 'rotation_degrees', accessory_placement.rotation, 1.0)
			tween.tween_callback(func():
				model.position = accessory_placement.position
				model.scale = accessory_placement.scale
				model.rotation_degrees = accessory_placement.rotation)
		await tween.finished
		tween.kill()
	queue_free()

func apply_item() -> void:
	if not Util.get_player():
		return
	
	var stats = Util.get_player().stats
	
	for stat in item.stats_add:
		if str(stat) in stats:
			if stat == 'money':
				print("Calling special money func")
				stats.add_money(item.stats_add[stat])
			else:
				stats[stat] += item.stats_add[stat]
	
	for stat in item.stats_multiply:
		if str(stat) in stats:
			stats[stat] *= item.stats_multiply[stat]
		elif stat.begins_with("gag_boost:"):
			var track: String = stat.get_slice(":", 1)
			if track in stats.gag_effectiveness:
				stats.gag_effectiveness[track] *= item.stats_multiply[stat]
	
	# Set player values
	for value in item.player_values:
		Util.get_player().set(value, item.player_values[value])
	
	# Run the item script if there is one
	if item.item_script:
		var item_node := ItemScript.add_item_script(Util.get_player(),item.item_script)
		if item_node is ItemScript:
			item_node.on_collect(item,model)
	
	# Reparent accessories to the player
	# They will get tweened into position after this
	if item is ItemAccessory:
		var bone := ItemAccessory.get_bone(item,Util.get_player().toon)
		remove_current_item(bone)
		model.reparent(bone)
	
	if model.has_method('collect'):
		model.collect()
	
	# Add the item to the player's item array
	if item.remember_item:
		Util.get_player().stats.items.append(item)
		print('added %s to item list (world item)' % item.item_name)
		ItemService.s_item_applied.emit(item)

func remove_current_item(bone : BoneAttachment3D):
	# If no accessory is there already, 
	if bone.get_child_count() == 0:
		return
	bone.get_child(0).queue_free()

func body_reacted(body):
	if not body is Player:
		return
	ItemService.item_in_proximity(self)

func body_not_reacting(body):
	if not body is Player:
		return
	ItemService.item_left_proximity(self)

func _remove_item() -> void:
	ItemService.item_removed(item)
	Util.s_floor_ended.disconnect(_remove_item)
