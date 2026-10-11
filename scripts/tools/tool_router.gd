class_name ToolRouter
extends Node

signal tool_changed(tool: int, symbol: StringName)

enum ToolId { RAIL, STATION }

@export var input: InputController

var _rail_builder: RailBuilder
var _station_placer: StationPlacer
var _eraser: CellEraser
var _station_enabled := true

## Ferramenta do botão esquerdo.
var _primary: BuildTool
## Ferramenta do traço em andamento (null quando nenhum botão está pressionado).
var _stroke_tool: BuildTool


func setup(model: GridModel, station_enabled: bool) -> void:
	_rail_builder = RailBuilder.new(model)
	_station_placer = StationPlacer.new(model)
	_eraser = CellEraser.new(model)
	_station_enabled = station_enabled
	_primary = _rail_builder

	input.primary_pressed.connect(_begin_stroke.bind(true))
	input.secondary_pressed.connect(_begin_stroke.bind(false))
	input.cursor_moved.connect(_on_cursor_moved)
	input.released.connect(_on_released)


func request_tool(tool: int, symbol: StringName = &"") -> void:
	if _stroke_tool != null:
		return # não troca de ferramenta no meio de um traço
	match tool:
		ToolId.RAIL:
			_primary = _rail_builder
		ToolId.STATION:
			if not _station_enabled or symbol.is_empty():
				return
			_station_placer.symbol = symbol
			_primary = _station_placer
		_:
			return
	tool_changed.emit(tool, symbol)


func _begin_stroke(cell: Vector2i, primary: bool) -> void:
	_stroke_tool = _primary if primary else _eraser
	_stroke_tool.begin(cell)


func _on_cursor_moved(cell: Vector2i) -> void:
	if _stroke_tool != null:
		_stroke_tool.move_to(cell)


func _on_released() -> void:
	if _stroke_tool != null:
		_stroke_tool.end_stroke()
		_stroke_tool = null
