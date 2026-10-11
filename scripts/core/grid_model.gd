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
## Ordem do ciclo de rotação por clique. Também é a lista de formatos válidos.
const SHAPE_CYCLE := [
	HORIZONTAL,
	VERTICAL,
	Dir.NORTH | Dir.EAST,
	Dir.EAST | Dir.SOUTH,
	Dir.SOUTH | Dir.WEST,
	Dir.WEST | Dir.NORTH,
]

var size: Vector2i
var spawn_cell: Vector2i
var exit_cell: Vector2i

## Formato (aberturas) de cada célula com trilho. Célula ausente = sem trilho.
var _shapes: Dictionary = {}


func _init(p_size: Vector2i, p_spawn: Vector2i, p_exit: Vector2i) -> void:
	size = p_size
	spawn_cell = p_spawn
	exit_cell = p_exit
	_shapes[spawn_cell] = _inward_dir(spawn_cell)
	_shapes[exit_cell] = _inward_dir(exit_cell)


# --- Consultas -------------------------------------------------------------

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func is_terminal(cell: Vector2i) -> bool:
	return cell == spawn_cell or cell == exit_cell


func is_node(cell: Vector2i) -> bool:
	return in_bounds(cell) or is_terminal(cell)


func has_rail(cell: Vector2i) -> bool:
	return _shapes.has(cell)


func get_shape(cell: Vector2i) -> int:
	return _shapes.get(cell, 0)


func opens_to(cell: Vector2i, dir: int) -> bool:
	return (get_shape(cell) & dir) != 0


## Direção (bit) de a para b, ou 0 se não forem vizinhos ortogonais.
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


## Conexão deduzida: as duas peças apontam uma para a outra.
func are_connected(a: Vector2i, b: Vector2i) -> bool:
	var dir := dir_between(a, b)
	return dir != 0 and opens_to(a, dir) and opens_to(b, OPPOSITE[dir])


## Máscara das direções em que a célula está de fato conectada.
func connected_dirs(cell: Vector2i) -> int:
	var result := 0
	for dir in DIR_OFFSETS:
		if opens_to(cell, dir) and opens_to(cell + DIR_OFFSETS[dir], OPPOSITE[dir]):
			result |= dir
	return result


# --- Comandos --------------------------------------------------------------

func place_rail(cell: Vector2i, shape: int = HORIZONTAL) -> bool:
	if not in_bounds(cell) or has_rail(cell) or shape not in SHAPE_CYCLE:
		return false
	_shapes[cell] = shape
	cell_changed.emit(cell)
	return true


## Terminais nunca mudam de formato.
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
	var i := SHAPE_CYCLE.find(get_shape(cell))
	return set_shape(cell, SHAPE_CYCLE[(i + 1) % SHAPE_CYCLE.size()])


func remove_rail(cell: Vector2i) -> bool:
	if not in_bounds(cell) or not has_rail(cell):
		return false
	_shapes.erase(cell)
	cell_changed.emit(cell)
	return true


## Direção do terminal para a única célula da grid adjacente a ele.
func _inward_dir(cell: Vector2i) -> int:
	for dir in DIR_OFFSETS:
		if in_bounds(cell + DIR_OFFSETS[dir]):
			return dir
	return 0
