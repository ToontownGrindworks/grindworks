extends RefCounted
class_name DynamicRegistry
## A registry object that can be created at runtime.

var _registry: Array = []
var _id_to_def: Dictionary[int, Resource] = {}
var _def_to_id: Dictionary[Resource, int] = {}

var id_collisions: Dictionary = {}

func _init(directory: String, extension := ".tres", recursive := true, filter_type: Variant = Object) -> void:
	# Build new registry.
	create_registry(directory, extension, recursive, filter_type)
	setup_registry()

func create_registry(directory: String, extension := ".tres", recursive := true, filter_type: Variant = Object) -> void:
	_registry = PathLoader.load_resources(directory, extension, recursive, filter_type)

func setup_registry() -> void:
	if _registry:
		if _registry[0] is IDResource:
			# Set IDs via IDResource.
			for resource: IDResource in _registry:
				if resource.id in _id_to_def:
					if not Engine.is_editor_hint():
						assert(false, '%s: ID collision detected' % resource.resource_path)
					id_collisions[resource.id] = null
					continue
				_id_to_def[resource.id] = resource
				_def_to_id[resource] = resource.id
		else:
			# Set IDs dynamically.
			_registry.sort_custom(_resource_sort)
			var id := 0
			for resource: Resource in _registry:
				_id_to_def[id] = resource
				_def_to_id[resource] = id
				id += 1

func get_all_definitions() -> Array:
	return _registry

static func _resource_sort(a: Resource, b: Resource):
	return a.resource_path < b.resource_path

func get_id(res: Resource) -> int:
	return _def_to_id[res]

func get_definition(id: int) -> Resource:
	return _id_to_def[id]

func get_available_id() -> int:
	var id := 0
	while id in _id_to_def:
		id += 1
	return id

func has_id(id: int) -> bool:
	return id in _id_to_def

func has_definition(res: Resource) -> bool:
	return res in _def_to_id

func has_id_collision(id: int) -> bool:
	return id in id_collisions
