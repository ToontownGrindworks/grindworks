extends Control
class_name QuestScroll

## For reroll icons
const DICE_BUTTON_PATH := "res://ui_assets/quests/dice_buttons/"
const DICE_BUTTON_PREFIX := "dice_button"
const DICE_DOWN_SUFFIX := "_down"
const DICE_ROLLOVER_SUFFIX := "_ro"
const DICE_BUTTON_TYPE := ".png"

@onready var icon: TextureRect = %QuestIcon
@onready var icon_viewer: TextureRect = %QuestIconViewer
@onready var title: Label = %TitleLabel
@onready var quest_label: Label = %QuotaLabel
@onready var location: Label = %LocationLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var progress_label: Label = %ProgressLabel
@onready var goal_icon: TextureRect = %GoalIcon
@onready var collect_button: GeneralButton = %CollectButton
@onready var reroll_button := %RerollButton

signal s_quest_rerolled


@export var quest : Quest:
	set(x):
		if quest:
			quest.s_quest_updated.disconnect(update_quest)
		quest = x
		#quest.s_quest_updated.connect(update_quest)
		update_quest()

func update_quest() -> void:
	title.set_text(quest.title)
	if quest.quota == 1:
		progress_bar.hide()
	progress_bar.max_value = quest.quota
	progress_bar.value = quest.current_amount
	progress_label.set_text(str(quest.current_amount) + " " + "of " + str(quest.quota) + " " + quest.quota_text)
	quest_label.set_text(quest.quest_txt)
	
	# Unused for now
	# Perhaps one day...
	#goal_icon.texture = Cog.get_department_emblem(quest.goal_dept)
	
	if quest.item_reward:
		set_item(quest.item_reward)
	
	if quest.current_amount >= quest.quota:
		$QuestBG.self_modulate = Color("cfffca")
		progress_bar.hide()
		title.set_text("COMPLETE")
		collect_button.show()

	icon.texture = null
	icon_viewer.node = null

	if quest.uses_3d_model():
		icon_viewer.node = quest.get_3d_model()
	else:
		icon.texture = await quest.get_icon()

func set_item(item: Item) -> void:
	var item_model = item.model.instantiate()
	%NodeViewer.camera_position_offset = item.ui_cam_offset
	%NodeViewer.node = item_model
	%NodeViewer.want_spin_tween = item.want_ui_spin
	if item_model.has_method('setup'):
		item_model.setup(item)

## Complete the quest and reset
func complete_quest() -> void:
	quest.item_reward.apply_item(Util.get_player())
	reset_quest()

func reroll_quest() -> void:
	reset_quest()
	s_quest_rerolled.emit()

func set_rerolls(count : int) -> void:
	if count == 0:
		reroll_button.set_disabled(true)
		reroll_button.self_modulate = Color.DARK_GRAY
		return
	# Failsafe as no 5+ textures exist
	if count > 4: count = 4
	
	# Set the textures
	var base_path := DICE_BUTTON_PATH + DICE_BUTTON_PREFIX + str(count)
	reroll_button.texture_normal = load(base_path + DICE_BUTTON_TYPE)
	reroll_button.texture_hover = load(base_path + DICE_ROLLOVER_SUFFIX + DICE_BUTTON_TYPE)
	reroll_button.texture_pressed = load(base_path + DICE_DOWN_SUFFIX + DICE_BUTTON_TYPE)
	reroll_button.self_modulate = Color.WHITE

func reset_quest() -> void:
	%NodeViewer.node = null
	collect_button.hide()
	ItemService.item_removed(quest.item_reward)
	quest.s_quest_finished.emit()
	quest.setup()
	update_quest()
	$QuestBG.self_modulate = Color.WHITE
