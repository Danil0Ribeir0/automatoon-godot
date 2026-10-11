class_name HUD
extends CanvasLayer

## O HUD só pede. Quem decide se a ferramenta pode ser usada é o ToolRouter.
signal tool_requested(tool: int, symbol: StringName)

@onready var _bar: HBoxContainer = $ToolBar

var _group := ButtonGroup.new()
var _buttons: Dictionary = {} # "tool:symbol" -> Button


func setup(symbols: Array[SymbolDefinition], station_enabled: bool) -> void:
	_add_button("Trilho", ToolRouter.ToolId.RAIL, &"", Color.WHITE)
	if station_enabled:
		for def in symbols:
			_add_button("Estação %s" % def.id, ToolRouter.ToolId.STATION, def.id, def.color)


func show_active_tool(tool: int, symbol: StringName) -> void:
	var button: Button = _buttons.get(_key(tool, symbol))
	if button != null:
		button.set_pressed_no_signal(true)


func _add_button(text: String, tool: int, symbol: StringName, color: Color) -> void:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = _group
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_pressed_color", color)
	button.pressed.connect(func(): tool_requested.emit(tool, symbol))
	_bar.add_child(button)
	_buttons[_key(tool, symbol)] = button


func _key(tool: int, symbol: StringName) -> String:
	return "%d:%s" % [tool, symbol]
