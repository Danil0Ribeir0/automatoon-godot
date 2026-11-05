class_name TerminalView
extends Node3D

## Casinha do Spawn/Exit. O modelo é feito com a porta da grid virada para +X
## (Leste); `apply` gira para a direção da grid, pinta os detalhes com a cor
## do terminal e escreve a placa.

@onready var _light: MeshInstance3D = get_node_or_null("Lamp/Light")
@onready var _trims: Node = get_node_or_null("Trims")
@onready var _sign: Label3D = get_node_or_null("Sign")


func apply(inward_dir: int, signal_color: Color, title := "") -> void:
	var o: Vector2i = GridModel.DIR_OFFSETS.get(inward_dir, Vector2i(1, 0))
	rotation.y = atan2(-o.y, o.x) # +X local passa a apontar para a grid

	var glow := StandardMaterial3D.new()
	glow.albedo_color = signal_color
	glow.emission_enabled = true
	glow.emission = signal_color
	glow.emission_energy_multiplier = 1.2
	if _light:
		_light.material_override = glow

	var paint := StandardMaterial3D.new()
	paint.albedo_color = signal_color
	paint.roughness = 1.0
	if _trims:
		for child in _trims.get_children():
			if child is MeshInstance3D:
				child.material_override = paint

	if _sign:
		_sign.text = title
		_sign.modulate = Color.WHITE
		_sign.outline_modulate = signal_color.darkened(0.5)
		_sign.visible = not title.is_empty()
