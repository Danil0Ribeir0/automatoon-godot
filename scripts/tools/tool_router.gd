class_name ToolRouter
extends Node

signal tool_changed(tool: int, symbol: StringName)
## Estado do fantasma de colocação (BuildTool.Preview) na célula indicada.
signal preview_changed(cell: Vector2i, state: int)

enum ToolId { RAIL, STATION }

@export var input: InputController

var _rail_builder: RailBuilder
var _station_placer: StationPlacer
var _eraser: CellEraser
var _station_enabled := true

var _symbols: Array[StringName] = []
var _symbol_index := 0
var _station_active := false

## Ferramenta do botão esquerdo.
var _primary: BuildTool
## Ferramenta do traço em andamento (null quando nenhum botão está pressionado).
var _stroke_tool: BuildTool
var _hover_cell := GridPicker.NO_CELL


func setup(model: GridModel, station_enabled: bool, symbols: Array[StringName]) -> void:
	_rail_builder = RailBuilder.new(model)
	_station_placer = StationPlacer.new(model)
	_eraser = CellEraser.new(model)
	_station_enabled = station_enabled
	_symbols = symbols
	_primary = _rail_builder

	input.primary_pressed.connect(_begin_stroke.bind(true))
	input.secondary_pressed.connect(_begin_stroke.bind(false))
	input.cursor_moved.connect(_on_cursor_moved)
	input.released.connect(_on_released)
	input.hover_changed.connect(_on_hover_changed)

	input.rail_tool_requested.connect(func(): request_tool(ToolId.RAIL))
	input.station_tool_requested.connect(func(): request_tool(ToolId.STATION))
	input.symbol_scrolled.connect(cycle_symbol)


## `symbol` vazio na ferramenta Estação = mantém o último símbolo usado.
func request_tool(tool: int, symbol: StringName = &"") -> void:
	if _stroke_tool != null:
		return # não troca de ferramenta no meio de um traço
	match tool:
		ToolId.RAIL:
			_primary = _rail_builder
			_station_active = false
		ToolId.STATION:
			if not _station_enabled or _symbols.is_empty():
				return
			if not symbol.is_empty():
				var i := _symbols.find(symbol)
				if i == -1:
					return
				_symbol_index = i
			_station_placer.symbol = _symbols[_symbol_index]
			_primary = _station_placer
			_station_active = true
		_:
			return
	tool_changed.emit(tool, _symbols[_symbol_index] if _station_active else &"")
	_refresh_preview()


func cycle_symbol(step: int) -> void:
	if not _station_active or _stroke_tool != null or _symbols.size() < 2:
		return
	_symbol_index = posmod(_symbol_index + step, _symbols.size())
	request_tool(ToolId.STATION, _symbols[_symbol_index])


func _begin_stroke(cell: Vector2i, primary: bool) -> void:
	_stroke_tool = _primary if primary else _eraser
	_refresh_preview() # esconde o fantasma durante o traço
	_stroke_tool.begin(cell)


func _on_cursor_moved(cell: Vector2i) -> void:
	if _stroke_tool != null:
		_stroke_tool.move_to(cell)


func _on_released() -> void:
	if _stroke_tool != null:
		_stroke_tool.end_stroke()
		_stroke_tool = null
	# O preview reaparece no hover_changed que o InputController emite em seguida.


func _on_hover_changed(cell: Vector2i) -> void:
	_hover_cell = cell
	_refresh_preview()


func _refresh_preview() -> void:
	var state := BuildTool.Preview.HIDDEN
	if _stroke_tool == null and _hover_cell != GridPicker.NO_CELL:
		state = _primary.preview(_hover_cell)
	preview_changed.emit(_hover_cell, state)
