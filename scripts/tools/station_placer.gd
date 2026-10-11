class_name StationPlacer
extends BuildTool

## Emitido quando a colocação é recusada (ponto de extensão para feedback futuro).
signal placement_rejected(cell: Vector2i)

var symbol: StringName
var _model: GridModel


func _init(model: GridModel) -> void:
	_model = model


func begin(cell: Vector2i) -> void:
	if symbol.is_empty() or not _model.in_bounds(cell) or _model.is_locked(cell):
		return
	if _model.has_station(cell):
		_model.set_station_symbol(cell, symbol)
	elif not _model.place_station(cell, symbol):
		placement_rejected.emit(cell)


func preview(cell: Vector2i) -> int:
	if not _model.in_bounds(cell):
		return Preview.HIDDEN
	if _model.is_locked(cell):
		return Preview.INVALID
	if _model.has_station(cell):
		return Preview.HIDDEN
	return Preview.VALID if _model.can_place_station(cell) else Preview.INVALID
