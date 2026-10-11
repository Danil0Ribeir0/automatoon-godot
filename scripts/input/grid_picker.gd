class_name GridPicker
extends Node

const NO_CELL := Vector2i.MIN

@export var camera: Camera3D
@export var board: GridBoard


func cell_at_screen(screen_pos: Vector2) -> Vector2i:
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var plane := Plane(Vector3.UP, board.global_position.y)
	var hit: Variant = plane.intersects_ray(origin, dir)
	if hit == null:
		return NO_CELL
	return board.world_to_cell(hit)
