extends CharacterBody3D

@onready var camera = $Head/Camera3D
@onready var head = $Head
@onready var scan_viewport = $Head/SubViewport
@onready var scan_camera = $Head/SubViewport/Camera3D

var move_speed = 4.0
var acceleration = 5.0
var air_acceleration = 1.0
var jump_height = 5.75
var mouse_sensitivity = 0.2
var gravity_force = 17.6
var max_slope_angle = 20.0
var in_air = false
var direction = Vector3.ZERO
var gravity_vector = Vector3.ZERO
var scanning = false

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	scan_camera.transform = camera.transform

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_camera(event.relative.x * mouse_sensitivity * 0.01, event.relative.y * mouse_sensitivity * 0.01)
	
	if event.is_action_pressed("scan"):
		start_scan()
	elif event.is_action_released("scan"):
		stop_scan()
	
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func rotate_camera(h: float, v: float):
	rotate_y(-h)
	
	var new_rotation = head.rotation.x - v
	head.rotation.x = clamp(new_rotation, deg_to_rad(-89), deg_to_rad(89))
	
	scan_camera.rotation = head.rotation

func _physics_process(delta):
	in_air = !is_on_floor()
	
	acceleration = 5.0 if is_on_floor() else air_acceleration
	
	direction = Vector3.ZERO
	
	direction -= Input.get_action_strength("player_forward") * head.global_transform.basis.z
	direction += Input.get_action_strength("player_backward") * head.global_transform.basis.z
	direction -= Input.get_action_strength("player_left") * head.global_transform.basis.x
	direction += Input.get_action_strength("player_right") * head.global_transform.basis.x
	direction.y = 0
	
	if direction.length_squared() > 1:
		direction = direction.normalized()
	
	var target_velocity = direction * move_speed
	var current_velocity = velocity
	current_velocity.y = 0
	
	current_velocity = current_velocity.lerp(target_velocity, acceleration * delta)
	velocity.x = current_velocity.x
	velocity.z = current_velocity.z
	
	if not is_on_floor():
		gravity_vector.y -= gravity_force * delta
	else:
		gravity_vector = Vector3.ZERO
		if Input.is_action_just_pressed("player_jump"):
			gravity_vector = Vector3.UP * jump_height
			in_air = true
	
	velocity.y = gravity_vector.y
	move_and_slide()

func start_scan():
	scan_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func stop_scan():
	scan_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _process(_delta):
	if scanning:
		pass # TODO: Implement scan visualization
