extends Control

@onready var current_mode_label = $ModePanel/Mode/CurrentMode
@onready var terrain_progress_bar = $ProgressPanel/Progress/TerrainProgress/ProgressBar
@onready var terrain_progress_label = $ProgressPanel/Progress/TerrainProgress/Label
@onready var banana_progress_bar = $ProgressPanel/Progress/BananaWarning/ProgressBar
@onready var banana_progress_label = $ProgressPanel/Progress/BananaWarning/Label
@onready var controls_panel = $ControlsPanel
@onready var mode_panel = $ModePanel
@onready var progress_panel = $ProgressPanel
@onready var tutorial_overlay = $TutorialOverlay
@onready var tutorial_ok_button = $TutorialOverlay/CenterContainer/PanelContainer/VBoxContainer/OkButton
@onready var glitch_overlay = $GlitchOverlay

var terrain_scanned = 0.0
var banana_scanned = 0.0

var grid_size = 2.0
var scanned_positions = {}
var max_scannable_cells = 0

const WIN_THRESHOLD = 0.8
const LOSE_THRESHOLD = 0.5
const SAVE_FILE = "user://game_data.save"

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if current_mode_label:
		current_mode_label.text = "CONE"
	
	controls_panel.modulate.a = 0
	mode_panel.modulate.a = 0
	progress_panel.modulate.a = 0
	
	if glitch_overlay:
		glitch_overlay.material.set_shader_parameter("glitch_intensity", 0.0)
	
	var tween = create_tween()
	tween.tween_property(progress_panel, "modulate:a", 1.0, 0.5)
	tween.tween_property(mode_panel, "modulate:a", 1.0, 0.5).set_delay(0.2)
	tween.tween_property(controls_panel, "modulate:a", 1.0, 0.5).set_delay(0.2)
	
	calculate_max_scannable_cells()
	update_progress_bars()
	
	show_tutorial()
	print("Tutorial button path: ", tutorial_ok_button.get_path())
	print("Tutorial button visible: ", tutorial_ok_button.visible)
	print("Tutorial button disabled: ", tutorial_ok_button.disabled)
	
	if tutorial_ok_button.is_connected("pressed", _on_tutorial_ok_pressed):
		tutorial_ok_button.pressed.disconnect(_on_tutorial_ok_pressed)
	tutorial_ok_button.pressed.connect(_on_tutorial_ok_pressed)
	
	tutorial_ok_button.gui_input.connect(_on_button_input)

func _on_button_input(event):
	print("Button received input: ", event)
	if event is InputEventMouseButton:
		print("Mouse button event: ", event.button_index, " pressed: ", event.pressed)

func is_first_time_playing() -> bool:
	print("Checking save file at: ", SAVE_FILE)
	if FileAccess.file_exists(SAVE_FILE):
		var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
		if file:
			var data = file.get_var()
			file.close()
			print("Save file data: ", data)
			if data is Dictionary and data.has("tutorial_completed"):
				return !data["tutorial_completed"]
	print("No save file found or invalid data")
	return true

func mark_tutorial_completed():
	print("Marking tutorial as completed")
	var file = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file:
		file.store_var({"tutorial_completed": true})
		file.close()
		print("Tutorial completion saved")
	else:
		print("Failed to save tutorial completion")

func show_tutorial():
	print("Showing tutorial")
	tutorial_overlay.show()
	tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var center = tutorial_overlay.get_node("CenterContainer")
	var panel = center.get_node("PanelContainer")
	var vbox = panel.get_node("VBoxContainer")
	
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	
	tutorial_ok_button.mouse_filter = Control.MOUSE_FILTER_STOP
	tutorial_ok_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tutorial_ok_button.focus_mode = Control.FOCUS_ALL
	
	tutorial_ok_button.show()
	tutorial_ok_button.disabled = false
	
	tutorial_overlay.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(tutorial_overlay, "modulate:a", 1.0, 0.5)

func _on_tutorial_ok_pressed():
	print("Tutorial OK button pressed!")
	var tween = create_tween()
	tween.tween_property(tutorial_overlay, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		print("Tutorial hide callback")
		tutorial_overlay.hide()
		mark_tutorial_completed()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	)

func calculate_max_scannable_cells():
	var terrain = get_node("../WorldEnvironment/Map/Map")
	if terrain:
		var aabb = terrain.get_aabb()
		var terrain_size = aabb.size * terrain.scale
		var total_volume = terrain_size.x * terrain_size.y * terrain_size.z
		var cell_volume = grid_size * grid_size * grid_size
		max_scannable_cells = int(total_volume / cell_volume)
		print("Calculated max scannable cells: ", max_scannable_cells)

func update_mode(mode: String):
	if current_mode_label:
		var tween = create_tween()
		tween.tween_property(mode_panel, "modulate", Color(1.5, 1.5, 1.5, 1), 0.1)
		tween.tween_property(mode_panel, "modulate", Color(1, 1, 1, 1), 0.1)
		
		current_mode_label.text = mode

func get_grid_key(pos: Vector3) -> String:
	var grid_x = floor(pos.x / grid_size)
	var grid_y = floor(pos.y / grid_size)
	var grid_z = floor(pos.z / grid_size)
	return "%d,%d,%d" % [grid_x, grid_y, grid_z]

func update_scan_progress(terrain_hit: bool, banana_hit: bool, hit_position: Vector3):
	if terrain_hit:
		var grid_key = get_grid_key(hit_position)
		if not scanned_positions.has(grid_key):
			scanned_positions[grid_key] = true
			if max_scannable_cells > 0:
				terrain_scanned = min(float(scanned_positions.size()) / max_scannable_cells, 1.0)
				
				var tween = create_tween()
				tween.tween_property(terrain_progress_bar, "modulate", Color(1.2, 1.2, 1.2, 1), 0.1)
				tween.tween_property(terrain_progress_bar, "modulate", Color(1, 1, 1, 1), 0.1)
	
	if banana_hit:
		banana_scanned = min(banana_scanned + 0.02, 1.0)
		
		if glitch_overlay:
			var intensity = banana_scanned * 1.5
			glitch_overlay.material.set_shader_parameter("glitch_intensity", intensity)
		
		var tween = create_tween()
		tween.tween_property(banana_progress_bar, "modulate", Color(1.5, 1.2, 1.2, 1), 0.1)
		tween.tween_property(banana_progress_bar, "modulate", Color(1, 1, 1, 1), 0.1)
	
	update_progress_bars()
	check_game_conditions()

func update_progress_bars():
	if terrain_progress_bar and terrain_progress_label:
		terrain_progress_bar.material.set_shader_parameter("progress", terrain_scanned)
		terrain_progress_label.text = "Terrain Scanned: %d%%" % (terrain_scanned * 100)
		
		if terrain_scanned >= WIN_THRESHOLD:
			terrain_progress_bar.material.set_shader_parameter("foreground_color", Color(0, 1, 0, 0.8))
			terrain_progress_bar.material.set_shader_parameter("glow_intensity", 0.7)
		else:
			terrain_progress_bar.material.set_shader_parameter("foreground_color", Color(0, 0.8, 0, 0.8))
			terrain_progress_bar.material.set_shader_parameter("glow_intensity", 0.5)
	
	if banana_progress_bar and banana_progress_label:
		banana_progress_bar.material.set_shader_parameter("progress", banana_scanned)
		banana_progress_label.text = "Banana Detection: %d%%" % (banana_scanned * 100)
		
		var warning_color
		var wave_speed
		var particle_amount
		if banana_scanned >= 1.0:
			warning_color = Color(1, 0, 0, 0.8)
			wave_speed = 4.0
			particle_amount = 40
		elif banana_scanned >= LOSE_THRESHOLD:
			warning_color = Color(1, 0.2, 0, 0.8)
			wave_speed = 3.0
			particle_amount = 30
		elif banana_scanned >= LOSE_THRESHOLD * 0.75:
			warning_color = Color(1, 0.3, 0, 0.8)
			wave_speed = 2.5
			particle_amount = 25
		else:
			warning_color = Color(1, 0.5, 0, 0.8)
			wave_speed = 2.0
			particle_amount = 20
		
		banana_progress_bar.material.set_shader_parameter("foreground_color", warning_color)
		banana_progress_bar.material.set_shader_parameter("wave_speed", wave_speed)
		banana_progress_bar.material.set_shader_parameter("particle_amount", particle_amount)
		banana_progress_bar.material.set_shader_parameter("glow_intensity", min(0.5 + banana_scanned * 0.5, 1.0))

func check_game_conditions():
	if banana_scanned >= 1.0:
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color(1, 0, 0, 0), 0.5)
		tween.tween_callback(func():
			get_tree().change_scene_to_file("res://game_over.tscn")
		)
	elif banana_scanned >= LOSE_THRESHOLD:
		if glitch_overlay:
			var intensity = (banana_scanned - LOSE_THRESHOLD) * 3.0
			glitch_overlay.material.set_shader_parameter("glitch_intensity", intensity)
	elif terrain_scanned >= WIN_THRESHOLD:
		get_tree().change_scene_to_file("res://win.tscn")
