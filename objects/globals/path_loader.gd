extends Object
class_name PathLoader
## A class that provides path loading utilities.

## Gathers the filepaths for all files matching the extension within a given directory.
static func load_filepaths(path: String, ext := ".tres", recursive := true, _filter_type: Variant = Object) -> Array[String]:
	if not path.ends_with("/"):
		path += '/'
	if not DirAccess.dir_exists_absolute(path):
		push_error("Could not find path: %s" % path)
		return []

	# First need to grab all relevant file paths
	var filepaths: Array[String] = []
	var dir: DirAccess = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir() and recursive:
				filepaths.append_array(PathLoader.load_filepaths(path + file_name, ext, recursive))
			elif file_name.ends_with(ext):
				filepaths.append(path + file_name)
			file_name = dir.get_next()
	return filepaths

## Loads the resources for all files matching the extension within a given directory.
static func load_resources(path: String, ext := ".tres", recursive := true, filter_type: Variant = Object) -> Array:
	# Harvest all filepaths, return them.
	var filepaths: Array[String] = load_filepaths(path, ext, recursive, filter_type)
	var loaded_resources: Array = filepaths.map(load)
	var filtered_resources: Array = loaded_resources.filter(is_instance_of.bind(filter_type))
	return filtered_resources

static func async_load_resources(path: String, ext := ".tres", recursive := true, filter_type: Variant = Object) -> Array:
	return load_resources(path, ext, recursive, filter_type)
	# Harvest all filepaths, return them.
	# var filepaths: Array[String] = load_filepaths(path, ext, recursive, filter_type)
	# var async_data: Array = ResourceThreadedLoader.bulk_load(filepaths)
	# var bulk_signal: Signal = async_data[1]
	# var loaded_resources: Array = await bulk_signal
	# var filtered_resources: Array = loaded_resources.filter(is_instance_of.bind(filter_type))
	# return filtered_resources
