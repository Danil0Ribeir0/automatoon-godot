class_name HUD
extends CanvasLayer

## O HUD só pede. Quem decide se a ferramenta pode ser usada é o ToolRouter.
signal tool_requested(tool: int, symbol: StringName)
signal test_requested

enum Mark { NONE, RUNNING, PASSED, FAILED }

const TOOL_BUTTON := preload("res://scenes/ui/ToolButton.tscn")

@onready var _test_button: ToolButton = $TestButton
@onready var _result_label: Label = $ResultLabel
@onready var _rail_button: ToolButton = $ToolBar/RailButton
@onready var _station_button: ToolButton = $ToolBar/StationButton

var _switch_button: ToolButton
var _group := ButtonGroup.new()
var _station_enabled := true
var _switch_enabled := false

# Painel da fase (canto superior esquerdo), criado por código.
var _info: VBoxContainer
var _title_label: Label
var _queue: VBoxContainer
var _marks: Array[Label] = []
var _rail_label: Label
var _par := 0


func setup(symbols: Array[StringName], station_enabled: bool, switch_enabled := false) -> void:
	_station_enabled = station_enabled
	_switch_enabled = switch_enabled
	_rail_button.button_group = _group
	_station_button.button_group = _group
	# Símbolo vazio = o router mantém o último símbolo usado.
	_rail_button.pressed.connect(func(): tool_requested.emit(ToolRouter.ToolId.RAIL, &""))
	_station_button.pressed.connect(func(): tool_requested.emit(ToolRouter.ToolId.STATION, &""))

	if switch_enabled:
		_switch_button = TOOL_BUTTON.instantiate()
		_switch_button.text = "Agulha"
		_switch_button.key_hint = "3"
		_switch_button.custom_minimum_size = _station_button.custom_minimum_size
		_switch_button.button_group = _group
		_switch_button.pressed.connect(func(): tool_requested.emit(ToolRouter.ToolId.SWITCH, &""))
		var bar := _rail_button.get_parent() as HBoxContainer
		bar.add_theme_constant_override("separation", 22) # três botões: aproxima para não encostar no título
		bar.add_child(_switch_button)

	_station_button.set_available(station_enabled)
	_station_button.set_symbol(String(symbols[0]) if not symbols.is_empty() else "–", false)
	_test_button.pressed.connect(func(): test_requested.emit())
	_result_label.add_theme_font_size_override("font_size", 28)
	_result_label.add_theme_constant_override("outline_size", 8)
	_result_label.add_theme_color_override("font_outline_color", Color("17345a"))
	clear_result()


func show_active_tool(tool: int, symbol: StringName) -> void:
	# Marca explicitamente: set_pressed_no_signal não atualiza o ButtonGroup.
	_rail_button.set_pressed_no_signal(tool == ToolRouter.ToolId.RAIL)
	_station_button.set_pressed_no_signal(tool == ToolRouter.ToolId.STATION)
	if _switch_button:
		_switch_button.set_pressed_no_signal(tool == ToolRouter.ToolId.SWITCH)
	if tool == ToolRouter.ToolId.STATION:
		_station_button.set_symbol(String(symbol), true)


## Título, fila de trens (palavra + chegar/barrar) e meta de trilhos.
func show_level(title: String, trains: Array[TrainDefinition], par: int) -> void:
	_ensure_info()
	_title_label.text = title
	_title_label.visible = not title.is_empty()
	_par = par
	for row in _queue.get_children():
		row.queue_free()
	_marks.clear()
	var multi := trains.size() > 1
	for i in trains.size():
		var t := trains[i]
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 6)
		var tag := _make_label(18)
		if multi:
			tag.text = "chega " if t.expect_accept else "barra "
			tag.add_theme_color_override("font_color", Color("7dff8a") if t.expect_accept else Color("ff9a9a"))
		else:
			tag.text = "Palavra:"
		tag.custom_minimum_size = Vector2(62 if multi else 0, 0)
		row.add_child(tag)
		for definition in t.wagons:
			row.add_child(_make_chip(definition))
		var mark := _make_label(22)
		row.add_child(mark)
		_marks.append(mark)
		_queue.add_child(row)


## Situação de cada trem da fila (▶ andando, ✔ certo, ✖ errado).
func mark_train(index: int, mark: Mark) -> void:
	if index < 0 or index >= _marks.size():
		return
	var label := _marks[index]
	match mark:
		Mark.RUNNING:
			label.text = " ▶"
			label.add_theme_color_override("font_color", Color.WHITE)
		Mark.PASSED:
			label.text = " ✔"
			label.add_theme_color_override("font_color", Color("7dff8a"))
		Mark.FAILED:
			label.text = " ✖"
			label.add_theme_color_override("font_color", Color("ff7a7a"))
		_:
			label.text = ""


func clear_marks() -> void:
	for i in _marks.size():
		mark_train(i, Mark.NONE)


func show_rail_count(count: int) -> void:
	_ensure_info()
	if _par > 0:
		_rail_label.text = "Trilhos: %d   (meta ★★★: %d)" % [count, _par]
		_rail_label.add_theme_color_override("font_color",
				Color.WHITE if count <= _par else Color("ffd38a"))
	else:
		_rail_label.text = "Trilhos: %d" % count


## Trava os botões enquanto o trem anda.
func set_editing_enabled(enabled: bool) -> void:
	_rail_button.set_available(enabled)
	_station_button.set_available(enabled and _station_enabled)
	if _switch_button:
		_switch_button.set_available(enabled)
	_test_button.set_available(enabled)


## Resultado final da fila. `train_index` = trem que divergiu (-1 = todos certos).
func show_result(result: ValidationResult, train_index := -1, expected_accept := true, total := 1) -> void:
	var ok := train_index < 0
	var text := ""
	if ok:
		text = "Palavra aceita!" if total <= 1 else "Todos os trens corretos!"
	elif not expected_accept:
		text = "O trem %d deveria ser barrado, mas chegou à Chegada" % (train_index + 1)
	else:
		text = _describe(result)
		if total > 1:
			text = "Trem %d: %s" % [train_index + 1, text]
	_result_label.text = text
	_result_label.add_theme_color_override("font_color", Color("7dff8a") if ok else Color("ff7a7a"))


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
		ValidationResult.Failure.LOOP:
			return "Trem preso num laço em %s" % result.error_cell
	return "Percurso inválido"


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
	_queue = VBoxContainer.new()
	_queue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_queue.add_theme_constant_override("separation", 6)
	_info.add_child(_queue)
	_rail_label = _make_label(20)
	_info.add_child(_rail_label)


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Color("17345a"))
	return label


## Vagão da palavra: quadradinho na cor do símbolo, com o símbolo escrito.
func _make_chip(definition: SymbolDefinition) -> Control:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.custom_minimum_size = Vector2(34, 34)
	var box := StyleBoxFlat.new()
	box.bg_color = definition.color if definition else Color.MAGENTA
	box.border_color = Color("17345a")
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	chip.add_theme_stylebox_override("panel", box)
	var label := _make_label(20)
	label.text = String(definition.id) if definition else "?"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(label)
	return chip
