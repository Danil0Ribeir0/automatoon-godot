class_name HUD
extends CanvasLayer

## O HUD só pede. Quem decide se a ferramenta pode ser usada é o ToolRouter.
signal tool_requested(tool: int, symbol: StringName)
signal test_requested

@onready var _test_button: ToolButton = $TestButton
@onready var _result_label: Label = $ResultLabel
@onready var _rail_button: ToolButton = $ToolBar/RailButton
@onready var _station_button: ToolButton = $ToolBar/StationButton

var _group := ButtonGroup.new()
var _station_enabled := true

# Painel de informações da fase (canto superior esquerdo), criado por código.
var _info: VBoxContainer
var _title_label: Label
var _word_strip: HBoxContainer
var _rail_label: Label
var _par := 0


func setup(symbols: Array[StringName], station_enabled: bool) -> void:
	_station_enabled = station_enabled
	_rail_button.button_group = _group
	_station_button.button_group = _group
	# Símbolo vazio = o router mantém o último símbolo usado.
	_rail_button.pressed.connect(func(): tool_requested.emit(ToolRouter.ToolId.RAIL, &""))
	_station_button.pressed.connect(func(): tool_requested.emit(ToolRouter.ToolId.STATION, &""))

	_station_button.set_available(station_enabled)
	_station_button.set_symbol(String(symbols[0]) if not symbols.is_empty() else "–", false)
	_test_button.pressed.connect(func(): test_requested.emit())
	_result_label.add_theme_font_size_override("font_size", 28)
	_result_label.add_theme_constant_override("outline_size", 8)
	_result_label.add_theme_color_override("font_outline_color", Color("17345a"))
	clear_result()


func show_active_tool(tool: int, symbol: StringName) -> void:
	# Marca os dois explicitamente: set_pressed_no_signal não atualiza o ButtonGroup.
	_rail_button.set_pressed_no_signal(tool == ToolRouter.ToolId.RAIL)
	_station_button.set_pressed_no_signal(tool == ToolRouter.ToolId.STATION)
	if tool == ToolRouter.ToolId.STATION:
		_station_button.set_symbol(String(symbol), true)

## Título da fase, palavra do trem (vagões na ordem de leitura) e meta de trilhos.
func show_level(title: String, wagons: Array[SymbolDefinition], par: int) -> void:
	_ensure_info()
	_title_label.text = title
	_title_label.visible = not title.is_empty()
	_par = par
	for chip in _word_strip.get_children():
		chip.queue_free()
	for definition in wagons:
		_word_strip.add_child(_make_chip(definition))


func show_rail_count(count: int) -> void:
	_ensure_info()
	if _par > 0:
		_rail_label.text = "Trilhos: %d   (meta ★★★: %d)" % [count, _par]
		_rail_label.add_theme_color_override("font_color",
				Color.WHITE if count <= _par else Color("ffd38a"))
	else:
		_rail_label.text = "Trilhos: %d" % count


func _ensure_info() -> void:
	if _info:
		return
	_info = VBoxContainer.new()
	_info.position = Vector2(24, 20)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_theme_constant_override("separation", 8)
	add_child(_info)
	_title_label = _make_label(26)
	_info.add_child(_title_label)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	var word_label := _make_label(20)
	word_label.text = "Palavra:"
	row.add_child(word_label)
	_word_strip = HBoxContainer.new()
	_word_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_word_strip.add_theme_constant_override("separation", 6)
	row.add_child(_word_strip)
	_info.add_child(row)
	_rail_label = _make_label(20)
	_info.add_child(_rail_label)


func _make_label(size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Color("17345a"))
	return label


## Vagão da palavra: quadradinho na cor do símbolo, com o símbolo escrito.
func _make_chip(definition: SymbolDefinition) -> Control:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.custom_minimum_size = Vector2(38, 38)
	var box := StyleBoxFlat.new()
	box.bg_color = definition.color if definition else Color.MAGENTA
	box.border_color = Color("17345a")
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	chip.add_theme_stylebox_override("panel", box)
	var label := _make_label(22)
	label.text = String(definition.id) if definition else "?"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(label)
	return chip


## Trava os botões enquanto o trem anda.
func set_editing_enabled(enabled: bool) -> void:
	_rail_button.set_available(enabled)
	_station_button.set_available(enabled and _station_enabled)
	_test_button.set_available(enabled)


func show_result(result: ValidationResult) -> void:
	_result_label.text = _describe(result)
	_result_label.add_theme_color_override("font_color",
			Color("7dff8a") if result.success else Color("ff7a7a"))


func clear_result() -> void:
	_result_label.text = ""


func _describe(result: ValidationResult) -> String:
	match result.failure:
		ValidationResult.Failure.NONE:
			return "Palavra aceita!"
		ValidationResult.Failure.BROKEN_TRACK:
			return "Trilho interrompido em %s" % result.error_cell
		ValidationResult.Failure.AMBIGUOUS_STATION:
			return "Estação com 3 saídas em %s" % result.error_cell
		ValidationResult.Failure.WRONG_SYMBOL:
			return "Estação errada em %s: o trem esperava %s" % [result.error_cell, result.expected_symbol]
		ValidationResult.Failure.TOO_MANY_STATIONS:
			return "Estação a mais em %s" % result.error_cell
		ValidationResult.Failure.MISSING_SYMBOLS:
			return "Faltaram %d estações" % (result.word_size - result.consumed)
	return "Percurso em laço (avise o desenvolvedor)"
