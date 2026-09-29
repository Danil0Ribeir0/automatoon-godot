class_name RailTileData
extends RefCounted

enum TileType { EMPTY, STRAIGHT, CURVE, STATION, SPAWN, EXIT }
enum Dir { NORTH = 0, EAST = 1, SOUTH = 2, WEST = 3 }

var type: TileType = TileType.EMPTY
var rotation_steps: int = 0
var is_locked: bool = false
var symbol: String = ""
var base_connections: Array[Dir] = []

func _init(p_type: TileType = TileType.EMPTY, p_rot: int = 0, p_locked: bool = false, p_symbol: String = "") -> void:
	type = p_type
	rotation_steps = p_rot
	is_locked = p_locked
	symbol = p_symbol
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
		var rotated_dir := (dir + rotation_steps) % 4
		active.append(rotated_dir as Dir)
	return active

static func opposite_dir(dir: int) -> int:
	return (dir + 2) % 4

static func dir_to_vector(dir: int) -> Vector2i:
	match dir:
		Dir.NORTH: return Vector2i(0, -1)
		Dir.EAST:  return Vector2i(1, 0)
		Dir.SOUTH: return Vector2i(0, 1)
		Dir.WEST:  return Vector2i(-1, 0)
	return Vector2i.ZERO

static func vector_to_dir(diff: Vector2i) -> int:
	if diff == Vector2i(0, -1): return Dir.NORTH
	if diff == Vector2i(1, 0):  return Dir.EAST
	if diff == Vector2i(0, 1):  return Dir.SOUTH
	if diff == Vector2i(-1, 0): return Dir.WEST
	return -1
