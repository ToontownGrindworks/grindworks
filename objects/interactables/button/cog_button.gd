extends Node3D
class_name CogButton

## Config
@export var up_color := Color("ff0000")
@export var pressed_color := Color("00c900")
@export var retracts := false
@export var retract_time := 5.0
@export var connected_objects : Array[Node]

## Child References
@onready var button := $Model/button
@onready var sfx_press := $PressSFX
@onready var sfx_retract := $RetractSFX
@onready var retract_timer := $RetractTimer

## Signals
signal s_pressed(button: CogButton)
signal s_retracted(button:  CogButton)

## Locals
var pressed := false
const PRESS_TIME := 0.75


func _ready() -> void:
	# Connect self to all specified objects
	for object in connected_objects:
		connect_to(object)
	
	# Create a material override for the button
	button.set_surface_override_material(0,button.mesh.surface_get_material(0).duplicate())
	set_color(up_color)
	
	# Setup the retract timer
	retract_timer.wait_time = retract_time


func body_entered(body : Node3D) -> void:
	if body is Player and body.state == Player.PlayerState.WALK:
		press()

## Presses the button and marks as pressed
func press() -> void:
	if pressed:
		return
	pressed = true
	sfx_press.play()
	s_pressed.emit(self)
	
	# Create a tween of the button moving down
	# And to change the button color
	var press_tween := create_tween()
	press_tween.set_parallel(true)
	press_tween.tween_property(button, 'position:z', 40, PRESS_TIME)
	press_tween.tween_method(set_color, up_color, pressed_color, PRESS_TIME)
	
	# Set up retraction if the button retracts
	if retracts:
		retract_timer.start()

## Attempt to connect to an object
func connect_to(object : Node) -> void:
	if 'connect_button' in object:
		object.connect_button(self)
	else:
		push_warning("Object " + object.name + " has no connect_button method!")

## Sets the color
func set_color(color : Color) -> void:
	if button.get_surface_override_material(0):
		button.get_surface_override_material(0).albedo_color = color

## Retracts the button and marks as unpressed
func retract() -> void:
	sfx_retract.play()
	
	# Animate the button retracting
	# And changing color back to up color
	var retract_tween := create_tween()
	retract_tween.set_parallel(true)
	retract_tween.tween_property(button,'position:z',0.0,PRESS_TIME)
	retract_tween.tween_method(set_color,pressed_color,up_color,PRESS_TIME)
	
	# After animation, mark button as unpressed
	await retract_tween.finished
	pressed = false
	s_retracted.emit()
