@tool
extends EditorPlugin

const ADD_PLAYER_CONTEXT_MENU_OPTION := preload('res://addons/toonlike_tools/add_player_context_menu_option.gd')

var add_player_context_menu_option: EditorContextMenuPlugin

func _enter_tree():
	add_autoload_singleton("Logging", "res://addons/toonlike_tools/logging/logging.gd")
	add_custom_type("Logger", "RefCounted", preload("logging/logger.gd"), preload("logging/GuiTabMenu.svg"))

	add_player_context_menu_option = ADD_PLAYER_CONTEXT_MENU_OPTION.new()
	add_player_context_menu_option.undo_redo = get_undo_redo()
	add_context_menu_plugin(
		EditorContextMenuPlugin.CONTEXT_SLOT_SCENE_TREE,
		add_player_context_menu_option
	)

func _exit_tree():
	remove_autoload_singleton("Logging")
	remove_custom_type("Logger")

	if add_player_context_menu_option:
		remove_context_menu_plugin(add_player_context_menu_option)
