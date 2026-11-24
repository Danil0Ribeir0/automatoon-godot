class_name ObstacleView
extends Node3D

## Obstáculo baixo (não tapa as células de trás).
## A variante sai da posição da célula: a mesma fase sempre tem o mesmo visual.
@export var variants: PackedStringArray = ["Rocks", "Stump", "Hay"]


func apply(cell: Vector2i) -> void:
	var pick := posmod(cell.x * 7 + cell.y * 13, variants.size())
	for i in variants.size():
		var node := get_node_or_null(NodePath(variants[i])) as Node3D
		if node:
			node.visible = i == pick
	rotation.y = posmod(cell.x * 3 + cell.y * 5, 4) * PI * 0.5
