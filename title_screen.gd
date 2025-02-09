extends Control

@onready var title_label = $CenterContainer/VBoxContainer/Title
@onready var description_label = $CenterContainer/VBoxContainer/Description
@onready var buttons_container = $CenterContainer/VBoxContainer/ButtonsContainer
@onready var game_jam_banner = $CenterContainer/VBoxContainer/GameJamBanner
@onready var title_music = $TitleMusic

var original_texts = {}
var glitch_chars = ["4", "3", "1", "0", "7", "X", "_", "/", "\\", "|", "=", "#", "$", "%", "&"]

func _ready():
	var system_font = SystemFont.new()
	system_font.font_names = ["Consolas", "Lucida Console", "DejaVu Sans Mono", "Courier New", "monospace"]
	
	var labels = [title_label, description_label, game_jam_banner]
	for label in labels:
		label.add_theme_font_override("font", system_font)
	
	for button in buttons_container.get_children():
		button.add_theme_font_override("font", system_font)
	
	# Store original texts for glitch effect
	original_texts["title"] = title_label.text
	original_texts["desc1"] = "SCAN_EVERYTHING.exe"
	original_texts["desc2"] = "AVOID_BANANA.dll"
	original_texts["banner"] = game_jam_banner.text
	original_texts["start"] = $CenterContainer/VBoxContainer/ButtonsContainer/StartButton.text
	original_texts["quit"] = $CenterContainer/VBoxContainer/ButtonsContainer/QuitButton.text
	
	title_label.modulate.a = 0
	description_label.modulate.a = 0
	buttons_container.modulate.a = 0
	
	var tween = create_tween()
	tween.tween_property(title_label, "modulate:a", 1.0, 1.0)
	tween.tween_property(description_label, "modulate:a", 1.0, 0.5)
	tween.tween_property(buttons_container, "modulate:a", 1.0, 0.5)
	
	_start_title_pulse()
	_start_glitch_effects()
	
	if $CenterContainer/VBoxContainer/ButtonsContainer/StartButton:
		$CenterContainer/VBoxContainer/ButtonsContainer/StartButton.pressed.connect(_on_start_button_pressed)
	if $CenterContainer/VBoxContainer/ButtonsContainer/QuitButton:
		$CenterContainer/VBoxContainer/ButtonsContainer/QuitButton.pressed.connect(_on_quit_button_pressed)

func _start_title_pulse():
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(title_label, "theme_override_colors/font_outline_color", Color(0.4, 0, 0, 1), 0.5)
	tween.tween_property(title_label, "theme_override_colors/font_outline_color", Color(0.2, 0, 0, 1), 0.5)

func _start_glitch_effects():
	# Major glitch effect for title
	var title_glitch = create_tween()
	title_glitch.set_loops()
	title_glitch.tween_interval(2.0)
	title_glitch.tween_callback(func():
		if randf() > 0.5:
			_apply_glitch_effect(title_label, "title", 0.15)
	)
	
	# Subtle glitches for description
	var desc_glitch = create_tween()
	desc_glitch.set_loops()
	desc_glitch.tween_interval(3.0)
	desc_glitch.tween_callback(func():
		if randf() > 0.7:
			var lines = description_label.text.split("\n")
			if randf() > 0.5:
				lines[0] = _glitch_text(original_texts["desc1"])
			else:
				lines[1] = _glitch_text(original_texts["desc2"])
			description_label.text = "\n".join(lines)
			await get_tree().create_timer(0.1).timeout
			description_label.text = original_texts["desc1"] + "\n" + original_texts["desc2"]
	)
	
	# Quick glitches for buttons
	var button_glitch = create_tween()
	button_glitch.set_loops()
	button_glitch.tween_interval(4.0)
	button_glitch.tween_callback(func():
		if randf() > 0.8:
			var start_btn = $CenterContainer/VBoxContainer/ButtonsContainer/StartButton
			var quit_btn = $CenterContainer/VBoxContainer/ButtonsContainer/QuitButton
			if randf() > 0.5:
				start_btn.text = "> " + _glitch_text("START_SCAN.exe")
				await get_tree().create_timer(0.08).timeout
				start_btn.text = original_texts["start"]
			else:
				quit_btn.text = "> " + _glitch_text("EXIT.exe")
				await get_tree().create_timer(0.08).timeout
				quit_btn.text = original_texts["quit"]
	)

func _apply_glitch_effect(label: Label, text_key: String, duration: float):
	var glitch_variations = [
		"SC4N4N4",
		"5C4N4N4",
		"SC4N4NA",
		"5CAN4NA",
		"SCAN4N4",
		"|SCAN4N4|",
		"[SCAN4N4]"
	]
	
	label.text = glitch_variations[randi() % glitch_variations.size()]
	await get_tree().create_timer(duration).timeout
	label.text = original_texts[text_key]

func _glitch_text(text: String) -> String:
	var result = ""
	for c in text:
		if randf() > 0.7:
			result += glitch_chars[randi() % glitch_chars.size()]
		else:
			result += c
	return result

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
