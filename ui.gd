extends Control

@onready var current_mode_label = $Mode/CurrentMode

func _ready():
	if current_mode_label:
		current_mode_label.text = "CONE"

func update_mode(mode: String):
	if current_mode_label:
		current_mode_label.text = mode 
