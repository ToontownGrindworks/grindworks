@tool
extends EditorPlugin

func _enter_tree():
	add_custom_type("Task", "Node", preload("task.gd"), preload("Timer.svg"))
	add_autoload_singleton("TaskContainer", "res://addons/task/task_container.gd")
	add_custom_type("SignalBarrier", "RefCounted", preload("signal_barrier.gd"), preload("Signals.svg"))

func _exit_tree():
	remove_custom_type("Task")
	remove_autoload_singleton("TaskContainer")
