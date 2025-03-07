extends Node

const LOADING_SCREEN := preload('res://scenes/loading_screen/loading_screen.tscn')

var persistent_node: Node
var persistent_nodes: Array[Node]:
	get: return persistent_node.get_children()
var current_scene: Node


func _ready() -> void:
	persistent_node = Node.new()
	add_child(persistent_node)
	persistent_node.name = "Persistent"
	
	if not get_tree().current_scene.is_node_ready():
		await get_tree().current_scene.ready
	LazyLoader.waiting_for_game_start = false
	get_tree().current_scene.call_deferred('reparent', self)

func change_scene_to_node(new_scene: Node):
	for child in get_children():
		if not child == persistent_node:
			child.queue_free()
	add_child(new_scene)
	current_scene = new_scene

func change_scene_to_packed(new_scene : PackedScene):
	change_scene_to_node(new_scene.instantiate())

func change_scene_to_file(new_scene : String):
	change_scene_to_node(load(new_scene).instantiate())

func add_persistent_node(node: Node) -> void:
	if node.get_parent() == persistent_node:
		return
	if not node.is_inside_tree():
		persistent_node.add_child(node)
		node.reset_physics_interpolation()
	else:
		node.reparent(persistent_node)

func load_into_scene(scene_path: String) -> void:
	var loading_screen := LOADING_SCREEN.instantiate()
	change_scene_to_node(loading_screen)
	loading_screen.load_scene(scene_path)

func clear_persistent_nodes() -> void:
	# Remove all persistent nodes from sceneloader
	for i in range(persistent_nodes.size() -1, -1 , -1):
		persistent_nodes[i].queue_free()
