class_name WagonView
extends Node3D

## Partes pintadas com a cor do símbolo (inclui os filhos).
@export var tinted_parts: Array[NodePath] = [^"Chassis/Hull"]

@onready var _label: Label3D = get_node_or_null("SymbolLabel")


func apply(definition: SymbolDefinition) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = definition.color if definition else Color.MAGENTA
	for part in tinted_parts:
		var node := get_node_or_null(part)
		if node:
			_tint(node, mat)
	if _label:
		_label.text = String(definition.id) if definition else "?"


func _tint(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_tint(child, mat)
