extends Control

@onready var bsod_sound = $BSODSound

func _ready():
	var system_font = SystemFont.new()
	system_font.font_names = ["Consolas", "Lucida Console", "DejaVu Sans Mono", "Courier New", "monospace"]
	
	var labels = [$VBoxContainer/ErrorTitle, $VBoxContainer/ErrorCode, $VBoxContainer/ErrorDetails]
	for label in labels:
		label.add_theme_font_override("font", system_font)
	
	$VBoxContainer/RestartButton.add_theme_font_override("font", system_font)
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if $VBoxContainer/RestartButton:
		$VBoxContainer/RestartButton.pressed.connect(_on_restart_button_pressed)
	else:
		push_error("Restart button not found")
	
	# Play BSOD sound when screen appears
	if bsod_sound:
		bsod_sound.play()

func _input(event):
	if event is InputEventKey and event.pressed:
		_on_restart_button_pressed()

func _on_restart_button_pressed():
	# Stop BSOD sound if it's still playing
	if bsod_sound and bsod_sound.playing:
		bsod_sound.stop()
	
	var scan_container = get_tree().root.get_node_or_null("ScanPoints")
	if scan_container:
		scan_container.queue_free()
	
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(0, 0, 0, 1), 0.5)
	tween.tween_callback(func():
		var err = get_tree().change_scene_to_file("res://title_screen.tscn")
		if err != OK:
			push_error("Failed to load title screen")
	)
