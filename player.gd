extends CharacterBody3D

func _notification(what):
	if OS.has_feature("web"):
		if what == Window.NOTIFICATION_APPLICATION_FOCUS_IN:
			print("Web window gained focus")
			JavaScriptBridge.eval("console.log('Web window gained focus')")
		elif what == Window.NOTIFICATION_APPLICATION_FOCUS_OUT:
			print("Web window lost focus")
			JavaScriptBridge.eval("console.log('Web window lost focus')")
		
	if what == Node.NOTIFICATION_CRASH:
		push_error("Game crashed! Last known state: Scanning=" + str(scanning) + ", Points=" + str(scan_points.size()))

@onready var camera = $Head/Camera3D
@onready var head = $Head
@onready var scan_viewport = $Head/SubViewport
@onready var scan_camera = $Head/SubViewport/Camera3D
@onready var scanner = $Head/Scanner
@onready var scan_lines = $Head/Scanner/Lines
@onready var ui = $"../UI"

@export var speed = 7.0
@export var fall_acceleration = 30.0
@export var mouse_sensitivity = 0.2

@export var scan_radius = 30.0
@export var scan_angle = 30.0
@export var rays_per_scan = 8
@export var point_size = 0.02
@export var close_distance = 5.0
@export var mid_distance = 15.0
@export var far_distance = 30.0
@export var grid_size = 5.0

enum Quality { LOW, MEDIUM, HIGH }
@export var quality_level: Quality = Quality.MEDIUM
@export var color_update_interval = 0.2

var quality_settings = {
	Quality.LOW: {
		"points_per_frame": 8,
		"fullscreen_step": 40,
		"max_points": 5000
	},
	Quality.MEDIUM: {
		"points_per_frame": 16,
		"fullscreen_step": 20,
		"max_points": 12000
	},
	Quality.HIGH: {
		"points_per_frame": 32,
		"fullscreen_step": 10,
		"max_points": 25000
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
var current_pool_size = 0
var scan_progress = 0.0
var is_single_scan = false
var color_update_timer = 0.0
var scan_points = []
var base_scan_material: StandardMaterial3D
var glitch_material: ShaderMaterial
var banana_scan_points = []
var max_scannable_cells = 0
var scanned_positions = {}
var terrain_scanned = 0.0
var terrain_progress_bar: TextureProgressBar

var shared_scan_mesh: SphereMesh
var material_pool = []
var material_pool_index = 0
const MATERIAL_POOL_SIZE = 50

var thermal_camera: Node3D
var beam_material: StandardMaterial3D
var active_beams = []
const MAX_BEAMS = 8

var beam_cleanup_data = {}

var last_scan_time = 0.0
var scan_cooldown = 0.05  # 50ms between scans
var max_scan_duration = 10.0  # Force stop scanning after 10 seconds
var scan_start_time = 0.0

func _ready():
	if OS.has_feature("web"):
		JavaScriptBridge.eval("console.log('DEBUG: Starting game initialization in web mode...')")
	print("DEBUG: Starting game initialization...")
	await get_tree().create_timer(0.1).timeout
	
	print("DEBUG: Setting up scan camera...")
	scan_camera.transform = camera.transform
	
	# Configure viewport for web compatibility
	if OS.has_feature("web"):
		scan_viewport.transparent_bg = false
		scan_viewport.msaa_2d = Viewport.MSAA_DISABLED
		scan_viewport.msaa_3d = Viewport.MSAA_DISABLED
		scan_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		scan_viewport.use_debanding = false
		scan_viewport.use_occlusion_culling = false
		scan_viewport.positional_shadow_atlas_size = 0
		scan_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
		scan_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		print("DEBUG: Configured viewport for web compatibility")
	
	rng.randomize()
	
	print("DEBUG: Setting up floor parameters...")
	floor_max_angle = deg_to_rad(60)
	floor_snap_length = 0.3
	floor_block_on_wall = false
	floor_constant_speed = true
	
	print("DEBUG: Creating scan container...")
	scan_container = Node3D.new()
	scan_container.name = "ScanPoints"
	call_deferred("add_scan_container")
	
	print("DEBUG: Loading thermal camera model...")
	var camera_scene = load("res://objects/Thermal_Camera.fbx")
	thermal_camera = camera_scene.instantiate()
	head.add_child(thermal_camera)
	
	thermal_camera.position = Vector3(0.2, -0.2, -0.3)
	thermal_camera.rotation_degrees = Vector3(-10, 250, 0)
	thermal_camera.scale = Vector3(0.6, 0.6, 0.6)
	print("DEBUG: Thermal camera setup complete")
	
	print("DEBUG: Setting up materials...")
	beam_material = StandardMaterial3D.new()
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.emission_enabled = true
	beam_material.emission = Color(1.0, 0.2, 0.2, 1.0)
	beam_material.emission_energy_multiplier = 2.0
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_material.albedo_color = Color(1.0, 0.2, 0.2, 0.3)
	
	glitch_material = ShaderMaterial.new()
	glitch_material.shader = load("res://glitch_particle.gdshader")
	glitch_material.set_shader_parameter("glitch_intensity", 0.5)
	glitch_material.set_shader_parameter("base_color", Color(1.0, 0.2, 0.0, 1.0))
	glitch_material.set_shader_parameter("time_offset", rng.randf() * 100.0)
	print("DEBUG: Materials setup complete")
	
	print("DEBUG: Setting up scan mesh...")
	shared_scan_mesh = SphereMesh.new()
	shared_scan_mesh.radius = 0.02
	shared_scan_mesh.height = 0.04
	shared_scan_mesh.radial_segments = 4
	shared_scan_mesh.rings = 2
	
	base_scan_material = StandardMaterial3D.new()
	base_scan_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	base_scan_material.emission_enabled = true
	base_scan_material.disable_ambient_light = true
	base_scan_material.disable_receive_shadows = true
	base_scan_material.disable_fog = true
	print("DEBUG: Scan mesh setup complete")
	
	print("DEBUG: Setting up material pool...")
	for i in MATERIAL_POOL_SIZE:
		var material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.disable_ambient_light = true
		material.disable_receive_shadows = true
		material.disable_fog = true
		material_pool.push_back({
			"material": material,
			"in_use": false
		})
	print("DEBUG: Material pool setup complete")
	
	update_mode_display()
	calculate_max_scannable_cells()
	
	var level = get_node("../WorldEnvironment")
	if level:
		_set_objects_visibility(level, false)
	
	print("DEBUG: Game initialization complete!")

func add_scan_container():
	get_tree().root.add_child(scan_container)

func _set_objects_visibility(node: Node, should_be_visible: bool):
	if node is MeshInstance3D:
		node.visible = should_be_visible
	
	for child in node.get_children():
		_set_objects_visibility(child, should_be_visible)

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
			target_velocity.y = 12.0
	
	var snap_vector = Vector3.DOWN * floor_snap_length if is_on_floor() and not Input.is_action_just_pressed("player_jump") else Vector3.ZERO
	
	velocity = target_velocity
	
	move_and_slide()

func start_scan():
	if !is_inside_tree() or !scanner or !scanner.is_inside_tree():
		if OS.has_feature("web"):
			JavaScriptBridge.eval("console.log('DEBUG: Cannot start scan - invalid state')")
		return
		
	scanning = true
	scan_start_time = Time.get_ticks_msec() / 1000.0
	if OS.has_feature("web"):
		scan_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		scan_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
		RenderingServer.force_draw(true)
		JavaScriptBridge.eval("console.log('DEBUG: Starting scan...')")
	else:
		scan_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	scan_progress = 0.0
	is_single_scan = current_mode == ScanMode.FULLSCREEN
	perform_scan()

func stop_scan():
	if !is_single_scan:
		scanning = false
		if OS.has_feature("web"):
			scan_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			scan_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
			RenderingServer.force_draw(true)
		else:
			scan_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func perform_scan():
	if !is_inside_tree() or !scanner or !scanner.is_inside_tree():
		return
		
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - scan_start_time > max_scan_duration:
		if OS.has_feature("web"):
			JavaScriptBridge.eval("console.log('DEBUG: Max scan duration reached, stopping scan')")
		stop_scan()
		return
		
	if current_time - last_scan_time < scan_cooldown:
		return
	
	last_scan_time = current_time
	
	var space_state = get_world_3d().direct_space_state
	var scan_origin = scanner.global_position
		
	var actual_rays = rays_per_scan
	if OS.has_feature("web"):
		actual_rays = rays_per_scan / 2
	
	match current_mode:
		ScanMode.CONE:
			perform_cone_scan(space_state, scan_origin, actual_rays)
		ScanMode.LINE:
			perform_line_scan(space_state, scan_origin, actual_rays)
		ScanMode.WIDE:
			perform_wide_scan(space_state, scan_origin, actual_rays)
		ScanMode.FULLSCREEN:
			perform_fullscreen_scan(space_state, scan_origin)

func perform_cone_scan(space_state, scan_origin, rays: int):
	for _i in rays:
		var phi = rng.randf_range(-scan_angle, scan_angle)
		var theta = rng.randf_range(-scan_angle, scan_angle)
		
		var ray_direction = Vector3(
			sin(deg_to_rad(phi)) * cos(deg_to_rad(theta)),
			sin(deg_to_rad(theta)),
			-cos(deg_to_rad(phi)) * cos(deg_to_rad(theta))
		).normalized()
		cast_ray(space_state, scan_origin, ray_direction)

func perform_line_scan(space_state, scan_origin, rays: int):
	for i in rays:
		var theta = rng.randf_range(-line_width/2.0, line_width/2.0)
		var vertical_angle = (float(i) - float(rays/2.0)) * (scan_angle*2.0/float(rays))
		
		var ray_direction = Vector3(
			sin(deg_to_rad(theta)),
			sin(deg_to_rad(vertical_angle)),
			-cos(deg_to_rad(theta)) * cos(deg_to_rad(vertical_angle))
		).normalized()
		cast_ray(space_state, scan_origin, ray_direction)

func perform_wide_scan(space_state, scan_origin, rays: int):
	for i in rays:
		var phi = (float(i) - float(rays/2.0)) * (scan_angle*2.0/float(rays))
		var theta = rng.randf_range(-wide_height/2.0, wide_height/2.0)
		
		var ray_direction = Vector3(
			sin(deg_to_rad(phi)) * cos(deg_to_rad(theta)),
			sin(deg_to_rad(theta)),
			-cos(deg_to_rad(phi)) * cos(deg_to_rad(theta))
		).normalized()
		cast_ray(space_state, scan_origin, ray_direction)

func perform_fullscreen_scan(space_state, scan_origin):
	var fov = 90.0
	var points_per_line = 64
	
	var vertical_angle = lerp(-fov/2.0, fov/2.0, scan_progress)
	
	for i in points_per_line:
		if i % 2 == 0:
			continue
			
		var horizontal_angle = lerp(-fov/2.0, fov/2.0, float(i) / float(points_per_line - 1))
		
		var ray_direction = Vector3(
			sin(deg_to_rad(horizontal_angle)),
			sin(deg_to_rad(vertical_angle)),
			-cos(deg_to_rad(horizontal_angle)) * cos(deg_to_rad(vertical_angle))
		).normalized()
		
		ray_direction = scanner.global_transform.basis * ray_direction
		
		var query = PhysicsRayQueryParameters3D.create(scanner.global_position, scanner.global_position + ray_direction * scan_radius)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		query.collision_mask = 0xFFFFFFFF
		
		var result = space_state.intersect_ray(query)
		if result:
			var collider = result.collider
			var is_banana = collider.name == "Banana" or collider.get_parent().name == "Banana"
			var is_terrain = collider.get_collision_layer_value(2)
			create_scan_point(result.position, is_banana)
			update_scan_progress(is_terrain, is_banana, result.position)
	
	scan_progress += 0.05
	if scan_progress >= 1.0:
		scanning = false
		scan_progress = 0.0

func cast_ray(space_state, scan_origin, ray_direction):
	if !is_inside_tree() or !scanner or !scanner.is_inside_tree():
		return
		
	ray_direction = scanner.global_transform.basis * ray_direction
	var query = PhysicsRayQueryParameters3D.create(scanner.global_position, scanner.global_position + ray_direction * scan_radius)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 0xFFFFFFFF
	
	var result = space_state.intersect_ray(query)
	if result:
		var collider = result.collider
		var is_banana = collider.name == "Banana" or collider.get_parent().name == "Banana"
		var is_terrain = collider.get_collision_layer_value(2)
		
		create_scan_point(result.position, is_banana)
		update_scan_progress(is_terrain, is_banana, result.position)

func create_scan_point(pos: Vector3, is_banana: bool = false):
	if current_pool_size >= quality_settings[quality_level]["max_points"]:
		if scan_points.size() > 0:
			var oldest_point = scan_points.pop_front()
			oldest_point.point.queue_free()
			current_pool_size -= 1
	
	var point = MeshInstance3D.new()
	
	if is_banana:
		var mesh = SphereMesh.new()
		mesh.radius = 0.04
		mesh.height = 0.08
		mesh.radial_segments = 8
		mesh.rings = 4
		
		var unique_material = glitch_material.duplicate()
		unique_material.set_shader_parameter("time_offset", rng.randf() * 100.0)
		point.material_override = unique_material
		point.mesh = mesh
		
		banana_scan_points.push_back({
			"point": point,
			"material": unique_material,
			"position": pos,
			"creation_time": Time.get_ticks_msec() / 1000.0
		})
	else:
		point.mesh = shared_scan_mesh
		
		var material = base_scan_material.duplicate()
		var distance = global_position.distance_to(pos)
		var color = get_distance_color(distance)
		
		material.albedo_color = color
		material.emission = color
		material.emission_energy_multiplier = 3.0 + (1.0 - distance / far_distance) * 2.0
		point.material_override = material
		
		scan_points.push_back({
			"point": point,
			"material": material,
			"position": pos
		})
		
		if scanning:
			create_beam(pos)
	
	scan_container.add_child(point)
	point.global_position = pos
	
	current_pool_size += 1

func get_distance_color(distance: float) -> Color:
	if distance <= close_distance:
		return Color(1.0, 0.0, 0.0, 1.0)
	elif distance <= mid_distance:
		var t = (distance - close_distance) / (mid_distance - close_distance)
		return Color(1.0, t, 0.0, 1.0)
	elif distance <= far_distance:
		var t = (distance - mid_distance) / (far_distance - mid_distance)
		return Color(1.0 - t, 1.0 - t, t, 1.0)
	else:
		return Color(0.0, 0.0, 1.0, 1.0)

func _process(delta):
	if !is_inside_tree():
		if OS.has_feature("web"):
			JavaScriptBridge.eval("console.error('DEBUG ERROR: Player node not in tree during process')")
		push_error("DEBUG ERROR: Player node not in tree during process")
		return
		
	if OS.has_feature("web") and scanning:
		if Engine.get_process_frames() % 30 == 0:  
			scan_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			RenderingServer.force_draw(true)
			if scan_viewport.get_texture().get_width() == 0:
				JavaScriptBridge.eval("console.log('DEBUG: Attempting to recover from WebGL context loss')")
				stop_scan()
				await get_tree().create_timer(0.5).timeout
				scan_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
				RenderingServer.force_draw(true)
	
	if Engine.get_process_frames() % 300 == 0:
		if OS.has_feature("web"):
			var stats = """
				DEBUG STATS:
				- Active beams: %d
				- Scan points: %d
				- Current pool size: %d
				- Banana points: %d
				- FPS: %d
				- Frame time (ms): %f
			""" % [
				active_beams.size(),
				scan_points.size(),
				current_pool_size,
				banana_scan_points.size(),
				Engine.get_frames_per_second(),
				1000.0 / Engine.get_frames_per_second()
			]
			JavaScriptBridge.eval("console.log(`%s`)" % stats)
		
		print("DEBUG STATS:")
		print("- Active beams: ", active_beams.size())
		print("- Scan points: ", scan_points.size())
		print("- Current pool size: ", current_pool_size)
		print("- Banana points: ", banana_scan_points.size())
		print("- FPS: ", Engine.get_frames_per_second())
		print("- Frame time (ms): ", 1000.0 / Engine.get_frames_per_second())
		
	if scanning:
		if !scanner or !scanner.is_inside_tree():
			push_error("DEBUG ERROR: Scanner not valid during scanning")
			return
		
		perform_scan()
		if thermal_camera:
			var scan_shake = sin(Time.get_ticks_msec() * 0.02) * 0.002
			thermal_camera.position.y = -0.2 + scan_shake
			thermal_camera.rotation_degrees.x = -10 + scan_shake * 2.0
			
			beam_material.emission_energy_multiplier = 2.0 + sin(Time.get_ticks_msec() * 0.01) * 0.5
	else:
		if thermal_camera:
			thermal_camera.position.y = lerp(thermal_camera.position.y, -0.2, delta * 10.0)
			thermal_camera.rotation_degrees.x = lerp(thermal_camera.rotation_degrees.x, -10.0, delta * 10.0)
		
		for beam in active_beams:
			if is_instance_valid(beam):
				beam.queue_free()
		active_beams.clear()
		beam_cleanup_data.clear()
	
	update_point_colors()
	update_banana_particles(delta)

func update_point_colors():
	if !is_inside_tree() or scan_points.size() == 0:
		return
		
	var chunk_size = 200
	var total_chunks = max(1, (scan_points.size() + chunk_size - 1) / chunk_size)
	
	var current_chunk = int(Time.get_ticks_msec() / 16.67) % total_chunks
	var start_index = current_chunk * chunk_size
	var end_index = min(start_index + chunk_size, scan_points.size())
	
	for i in range(start_index, end_index):
		if i >= scan_points.size():
			break
			
		var point_data = scan_points[i]
		if !is_instance_valid(point_data.point) or !point_data.point.is_inside_tree():
			continue
			
		var distance = global_position.distance_to(point_data.position)
		var new_color = get_distance_color(distance)
		if point_data.material.albedo_color != new_color:
			point_data.material.albedo_color = new_color
			point_data.material.emission = new_color

func update_banana_particles(delta):
	var current_time = Time.get_ticks_msec() / 1000.0
	var banana_scan_progress = 0.0
	if ui:
		banana_scan_progress = ui.banana_scanned
	
	for point_data in banana_scan_points:
		var time_alive = current_time - point_data.creation_time
		var intensity = (sin(time_alive * 5.0) * 0.25 + 0.75) * banana_scan_progress
		point_data.material.set_shader_parameter("glitch_intensity", intensity)
		
		var glitch_offset = Vector3(
			sin(time_alive * 10.0 + point_data.creation_time) * 0.05,
			cos(time_alive * 8.0 + point_data.creation_time) * 0.05,
			sin(time_alive * 12.0 + point_data.creation_time) * 0.05
		) * banana_scan_progress
		
		point_data.point.global_position = point_data.position + glitch_offset

func reset_scan_state():
	scanning = false
	scan_progress = 0.0
	is_single_scan = false
	scan_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func calculate_max_scannable_cells():
	var terrain = get_node("../WorldEnvironment/Map/Map")
	if terrain:
		var aabb = terrain.get_aabb()
		var terrain_size = aabb.size * terrain.scale
		print("Terrain AABB: ", aabb)
		print("Terrain scale: ", terrain.scale)
		print("Terrain size: ", terrain_size)
		
		var grid_cells_x = ceil(terrain_size.x / grid_size)
		var grid_cells_z = ceil(terrain_size.z / grid_size)
		max_scannable_cells = int(grid_cells_x * grid_cells_z)
		
		max_scannable_cells = int(max_scannable_cells * 0.8)
		
		print("Grid size: ", grid_size)
		print("Grid cells X: ", grid_cells_x)
		print("Grid cells Z: ", grid_cells_z)
		print("Raw max cells: ", grid_cells_x * grid_cells_z)
		print("Adjusted max scannable cells (80%): ", max_scannable_cells)
		
		if max_scannable_cells <= 0:
			max_scannable_cells = 100
			print("WARNING: Invalid max_scannable_cells, using fallback value of 100")

func get_grid_key(pos: Vector3) -> String:
	var grid_x = floor(pos.x / grid_size)
	var grid_z = floor(pos.z / grid_size)
	return "%d,%d" % [grid_x, grid_z]

func update_scan_progress(terrain_hit: bool, banana_hit: bool, hit_position: Vector3):
	if terrain_hit:
		var grid_key = get_grid_key(hit_position)
		if not scanned_positions.has(grid_key):
			scanned_positions[grid_key] = true
			if max_scannable_cells > 0:
				terrain_scanned = min(float(scanned_positions.size()) / float(max_scannable_cells), 0.8)
				
				var scaled_progress = min(terrain_scanned * 1.25, 1.0)
				
				if ui:
					ui.terrain_scanned = scaled_progress
					ui.update_progress_bars()
					
					if terrain_scanned >= 0.8:
						if scan_container:
							scan_container.queue_free()
						get_tree().change_scene_to_file("res://win.tscn")
	
	if banana_hit:
		if ui:
			ui.banana_scanned = min(ui.banana_scanned + 0.02, 1.0)
			ui.update_progress_bars()
			ui.check_game_conditions()

func cleanup_beam(beam_id: String):
	if beam_cleanup_data.has(beam_id):
		var beam = beam_cleanup_data[beam_id].beam
		if is_instance_valid(beam) and !beam.is_queued_for_deletion():
			beam.queue_free()
		var index = active_beams.find(beam)
		if index != -1:
			active_beams.remove_at(index)
		beam_cleanup_data.erase(beam_id)

func create_beam(target_pos: Vector3):
	if !is_inside_tree() or !scanner or !scanner.is_inside_tree() or !thermal_camera or !thermal_camera.is_inside_tree():
		return
		
	while active_beams.size() >= MAX_BEAMS:
		var old_beam = active_beams.pop_front()
		if is_instance_valid(old_beam):
			old_beam.queue_free()
	
	var beam = MeshInstance3D.new()
	var mesh = ImmediateMesh.new()
	
	beam.mesh = mesh
	beam.material_override = beam_material
	
	var dir_to_target = (target_pos - scanner.global_position).normalized()
	
	var beam_local_offset = Vector3(0, 0.1, 0)
	var visual_start = thermal_camera.global_transform * beam_local_offset
	
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(visual_start)
	mesh.surface_add_vertex(target_pos)
	mesh.surface_end()
	
	scan_container.add_child(beam)
	active_beams.push_back(beam)
	
	var beam_id = str(Time.get_ticks_msec()) + str(rng.randi())
	
	beam_cleanup_data[beam_id] = {
		"beam": beam,
		"creation_time": Time.get_ticks_msec()
	}
	
	var timer = get_tree().create_timer(0.1)
	timer.timeout.connect(func(): cleanup_beam(beam_id))

func _exit_tree():
	for beam in active_beams:
		if is_instance_valid(beam):
			beam.queue_free()
	active_beams.clear()
	beam_cleanup_data.clear()
