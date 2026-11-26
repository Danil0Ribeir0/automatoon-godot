class_name ToolRouter
extends Node

signal tool_changed(tool: int, symbol: StringName)
## Fantasma de colocação: estado (BuildTool.Preview) e ferramenta (ToolId) na célula.
signal preview_changed(cell: Vector2i, state: int, tool: int)

enum ToolId { RAIL, STATION, SWITCH }

@export var input: InputController

var _rail_builder: RailBuilder
var _station_placer: StationPlacer
var _switch_placer: SwitchPlacer
var _eraser: CellEraser
var _station_enabled := true
var _switch_enabled := false

var _symbols: Array[StringName] = []
var _symbol_index := 0
var _active_tool := ToolId.RAIL

## Ferramenta do botão esquerdo.
var _primary: BuildTool
## Ferramenta do traço em andamento (null quando nenhum botão está pressionado).
var _stroke_tool: BuildTool
var _hover_cell := GridPicker.NO_CELL
## false enquanto o trem anda: ignora input de edição.
var _enabled := true


func setup(model: GridModel, station_enabled: bool, symbols: Array[StringName],
		switch_enabled := false) -> void:
	_rail_builder = RailBuilder.new(model)
	_station_placer = StationPlacer.new(model)
	_switch_placer = SwitchPlacer.new(model)
	_eraser = CellEraser.new(model)
	_station_enabled = station_enabled
	_switch_enabled = switch_enabled
	_symbols = symbols
	_primary = _rail_builder

	input.primary_pressed.connect(_begin_stroke.bind(true))
	input.secondary_pressed.connect(_begin_stroke.bind(false))
	input.cursor_moved.connect(_on_cursor_moved)
	input.released.connect(_on_released)
	input.hover_changed.connect(_on_hover_changed)

	input.rail_tool_requested.connect(func(): request_tool(ToolId.RAIL))
	input.station_tool_requested.connect(func(): request_tool(ToolId.STATION))
	input.switch_tool_requested.connect(func(): request_tool(ToolId.SWITCH))
	input.symbol_scrolled.connect(cycle_symbol)


## `symbol` vazio na ferramenta Estação = mantém o último símbolo usado.
func request_tool(tool: int, symbol: StringName = &"") -> void:
	if not _enabled or _stroke_tool != null:
		return # não troca de ferramenta no meio de um traço
	match tool:
		ToolId.RAIL:
			_primary = _rail_builder
		ToolId.STATION:
			if not _station_enabled or _symbols.is_empty():
				return
			if not symbol.is_empty():
				var i := _symbols.find(symbol)
				if i == -1:
					return
				_symbol_index = i
			elif _active_tool == ToolId.STATION:
				# Pedir Estação com ela já ativa (tecla 2 / clique no botão) = próximo símbolo.
				_symbol_index = posmod(_symbol_index + 1, _symbols.size())
			_station_placer.symbol = _symbols[_symbol_index]
			_primary = _station_placer
		ToolId.SWITCH:
			if not _switch_enabled:
				return
			_primary = _switch_placer
		_:
			return
	_active_tool = tool
	tool_changed.emit(tool, _symbols[_symbol_index] if tool == ToolId.STATION else &"")
	_refresh_preview()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	_refresh_preview()


## Há um traço em andamento (botão do mouse pressionado)?
func is_busy() -> bool:
	return _stroke_tool != null


## Roda do mouse: na Estação troca o símbolo ativo; na Agulha troca os ramos 0/1
## da agulha sob o mouse.
func cycle_symbol(step: int) -> void:
	if not _enabled or _stroke_tool != null:
		return
	match _active_tool:
		ToolId.STATION:
			if _symbols.size() < 2:
				return
			_symbol_index = posmod(_symbol_index + step, _symbols.size())
			request_tool(ToolId.STATION, _symbols[_symbol_index])
		ToolId.SWITCH:
			if _hover_cell != GridPicker.NO_CELL:
				_switch_placer.flip_at(_hover_cell)


func _begin_stroke(cell: Vector2i, primary: bool) -> void:
	if not _enabled:
		return
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
	if _enabled and _stroke_tool == null and _hover_cell != GridPicker.NO_CELL:
		state = _primary.preview(_hover_cell)
	preview_changed.emit(_hover_cell, state, _active_tool)
