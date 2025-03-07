extends Node
class_name SignalBarrier
## A container that waits for one or all of multiple signals to be emitted
## before emitting its complete signal.

## Emitted when the barrier is done respective to its set BarrierType
signal s_complete
## Emmitted if the barrier was given a timeout and it has passed
signal s_timeout

## The mode for the barrier.
## ANY: One of the signals is required to emit s_complete
## ALL: All of the signals are required to emit s_complete
enum BarrierType { ANY, ALL }

@export var _signal_arr: Array[Signal] = []
@export var _barrier_type: BarrierType = BarrierType.ALL
@export var _timeout_time: float = 0.0

var _signals_completed: Array[Signal] = []
var _timeout_task: Task

## The barrier has emitted its complete signal and is no longer active
var has_completed: bool = false
## The barrier has emitted its timeout signal and is no longer active
var has_timed_out: bool = false


#region Internal Funcs

func _init(p_signal_arr: Array[Signal] = [], p_barrier_type := BarrierType.ALL, p_timeout_time := 0.0) -> void:
	_signal_arr = p_signal_arr
	_barrier_type = p_barrier_type
	_timeout_time = p_timeout_time
	_connect_to_signals()
	if _timeout_time > 0.0:
		_timeout_task = Task.delayed_call(null, _timeout_time, _timeout)

## Start listening to all signals passed
func _connect_to_signals() -> void:
	for s: Signal in _signal_arr:
		_connect_to_signal(s)

## Start listening to a signal and tie it into the barrier
func _connect_to_signal(s: Signal) -> void:
	# Looks ugly but its the only way in GDScript to zero out incoming
	# args from other signals
	s.connect(func(a1=null, a2=null, a3=null, a4=null, a5=null): _got_signal_emit(s))

## A signal has emitted, see if we need to emit our complete signal
func _got_signal_emit(s: Signal) -> void:
	if has_completed or has_timed_out:
		return

	if s not in _signals_completed:
		_signals_completed.append(s)
	if _barrier_type == BarrierType.ANY or _signals_completed.size() == _signal_arr.size():
		_complete()

## The barrier has completed, as all signals have emitted. Emit our own complete signal
func _complete() -> void:
	has_completed = true
	s_complete.emit()
	if _timeout_task:
		_timeout_task = _timeout_task.cancel()
	queue_free.call_deferred()

## The barrier has timed out, cancel everything and emit the timeout signal
func _timeout() -> void:
	has_timed_out = true
	s_timeout.emit()
	queue_free.call_deferred()

#endregion
#region Public Funcs

## Adds a new signal to the barrier, assuming it is not completed or timed out already
func append(s: Signal) -> void:
	if has_completed or has_timed_out:
		return
	_signal_arr.append(s)
	_connect_to_signal(s)

#endregion
