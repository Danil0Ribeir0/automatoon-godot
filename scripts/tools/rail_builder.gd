class_name RailBuilder
extends BuildTool

const NO_SHAPE := -1
## A célula aceita a ligação sem mudar de formato (estação ou terminal).
const KEEP := -2

var _model: GridModel
var _active := false
var _moved := false
var _first_created := false

var _trail: Array[Vector2i] = []
var _protected: Array[int] = []
var _prev_shape_before: Array[int] = []
var _cell_shape_before: Array[int] = []


func _init(model: GridModel) -> void:
	_model = model


func begin(cell: Vector2i) -> void:
	_reset()
	if not _model.is_node(cell):
		return
	_first_created = not _model.is_occupied(cell)
	if _first_created:
		_model.place_rail(cell)
	_active = true
	_push(cell, _model.connected_dirs(cell), NO_SHAPE, NO_SHAPE)


func move_to(target: Vector2i) -> void:
	while _active and _trail.back() != target:
		if not _build_step(step_toward(_trail.back(), target)):
			break


func end_stroke() -> void:
	# Clique sem arraste num trilho existente = rotação (estações ignoram).
	if _active and not _moved and not _first_created:
		_model.rotate_rail(_trail[0])
	_reset()


func _build_step(next: Vector2i) -> bool:
	var last: Vector2i = _trail.back()

	if _trail.size() >= 2 and next == _trail[-2]:
		_undo_last()
		return true

	if not _model.is_node(next):
		return false
	# Só estações podem ser revisitadas no mesmo traço (cruzamento).
	if next in _trail and not _model.has_station(next):
		return false

	var dir := GridModel.dir_between(last, next)
	var back: int = GridModel.OPPOSITE[dir]

	if _model.are_connected(last, next):
		_push(next, _model.connected_dirs(next), _model.get_shape(last), _model.get_shape(next))
		return true

	var next_links := _model.connected_dirs(next)
	var last_shape := _shape_toward(last, _protected.back(), dir)
	var next_shape := _shape_toward(next, next_links, back)
	if last_shape == NO_SHAPE or next_shape == NO_SHAPE:
		return false

	var last_before := _model.get_shape(last)
	var next_before := _model.get_shape(next) if _model.is_occupied(next) else NO_SHAPE

	if last_shape != KEEP:
		_model.set_shape(last, last_shape)
	if next_before == NO_SHAPE:
		_model.place_rail(next, next_shape)
	elif next_shape != KEEP:
		_model.set_shape(next, next_shape)

	_push(next, next_links | back, last_before, next_before)
	return true


func _shape_toward(cell: Vector2i, keep: int, dir: int) -> int:
	if _model.has_station(cell):
		return KEEP
	if _model.is_terminal(cell):
		return KEEP if _model.opens_to(cell, dir) else NO_SHAPE
	var others := keep & ~dir
	match GridModel.bit_count(others):
		0:
			return dir | GridModel.OPPOSITE[dir]
		1:
			return dir | others
	return NO_SHAPE


func _undo_last() -> void:
	var last: Vector2i = _trail.pop_back()
	_protected.pop_back()
	var prev_before: int = _prev_shape_before.pop_back()
	var cell_before: int = _cell_shape_before.pop_back()
	if cell_before == NO_SHAPE:
		_model.remove_rail(last)
	else:
		_model.set_shape(last, cell_before) # estações/terminais ignoram
	_model.set_shape(_trail.back(), prev_before)


func _push(cell: Vector2i, protected: int, prev_before: int, cell_before: int) -> void:
	_trail.append(cell)
	_protected.append(protected)
	_prev_shape_before.append(prev_before)
	_cell_shape_before.append(cell_before)
	if _trail.size() > 1:
		_moved = true


func _reset() -> void:
	_active = false
	_moved = false
	_first_created = false
	_trail.clear()
	_protected.clear()
	_prev_shape_before.clear()
	_cell_shape_before.clear()
