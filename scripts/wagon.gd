extends PathFollow3D
class_name Wagon

@export var body_mesh: MeshInstance3D
@onready var number_label: Label3D = $Visual/NumberLabel

var current_symbol: String = ""

func setup(symbol: String) -> void:
	current_symbol = symbol
	
	if number_label:
		number_label.text = symbol
		
	if body_mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = AutomataPalette.get_symbol_color(symbol)
		mat.roughness = 0.4
		
		if body_mesh.get_surface_override_material_count() > 1:
			body_mesh.set_surface_override_material(1, mat)
		else:
			body_mesh.set_surface_override_material(0, mat)

func play_consumed_effect() -> void:
	var tween := create_tween()
	tween.tween_property($Visual, "scale", Vector3(1.25, 1.25, 1.25), 0.1)
	tween.tween_property($Visual, "scale", Vector3(1.0, 1.0, 1.0), 0.15)
