class_name CellEraser
extends BuildTool

var _model: GridModel
var _active := false
var _cursor: Vector2i


func _init(model: GridModel) -> void:
	_model = model


func begin(cell: Vector2i) -> void:
	_active = true
	_cursor = cell
	_erase(cell)


func move_to(target: Vector2i) -> void:
	while _active and _cursor != target:
		_cursor = step_toward(_cursor, target)
		_erase(_cursor)


func end_stroke() -> void:
	_active = false


func _erase(cell: Vector2i) -> void:
	if _model.clear_cell(cell):
		_model.drop_junction_stems_toward(cell)
