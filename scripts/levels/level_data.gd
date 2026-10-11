class_name LevelData
extends Resource

@export var grid_size: Vector2i = Vector2i(5, 5)


func get_spawn_cell() -> Vector2i:
	return Vector2i(-1, floori(grid_size.y / 2.0))

func get_exit_cell() -> Vector2i:
	return Vector2i(grid_size.x,floori(grid_size.y / 2.0))
