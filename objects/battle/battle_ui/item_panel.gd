extends TextureRect

const TOON_UP = preload("res://objects/battle/battle_resources/gag_loadouts/gag_tracks/toon_up.tres")

const SFX_TRAP := preload("res://audio/sfx/battle/gags/trap/TL_banana.ogg")
const SFX_SQUIRT := preload("res://audio/sfx/battle/gags/squirt/AA_squirt_flowersquirt.ogg")
const SFX_LURE := preload("res://audio/sfx/battle/gags/lure/TL_fishing_pole.ogg")
const SFX_SOUND := preload("res://audio/sfx/battle/gags/sound/AA_sound_bikehorn.ogg")
const SFX_THROW := preload("res://audio/sfx/battle/gags/throw/AA_pie_throw_only.ogg")
const SFX_DROP := preload("res://audio/sfx/battle/gags/drop/AA_drop_anvil.ogg")

const SfxData := {
	"Trap": [SFX_TRAP, 0.75],
	"Squirt": [SFX_SQUIRT, 0.67],
	"Lure": [SFX_LURE, 1.24],
	"Sound": [SFX_SOUND, 0.0],
	"Throw": [SFX_THROW, 0.0],
	"Drop": [SFX_DROP, 0.0],
}

@export var hide_close_button := false

signal s_voucher_used


func _ready() -> void:
	_ready_vouchers()
	_ready_toonup()
	_ready_treasures()
	if NodeGlobals.get_ancestor_of_type(self, BattleUI):
		%VoucherPreventer.hide()
		%ToonupPreventer.hide()
	if hide_close_button:
		%CloseButton.hide()

#region GAG VOUCHERS
@export_category('Gag Vouchers')
@export var point_label_settings: LabelSettings

@onready var voucher_template: Control = %VoucherTemplate
@onready var voucher_container: HBoxContainer = %VoucherContainer

func _ready_vouchers() -> void:
	_refresh_vouchers()

func _populate_vouchers() -> void:
	var vouchers := get_voucher_counts()
	
	for entry in vouchers.keys():
		var gag_track := get_track(entry)
		var new_button := create_new_voucher(gag_track, vouchers[entry])
		voucher_container.add_child(new_button)

func get_voucher_counts() -> Dictionary:
	var player := Util.get_player()
	if not is_instance_valid(player):
		return {}
	return player.stats.gag_vouchers

func create_new_voucher(track: Track, count: int) -> Control:
	var button_copy := voucher_template.duplicate()
	button_copy.show()
	button_copy.get_node('GagSprite').texture_normal = track.gags[0].icon
	button_copy.get_node('TrackName').set_text(track.track_name)
	button_copy.get_node('Quantity').set_text("x%d" % count)
	button_copy.get_node('GagSprite').set_disabled(count == 0)
	if is_instance_valid(BattleService.ongoing_battle):
		button_copy.get_node('GagSprite').pressed.connect(use_voucher.bind(track))
		button_copy.get_node('GagSprite').mouse_entered.connect(HoverManager.hover.bind("+5 %s points" % track.track_name))
		button_copy.get_node('GagSprite').mouse_exited.connect(HoverManager.stop_hover)
	else:
		button_copy.get_node('GagSprite').pressed.connect(play_fail_sfx)
		button_copy.modulate = Color.GRAY
	if button_copy.get_node('GagSprite').disabled: button_copy.modulate = Color.GRAY
	return button_copy

func _clear_vouchers() -> void:
	for child in voucher_container.get_children():
		child.queue_free()

func _refresh_vouchers() -> void:
	_clear_vouchers()
	_populate_vouchers()

func use_voucher(track: Track) -> void:
	Util.get_player().stats.gag_vouchers[track.track_name] -= 1
	Util.get_player().stats.gag_balance[track.track_name] += 5
	_refresh_vouchers()
	for child in get_parent().gag_tracks.get_children():
		child.refresh()
	s_voucher_used.emit()
	var sfx_data: Array = SfxData[track.track_name]
	AudioManager.play_snippet(sfx_data[0], sfx_data[1])

#endregion
#region Toon-Up

@onready var toonup_container: HBoxContainer = %ToonUpContainer
@onready var toonup_template: Control = %ToonUpTemplate

func _ready_toonup() -> void:
	_refresh_toonup()
	if is_instance_valid(BattleService.ongoing_battle):
		get_parent().s_update_toonups.connect(_refresh_toonup)

func _populate_toonup() -> void:
	var toonups := get_toonup_counts()
	
	for entry in toonups.keys():
		var new_button := create_new_toonup(entry, toonups[entry])
		toonup_container.add_child(new_button)

func get_toonup_counts() -> Dictionary:
	var player := Util.get_player()
	if not is_instance_valid(player):
		return {}
	return player.stats.toonups

func create_new_toonup(level: int, count: int) -> Control:
	var button_copy := toonup_template.duplicate()
	button_copy.show()
	button_copy.get_node('GagSprite').texture_normal = TOON_UP.gags[level].icon
	var action_name: String
	if level == 1:
		# Megaphone is stupid and should be split
		action_name = "Mega-\nPhone"
	else:
		action_name = TOON_UP.gags[level].action_name.replace(" ", "\n")
	button_copy.get_node('GagName').set_text(action_name)
	button_copy.get_node('Quantity').set_text("x%d" % count)
	button_copy.get_node('GagSprite').set_disabled(count == 0)
	if is_instance_valid(BattleService.ongoing_battle):
		button_copy.get_node('GagSprite').pressed.connect(use_toonup.bind(level))
		button_copy.get_node('GagSprite').mouse_entered.connect(hover_toonup.bind(level))
		button_copy.get_node('GagSprite').mouse_exited.connect(HoverManager.stop_hover)
	else:
		button_copy.get_node('GagSprite').pressed.connect(play_fail_sfx)
		button_copy.modulate = Color.GRAY
	if button_copy.get_node('GagSprite').disabled: button_copy.modulate = Color.GRAY
	return button_copy

func hover_toonup(level: int) -> void:
	HoverManager.hover(get_toonup_description(level))

func get_toonup_description(level: int) -> String:
	match level:
		4:
			return "%s%% laff regeneration" % roundi(20.0 * Util.get_player().stats.healing_effectiveness)
		_:
			return TOON_UP.gags[level].custom_description

func _clear_toonup() -> void:
	for child in toonup_container.get_children():
		child.queue_free()

func _refresh_toonup() -> void:
	_clear_toonup()
	_populate_toonup()

func use_toonup(level: int) -> void:
	if Util.get_player().stats.toonups[level] > 0:
		Util.get_player().stats.toonups[level] -= 1
		TOON_UP.gags[level].apply(Util.get_player())
		_refresh_toonup()

#endregion


#region TREASURES
@onready var treasure_template := %TreasureTemplate
@onready var treasure_pool : ItemPool = GameLoader.load("res://objects/items/pools/treasures.tres")
@onready var treasure_container := %TreasureContainer

func _ready_treasures() -> void:
	_refresh_treasures()

func _populate_treasures() -> void:
	var treasures := get_treasure_counts()
	
	for entry in treasures.keys():
		var new_button := create_new_treasure(entry, treasures[entry])
		treasure_container.add_child(new_button)

func get_treasure_counts() -> Dictionary:
	var player := Util.get_player()
	if not is_instance_valid(player):
		return {}
	return player.stats.treasures

func _refresh_treasures() -> void:
	_clear_treasures()
	_populate_treasures()

func use_treasure(level: int) -> void:
	var treasure : Item = get_treasure(level)
	if Util.get_player().stats.treasures[level] > 0:
		Util.get_player().stats.treasures[level] -= 1
		Util.get_player().quick_heal(get_treasure_heal(treasure))
		treasure.play_collection_sound()
		_refresh_treasures()

func _clear_treasures() -> void:
	for child in treasure_container.get_children():
		child.queue_free()

func hover_treasure(level: int) -> void:
	HoverManager.hover(get_treasure_description(level))

func create_new_treasure(level: int, count: int) -> Control:
	var treasure := get_treasure(level)
	var button_copy := treasure_template.duplicate()
	button_copy.show()
	button_copy.get_node('GagSprite').texture_normal = get_treasure_icon(treasure)
	var action_name: String
	action_name = treasure.item_name.replace(" Treasure","")
	action_name = action_name.replace(" ", "\n")
	button_copy.get_node('GagName').set_text(action_name)
	button_copy.get_node('Quantity').set_text("x%d" % count)
	button_copy.get_node('GagSprite').set_disabled(count == 0)
	button_copy.get_node('GagSprite').pressed.connect(use_treasure.bind(level))
	button_copy.get_node('GagSprite').mouse_entered.connect(hover_treasure.bind(level))
	button_copy.get_node('GagSprite').mouse_exited.connect(HoverManager.stop_hover)
	if button_copy.get_node('GagSprite').disabled: button_copy.modulate = Color.GRAY
	return button_copy

func get_treasure(idx: int) -> Item:
	return treasure_pool.items[idx]

func get_treasure_icon(item : Item) -> Texture2D:
	return item.arbitrary_data['texture']

func get_treasure_heal(item : Item) -> int:
	var stats := Util.get_player().stats
	var heal_perc = float(item.arbitrary_data['heal_perc']) / 100.0
	return ceili(stats.max_hp * heal_perc)

func get_treasure_perc(item : Item) -> int:
	return item.arbitrary_data['heal_perc']

func get_treasure_description(level: int) -> String:
	return "Heals: %d%% Laff (+%d)" % [get_treasure_perc(get_treasure(level)), get_treasure_heal(get_treasure(level))]

#endregion

func get_track(track_name: String) -> Track:
	for track in Util.get_player().stats.character.gag_loadout.loadout:
		if track.track_name == track_name:
			return track
	return null

func _exit() -> void:
	hide()
	get_parent().main_container.show()

func play_fail_sfx() -> void:
	AudioManager.play_sound(GameLoader.load("res://audio/sfx/ui/ring_miss.ogg"))
	# Focus testing said this was stupid :(
	#var audio_player := AudioManager.play_sound(GameLoader.load("res://audio/sfx/ui/ring_miss.ogg"))
	#audio_player.set_pitch_scale(RandomService.randf_range_channel('true_random', 0.7, 1.8))
