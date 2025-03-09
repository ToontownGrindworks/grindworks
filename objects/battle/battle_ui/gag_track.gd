extends TextureRect
class_name TrackElement

const WARNING_COLOR := Color.RED

@onready var gag_buttons: = $Gags.get_children()
@onready var ui_root: BattleUI = NodeGlobals.get_ancestor_of_type(self, BattleUI)
@onready var point_label := %Points
@onready var track_label := %TrackName

## Locals
var unlocked: int 
var track: Track
var gags: Array[ToonAttack]

## Signals
signal s_refreshing(element: TrackElement)


func _ready():
	var loadout: GagLoadout = Util.get_player().stats.character.gag_loadout
	var track_index : int = get_parent().get_children().find(self)
	if track_index >= loadout.loadout.size():
		grey_out()
		return
	
	track = loadout.loadout[track_index]
	unlocked = Util.get_player().stats.gags_unlocked[track.track_name]
	
	# Set the track color and name
	if unlocked > 0:
		track_label.set_text(track.track_name.to_upper())
		self_modulate = track.track_color
	else:
		grey_out()
	
	# Always check the refunds
	ui_root.s_gag_canceled.connect(refund_gag)
	
	# Add track to the bar
	refresh()

func emit_gag(gag: ToonAttack, price: int):
	var newgag := gag.duplicate()
	Util.get_player().stats.gag_balance[track.track_name] -= price
	refresh()
	ui_root.s_gag_pressed.emit(newgag)
	newgag.price = price

func refresh():
	if not track:
		return
	
	# Allow scripts to alter the gag track by signaling out
	# Duplicate the base track so that the effects are not permanent
	gags = track.gags.duplicate()
	s_refreshing.emit(self)
	
	for i in gag_buttons.size():
		if gags.size() >= i + 1 and i < unlocked:
			var gag := gags[i]
			var button: GagButton = gag_buttons[i]
			button.image = gag.icon
			
			if button.pressed.is_connected(emit_gag):
				button.pressed.disconnect(emit_gag)
				button.mouse_entered.disconnect(ui_root.gag_hovered)
			
			var price := 0
			if not button.pressed.is_connected(emit_gag):
				price = i
				price -= BattleService.ongoing_battle.battle_stats[Util.get_player()].gag_discount
				button.mouse_entered.connect(ui_root.gag_hovered.bind(gag))
				button.set_count(price)
				button.pressed.connect(emit_gag.bind(gag,price))
			
			if Util.get_player().stats.gag_balance[track.track_name] < price:
				button.disable()
			elif (gag is GagLure) and all_cogs_lured():
				button.disable()
			elif (gag is GagTrap) and ((all_cogs_lured() and Util.get_player().trap_needs_lure) or all_cogs_trapped()):
				button.disable()
			else:
				button.enable()
		else:
			gag_buttons[i].hide()
	
	point_label.text = "Points: " + str(roundi(Util.get_player().stats.gag_balance[track.track_name])) + '/' + str(roundi(Util.get_player().stats.gag_cap))
	if Util.get_player().stats.gag_balance[track.track_name] > Util.get_player().stats.gag_cap:
		point_label.self_modulate = WARNING_COLOR
	else:
		point_label.self_modulate = Color.WHITE

func refund_gag(gag: ToonAttack):
	for i in track.gags.size():
		if track.gags[i].action_name == gag.action_name:
			Util.get_player().stats.gag_balance[track.track_name] += gag.price
			refresh()
			return

# Gag checks
func all_cogs_lured() -> bool:
	var battle_manager: BattleManager = ui_root.get_parent()
	var all_lured := true
	for cog in battle_manager.cogs:
		if not cog.lured:
			all_lured = false
			break
	return all_lured

func all_cogs_trapped() -> bool:
	var battle_manager: BattleManager = ui_root.get_parent()
	var all_trapped := true
	for cog in battle_manager.cogs:
		if not cog.trap:
			all_trapped = false
			break
	return all_trapped

func grey_out() -> void:
	point_label.hide()
	track_label.set_text("???")
	self_modulate = Color.GRAY
	for button in gag_buttons:
		button.hide()

func set_disabled(disabled : bool) -> void:
	for button : GagButton in gag_buttons:
		if disabled:
			button.disable()
		else:
			refresh()
