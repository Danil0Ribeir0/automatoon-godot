extends CanvasLayer
class_name GameHUD

signal tool_changed(is_station_tool: bool, station_symbol: String)

@onready var rail_btn: Button = $MarginContainer/HBoxContainer/RailToolButton
@onready var station_btn: Button = $MarginContainer/HBoxContainer/StationToolButton

var title_label: Label
var hint_label: Label

var allow_stations: bool = false
var available_symbols: Array[String] = ["1"]
var current_symbol_idx: int = 0
var is_station_active: bool = false

func _ready() -> void:
	_create_top_banner()
	rail_btn.pressed.connect(select_rail_tool)
	station_btn.pressed.connect(select_or_cycle_station_tool)

# Configura a HUD de acordo com as regras da fase atual (LevelConfig)
func setup_for_level(config: LevelConfig) -> void:
	title_label.text = config.level_title
	hint_label.text = config.tutorial_hint
	
	allow_stations = config.allow_placing_stations
	available_symbols = config.available_symbols.duplicate()
	current_symbol_idx = 0
	
	# Na Fase 1, trava o botão de estação para focar só nos trilhos
	station_btn.disabled = not allow_stations
	_update_station_button_text()
	select_rail_tool()

func select_rail_tool() -> void:
	is_station_active = false
	_refresh_visuals()
	tool_changed.emit(false, get_current_symbol())

func select_or_cycle_station_tool() -> void:
	if not allow_stations or available_symbols.is_empty():
		return
		
	# Se já estava na ferramenta de Estação e apertou '2' de novo, troca para o próximo número!
	if is_station_active and available_symbols.size() > 1:
		current_symbol_idx = (current_symbol_idx + 1) % available_symbols.size()
	else:
		is_station_active = true
		
	_update_station_button_text()
	_refresh_visuals()
	tool_changed.emit(true, get_current_symbol())

func get_current_symbol() -> String:
	if available_symbols.is_empty():
		return "1"
	return available_symbols[current_symbol_idx]

func _update_station_button_text() -> void:
	if not allow_stations:
		station_btn.text = "[2] Estação (Fixa)"
	else:
		station_btn.text = "[2] Estação: [" + get_current_symbol() + "]"

func _refresh_visuals() -> void:
	if not is_station_active:
		rail_btn.modulate = Color(0.4, 0.9, 1.0)
		station_btn.modulate = Color(0.7, 0.7, 0.7)
	else:
		rail_btn.modulate = Color(0.7, 0.7, 0.7)
		# Pinta o botão da estação com a cor exata do símbolo atual (Vermelho, Azul, Cinza...)
		station_btn.modulate = AutomataPalette.get_symbol_color(get_current_symbol()).lightened(0.2)

# Cria o cabeçalho superior com Título da Fase e Dica do Tutorial automaticamente
func _create_top_banner() -> void:
	var top_margin := MarginContainer.new()
	top_margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_margin.add_theme_constant_override("margin_top", 20)
	top_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_margin)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_margin.add_child(vbox)
	
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_constant_override("outline_size", 8)
	vbox.add_child(title_label)
	
	hint_label = Label.new()
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 16)
	hint_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	hint_label.add_theme_constant_override("outline_size", 6)
	vbox.add_child(hint_label)
