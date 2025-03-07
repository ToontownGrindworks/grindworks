extends Resource
class_name Quest

const FALLBACK_ITEM_POOL := preload("res://objects/items/pools/toontasks.tres")

@export var icon : Texture2D
@export var title := ""
@export var quota := 1
@export var location_text := "Anywhere"
@export var quota_text := " completed"
@export var current_amount := 0
@export var quest_txt := ""
@export var goal_dept : CogDNA.CogDept
@export var item_reward : Item
@export var item_pool : ItemPool

signal s_quest_updated
signal s_quest_complete
signal s_quest_finished


## Override this to prepare values for quest scroll
## Though you can run super() to get your item set up
func setup() -> void:
	item_reward = roll_for_item()
	set_up_item()

func roll_for_item() -> Item:
	if not item_pool:
		item_pool = FALLBACK_ITEM_POOL
	var item := ItemService.get_random_item(item_pool)
	item.guarantee_collection = true
	if not item.evergreen:
		ItemService.seen_item(item)
	else:
		item = item.duplicate()
	return item

func reset() -> void:
	current_amount = 0
	quota = 0
	quota_text = " completed"
	location_text = "Anywhere"
	quest_txt = ""
	title = ""
	item_reward = null

func get_icon() -> Texture2D:
	await Util.s_process_frame
	return icon

func uses_3d_model() -> bool:
	return false

func get_3d_model() -> Node3D:
	return Node3D.new()

func set_up_item() -> void:
	# Many items need access to the player on setup
	# So ensure the player exists
	if not Util.get_player():
		await Util.s_player_assigned
	# Mark Item as in play
	ItemService.item_created(item_reward)
	# Handle item rerolls
	item_reward.s_reroll.connect(item_rerolled)
	
	# Allow the item to do its setup
	var model : Node3D = item_reward.model.instantiate()
	model.hide()
	Util.add_child(model)
	if model.has_method('setup'):
		model.setup(item_reward)
	model.queue_free()

func item_rerolled() -> void:
	ItemService.item_removed(item_reward)
	item_reward = roll_for_item()
	set_up_item()

func is_complete() -> bool:
	return current_amount >= quota
