class_name HUD
extends CanvasLayer

## O HUD só pede. Quem decide se a ferramenta pode ser usada é o ToolRouter.
signal tool_requested(tool: int, symbol: StringName)

@onready var _rail_button: ToolButton = $ToolBar/RailButton
@onready var _station_button: ToolButton = $ToolBar/StationButton

var _group := ButtonGroup.new()


func setup(symbols: Array[StringName], station_enabled: bool) -> void:
	_rail_button.button_group = _group
	_station_button.button_group = _group
	# Símbolo vazio = o router mantém o último símbolo usado.
	_rail_button.pressed.connect(func(): tool_requested.emit(ToolRouter.ToolId.RAIL, &""))
	_station_button.pressed.connect(func(): tool_requested.emit(ToolRouter.ToolId.STATION, &""))

	_station_button.set_available(station_enabled)
	_station_button.set_symbol(String(symbols[0]) if not symbols.is_empty() else "–", false)


func show_active_tool(tool: int, symbol: StringName) -> void:
	# Marca os dois explicitamente: set_pressed_no_signal não atualiza o ButtonGroup.
	_rail_button.set_pressed_no_signal(tool == ToolRouter.ToolId.RAIL)
	_station_button.set_pressed_no_signal(tool == ToolRouter.ToolId.STATION)
	if tool == ToolRouter.ToolId.STATION:
		_station_button.set_symbol(String(symbol), true)
