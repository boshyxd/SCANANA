extends Control

@onready var restart_button = $CenterContainer/PanelContainer/VBoxContainer/RestartButton

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	restart_button.pressed.connect(_on_restart_pressed)
	
	var scan_container = get_node_or_null("/root/ScanPoints")
	if scan_container:
		scan_container.queue_free()

func _on_restart_pressed():
	get_tree().change_scene_to_file("res://title_screen.tscn")