@tool
extends Resource
class_name IDResource
## It's a resource with an ID

@export var id: int = 0

@warning_ignore("unused_private_class_variable")
@export_tool_button("Generate ID", "Callable") var _generate_id = func(): generate_new_id()

## Returns the resource path for these associated resources.
## Can be overridden by base classes.
static func get_registry_path() -> String:
	return ""

## Returns if we are loading our registry definitions recursively.
## Can be overridden by base classes.
static func get_registry_recursive() -> bool:
	return true

## Returns the registry associated with this resource.
static func get_fresh_registry(base: GDScript) -> DynamicRegistry:
	var path: String = base.get_registry_path()
	if not path:
		assert(false, "IDResource %s has undefined get_registry_path." % base)
		return null
	var reg := DynamicRegistry.new(path, ".tres", base.get_registry_recursive(), base)
	return reg

## Generates a new ID for this resource.
func generate_new_id(p := true) -> void:
	var script: GDScript = get_registry_path.get_object()
	var registry: DynamicRegistry = get_fresh_registry(script)
	if registry.has_id_collision(id):
		var old_id := id
		id = registry.get_available_id()
		ResourceSaver.save(self)
		if p:
			print_rich('[i]%s: updated id %s => %s' % [script.get_global_name(), old_id, id])
	elif p:
		print_rich('[i]%s:[/i] id is unique' % [script.get_global_name()])
