extends Control

func _ready():
	# Set monospace font for all labels
	var system_font = SystemFont.new()
	system_font.font_names = ["Consolas", "Lucida Console", "DejaVu Sans Mono", "Courier New", "monospace"]
	
	var labels = [$VBoxContainer/ErrorTitle, $VBoxContainer/ErrorCode, $VBoxContainer/ErrorDetails]
	for label in labels:
		label.add_theme_font_override("font", system_font)
	
	# Set monospace font for button
	$VBoxContainer/RestartButton.add_theme_font_override("font", system_font)
	
	# Show mouse cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Connect restart button signal
	if $VBoxContainer/RestartButton:
		$VBoxContainer/RestartButton.pressed.connect(_on_restart_button_pressed)
	else:
		push_error("Restart button not found")
	
	# Play error sound effect
	# TODO: Add Windows error sound when assets are available

func _input(event):
	if event is InputEventKey and event.pressed:
		_on_restart_button_pressed()

func _on_restart_button_pressed():
	# Clear all existing scan points
	var scan_container = get_tree().root.get_node_or_null("ScanPoints")
	if scan_container:
		scan_container.queue_free()
	
	# Change scene back to title screen with fade effect
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(0, 0, 0, 1), 0.5)
	tween.tween_callback(func():
		var err = get_tree().change_scene_to_file("res://title_screen.tscn")
		if err != OK:
			push_error("Failed to load title screen")
	) 
