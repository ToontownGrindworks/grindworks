extends EditorContextMenuPlugin

const PLAYER_SCENE := preload("res://objects/player/player.tscn")

var undo_redo: EditorUndoRedoManager

func _popup_menu(paths: PackedStringArray):
	if PLAYER_SCENE and paths.size() == 1:
		add_context_menu_item(
			'Instantiate Player as Child Scene',
			_add_player_pressed,
			EditorInterface.get_base_control().get_theme_icon('CharacterBody3D', 'EditorIcons')
		)

func _add_player_pressed(nodes: Array[Node]):
	var player := PLAYER_SCENE.instantiate()
	player.state = Player.PlayerState.WALK
	undo_redo.create_action('Instantiate Player as Child Scene')
	undo_redo.add_do_method(nodes[0], 'add_child', player)
	undo_redo.add_do_method(player, 'set_owner', nodes[0])
	undo_redo.add_do_reference(player)
	undo_redo.add_undo_method(nodes[0], 'remove_child', player)
	undo_redo.commit_action()
