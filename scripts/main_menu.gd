extends Control

@export_file("*.tscn") var tutorial_scene_path: String
@export_file("*.tscn") var arcade_scene_path: String
@export_file("*.tscn") var options_scene_path: String

@onready var tutorial_btn: Button = $CenterContainer/VBoxContainer/TutorialButton
@onready var arcade_btn: Button = $CenterContainer/VBoxContainer/ArcadeButton
@onready var options_btn: Button = $CenterContainer/VBoxContainer/OptionsButton
@onready var feedback_lbl: Label = $CenterContainer/VBoxContainer/FeedbackLabel

func _ready() -> void:
	tutorial_btn.pressed.connect(_on_tutorial_pressed)
	arcade_btn.pressed.connect(_on_arcade_pressed)
	options_btn.pressed.connect(_on_options_pressed)
	
	tutorial_btn.grab_focus()

func _on_tutorial_pressed() -> void:
	if tutorial_scene_path.is_empty():
		feedback_lbl.text = "Selecione a cena do Tutorial no Inspector do MainMenu!"
		return
	get_tree().change_scene_to_file(tutorial_scene_path)

func _on_arcade_pressed() -> void:
	if arcade_scene_path.is_empty():
		feedback_lbl.text = "Modo Arcade em desenvolvimento!"
		return
	get_tree().change_scene_to_file(arcade_scene_path)

func _on_options_pressed() -> void:
	if options_scene_path.is_empty():
		feedback_lbl.text = "Menu de Opções em desenvolvimento!"
		return
	get_tree().change_scene_to_file(options_scene_path)
