extends Node3D
class_name TreasureChest

var WORLD_ITEM := LazyLoader.defer("res://objects/items/world_item/world_item.tscn")
var SFX_OPEN := LazyLoader.defer("res://audio/sfx/misc/diving_treasure_pick_up.ogg")

@export var override_replacement_rolls := false
@export var override_item: Item
@export var unopenable := false

@export var item_pool: ItemPool
@export var scripted_progression := false

@onready var EXTRA_TURN := load(ExtraTurnItem.BASE_ITEM)
@onready var POINT_BOOST := load(PointBoostItem.BASE_ITEM)
@onready var LAFF_BOOST := load("res://objects/items/resources/passive/laff_boost.tres")
@onready var SCRIPTED_PROGRESSION_ITEMS: Dictionary = {
	0: null,
	1: EXTRA_TURN,
	2: POINT_BOOST,
	3: null,
	4: EXTRA_TURN,
	5: LAFF_BOOST,
}

var opened := false

signal s_opened

func body_entered(body: Node3D) -> void:
	if unopenable:
		return
	if not body is Player or opened:
		return
	elif body is Player and body.state == Player.PlayerState.STOPPED:
		return
	open()
	opened = true

func open():
	AudioManager.play_sound(SFX_OPEN.load())
	s_opened.emit()
	$AnimationPlayer.play('open')
	var item: WorldItem = WORLD_ITEM.load().instantiate()
	item.override_replacement_rolls = override_replacement_rolls
	assign_item(item)
	$Item.add_child(item)

func assign_item(world_item: WorldItem):
	if scripted_progression and SCRIPTED_PROGRESSION_ITEMS[Util.floor_number] != null:
		var scripted_item: Item = SCRIPTED_PROGRESSION_ITEMS[Util.floor_number]
		# 5th floor has a +8 laff boost
		if scripted_item == LAFF_BOOST:
			# No laff for forced 1 laffers
			if Util.player.stats.melancholic:
				return
			scripted_item = scripted_item.duplicate()
			scripted_item.stats_add['max_hp'] = 8
			scripted_item.stats_add['hp'] = 8
		world_item.item = scripted_item
		return
	if override_item:
		world_item.item = override_item
		return
	world_item.pool = item_pool

func _ready() -> void:
	if is_instance_valid(Util.floor_manager):
		Util.floor_manager.s_chest_spawned.emit(self)

func vanish() -> void:
	var dust_cloud = Globals.DUST_CLOUD.load().instantiate()
	get_tree().get_root().add_child(dust_cloud)
	dust_cloud.global_position = global_position
	queue_free()
