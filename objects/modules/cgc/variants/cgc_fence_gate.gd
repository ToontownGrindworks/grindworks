extends Node3D

const SFX_OPEN = preload("res://audio/sfx/objects/facility_door/CHQ_FACT_arms_retracting.ogg")
const SFX_CLOSE = preload("res://audio/sfx/misc/CHQ_SOS_cage_land.ogg")

@export var start_opened := false
@export var left_pivot: Node3D
@export var right_pivot: Node3D
@export var fence_cam: Camera3D
@export var want_cam_cut := true

var opened := false

var tween: Tween:
	set(x):
		if tween and tween.is_valid():
			tween.kill()
		tween = x

func _ready() -> void:
	if start_opened:
		left_pivot.rotation_degrees.y = 75.0
		right_pivot.rotation_degrees.y = -75.0

func open() -> void:
	if opened:
		return
	opened = true

	AudioManager.play_sound(SFX_OPEN)

	if want_cam_cut and is_instance_valid(Util.get_player()):
		Util.get_player().state = Player.PlayerState.STOPPED
		Util.get_player().set_animation('neutral')
	fence_cam.make_current()

	tween = Parallel.new([
		LerpProperty.new(left_pivot, "rotation_degrees:y", 3.0, 75.0).interp(Tween.EASE_IN_OUT, Tween.TRANS_QUAD),
		LerpProperty.new(right_pivot, "rotation_degrees:y", 3.0, -75.0).interp(Tween.EASE_IN_OUT, Tween.TRANS_QUAD),
	]).as_tween(self)

	await Task.delay(2.0)
	if want_cam_cut and is_instance_valid(Util.get_player()):
		Util.get_player().state = Player.PlayerState.WALK
		Util.get_player().camera.make_current()

func play_close_anim() -> void:
	tween = Sequence.new([
		Parallel.new([
			LerpProperty.new(left_pivot, "rotation_degrees:y", 0.65, -10.0).interp(Tween.EASE_IN, Tween.TRANS_QUAD),
			LerpProperty.new(right_pivot, "rotation_degrees:y", 0.65, 10.0).interp(Tween.EASE_IN, Tween.TRANS_QUAD),
		]),
		Parallel.new([
			LerpProperty.new(left_pivot, "rotation_degrees:y", 0.12, 0.0).interp(Tween.EASE_OUT, Tween.TRANS_QUAD),
			LerpProperty.new(right_pivot, "rotation_degrees:y", 0.12, 0.0).interp(Tween.EASE_OUT, Tween.TRANS_QUAD),
		]),
	]).as_tween(self)
	await Task.delay(0.5)
	AudioManager.play_sound(SFX_CLOSE)

func connect_button(button: CogButton) -> void:
	button.s_pressed.connect(open.unbind(1))
