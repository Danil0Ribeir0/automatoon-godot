extends Control

## Seleção de fases: abas de mundo + mapa de fases do mundo escolhido.
const MAIN := "res://scenes/main/Main.tscn"
const MENU := "res://scenes/menu/MainMenu.tscn"
const TOOL_BUTTON := preload("res://scenes/ui/ToolButton.tscn")

@export var catalog: GameCatalog

var _map: LevelMap
var _tabs: HBoxContainer
var _world_title: Label
var _group := ButtonGroup.new()
var _world_index := 0


func _ready() -> void:
	if catalog == null or catalog.worlds.is_empty():
		push_error("LevelSelect: configure 'catalog' no Inspetor")
		return
	if GameSession.world:
		_world_index = maxi(catalog.worlds.find(GameSession.world), 0)
	_build()
	_select_world(_world_index)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file(MENU)


func _build() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 32
	column.offset_right = -32
	column.offset_top = 28
	column.offset_bottom = -28
	column.add_theme_constant_override("separation", 18)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 28)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	var back := _button("Voltar", "Esc", false)
	back.custom_minimum_size = Vector2(190, 64)
	back.pressed.connect(func(): get_tree().change_scene_to_file(MENU))
	top.add_child(back)
	var title := _label("Escolha a fase", 44)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	top.add_child(title)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 22)
	_tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_tabs)
	for i in catalog.worlds.size():
		var world := catalog.worlds[i]
		var tab := _button("Mundo %d · %s   ★ %d/%d" % [i + 1, world.title,
				ProgressStore.world_stars(world), world.levels.size() * 3], "", true)
		tab.button_group = _group
		tab.pressed.connect(_select_world.bind(i))
		_tabs.add_child(tab)
	for k in catalog.upcoming_worlds:
		var soon := _button("Mundo %d · em breve" % (catalog.worlds.size() + k + 1), "", false)
		soon.set_available(false)
		_tabs.add_child(soon)

	_world_title = _label("", 26)
	_world_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(_world_title)

	_map = LevelMap.new()
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.mouse_filter = Control.MOUSE_FILTER_PASS
	_map.level_chosen.connect(_on_level_chosen)
	column.add_child(_map)


func _select_world(index: int) -> void:
	_world_index = index
	var tab := _tabs.get_child(index) as ToolButton
	if tab:
		tab.set_pressed_no_signal(true)
	var world := catalog.worlds[index]
	_world_title.text = "Cada fase é uma estação da linha. Conclua uma para liberar a próxima."
	_map.show_world(world)


func _on_level_chosen(index: int) -> void:
	GameSession.world = catalog.worlds[_world_index]
	GameSession.level_index = index
	get_tree().change_scene_to_file(MAIN)


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f3e7b3"))
	label.add_theme_constant_override("outline_size", 12)
	label.add_theme_color_override("font_outline_color", Color("17345a"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String, key: String, toggle: bool) -> ToolButton:
	var button: ToolButton = TOOL_BUTTON.instantiate()
	button.text = text
	button.key_hint = key
	button.toggleable = toggle
	button.font_size = 24
	button.custom_minimum_size = Vector2(0, 60)
	return button
