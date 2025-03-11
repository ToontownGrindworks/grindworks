extends Node

var Difficulty : float
@onready var Targets : Node = $Targets
@export var AcceptRange := 0.08
@export var GracePeriod := 0.25
@export var FreezePeriod := 0.25
# pixels per second
@export var TargetSpeed : float = 600
@export var TargetsToSend := 1
var targets_hit := 0
var grace_period_tick := 0.0
var freeze_period_tick := 0.0

const SFX_FREEZE = preload("res://mod_assets/sans/clutch_dodge/snd_bell.wav")
const SFX_HIT = preload("res://mod_assets/sans/clutch_dodge/mus_sfx_eyeflash.wav")

signal game_finished(result: bool)

# Called when the node enters the scene tree for the first time.
func _ready():
	Difficulty = 1
	var defense := Util.get_player().stats.defense
	var evasiveness := Util.get_player().stats.evasiveness
	TargetSpeed = (600 / evasiveness) / (log(4) * defense)
	print("TargetSpeed set to " + str(TargetSpeed) + " with " + str(defense) + " Defense & " + str(evasiveness) + " Evasiveness")

func _physics_process(delta):
	var target_array = Targets.get_children()
	if target_array.size() > 0:
		for target in target_array:
			target.position += Vector2.RIGHT * TargetSpeed * delta
			if target.position.x / Targets.size.x > 1:
				print("Game lost!")
				game_finished.emit(false)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if grace_period_tick > 0.0:
		grace_period_tick -= delta
	if freeze_period_tick > 0.0:
		freeze_period_tick -= delta


func _input(event):
	if event.is_action_pressed("click"):
		if freeze_period_tick > 0.0:
			print("Cannot dodge while frozen!")
			return
		
		var AimedTarget = false
		
		var target_array = Targets.get_children()
		if target_array.size() > 0:
			for target in target_array:
				var target_value = target.position.x / Targets.size.x
				print(target_value)
				if target_value >= 0.5 - AcceptRange && target_value < 0.5 + AcceptRange :
					AimedTarget = target
		
		if AimedTarget is Node:
			AimedTarget.queue_free()
			AimedTarget = false
			AudioManager.play_sound(SFX_HIT)
			targets_hit += 1
			if targets_hit >= TargetsToSend:
				print("Game won!")
				await get_tree().create_timer(1.0).timeout
				game_finished.emit(true)
			grace_period_tick = GracePeriod

		else:
			print("Missed!")
			AudioManager.play_sound(SFX_FREEZE)
			freeze_period_tick = FreezePeriod
