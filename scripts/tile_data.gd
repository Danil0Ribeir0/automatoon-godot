class_name RailTileData
extends RefCounted

enum TileType { EMPTY, STRAIGHT, CURVE, STATION, SPAWN, EXIT }
enum Dir { NORTH = 0, EAST = 1, SOUTH = 2, WEST = 3 }

var type: TileType = TileType.EMPTY
var rotation_steps: int = 0
var is_locked: bool = false
var base_connections: Array[Dir] = []

func _init(p_type: TileType = TileType.EMPTY, p_rot: int = 0, p_locked: bool = false) -> void:
	type = p_type
	rotation_steps = p_rot
	is_locked = p_locked
	_setup_base_connections()

func _setup_base_connections() -> void:
	match type:
		TileType.EMPTY:
			base_connections = []
		TileType.STRAIGHT, TileType.STATION:
			base_connections = [Dir.NORTH, Dir.SOUTH]
		TileType.CURVE:
			base_connections = [Dir.NORTH, Dir.EAST]
		TileType.SPAWN, TileType.EXIT:
			base_connections = [Dir.SOUTH]

func get_active_connections() -> Array[Dir]:
	var active: Array[Dir] = []
	for dir in base_connections:
		var rotated_dir = (dir + rotation_steps) % 4
		active.append(rotated_dir as Dir)
	return active
