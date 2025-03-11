extends Resource
class_name Item

enum QualitoonRating {
	Q1,
	Q2,
	Q3,
	Q4,
	Q5,
}

enum Rarity {
	NIL,
	Q1,
	Q2,
	Q3,
	Q4,
	Q5,
	Q6,
	Q7
}

const RarityToRolls: Dictionary[Rarity, int] = {
	Rarity.Q1: 0,
	Rarity.Q2: 1,
	Rarity.Q3: 2,
	Rarity.Q4: 3,
	Rarity.Q5: 4,
	Rarity.Q6: 5,
	Rarity.Q7: 6,
}

const QualityToRarity: Dictionary[QualitoonRating, Rarity] = {
	QualitoonRating.Q1: Rarity.Q1,
	QualitoonRating.Q2: Rarity.Q2,
	QualitoonRating.Q3: Rarity.Q3,
	QualitoonRating.Q4: Rarity.Q4,
	QualitoonRating.Q5: Rarity.Q5,
}

## The in-game displayed qualitoon of an item
@export var qualitoon: QualitoonRating
## Item rarity value. Q0 = Super duper common. Q7 = Super duper rare. Nil uses qualitoon as rarity.
@export var rarity: Rarity = Rarity.NIL
## Evergreen items can appear multiple times per-run.
@export var evergreen := false
## Realtime items exist and run processes in the game world.
## They have to be marked to properly spawn in the game world when a save is loaded.
@export var realtime := false

enum ItemSlot {
	PASSIVE,
	HAT,
	GLASSES,
	BACKPACK,
}
@export var slot := ItemSlot.PASSIVE
@export var world_scale := 1.0
@export var want_ui_spin := true
@export var ui_cam_offset := 0.0

@export var item_name: String
@export_multiline var item_description: String
@export_multiline var big_description: String
@export var model: PackedScene

## Plays a sound on world item pickup
@export var pickup_sfx: AudioStream

# Stat effects
@export var stats_add: Dictionary
@export var stats_multiply: Dictionary

## Key should be the string name of a value
## Entry should be the value to set the variable to
@export var player_values: Dictionary

## Arbitrary data holds any values you may want access to later
@export var arbitrary_data: Dictionary

## Optional Script to run with the player
@export var item_script: Script

## Whether the object should be saved to the run file
@export var remember_item := true

## The icon to display the item on the UI
@export var icon: Texture2D

## What to display as the shop title for boost items
## This is only really used for the doodle item
@export var shop_category_title := "Boost Item"

## What to display as the shop title COLOR
@export var shop_category_color := Color("3294ea")
@export var force_show_shop_category := false
## Overrides shop price. No override if set to 0.
@export var custom_shop_price: int = 0

## Should only be needed on initial setup
var guarantee_collection := false
## Disallows reroll signal to be emitted
var rerollable := true

var is_acessory: bool:
	get: return slot in [ItemSlot.HAT, ItemSlot.GLASSES, ItemSlot.BACKPACK]

## Reroll request
signal s_reroll

func reroll() -> void:
	if rerollable:
		print(item_name + ": Reroll signal sent")
		s_reroll.emit()
	else:
		print(item_name + ": Attempted to reroll, but was unable to")

## Applies item stats and script.
func apply_item(player: Player) -> void:
	if item_script:
		var item_node := ItemScript.add_item_script(player,item_script)
		if item_node is ItemScript:
			item_node.on_collect(self,null)
	
	var stats := player.stats
	
	for stat in stats_add:
		if str(stat) in stats:
			if stat == 'money':
				print("Calling special money func")
				stats.add_money(stats_add[stat])
			else:
				stats[stat] += stats_add[stat]
	
	for stat in stats_multiply:
		if str(stat) in stats:
			stats[stat] *= stats_multiply[stat]
		elif stat.begins_with("gag_boost:"):
			var track: String = stat.get_slice(":",1)
			if track in stats.gag_effectiveness:
				stats.gag_effectiveness[track] *= stats_multiply[stat]
	
	for value in player_values:
		player.set(value, player_values[value])
	
	# Check the model for custom item setups
	if model:
		rerollable = false
		var mod: Node3D = model.instantiate()
		Util.add_child(mod)
		if mod.has_method('setup'):
			mod.setup(self)
		if mod.has_method('collect'):
			mod.collect()
		mod.queue_free()
	
	if remember_item:
		player.stats.items.append(self)
		print('added %s to item list' % item_name)
		ItemService.s_item_applied.emit(self)

const SFX_FALLBACK := 'res://audio/sfx/misc/MG_pairing_all_matched.ogg'
func play_collection_sound() -> void:
	if pickup_sfx:
		AudioManager.play_sound(pickup_sfx)
	else:
		AudioManager.play_sound(load(SFX_FALLBACK))
