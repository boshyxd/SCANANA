extends Node3D

@onready var scan_container = $ScannerPoints
@onready var logo_mesh = $Logo/LogoMesh
@onready var banana_mesh = $Logo/BananaMesh
@onready var animation_player = $AnimationPlayer
@onready var scan_timer = $ScanTimer

var rng = RandomNumberGenerator.new()
var scan_points = []
var point_size = 0.05
var scan_radius = 10.0
var rays_per_scan = 32
var max_points = 2000

func _ready():
	$Title/VBoxContainer/StartButton.pressed.connect(_on_start_button_pressed)
	$Title/VBoxContainer/QuitButton.pressed.connect(_on_quit_button_pressed)
	
	animation_player.play("title_rotate")
	
	scan_timer.timeout.connect(_on_scan_timer_timeout)
	
	rng.randomize()
	
	logo_mesh.visible = true
	banana_mesh.visible = true

func _on_start_button_pressed():
	var tween = create_tween()
	for point in scan_points:
		tween.parallel().tween_property(point, "scale", Vector3.ZERO, 0.5)
	
	tween.tween_callback(func():
		for point in scan_points:
			point.queue_free()
		scan_points.clear()
		
		get_tree().change_scene_to_file("res://node_3d.tscn")
	)

func _on_quit_button_pressed():
	get_tree().quit()

func _on_scan_timer_timeout():
	perform_scan()

func perform_scan():
	var space_state = get_world_3d().direct_space_state
	
	while scan_points.size() > max_points:
		var old_point = scan_points.pop_front()
		old_point.queue_free()
	
	for _i in rays_per_scan:
		var phi = rng.randf_range(-180, 180)
		var theta = rng.randf_range(-180, 180)
		
		var ray_direction = Vector3(
			sin(deg_to_rad(phi)) * cos(deg_to_rad(theta)),
			sin(deg_to_rad(theta)),
			-cos(deg_to_rad(phi)) * cos(deg_to_rad(theta))
		).normalized()
		
		ray_direction = $Camera3D.global_transform.basis * ray_direction
		
		var query = PhysicsRayQueryParameters3D.create(
			$Camera3D.global_position,
			$Camera3D.global_position + ray_direction * scan_radius
		)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		
		var result = space_state.intersect_ray(query)
		if result:
			create_scan_point(result.position)

func create_scan_point(pos: Vector3):
	var point = CSGSphere3D.new()
	point.radius = point_size
	
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	
	var distance = $Camera3D.global_position.distance_to(pos)
	var color = get_distance_color(distance)
	material.albedo_color = color
	material.emission = color
	
	point.material = material
	scan_container.add_child(point)
	point.global_position = pos
	
	point.scale = Vector3.ZERO
	var tween = create_tween()
	tween.tween_property(point, "scale", Vector3.ONE, 0.2)
	
	scan_points.push_back(point)

func get_distance_color(distance: float) -> Color:
	var close_distance = 2.0
	var mid_distance = 5.0
	var far_distance = 10.0
	
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