extends CanvasLayer
class_name BattleUI

# Child References
@onready var gag_tracks := %Tracks
@onready var attack_label := %AttackLabel
@onready var right_panel := %RightPanel
@onready var cog_panels := %CogPanels
@onready var main_container := %BattleMenuContainer
@onready var gag_order_menu := %SelectedGags

# Bottom-right buttons
@onready var fire_button := %Fire

@onready var status_container: HBoxContainer = %StatusContainer

# Signals
signal s_gag_pressed(gag: BattleAction)
signal s_gag_selected(gag: BattleAction)
signal s_turn_complete(gag_order: Array[ToonAttack])
signal s_gag_canceled(gag: BattleAction)
signal s_gags_updated(gags: Array[ToonAttack])
signal s_update_toonups

# Locals
var turn := 0:
	set(x):
		turn = x
		refresh_turns()
var remaining_turns: int:
	get:
		return Util.get_player().stats.turns - turn
var selected_gags: Array[ToonAttack] = []
var fire_action: ToonAttackFire

func _ready():
	refresh_turns()
	reset()
	
	# Create fire action
	fire_action = ToonAttackFire.new()
	fire_action.target_type = BattleAction.ActionTarget.ENEMY
	fire_action.icon = load("res://objects/items/custom/pink_slip/pink_slip_icon.png")
	fire_action.action_name = "FIRE"
	check_pink_slips()

	status_container.target = Util.get_player()

func gag_selected(gag: BattleAction) -> void:
	if remaining_turns <= 0:
		s_gag_canceled.emit(gag)
		complete_turn()
		return
	
	# Un-preview gag
	gag_hovered(null)

	# Parse gag data
	gag.user = Util.get_player()
	# Infer target
	match gag.target_type:
		BattleAction.ActionTarget.SELF:
			gag.targets = [Util.get_player()]
		BattleAction.ActionTarget.ENEMY, BattleAction.ActionTarget.ENEMY_SPLASH:
			# Skip choice UI if only one Cog
			if get_parent().cogs.size() == 1:
				gag.targets = get_parent().cogs.duplicate()
				if gag.target_type == BattleAction.ActionTarget.ENEMY_SPLASH:
					gag.main_target = gag.targets[0]
			else:
				# Swap UIs
				%TargetSelect.show()
				%TargetSelect.gag = gag
				%TargetSelect.reposition_buttons(get_parent().cogs.size())
				main_container.hide()
				var selection = await $TargetSelect.s_arrow_pressed
				if selection == -1:
					# Swap UIs back
					%TargetSelect.hide()
					main_container.show()
					s_gag_canceled.emit(gag)
					return
				else:
					# Set the target
					if gag.target_type == BattleAction.ActionTarget.ENEMY_SPLASH:
						gag.reassess_splash_targets(selection, get_parent())
					else:
						gag.targets = [get_parent().cogs[selection]]
					# Swap UIs back
					%TargetSelect.hide()
					main_container.show()
		_:
			gag.targets = get_parent().cogs.duplicate()
	selected_gags.append(gag)
	selected_gags = sort_gags(selected_gags)
	s_gag_selected.emit(gag)
	gag_order_menu.refresh_gags(selected_gags)
	
	# Lower turns
	turn += 1

func refresh_turns():
	attack_label.set_text("Turns Remaining: " + str(Util.get_player().stats.turns - turn))
	
	if remaining_turns == 0:
		for track in gag_tracks.get_children():
			track.set_disabled(true)
		fire_button.disable()
	else:
		for track in gag_tracks.get_children():
			track.set_disabled(false)
		check_pink_slips()

func check_fires() -> bool:
	return Util.get_player().stats.pink_slips > 0

func gag_hovered(gag: BattleAction):
	right_panel.preview_gag(gag)

func complete_turn():
	# Reset turns
	turn = 0
	
	var gag_order := sort_gags(selected_gags)
	
	s_turn_complete.emit(gag_order)
	selected_gags.clear()

func sort_gags(gags: Array[ToonAttack]) -> Array[ToonAttack]:
	if Util.get_player().custom_gag_order:
		return gags
	
	var gag_order : Array[ToonAttack] = []
	var loadout: Array[Track] = Util.get_player().character.gag_loadout.loadout
	for track in loadout:
		for gag in track.gags:
			for selection in selected_gags:
				if selection.action_name == gag.action_name:
					gag_order.append(selection)
	for i in range(selected_gags.size() -1, -1, -1):
		if not selected_gags[i] in gag_order:
			gag_order.insert(0, selected_gags[i])
	
	return gag_order

func reset():
	show()
	cog_panels.assign_cogs(get_parent().cogs)
	for track in gag_tracks.get_children():
		track.refresh()
	status_container.refresh()

	if %TargetSelect.visible:
		# Force reset target select, and also potentially
		# refund any points player might have spent on this
		# without it going through
		# This is relevant because goggles (and maybe other items eventually)
		# can force the battle UI to be over early
		%TargetSelect.s_arrow_pressed.emit(-1)
		%TargetSelect.reset_buttons()

func cancel_gag(index: int):
	var gag: BattleAction = selected_gags[index]
	selected_gags.remove_at(index)
	s_gags_updated.emit(selected_gags)
	turn -= 1
	s_gag_canceled.emit(gag)

func get_track_element(track: Track) -> TextureRect:
	for track_elem in gag_tracks.get_children():
		if track_elem.track == track:
			return track_elem 
	return null

func fire_pressed() -> void:
	Util.get_player().stats.pink_slips -= 1
	check_pink_slips()
	gag_selected(fire_action.duplicate())

func check_pink_slips() -> void:
	if Util.get_player().stats.pink_slips <= 0:
		fire_button.disable()
	else:
		fire_button.enable()

func gag_canceled(gag: BattleAction) -> void:
	if gag is ToonAttackFire:
		Util.get_player().stats.pink_slips += 1
		check_pink_slips()

func fire_hovered() -> void:
	if fire_action:
		gag_hovered(fire_action)

func open_items() -> void:
	%ItemPanel.show()
	main_container.hide()
