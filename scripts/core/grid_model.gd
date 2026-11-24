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

## Trilho em T (junção passiva): reta (barra) + curva saindo para o lado (perna).
## Codificado no próprio formato: bits 0..3 = lados abertos, bits 4..7 = o braço
## da barra onde a curva da perna desemboca. Pela perna, o trem vira para esse
## braço; por qualquer braço, segue reto pela barra. Não lê símbolo.
const JUNCTION_SHIFT := 4

## As 8 posições da agulha, na ordem do clique: [tronco, desvio].
const SWITCH_ORIENTATIONS := [
	[Dir.WEST, Dir.NORTH], [Dir.WEST, Dir.SOUTH],
	[Dir.NORTH, Dir.EAST], [Dir.NORTH, Dir.WEST],
	[Dir.EAST, Dir.SOUTH], [Dir.EAST, Dir.NORTH],
	[Dir.SOUTH, Dir.WEST], [Dir.SOUTH, Dir.EAST],
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
## Obstáculos da fase: nada pode ser construído ali.
var _blocked: Dictionary = {}
## Agulhas: Vector2i -> SwitchData.
var _switches: Dictionary = {}
## Peças fixas da fase que ainda podem girar (não podem ser apagadas).
var _pinned: Dictionary = {}


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
	return (in_bounds(cell) and not is_blocked(cell)) or is_terminal(cell)


func is_blocked(cell: Vector2i) -> bool:
	return _blocked.has(cell)


## Trilhos colocados na grid (terminais não contam). Base das estrelas.
func rail_count() -> int:
	var count := 0
	for cell in _shapes:
		if in_bounds(cell):
			count += 1
	return count


func has_rail(cell: Vector2i) -> bool:
	return _shapes.has(cell)


func has_station(cell: Vector2i) -> bool:
	return _stations.has(cell)


func has_switch(cell: Vector2i) -> bool:
	return _switches.has(cell)


func get_switch(cell: Vector2i) -> SwitchData:
	return _switches.get(cell)


func is_occupied(cell: Vector2i) -> bool:
	return has_rail(cell) or has_station(cell) or has_switch(cell)


func is_pinned(cell: Vector2i) -> bool:
	return _pinned.has(cell)


func is_locked(cell: Vector2i) -> bool:
	return _locked.has(cell)


func get_shape(cell: Vector2i) -> int:
	return _shapes.get(cell, 0)


# --- Trilho em T ---------------------------------------------------------

static func make_junction(stem: int, arm: int) -> int:
	return stem | arm | OPPOSITE[arm] | (arm << JUNCTION_SHIFT)


static func is_junction(shape: int) -> bool:
	return (shape >> JUNCTION_SHIFT) != 0


## Braço da barra para onde a curva da perna leva.
static func junction_arm(shape: int) -> int:
	return (shape >> JUNCTION_SHIFT) & 15


static func junction_stem(shape: int) -> int:
	var arm := junction_arm(shape)
	return (shape & 15) & ~(arm | OPPOSITE[arm])


## Barra do T como trilho reto (o que sobra ao perder a perna).
static func junction_bar(shape: int) -> int:
	var arm := junction_arm(shape)
	return arm | OPPOSITE[arm]


## As 8 posições do T na ordem do clique: perna em S, W, N, E; dois braços cada.
static func junction_shapes() -> Array[int]:
	var result: Array[int] = []
	for stem in [Dir.SOUTH, Dir.WEST, Dir.NORTH, Dir.EAST]:
		var arms := [Dir.EAST, Dir.WEST] if stem in [Dir.NORTH, Dir.SOUTH] else [Dir.NORTH, Dir.SOUTH]
		for arm in arms:
			result.append(make_junction(stem, arm))
	return result


static func is_rail_shape(shape: int) -> bool:
	return shape in SHAPE_CYCLE or shape in junction_shapes()


## Apagaram a célula da perna de um T vizinho: ele volta a ser só a barra.
func drop_junction_stems_toward(cell: Vector2i) -> void:
	for dir in DIR_OFFSETS:
		var neighbor: Vector2i = cell + DIR_OFFSETS[dir]
		var shape := get_shape(neighbor)
		if in_bounds(neighbor) and is_junction(shape) and junction_stem(shape) == OPPOSITE[dir] \
				and not is_pinned(neighbor):
			set_shape(neighbor, junction_bar(shape))


func get_station(cell: Vector2i) -> StationData:
	return _stations.get(cell)


## Estações abrem para os 4 lados. Trilhos, só para onde o formato aponta.
func opens_to(cell: Vector2i, dir: int) -> bool:
	if has_station(cell):
		return true
	if has_switch(cell):
		return (get_switch(cell).openings() & dir) != 0
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
	if not in_bounds(cell) or is_blocked(cell) or is_occupied(cell) or not is_rail_shape(shape):
		return false
	_shapes[cell] = shape
	cell_changed.emit(cell)
	return true


func set_shape(cell: Vector2i, shape: int) -> bool:
	if not in_bounds(cell) or not has_rail(cell) or not is_rail_shape(shape):
		return false
	if _shapes[cell] != shape:
		_shapes[cell] = shape
		cell_changed.emit(cell)
	return true


func rotate_rail(cell: Vector2i) -> bool:
	if not in_bounds(cell) or not has_rail(cell):
		return false
	var shape := get_shape(cell)
	if is_junction(shape):
		var all := junction_shapes()
		return set_shape(cell, all[(all.find(shape) + 1) % all.size()])
	if shape == HORIZONTAL:
		return set_shape(cell, VERTICAL)
	if shape == VERTICAL:
		return set_shape(cell, HORIZONTAL)
	var i := CURVES.find(shape)
	return set_shape(cell, CURVES[(i + 1) % CURVES.size()])


## Clique numa peça: trilho gira; agulha avança para a próxima das 8 posições.
func rotate_piece(cell: Vector2i) -> bool:
	if has_switch(cell):
		return rotate_switch(cell)
	return rotate_rail(cell)


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


# --- Agulhas -------------------------------------------------------------

func can_place_switch(cell: Vector2i) -> bool:
	return in_bounds(cell) and not is_blocked(cell) and not has_station(cell) \
			and not has_switch(cell) and not is_locked(cell) and not is_pinned(cell)


## Substitui um trilho, se houver.
func place_switch(cell: Vector2i, trunk: int, diverge: int, straight_symbol: StringName) -> bool:
	if not can_place_switch(cell):
		return false
	_shapes.erase(cell)
	_switches[cell] = SwitchData.new(trunk, diverge, straight_symbol)
	cell_changed.emit(cell)
	return true


func rotate_switch(cell: Vector2i) -> bool:
	if not has_switch(cell) or is_locked(cell):
		return false
	var sw: SwitchData = _switches[cell]
	var index := 0
	for i in SWITCH_ORIENTATIONS.size():
		if SWITCH_ORIENTATIONS[i][0] == sw.trunk and SWITCH_ORIENTATIONS[i][1] == sw.diverge:
			index = i
	var next: Array = SWITCH_ORIENTATIONS[(index + 1) % SWITCH_ORIENTATIONS.size()]
	sw.trunk = next[0]
	sw.diverge = next[1]
	cell_changed.emit(cell)
	return true


## Troca qual ramo é 0 e qual é 1.
func flip_switch(cell: Vector2i) -> bool:
	if not has_switch(cell) or is_locked(cell):
		return false
	var sw: SwitchData = _switches[cell]
	sw.straight_symbol = sw.diverge_symbol()
	cell_changed.emit(cell)
	return true


func remove_switch(cell: Vector2i) -> bool:
	if not has_switch(cell) or is_locked(cell) or is_pinned(cell):
		return false
	_switches.erase(cell)
	cell_changed.emit(cell)
	return true


func pin_cell(cell: Vector2i) -> void:
	_pinned[cell] = true
	cell_changed.emit(cell)


## Obstáculo definido pela fase. Só em célula vazia da grid.
func block_cell(cell: Vector2i) -> void:
	if not in_bounds(cell) or is_occupied(cell):
		return
	_blocked[cell] = true
	cell_changed.emit(cell)


func lock_cell(cell: Vector2i) -> void:
	_locked[cell] = true
	cell_changed.emit(cell)


## Apaga o que houver na célula (respeita travas e terminais).
func clear_cell(cell: Vector2i) -> bool:
	return remove_rail(cell) or remove_station(cell) or remove_switch(cell)


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
	return in_bounds(cell) and not is_blocked(cell) and not has_station(cell) \
			and not has_switch(cell) and not is_locked(cell) and not has_adjacent_station(cell)
