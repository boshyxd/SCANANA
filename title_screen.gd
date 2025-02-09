extends Control

@onready var title_label = $CenterContainer/VBoxContainer/Title
@onready var description_label = $CenterContainer/VBoxContainer/Description
@onready var buttons_container = $CenterContainer/VBoxContainer/ButtonsContainer

func _ready():
	title_label.modulate.a = 0
	description_label.modulate.a = 0
	buttons_container.modulate.a = 0
	
	var tween = create_tween()
	tween.tween_property(title_label, "modulate:a", 1.0, 1.0)
	tween.tween_property(description_label, "modulate:a", 1.0, 0.5)
	tween.tween_property(buttons_container, "modulate:a", 1.0, 0.5)
	
	_start_title_pulse()
	
	if $CenterContainer/VBoxContainer/ButtonsContainer/StartButton:
		$CenterContainer/VBoxContainer/ButtonsContainer/StartButton.pressed.connect(_on_start_button_pressed)
	if $CenterContainer/VBoxContainer/ButtonsContainer/QuitButton:
		$CenterContainer/VBoxContainer/ButtonsContainer/QuitButton.pressed.connect(_on_quit_button_pressed)

func _start_title_pulse():
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(title_label, "theme_override_colors/font_outline_color", Color(0.4, 0, 0, 1), 1.0)
	tween.tween_property(title_label, "theme_override_colors/font_outline_color", Color(0.2, 0, 0, 1), 1.0)

func _on_start_button_pressed():
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 0, 0, 0), 0.5)
	tween.tween_callback(func():
		var err = get_tree().change_scene_to_file("res://node_3d.tscn")
		if err != OK:
			push_error("Failed to load main scene")
	)

func _on_quit_button_pressed():
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(0, 0, 0, 0), 0.5)
	tween.tween_callback(func():
		get_tree().quit()
	)
