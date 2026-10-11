class_name GridModel
extends RefCounted

signal cell_changed(cell: Vector2i)

enum Dir { NORTH = 1, EAST = 2, SOUTH = 4, WEST = 8 }

const DIR_OFFSETS := {
	Dir.NORTH: Vector2i(0, -1),
	Dir.EAST: Vector2i(1, 0),
	Dir.SOUTH: Vector2i(0, 1),
	Dir.WEST: Vector2i(-1, 0),
}
const OPPOSITE := {
	Dir.NORTH: Dir.SOUTH,
	Dir.EAST: Dir.WEST,
	Dir.SOUTH: Dir.NORTH,
	Dir.WEST: Dir.EAST,
}

const HORIZONTAL := Dir.EAST | Dir.WEST
const VERTICAL := Dir.NORTH | Dir.SOUTH
const SHAPE_CYCLE := [
	HORIZONTAL,
	VERTICAL,
	Dir.NORTH | Dir.EAST,
	Dir.EAST | Dir.SOUTH,
	Dir.SOUTH | Dir.WEST,
	Dir.WEST | Dir.NORTH,
]

const CURVES := [
	Dir.NORTH | Dir.EAST,
	Dir.EAST | Dir.SOUTH,
	Dir.SOUTH | Dir.WEST,
	Dir.WEST | Dir.NORTH,
]

var size: Vector2i
var spawn_cell: Vector2i
var exit_cell: Vector2i

## Formato dos trilhos (e terminais). Célula ausente = sem trilho.
var _shapes: Dictionary = {}
## Estações: Vector2i -> StationData.
var _stations: Dictionary = {}
## Células travadas pela fase (estações fixas).
var _locked: Dictionary = {}


func _init(p_size: Vector2i, p_spawn: Vector2i, p_exit: Vector2i) -> void:
	size = p_size
	spawn_cell = p_spawn
	exit_cell = p_exit
	_shapes[spawn_cell] = _inward_dir(spawn_cell)
	_shapes[exit_cell] = _inward_dir(exit_cell)


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func is_terminal(cell: Vector2i) -> bool:
	return cell == spawn_cell or cell == exit_cell


func is_node(cell: Vector2i) -> bool:
	return in_bounds(cell) or is_terminal(cell)


func has_rail(cell: Vector2i) -> bool:
	return _shapes.has(cell)


func has_station(cell: Vector2i) -> bool:
	return _stations.has(cell)


func is_occupied(cell: Vector2i) -> bool:
	return has_rail(cell) or has_station(cell)


func is_locked(cell: Vector2i) -> bool:
	return _locked.has(cell)


func get_shape(cell: Vector2i) -> int:
	return _shapes.get(cell, 0)


func get_station(cell: Vector2i) -> StationData:
	return _stations.get(cell)


## Estações abrem para os 4 lados. Trilhos, só para onde o formato aponta.
func opens_to(cell: Vector2i, dir: int) -> bool:
	if has_station(cell):
		return true
	return (get_shape(cell) & dir) != 0


static func dir_between(a: Vector2i, b: Vector2i) -> int:
	for dir in DIR_OFFSETS:
		if a + DIR_OFFSETS[dir] == b:
			return dir
	return 0


static func bit_count(mask: int) -> int:
	var count := 0
	while mask > 0:
		count += mask & 1
		mask >>= 1
	return count


func are_connected(a: Vector2i, b: Vector2i) -> bool:
	var dir := dir_between(a, b)
	return dir != 0 and opens_to(a, dir) and opens_to(b, OPPOSITE[dir])


func connected_dirs(cell: Vector2i) -> int:
	if not is_occupied(cell):
		return 0
	var result := 0
	for dir in DIR_OFFSETS:
		if opens_to(cell, dir) and opens_to(cell + DIR_OFFSETS[dir], OPPOSITE[dir]):
			result |= dir
	return result


func place_rail(cell: Vector2i, shape: int = HORIZONTAL) -> bool:
	if not in_bounds(cell) or is_occupied(cell) or shape not in SHAPE_CYCLE:
		return false
	_shapes[cell] = shape
	cell_changed.emit(cell)
	return true


func set_shape(cell: Vector2i, shape: int) -> bool:
	if not in_bounds(cell) or not has_rail(cell) or shape not in SHAPE_CYCLE:
		return false
	if _shapes[cell] != shape:
		_shapes[cell] = shape
		cell_changed.emit(cell)
	return true


func rotate_rail(cell: Vector2i) -> bool:
	if not in_bounds(cell) or not has_rail(cell):
		return false
	var shape := get_shape(cell)
	if shape == HORIZONTAL:
		return set_shape(cell, VERTICAL)
	if shape == VERTICAL:
		return set_shape(cell, HORIZONTAL)
	var i := CURVES.find(shape)
	return set_shape(cell, CURVES[(i + 1) % CURVES.size()])


func remove_rail(cell: Vector2i) -> bool:
	if not in_bounds(cell) or not has_rail(cell):
		return false
	_shapes.erase(cell)
	cell_changed.emit(cell)
	return true


func place_station(cell: Vector2i, symbol: StringName) -> bool:
	if not can_place_station(cell):
		return false
	_shapes.erase(cell)
	_stations[cell] = StationData.new(symbol)
	cell_changed.emit(cell)
	return true


func set_station_symbol(cell: Vector2i, symbol: StringName) -> bool:
	if not has_station(cell) or is_locked(cell):
		return false
	var station: StationData = _stations[cell]
	if station.symbol != symbol:
		station.symbol = symbol
		cell_changed.emit(cell)
	return true


func remove_station(cell: Vector2i) -> bool:
	if not has_station(cell) or is_locked(cell):
		return false
	_stations.erase(cell)
	cell_changed.emit(cell)
	return true


func lock_cell(cell: Vector2i) -> void:
	_locked[cell] = true
	cell_changed.emit(cell)


## Apaga o que houver na célula (respeita travas e terminais).
func clear_cell(cell: Vector2i) -> bool:
	return remove_rail(cell) or remove_station(cell)


func _inward_dir(cell: Vector2i) -> int:
	for dir in DIR_OFFSETS:
		if in_bounds(cell + DIR_OFFSETS[dir]):
			return dir
	return 0

## Alguma das 4 células vizinhas (ortogonais) tem estação?
func has_adjacent_station(cell: Vector2i) -> bool:
	for dir in DIR_OFFSETS:
		if has_station(cell + DIR_OFFSETS[dir]):
			return true
	return false


## Regra: duas estações nunca ficam coladas. Entre elas há pelo menos um trilho.
func can_place_station(cell: Vector2i) -> bool:
	return in_bounds(cell) and not has_station(cell) and not is_locked(cell) \
			and not has_adjacent_station(cell)
