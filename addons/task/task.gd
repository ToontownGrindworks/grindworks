extends Node
class_name Task
## A simple Timer-based task manager that allows specifying delay times for functions,
## as well as handling frame-based functions as a standalone.

## Returning Task.AGAIN on a delayed_call function will call it again with the same delay.
const AGAIN: StringName = &"Task-AGAIN"
## Placeholder value indicating no owner on a Task
const NO_OWNER: StringName = &"Task-NO-OWNER"

var callback: Callable
var args: Array
var timer: Timer
var is_process: bool
var task_time: float
var pausable: bool
var want_delta: bool
var task_owner: Variant

func _init(p_task_owner: Variant, p_callback: Callable, p_args: Array,
		p_timer: Timer, p_is_process: bool, p_task_time: float, p_pausable: bool, p_want_delta: bool):
	callback = p_callback
	args = p_args
	timer = p_timer
	is_process = p_is_process
	task_time = p_task_time
	pausable = p_pausable
	want_delta = p_want_delta
	task_owner = p_task_owner

	if not pausable:
		process_mode = PROCESS_MODE_ALWAYS

	name = 'Task'
	if is_process:
		name += '-Process'
	var method_name: StringName = &""
	if callback.is_custom():
		method_name = "LambdaFunc"
	else:
		method_name = str(callback.get_method())

	var obj_name = "-"
	if callback.get_object():
		obj_name = '-%s' % ToonUtils.get_object_name(callback.get_object())
	name += obj_name + '-' + method_name

	Logging.debug(self, '%s: Adding task' % name)

	if timer:
		timer.timeout.connect(complete_callback)

func complete_callback():
	if (not callback.is_valid()) or ((not task_owner is StringName) and not is_instance_valid(task_owner)):
		Logging.debug(self, '%s: Clearing because callback or object was invalid' % name)
		# Cancel this task if our owner object is no longer valid
		cancel()
		return

	var result = await callback.callv(args)
	if result != null and result == Task.AGAIN:
		if timer and is_instance_valid(timer):
			timer.queue_free()
		timer = Task._make_new_timer(task_time, not pausable)
		timer.timeout.connect(complete_callback)
		add_child(timer)
	else:
		cancel()

func cancel():
	if timer and timer.timeout.is_connected(complete_callback):
		timer.timeout.disconnect(complete_callback)
	set_process(false)
	queue_free()
	return null

func _process(delta):
	if not is_process:
		return

	var base_args: Array = [delta] if want_delta else []
	callback.callv(base_args + args)

func set_paused(paused: bool):
	timer.paused = paused

#region Public Funcs

## Begins calling a function every process frame
## Functions called via process_call always have delta as the first argument.
static func process_call(task_owner: Node, function: Callable, args: Array = [], pausable: bool = true, want_delta: bool = false) -> Task:
	var new_task = _make_new_task(task_owner, null, function, args, true, 0.0, pausable, want_delta)
	return new_task

## Calls a function after the specified time without disrupting code execution.
static func delayed_call(task_owner: Node, time: float, function: Callable, args: Array = [], pausable: bool = true) -> Task:
	var new_timer = _make_new_timer(time)
	var new_task = _make_new_task(task_owner, new_timer, function, args, false, time, pausable, false)
	new_task.add_child(new_timer)
	return new_task

## A simplified timer await. Does not return a Task ID and is not cancellable.
static func delay(time: float) -> Signal:
	return TaskContainer.get_tree().create_timer(time, false).timeout

## Returns a tween that repeats a given callback on the indicated time.
static func task_tween(parent: Node, callback: Callable, time: float, args: Array = []) -> Tween:
	return Sequence.new([
		Wait.new(time),
		Func.new(func(): callback.callv(args)),
	]).as_tween(parent if parent else TaskContainer).set_loops()

## Cancels all tasks on this object.
static func cancel_obj_tasks(parent: Node) -> void:
	var all_tasks := NodeGlobals.get_children_of_type(parent, Task, false)
	for task: Task in all_tasks:
		task.cancel()

#endregion
#region Internal Funcs

static func _make_new_timer(time: float, scene_tree: bool = false) -> Timer:
	var new_timer: Timer = Timer.new()
	new_timer.wait_time = time
	new_timer.autostart = true
	return new_timer

static func _make_new_task(task_owner: Node, timer: Timer, callback: Callable, args: Array, is_process: bool, start_time: float, pausable: bool, want_delta: bool) -> Task:
	assert(callback.is_standard() or (task_owner is Node and is_instance_valid(task_owner)), "Must have a valid task owner set if using a lambda callback!")
	var new_task = Task.new(task_owner, callback, args, timer, is_process, start_time, pausable, want_delta)
	if task_owner:
		task_owner.add_child(new_task)
	else:
		TaskContainer.add_child(new_task)
	return new_task

#endregion
