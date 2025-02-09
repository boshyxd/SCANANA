extends CharacterBody3D

@onready var camera = $Head/Camera3D
@onready var head = $Head
@onready var scan_viewport = $Head/SubViewport
@onready var scan_camera = $Head/SubViewport/Camera3D
@onready var scanner = $Head/Scanner
@onready var scan_lines = $Head/Scanner/Lines
@onready var ui = $"../UI"

@export var speed = 14.0
@export var fall_acceleration = 75.0
@export var mouse_sensitivity = 0.2

@export var scan_radius = 30.0
@export var scan_angle = 45.0
@export var rays_per_scan = 32
@export var point_size = 0.02
@export var close_distance = 5.0  # Distance for red color
@export var mid_distance = 15.0   # Distance for yellow color
@export var far_distance = 30.0   # Distance for blue color

# Quality Settings
enum Quality { LOW, MEDIUM, HIGH }
@export var quality_level: Quality = Quality.MEDIUM
@export var color_update_interval = 0.2  # Reduced update frequency

var quality_settings = {
	Quality.LOW: {
		"points_per_frame": 32,
		"fullscreen_step": 20,
		"max_points": 5000
	},
	Quality.MEDIUM: {
		"points_per_frame": 64,
		"fullscreen_step": 10,
		"max_points": 10000
	},
	Quality.HIGH: {
		"points_per_frame": 128,
		"fullscreen_step": 5,
		"max_points": 20000
	}
}

enum ScanMode {
	CONE,
	LINE,
	WIDE,
	FULLSCREEN
}
@export var current_mode: ScanMode = ScanMode.CONE
@export var line_width = 2.0
@export var wide_height = 10.0

var target_velocity = Vector3.ZERO
var scanning = false
var rng = RandomNumberGenerator.new()
var scan_container: Node3D
var current_pool_size = 0  # Track how many points we've created
var scan_progress = 0.0  # Track scan progress for sweeping effect
var is_single_scan = false  # Track if we're doing a single sweep scan
var color_update_timer = 0.0
var scan_points = []  # Store point references
var base_material: StandardMaterial3D  # Reusable material

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	scan_camera.transform = camera.transform
	rng.randomize()
	
	# Create scan container
	scan_container = Node3D.new()
	scan_container.name = "ScanPoints"
	call_deferred("add_scan_container")
	
	# Create reusable material
	base_material = StandardMaterial3D.new()
	base_material.emission_enabled = true
	base_material.emission_energy = 2.0
	base_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	update_mode_display()
	
	# Hide all environment objects in game
	var level = get_node("../Level")
	if level:
		_set_objects_visibility(level, false)

func add_scan_container():
	get_tree().root.add_child(scan_container)

func _set_objects_visibility(node: Node, is_visible: bool):
	if node is MeshInstance3D:
		node.visible = is_visible
	
	for child in node.get_children():
		_set_objects_visibility(child, is_visible)

func update_mode_display():
	if ui:
		var mode_text = ""
		match current_mode:
			ScanMode.CONE:
				mode_text = "CONE"
			ScanMode.LINE:
				mode_text = "LINE"
			ScanMode.WIDE:
				mode_text = "WIDE"
			ScanMode.FULLSCREEN:
				mode_text = "FULLSCREEN"
		ui.update_mode(mode_text)

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity * 0.01)
		head.rotate_x(-event.relative.y * mouse_sensitivity * 0.01)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
		scan_camera.rotation = head.rotation
	
	if event.is_action_pressed("scan"):
		start_scan()
	elif event.is_action_released("scan"):
		stop_scan()
	
	if event.is_action_pressed("mode_cone"):
		current_mode = ScanMode.CONE
		reset_scan_state()
		update_mode_display()
	elif event.is_action_pressed("mode_line"):
		current_mode = ScanMode.LINE
		reset_scan_state()
		update_mode_display()
	elif event.is_action_pressed("mode_wide"):
		current_mode = ScanMode.WIDE
		reset_scan_state()
		update_mode_display()
	elif event.is_action_pressed("mode_fullscreen"):
		current_mode = ScanMode.FULLSCREEN
		reset_scan_state()
		update_mode_display()
	
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	var input_dir = Input.get_vector("player_left", "player_right", "player_forward", "player_backward")
	var move_direction = Vector3.ZERO
	
	move_direction = Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, rotation.y)
	
	if move_direction:
		target_velocity.x = move_direction.x * speed
		target_velocity.z = move_direction.z * speed
	else:
		target_velocity.x = move_toward(target_velocity.x, 0, speed)
		target_velocity.z = move_toward(target_velocity.z, 0, speed)
	
	if not is_on_floor():
		target_velocity.y = target_velocity.y - (fall_acceleration * delta)
	else:
		target_velocity.y = 0
		if Input.is_action_just_pressed("player_jump"):
			target_velocity.y = 10.0
	
	velocity = target_velocity
	move_and_slide()

func start_scan():
	scanning = true
	scan_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	scan_progress = 0.0  # Reset progress
	is_single_scan = current_mode == ScanMode.FULLSCREEN
	perform_scan()

func stop_scan():
	if !is_single_scan:  # Only stop if not doing a single sweep scan
		scanning = false
		scan_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func perform_scan():
	var space_state = get_world_3d().direct_space_state
	var scan_origin = scanner.global_position
	
	match current_mode:
		ScanMode.CONE:
			perform_cone_scan(space_state, scan_origin)
		ScanMode.LINE:
			perform_line_scan(space_state, scan_origin)
		ScanMode.WIDE:
			perform_wide_scan(space_state, scan_origin)
		ScanMode.FULLSCREEN:
			perform_fullscreen_scan(space_state, scan_origin)

func perform_cone_scan(space_state, scan_origin):
	for _i in rays_per_scan:
		var phi = rng.randf_range(-scan_angle, scan_angle)
		var theta = rng.randf_range(-scan_angle, scan_angle)
		
		var ray_direction = Vector3(
			sin(deg_to_rad(phi)) * cos(deg_to_rad(theta)),
			sin(deg_to_rad(theta)),
			-cos(deg_to_rad(phi)) * cos(deg_to_rad(theta))
		).normalized()
		cast_ray(space_state, scan_origin, ray_direction)

func perform_line_scan(space_state, scan_origin):
	for i in rays_per_scan:
		var theta = rng.randf_range(-line_width/2.0, line_width/2.0)
		var vertical_angle = (float(i) - float(rays_per_scan)/2.0) * (scan_angle*2.0/float(rays_per_scan))
		
		var ray_direction = Vector3(
			sin(deg_to_rad(theta)),
			sin(deg_to_rad(vertical_angle)),
			-cos(deg_to_rad(theta)) * cos(deg_to_rad(vertical_angle))
		).normalized()
		cast_ray(space_state, scan_origin, ray_direction)

func perform_wide_scan(space_state, scan_origin):
	for i in rays_per_scan:
		var phi = (float(i) - float(rays_per_scan)/2.0) * (scan_angle*2.0/float(rays_per_scan))
		var theta = rng.randf_range(-wide_height/2.0, wide_height/2.0)
		
		var ray_direction = Vector3(
			sin(deg_to_rad(phi)) * cos(deg_to_rad(theta)),
			sin(deg_to_rad(theta)),
			-cos(deg_to_rad(phi)) * cos(deg_to_rad(theta))
		).normalized()
		cast_ray(space_state, scan_origin, ray_direction)

func perform_fullscreen_scan(space_state, scan_origin):
	var screen_size = get_viewport().get_visible_rect().size
	
	# Use quality-based pixel step
	var pixel_step = quality_settings[quality_level]["fullscreen_step"]
	var cols = int(screen_size.x / pixel_step)
	var total_rows = int(screen_size.y / pixel_step)
	
	var current_row = int(scan_progress * total_rows)
	scan_progress += 0.05
	
	if scan_progress >= 1.0:
		scanning = false
		scan_progress = 0.0
		return
	
	for col in cols:
		var x = (float(col) / float(cols - 1)) * screen_size.x - (screen_size.x / 2)
		var y = (float(current_row) / float(total_rows - 1)) * screen_size.y - (screen_size.y / 2)
		
		var ray_direction = -scanner.global_transform.basis.z
		var ray_origin = scan_origin + scanner.global_transform.basis.x * (x / screen_size.x * 2.0) + scanner.global_transform.basis.y * (y / screen_size.y * 2.0)
		
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * scan_radius)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		query.collision_mask = 0xFFFFFFFF  # Collide with all layers
		
		var result = space_state.intersect_ray(query)
		if result:
			create_scan_point(result.position)

func cast_ray(space_state, scan_origin, ray_direction):
	ray_direction = scanner.global_transform.basis * ray_direction
	var query = PhysicsRayQueryParameters3D.create(scan_origin, scan_origin + ray_direction * scan_radius)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 0xFFFFFFFF  # Collide with all layers
	
	var result = space_state.intersect_ray(query)
	if result:
		create_scan_point(result.position)

func create_scan_point(pos: Vector3):
	if current_pool_size >= quality_settings[quality_level]["max_points"]:
		# Remove oldest point if we're at max capacity
		if scan_points.size() > 0:
			var oldest_point = scan_points.pop_front()
			oldest_point.point.queue_free()
			current_pool_size -= 1
	
	var point = CSGSphere3D.new()
	point.radius = point_size
	
	# Use the base material instance
	var material = base_material.duplicate()
	
	# Calculate initial color based on distance
	var distance = global_position.distance_to(pos)
	var color = get_distance_color(distance)
	material.albedo_color = color
	material.emission = color
	
	point.material = material
	scan_container.add_child(point)
	point.global_position = pos
	
	# Store point reference for updating
	scan_points.push_back({"point": point, "material": material, "position": pos})
	
	current_pool_size += 1

func get_distance_color(distance: float) -> Color:
	if distance <= close_distance:
		return Color(1.0, 0.0, 0.0, 1.0)  # Red
	elif distance <= mid_distance:
		var t = (distance - close_distance) / (mid_distance - close_distance)
		return Color(1.0, t, 0.0, 1.0)  # Red to Yellow
	elif distance <= far_distance:
		var t = (distance - mid_distance) / (far_distance - mid_distance)
		return Color(1.0 - t, 1.0 - t, t, 1.0)  # Yellow to Blue
	else:
		return Color(0.0, 0.0, 1.0, 1.0)  # Blue

func _process(delta):
	if scanning:
		perform_scan()
	
	# Update colors every frame for smoother transitions
	update_point_colors()

func update_point_colors():
	# Skip if no points to update
	if scan_points.size() == 0:
		return
		
	# Update all points every frame, but in chunks to spread the load
	var chunk_size = 200  # Process more points per frame
	var total_chunks = max(1, (scan_points.size() + chunk_size - 1) / chunk_size)
	
	# Use the timer to determine which chunk to update
	var current_chunk = int(Time.get_ticks_msec() / 16.67) % total_chunks  # 16.67ms = 1 frame at 60fps
	var start_index = current_chunk * chunk_size
	var end_index = min(start_index + chunk_size, scan_points.size())
	
	for i in range(start_index, end_index):
		var point_data = scan_points[i]
		var distance = global_position.distance_to(point_data.position)
		var new_color = get_distance_color(distance)
		point_data.material.albedo_color = new_color
		point_data.material.emission = new_color

func reset_scan_state():
	scanning = false
	scan_progress = 0.0
	is_single_scan = false
	scan_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
