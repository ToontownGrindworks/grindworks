@tool
extends Object
class_name ToonUtils
## A modified cut down version of DogUtils by Mica & Sketched


static func get_object_name(obj: Variant) -> String:
	if obj is Callable:
		var method_name: String
		if obj.is_custom():
			return "LambdaFunc"
		else:
			method_name = str(obj.get_method())
			return get_object_name(obj.get_object()) + '(%s)' % method_name

	elif obj is Object:
		var script: Script = null
		if obj is Script:
			script = obj
		elif obj.get_script():
			script = obj.get_script()
		if script:
			return script.resource_path.get_file()
		
		if obj is Resource and obj.resource_name:
			return obj.resource_name
		
		var obj_name = obj.get("name")
		if not obj_name:
			obj_name = obj.get_class()
		return obj_name
	
	return str(obj)

static func is_script_of_type(script: GDScript, type: GDScript) -> bool:
	while script:
		if script == type:
			return true
		script = script.get_base_script()
	return false

static func get_look_at_rotation(node: Node3D, target_global_pos: Vector3) -> Vector3:
	var dummy = Node3D.new()
	node.add_child(dummy)
	dummy.look_at(target_global_pos)
	dummy.queue_free()
	return dummy.global_rotation

static func plural(num: int) -> String:
	return "" if num == 1 else "s"

static func reverse_dictionary(the_dictionary_in_question: Dictionary) -> Dictionary:
	var new_dict: Dictionary = {}
	for key in the_dictionary_in_question.keys():
		new_dict[the_dictionary_in_question[key]] = key
	return new_dict

static func get_enum_value_name(the_enum: Dictionary, value: int) -> String:
	var reversed: Dictionary = reverse_dictionary(the_enum)
	return reversed[value]

static func sum_inner(accum: float, number: float) -> float:
	return accum + number

## Returns a sum of an array of values that can be added
static func sum_array(array: Array) -> float:
	return array.reduce(sum_inner, 0)
