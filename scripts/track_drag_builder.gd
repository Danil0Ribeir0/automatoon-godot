class_name TrackDragBuilder
extends RefCounted

var grid_system: GridSystem
var is_building: bool = false
var is_erasing: bool = false
var drag_path: Array[Vector2i] = []
var start_incoming_dir: int = -1

func _init(p_grid_system: GridSystem) -> void:
	grid_system = p_grid_system

func start_build(start_coords: Vector2i) -> void:
	if not grid_system.is_inside_playable_grid(start_coords):
		return
	is_building = true
	drag_path = [start_coords]
	
	start_incoming_dir = grid_system.find_incoming_neighbor_dir(start_coords)
	if start_incoming_dir != -1:
		grid_system.set_tile_single_dir(start_coords, start_incoming_dir)
	else:
		grid_system.set_tile_single_dir(start_coords, RailTileData.Dir.EAST)

func step_build(new_coords: Vector2i) -> void:
	if not is_building or drag_path.is_empty():
		return
	if not grid_system.is_inside_playable_grid(new_coords):
		return
		
	var last_coords: Vector2i = drag_path.back()
	
	if drag_path.size() >= 2 and new_coords == drag_path[drag_path.size() - 2]:
		grid_system.clear_tile(last_coords)
		drag_path.pop_back()
		_refresh_tile_in_path(drag_path.size() - 1)
		return
		
	# 2. Garante movimento ortogonal (distância Manhattan == 1) e sem cruzar o próprio rastro
	var diff: Vector2i = (new_coords - last_coords).abs()
	if diff.x + diff.y != 1 or new_coords in drag_path:
		return
		
	drag_path.append(new_coords)
	_refresh_tile_in_path(drag_path.size() - 2)
	_refresh_tile_in_path(drag_path.size() - 1)

func stop_build() -> void:
	is_building = false
	drag_path.clear()

func start_erase(coords: Vector2i) -> void:
	is_erasing = true
	step_erase(coords)

func step_erase(coords: Vector2i) -> void:
	if is_erasing and grid_system.is_inside_playable_grid(coords):
		grid_system.clear_tile(coords)

func stop_erase() -> void:
	is_erasing = false

func cancel_all() -> void:
	stop_build()
	stop_erase()

func _refresh_tile_in_path(idx: int) -> void:
	if idx < 0 or idx >= drag_path.size():
		return
		
	var current_coords: Vector2i = drag_path[idx]
	var in_dir: int = -1
	var out_dir: int = -1
	
	if idx > 0:
		in_dir = grid_system.get_direction_between(current_coords, drag_path[idx - 1])
	else:
		in_dir = start_incoming_dir
		
	if idx < drag_path.size() - 1:
		out_dir = grid_system.get_direction_between(current_coords, drag_path[idx + 1])
	else:
		var neighbor_dir := grid_system.find_incoming_neighbor_dir(current_coords)
		if neighbor_dir != -1 and neighbor_dir != in_dir:
			out_dir = neighbor_dir
			
	if in_dir != -1 and out_dir != -1:
		grid_system.set_tile_two_dirs(current_coords, in_dir, out_dir)
	elif in_dir != -1:
		grid_system.set_tile_single_dir(current_coords, in_dir)
	elif out_dir != -1:
		grid_system.set_tile_single_dir(current_coords, out_dir)
