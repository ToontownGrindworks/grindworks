extends Camera3D
class_name FreeCamTool

var base_speed := 5.0:
	set(x):
		base_speed = clamp(x,0.1,20.0)

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	make_current()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x*Globals.SENSITIVITY)
		rotation.x-=event.relative.y*Globals.SENSITIVITY
		rotation.x = clamp(rotation.x,deg_to_rad(-89),deg_to_rad(89))

func _physics_process(delta: float) -> void:
	var velocity := Vector3(0,0,0)
	var spd := base_speed*delta
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * spd
		velocity.z = direction.z * spd
		velocity.y = direction.y * spd
	else:
		velocity.x = move_toward(velocity.x, 0, spd)
		velocity.z = move_toward(velocity.z, 0, spd)
		velocity.y = move_toward(velocity.y, 0, spd)
	
	# Up and Down Velocity
	if Input.is_action_pressed('jump'):
		velocity.y+=spd
	if Input.is_action_pressed('sprint'):
		velocity.y-=spd
	
	position+=velocity
	
	if Input.is_action_just_pressed('zoom_in'):
		base_speed+=0.25
	if Input.is_action_just_pressed('zoom_out'):
		base_speed-=0.25
	
	if Input.is_action_just_pressed('pause'):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
