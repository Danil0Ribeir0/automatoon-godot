class_name HUD
extends CanvasLayer

## O HUD só pede. Quem decide se a ferramenta pode ser usada é o ToolRouter.
signal tool_requested(tool: int, symbol: StringName)
signal test_requested
signal restart_requested

## Situação de cada trem da fila (▶ andando, ✔ certo, ✖ errado).
enum Mark { NONE, RUNNING, PASSED, FAILED }

const TOOL_BUTTON := preload("res://scenes/ui/ToolButton.tscn")
const SWITCH_SCENE := preload("res://scenes/switches/Switch.tscn")

@onready var _test_button: ToolButton = $TestButton
@onready var _reset_button: ToolButton = $ResetButton
## Mensagem do resultado, logo acima dos botões. RichTextLabel para colorir o símbolo.
@onready var _result_label: RichTextLabel = $ResultLabel
@onready var _rail_button: ToolButton = $ToolBar/RailButton
@onready var _station_button: ToolButton = $ToolBar/StationButton

var _switch_button: ToolButton
var _group := ButtonGroup.new()
var _station_enabled := true
var _switch_enabled := false
## id do símbolo -> SymbolDefinition (para pintar o ícone da estação).
var _symbol_defs := {}

## Dica "trocar símbolo" acima do botão Estação. Some de vez (até fechar o jogo)
## na primeira troca de símbolo: static porque o HUD é recriado a cada fase.
static var _learned_symbol_switch := false
var _symbol_hint: Label
## Dica "segure Espaço para acelerar" durante o percurso; some de vez quando o
## jogador acelera pela primeira vez.
static var _learned_fast_forward := false
var _speed_hint_visible := false
var _symbol_count := 0
var _current_symbol: StringName = &""

# Painel de informações da fase (canto superior esquerdo), criado por código.
var _info: VBoxContainer
var _title_label: Label
# OBJETIVO (topo central) com o trem da vez + FILA de trens no canto superior direito.
var _goal_current: HBoxContainer
var _next_panel: VBoxContainer
var _next_list: VBoxContainer
var _trains: Array[TrainDefinition] = []
var _marks: Array[int] = []
## Trem mostrado em destaque (o que está andando, ou o primeiro).
var _focus := 0
var _rail_count: Label
var _par_label: Label
var _par := 0


func setup(symbols: Array[StringName], station_enabled: bool, switch_enabled := false,
		definitions: Array[SymbolDefinition] = []) -> void:
	_station_enabled = station_enabled
	_switch_enabled = switch_enabled
	for definition in definitions:
		_symbol_defs[definition.id] = definition
	# Permite clicar no botão já ativo (Estação ativa + clique = próximo símbolo).
	# O ToolRouter devolve o estado certo via show_active_tool.
	_group.allow_unpress = true
	_rail_button.button_group = _group
	_station_button.button_group = _group
	# Símbolo vazio = o router mantém o último símbolo usado.
	_rail_button.pressed.connect(func(): tool_requested.emit(ToolRouter.ToolId.RAIL, &""))
	_station_button.pressed.connect(func(): tool_requested.emit(ToolRouter.ToolId.STATION, &""))

	if switch_enabled:
		_add_switch_button()

	_station_button.set_available(station_enabled)
	_station_button.set_symbol(String(symbols[0]) if not symbols.is_empty() else "–", false)
	if not symbols.is_empty():
		_paint_station_icon(symbols[0])
		_current_symbol = symbols[0]
	_symbol_count = symbols.size()
	_build_symbol_hint()
	_test_button.pressed.connect(func(): test_requested.emit())
	_reset_button.pressed.connect(func(): restart_requested.emit())
	_result_label.add_theme_font_size_override("normal_font_size", 28)
	_result_label.add_theme_font_size_override("bold_font_size", 30)
	_result_label.add_theme_constant_override("outline_size", 8)
	_result_label.add_theme_color_override("font_outline_color", Color("17345a"))
	clear_result()


func show_active_tool(tool: int, symbol: StringName) -> void:
	# Marca os dois explicitamente: set_pressed_no_signal não atualiza o ButtonGroup.
	_rail_button.set_pressed_no_signal(tool == ToolRouter.ToolId.RAIL)
	_station_button.set_pressed_no_signal(tool == ToolRouter.ToolId.STATION)
	if _switch_button:
		_switch_button.set_pressed_no_signal(tool == ToolRouter.ToolId.SWITCH)
	if tool == ToolRouter.ToolId.STATION:
		if symbol != _current_symbol:
			_learned_symbol_switch = true # trocou: já aprendeu, a dica não volta
		_current_symbol = symbol
		_station_button.set_symbol(String(symbol), true)
		_paint_station_icon(symbol)
	_update_symbol_hint(tool == ToolRouter.ToolId.STATION)


## Botão Agulha (tecla 3), só nas fases com agulha. Mesmo estilo dos outros:
## modelo 3D da agulha no lugar do texto, com os ramos 0 e 1 coloridos.
func _add_switch_button() -> void:
	_switch_button = TOOL_BUTTON.instantiate()
	_switch_button.key_hint = "3"
	_switch_button.icon_model = SWITCH_SCENE
	_switch_button.model_hide_labels = false # os números dos ramos fazem parte do ícone
	_switch_button.model_yaw = 0.0
	_switch_button.model_tilt = 45.0
	_switch_button.model_padding = 1.0
	_switch_button.content_margin = 4
	_switch_button.button_group = _group
	_switch_button.pressed.connect(func(): tool_requested.emit(ToolRouter.ToolId.SWITCH, &""))
	_rail_button.get_parent().add_child(_switch_button)
	var view := _switch_button.get_icon_model() as SwitchView
	if view:
		# Tronco à esquerda, reto para a direita, desvio para baixo.
		view.apply(SwitchData.new(GridModel.Dir.WEST, GridModel.Dir.SOUTH, &"0"), _symbol_defs, false)


func _build_symbol_hint() -> void:
	_symbol_hint = _make_label(16)
	_symbol_hint.text = "Clique de novo para trocar o símbolo"
	_symbol_hint.add_theme_color_override("font_color", Color("f3e7b3"))
	_symbol_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Centralizada acima do botão Estação (filha dele, então acompanha o layout).
	_symbol_hint.anchor_left = 0.5
	_symbol_hint.anchor_right = 0.5
	_symbol_hint.offset_top = -34
	_symbol_hint.offset_bottom = -14
	_symbol_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_symbol_hint.visible = false
	_station_button.add_child(_symbol_hint)


func _update_symbol_hint(station_active: bool) -> void:
	var show := station_active and _symbol_count > 1 and not _learned_symbol_switch
	if show and not _symbol_hint.visible:
		_symbol_hint.modulate.a = 0.0
		create_tween().tween_property(_symbol_hint, "modulate:a", 1.0, 0.25)
	_symbol_hint.visible = show


## Pinta o modelo 3D do botão Estação com as cores do símbolo, igual ao tabuleiro.
func _paint_station_icon(symbol: StringName) -> void:
	var view := _station_button.get_icon_model() as StationView
	var definition: SymbolDefinition = _symbol_defs.get(symbol)
	if view and definition:
		view.apply(definition, false)


## Título da fase, fila de trens (palavra + chegar/barrar) e meta de trilhos.
func show_level(title: String, trains: Array[TrainDefinition], par: int) -> void:
	_ensure_info()
	_title_label.text = title
	_title_label.visible = not title.is_empty()
	_par = par
	_trains = trains
	_marks.clear()
	_marks.resize(trains.size())
	_marks.fill(Mark.NONE)
	_focus = 0
	_render_goal()


func mark_train(index: int, mark: Mark) -> void:
	if index < 0 or index >= _marks.size():
		return
	_marks[index] = mark
	if mark == Mark.RUNNING:
		_focus = index # o trem que vai andar passa para o destaque
	_render_goal()


func clear_marks() -> void:
	_marks.fill(Mark.NONE)
	_focus = 0
	_render_goal()


## Redesenha o OBJETIVO (só os vagões do trem da vez) e a FILA no canto
## superior direito: todos os trens em ordem, o da vez marcado com ▶ e os que
## já passaram apagados. Deixa claro que são viagens separadas, uma de cada vez.
func _render_goal() -> void:
	if _goal_current == null:
		return
	for child in _goal_current.get_children():
		child.queue_free()
	for child in _next_list.get_children():
		child.queue_free()
	if _trains.is_empty():
		return
	for definition in _trains[_focus].wagons:
		_goal_current.add_child(_make_chip(definition, 52))
	for i in _trains.size():
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.alignment = BoxContainer.ALIGNMENT_END
		row.add_theme_constant_override("separation", 4)
		var pointer := _make_label(20)
		pointer.text = "▶" if i == _focus else ""
		pointer.custom_minimum_size = Vector2(22, 0)
		pointer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pointer)
		for definition in _trains[i].wagons:
			row.add_child(_make_chip(definition, 30))
		if i < _focus:
			row.modulate.a = 0.35 # já passou
		_next_list.add_child(row)
	_next_panel.visible = _trains.size() > 1


func show_rail_count(count: int) -> void:
	_ensure_info()
	_rail_count.text = str(count)
	_par_label.visible = _par > 0
	_par_label.text = "/ %d" % _par
	_rail_count.add_theme_color_override("font_color", rails_color(count, _par))


## Cor do contador conforme as estrelas que esses trilhos dariam
## (mesma regra de LevelData.stars_for). Usada também no painel de fim de fase.
static func rails_color(count: int, par: int) -> Color:
	if par <= 0 or count <= par:
		return Color("8dff9a") # ★★★ verde
	if count <= par + LevelData.TWO_STAR_MARGIN:
		return Color("ffd34d") # ★★ amarelo
	return Color("ff7a5c") # ★ vermelho-alaranjado


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
	_info.add_child(_build_rail_block())
	_build_goal_panel()


## Bloco de trilhos: legenda e "usados / meta" (a meta vale 3 estrelas).
func _build_rail_block() -> Control:
	var block := VBoxContainer.new()
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_theme_constant_override("separation", 0)

	var caption := _make_label(16)
	caption.text = "TRILHOS"
	caption.add_theme_color_override("font_color", Color("f3e7b3"))
	block.add_child(caption)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	block.add_child(row)

	_rail_count = _make_label(36)
	row.add_child(_rail_count)

	_par_label = _make_label(24)
	_par_label.add_theme_color_override("font_color", Color("f3e7b3"))
	_par_label.size_flags_vertical = Control.SIZE_SHRINK_END # apoia na base do número
	row.add_child(_par_label)
	return block


## Painel "OBJETIVO" no topo central: a palavra que o trem precisa formar.
func _build_goal_panel() -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new()) # sem fundo
	add_child(panel)
	# Centralizado no topo; cresce para os dois lados conforme o tamanho da palavra.
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_top = 20

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)

	var title := _make_label(18)
	title.text = "OBJETIVO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("f3e7b3"))
	column.add_child(title)

	_goal_current = HBoxContainer.new()
	_goal_current.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goal_current.alignment = BoxContainer.ALIGNMENT_CENTER
	_goal_current.add_theme_constant_override("separation", 8)
	column.add_child(_goal_current)

	_build_next_panel()


## FILA de trens no canto superior direito, alinhada à direita.
func _build_next_panel() -> void:
	_next_panel = VBoxContainer.new()
	_next_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_next_panel.add_theme_constant_override("separation", 4)
	_next_panel.visible = false
	add_child(_next_panel)
	_next_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_next_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_next_panel.offset_right = -24
	_next_panel.offset_top = 20

	var caption := _make_label(14)
	caption.text = "FILA"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caption.add_theme_color_override("font_color", Color("f3e7b3"))
	_next_panel.add_child(caption)

	_next_list = VBoxContainer.new()
	_next_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_next_list.add_theme_constant_override("separation", 4)
	_next_panel.add_child(_next_list)


func _make_label(size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Color("17345a"))
	return label


## Vagão da palavra: quadradinho na cor do símbolo, com o símbolo escrito.
func _make_chip(definition: SymbolDefinition, size := 52) -> Control:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.custom_minimum_size = Vector2(size, size)
	var box := StyleBoxFlat.new()
	box.bg_color = definition.color if definition else Color.MAGENTA
	box.border_color = Color("17345a")
	box.set_border_width_all(3 if size > 40 else 2)
	box.set_corner_radius_all(8 if size > 40 else 5)
	chip.add_theme_stylebox_override("panel", box)
	var label := _make_label(int(size * 0.58))
	if size < 30:
		label.add_theme_constant_override("outline_size", 4) # contorno fino nos pequenos
	label.text = String(definition.id) if definition else "?"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(label)
	return chip


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
		text = "Chegou ao destino!" if total <= 1 else "Todos os trens corretos!"
	elif not expected_accept:
		text = "Esse trem devia ser barrado, mas chegou à chegada"
	else:
		text = _describe(result)
	if not ok and total > 1:
		text = "Trem %d: %s" % [train_index + 1, text]
	_result_label.text = "[center]%s[/center]" % text
	_result_label.add_theme_color_override("default_color", Color("7dff8a") if ok else Color("ff7a7a"))


## Mostra a dica no lugar da mensagem de resultado enquanto o trem anda.
func show_speed_hint(show: bool) -> void:
	if show and not _learned_fast_forward:
		_result_label.text = "[center]Segure Espaço para acelerar[/center]"
		_result_label.add_theme_color_override("default_color", Color("f3e7b3"))
		_speed_hint_visible = true
	elif _speed_hint_visible:
		clear_result()


func speed_hint_learned() -> void:
	_learned_fast_forward = true
	if _speed_hint_visible:
		clear_result()


func clear_result() -> void:
	_speed_hint_visible = false
	_result_label.text = ""


## Texto do resultado, do ponto de vista do trem. A célula do erro já fica
## destacada no tabuleiro, então não citamos coordenadas.
func _describe(result: ValidationResult) -> String:
	match result.failure:
		ValidationResult.Failure.NONE:
			return "Chegou ao destino!"
		ValidationResult.Failure.BROKEN_TRACK:
			return "O trilho acabou antes da chegada!"
		ValidationResult.Failure.AMBIGUOUS_STATION:
			return "O trem não sabe para onde ir nesta estação"
		ValidationResult.Failure.WRONG_SYMBOL:
			return "Estação errada: o trem esperava uma estação %s" % _symbol_tag(result.expected_symbol)
		ValidationResult.Failure.TOO_MANY_STATIONS:
			return "Estação a mais no caminho"
		ValidationResult.Failure.MISSING_SYMBOLS:
			var missing := result.word_size - result.consumed
			return "Faltou 1 estação" if missing == 1 else "Faltaram %d estações" % missing
	return "O trem ficou andando em círculos"


## Símbolo em negrito, na cor dele (como os vagões do OBJETIVO).
func _symbol_tag(symbol: StringName) -> String:
	var definition: SymbolDefinition = _symbol_defs.get(symbol)
	var text := "[b]%s[/b]" % String(symbol)
	if definition == null:
		return text
	return "[color=#%s]%s[/color]" % [definition.color.to_html(false), text]
