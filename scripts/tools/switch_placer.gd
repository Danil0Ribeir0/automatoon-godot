class_name SwitchPlacer
extends BuildTool

## Ferramenta Agulha (tecla 3): clique em célula vazia/trilho coloca; clique numa
## agulha gira (8 posições); a roda sobre uma agulha troca qual ramo é 0 e qual é 1.

signal placement_rejected(cell: Vector2i)

## Posição inicial de toda agulha nova: tronco para o Oeste, desvio para o Norte.
var trunk := GridModel.Dir.WEST
var diverge := GridModel.Dir.NORTH
var straight_symbol := &"0"

var _model: GridModel


func _init(model: GridModel) -> void:
	_model = model


func begin(cell: Vector2i) -> void:
	if _model.has_switch(cell):
		_model.rotate_switch(cell)
	elif not _model.place_switch(cell, trunk, diverge, straight_symbol):
		placement_rejected.emit(cell)


func flip_at(cell: Vector2i) -> bool:
	return _model.flip_switch(cell)


func preview(cell: Vector2i) -> int:
	if not _model.in_bounds(cell) or _model.has_switch(cell):
		return Preview.HIDDEN
	return Preview.VALID if _model.can_place_switch(cell) else Preview.INVALID
