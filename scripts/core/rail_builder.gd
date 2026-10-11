class_name RailBuilder
extends RefCounted

enum Mode { NONE, BUILD, ERASE }

const NO_SHAPE := -1

var _model: GridModel
var _mode := Mode.NONE
var _moved := false
var _first_created := false

var _trail: Array[Vector2i] = []
var _protected: Array[int] = []
var _prev_shape_before: Array[int] = []
var _cell_shape_before: Array[int] = []


func _init(model: GridModel) -> void:
	_model = model


func begin_build(cell: Vector2i) -> void:
	_reset()
	if not _model.is_node(cell):
		return
	_first_created = not _model.has_rail(cell)
	if _first_created:
		_model.place_rail(cell)
	_mode = Mode.BUILD
	_push(cell, _model.connected_dirs(cell), NO_SHAPE, NO_SHAPE)


func begin_erase(cell: Vector2i) -> void:
	_reset()
	_mode = Mode.ERASE
	_trail.append(cell)
	_model.remove_rail(cell)


func move_to(target: Vector2i) -> void:
	while _mode != Mode.NONE and _trail.back() != target:
		var next := _step_toward(_trail.back(), target)
		var advanced := _build_step(next) if _mode == Mode.BUILD else _erase_step(next)
		if not advanced:
			break


func end_stroke() -> void:
	# Clique sem arraste num trilho que já existia = rotação.
	if _mode == Mode.BUILD and not _moved and not _first_created:
		_model.rotate_rail(_trail[0])
	_reset()


func _build_step(next: Vector2i) -> bool:
	var last: Vector2i = _trail.back()

	# Backtracking: o cursor voltou para a penúltima célula do rastro.
	if _trail.size() >= 2 and next == _trail[-2]:
		_undo_last()
		return true

	if next in _trail or not _model.is_node(next):
		return false

	var dir := GridModel.dir_between(last, next)
	var back: int = GridModel.OPPOSITE[dir]

	# Já ligados: o traço só caminha pelo trilho existente.
	if _model.are_connected(last, next):
		_push(next, _model.connected_dirs(next), _model.get_shape(last), _model.get_shape(next))
		return true

	var next_links := _model.connected_dirs(next) if _model.has_rail(next) else 0
	var last_shape := _shape_toward(last, _protected.back(), dir)
	var next_shape := _shape_toward(next, next_links, back)
	if last_shape == NO_SHAPE or next_shape == NO_SHAPE:
		return false # quebraria uma conexão existente

	var last_before := _model.get_shape(last)
	var next_before := _model.get_shape(next) if _model.has_rail(next) else NO_SHAPE

	_model.set_shape(last, last_shape)
	if next_before == NO_SHAPE:
		_model.place_rail(next, next_shape)
	else:
		_model.set_shape(next, next_shape)

	_push(next, next_links | back, last_before, next_before)
	return true


## Formato que abre para `dir` preservando as aberturas em `keep`,
## ou NO_SHAPE se for impossível sem quebrar alguma conexão.
func _shape_toward(cell: Vector2i, keep: int, dir: int) -> int:
	if _model.is_terminal(cell):
		return _model.get_shape(cell) if _model.opens_to(cell, dir) else NO_SHAPE
	var others := keep & ~dir
	match GridModel.bit_count(others):
		0:
			return dir | GridModel.OPPOSITE[dir] # ponta do traço: reta
		1:
			return dir | others # reta ou curva
	return NO_SHAPE


func _undo_last() -> void:
	var last: Vector2i = _trail.pop_back()
	_protected.pop_back()
	var prev_before: int = _prev_shape_before.pop_back()
	var cell_before: int = _cell_shape_before.pop_back()
	if cell_before == NO_SHAPE:
		_model.remove_rail(last)
	else:
		_model.set_shape(last, cell_before)
	_model.set_shape(_trail.back(), prev_before)


func _push(cell: Vector2i, protected: int, prev_before: int, cell_before: int) -> void:
	_trail.append(cell)
	_protected.append(protected)
	_prev_shape_before.append(prev_before)
	_cell_shape_before.append(cell_before)
	if _trail.size() > 1:
		_moved = true


# --- Remoção ---------------------------------------------------------------

func _erase_step(next: Vector2i) -> bool:
	_model.remove_rail(next) # ignora terminais e células vazias
	_trail[0] = next
	return true


func _reset() -> void:
	_mode = Mode.NONE
	_moved = false
	_first_created = false
	_trail.clear()
	_protected.clear()
	_prev_shape_before.clear()
	_cell_shape_before.clear()


## Um passo ortogonal de `from` em direção a `to` (preenche saltos do mouse).
func _step_toward(from: Vector2i, to: Vector2i) -> Vector2i:
	var d := to - from
	if absi(d.x) >= absi(d.y):
		return from + Vector2i(signi(d.x), 0)
	return from + Vector2i(0, signi(d.y))
