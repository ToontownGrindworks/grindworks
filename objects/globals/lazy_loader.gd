extends RefCounted
class_name LazyLoader

enum LoadType { ONE, ARRAY, DICT }
static var lazy_loaders: Array[WeakRef]
static var waiting_for_game_start := true:
	set(now_waiting):
		if waiting_for_game_start and not now_waiting:
			for loader_ref in lazy_loaders:
				var lazy_loader: LazyLoader = loader_ref.get_ref()
				if lazy_loader:
					lazy_loader.load_thread.start(lazy_loader._do_load)
		waiting_for_game_start = now_waiting

var load_type: LoadType
var resources: Dictionary
var load_thread := Thread.new()
var _cache: Variant

static func _new_lazy_loader() -> LazyLoader:
	var lazy_loader := LazyLoader.new()
	lazy_loaders.append(weakref(lazy_loader))
	return lazy_loader

static func defer(path: String) -> LazyLoader:
	var lazy_loader := _new_lazy_loader()
	lazy_loader.load_type = LoadType.ONE
	lazy_loader.resources[path] = path
	if not waiting_for_game_start:
		lazy_loader.load_thread.start(lazy_loader._do_load)
	return lazy_loader

static func defer_array(paths: PackedStringArray) -> LazyLoader:
	var lazy_loader := _new_lazy_loader()
	lazy_loader.load_type = LoadType.ARRAY
	for path in paths:
		lazy_loader.resources[path] = path
	if not waiting_for_game_start:
		lazy_loader.load_thread.start(lazy_loader._do_load)
	return lazy_loader

static func defer_dict(name_to_path: Dictionary) -> LazyLoader:
	var lazy_loader := _new_lazy_loader()
	lazy_loader.load_type = LoadType.DICT
	for name in name_to_path.keys():
		lazy_loader.resources[name] = name_to_path[name]
	if not waiting_for_game_start:
		lazy_loader.load_thread.start(lazy_loader._do_load)
	return lazy_loader

func _do_load():
	if not resources:
		assert(_cache != null)
		return
	match load_type:
		LoadType.ARRAY:
			_cache = resources.keys().map(func(path: String): return ResourceLoader.load(path))
		LoadType.DICT:
			var resp: Dictionary
			for name in resources.keys():
				resp[name] = ResourceLoader.load(resources[name])
			_cache = resp
		_:
			_cache = ResourceLoader.load(resources.keys()[0])
	resources.clear()

func _notification(what: int):
	if what == NOTIFICATION_PREDELETE and load_thread.is_started():
		if str(OS.get_thread_caller_id()) != load_thread.get_id():
			load_thread.wait_to_finish()
		else:
			push_warning('LazyLoader being pre-deleted in its own thread without load() called')

func load() -> Variant:
	ensure_realized()
	return _cache
	
func is_loaded():
	return _cache != null
	
func ensure_realized():
	if load_thread.is_started():
		# Our separate thread is already started, finish loading there.
		load_thread.wait_to_finish()
	elif not _cache:
		# Our thread is not started (the main scene isn't finished loading),
		# but we need this resource now. Finish loading on the main thread.
		_do_load()
