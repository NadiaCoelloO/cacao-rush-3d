extends Control
## Dual-mode selector: Arcade 2D (separate build) vs 3D Cinemático (this project).
## Display world name: Cuyabeno (code id remains selva).

@onready var btn_arcade: Button = $Center/BtnArcade2D
@onready var btn_cinematic: Button = $Center/BtnCinematic3D
@onready var info_label: Label = $Center/InfoLabel


func _ready() -> void:
	btn_arcade.pressed.connect(_on_arcade_pressed)
	btn_cinematic.pressed.connect(_on_cinematic_pressed)
	info_label.text = "Pilot: Cuyabeno (world id selva) · greybox only"


func _on_arcade_pressed() -> void:
	# Arcade 2D truth lives in sand-vivid-dawn-sail — separate build, no launch here.
	info_label.text = (
		"Arcade 2D runs from sand-vivid-dawn-sail / separate build.\n"
		+ "No launch required from this Godot project."
	)


func _on_cinematic_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/pilot_cuyabeno.tscn")
