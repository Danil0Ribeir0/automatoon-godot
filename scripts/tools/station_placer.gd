class_name StationPlacer
extends BuildTool

var symbol: StringName
var _model: GridModel


func _init(model: GridModel) -> void:
	_model = model


func begin(cell: Vector2i) -> void:
	if symbol.is_empty() or not _model.in_bounds(cell) or _model.is_locked(cell):
		return
	if _model.has_station(cell):
		_model.set_station_symbol(cell, symbol) # mesmo símbolo = nada muda
	else:
		_model.place_station(cell, symbol) # vazio ou trilho
