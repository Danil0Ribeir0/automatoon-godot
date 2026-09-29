extends PathFollow3D
class_name Wagon

@export var body_mesh: MeshInstance3D
@onready var number_label: Label3D = $Visual/NumberLabel

const DIGIT_COLORS: Dictionary = {
	"0": Color("#7f8c8d"), # Cinza
	"1": Color("#e74c3c"), # Vermelho
	"2": Color("#3498db"), # Azul
	"3": Color("#2ecc71"), # Verde
	"4": Color("#f1c40f"), # Amarelo
	"5": Color("#9b59b6"), # Roxo
	"6": Color("#e67e22"), # Laranja
	"7": Color("#1abc9c"), # Turquesa
	"8": Color("#e84393"), # Rosa choque
	"9": Color("#ffffff")  # Branco
}

var current_symbol: String = ""

func setup(symbol: String) -> void:
	current_symbol = symbol
	
	if number_label:
		number_label.text = symbol
		
	if body_mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = DIGIT_COLORS.get(symbol, Color.WHITE)
		mat.roughness = 0.4
		
		# Se o modelo tiver 2 materiais (0 = Metal, 1 = Pintura), pinta só o 1!
		if body_mesh.get_surface_override_material_count() > 1:
			body_mesh.set_surface_override_material(1, mat)
		else:
			body_mesh.set_surface_override_material(0, mat)
