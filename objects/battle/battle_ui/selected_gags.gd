extends HBoxContainer

## References to the selected gag panels
var panels: Array[TextureRect] = []

## The base gag panel
@onready var gag_panel := $SelectedGag
@onready var battle_ui : BattleUI = get_parent()
@onready var manager: BattleManager = NodeGlobals.get_ancestor_of_type(self, BattleManager)

var current_gags: Array[ToonAttack] = []

## Signals the gag index to cancel
signal s_gag_canceled(index : int)


## Find the proper amount of gag panels to have on startup
func _ready():
	# Add the first gag panel to the array
	panels.append(gag_panel)
	
	# Amount of panels is based on Player turns (-1)
	var panels_to_make: int = Util.get_player().stats.turns - 1
	
	# Append the panels
	for i in panels_to_make:
		var panel = gag_panel.duplicate()
		add_child(panel)
		panels.append(panel)
	
	# X Button configuration
	for panel in panels:
		panel.get_node('GagIcon').mouse_entered.connect(hover_slot.bind(panels.find(panel)))
		panel.get_node('GagIcon').mouse_exited.connect(stop_hover)
		panel.get_node('GeneralButton').disabled = true
		panel.get_node('GeneralButton').hide()
		panel.get_node('GeneralButton').pressed.connect(cancel_gag.bind(panels.find(panel)))

func append_gag(gag: ToonAttack) -> void:
	# Add the icon to the gag panels
	for panel in panels:
		var icon: TextureRect = panel.get_node('GagIcon')
		if not icon.texture:
			icon.texture = gag.icon
			break
	
	# Enable/Disable x buttons
	for panel in panels:
		panel.get_node('GeneralButton').disabled = not panel.get_node('GagIcon').texture
		panel.get_node('GeneralButton').visible = not panel.get_node('GeneralButton').disabled

## Reset all panels
func on_round_start(_gag_order: Array[ToonAttack]) -> void:
	for panel in panels:
		panel.get_node('GagIcon').texture = null
		panel.get_node('GeneralButton').disabled = true
		panel.get_node('GeneralButton').hide()

func cancel_gag(index: int):
	s_gag_canceled.emit(index)

func refresh_gags(gags: Array[ToonAttack]):
	current_gags = gags
	for i in panels.size():
		var panel = panels[i]
		if i < gags.size():
			panel.get_node('GagIcon').texture = gags[i].icon
			panel.get_node('GeneralButton').disabled = false
		else:
			panel.get_node('GagIcon').texture = null
			panel.get_node('GeneralButton').disabled = true
		panel.get_node('GeneralButton').visible = not panel.get_node('GeneralButton').disabled

func hover_slot(idx: int) -> void:
	if (not current_gags) or current_gags.size() - 1 < idx:
		return

	var gag: ToonAttack = current_gags[idx]
	var atk_string: String = ""
	var has_main_target: bool = gag.main_target != null
	for cog in manager.cogs:
		if cog in gag.targets:
			atk_string += "X" if ((not has_main_target) or (has_main_target and cog == gag.main_target)) else "x"
		else:
			atk_string += "-"
		if manager.cogs.find(cog) < manager.cogs.size() - 1:
			atk_string += " "
	HoverManager.hover(atk_string, 20, 0.0125)

func stop_hover() -> void:
	HoverManager.stop_hover()
