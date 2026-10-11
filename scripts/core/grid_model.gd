class_name GridModel
extends RefCounted

var size: Vector2i

func _init(p_size: Vector2i) -> void:
	size = p_size

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y
