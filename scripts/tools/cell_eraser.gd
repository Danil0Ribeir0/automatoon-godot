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
	_model.clear_cell(cell)


func move_to(target: Vector2i) -> void:
	while _active and _cursor != target:
		_cursor = step_toward(_cursor, target)
		_model.clear_cell(_cursor)


func end_stroke() -> void:
	_active = false
