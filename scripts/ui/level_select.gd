extends Control

## Seleção de fases no visual minimalista do menu inicial: texto solto sobre o
## fundo animado, abas de mundo em texto (MenuLink) e o mapa de estações.
const MAIN := "res://scenes/main/Main.tscn"
const MENU := "res://scenes/menu/MainMenu.tscn"

@export var catalog: GameCatalog

var _map: LevelMap
var _tabs: Array[MenuLink] = []
var _world_index := 0


func _ready() -> void:
	if catalog == null or catalog.worlds.is_empty():
		push_error("LevelSelect: configure 'catalog' no Inspetor")
		return
	if GameSession.world:
		_world_index = maxi(catalog.worlds.find(GameSession.world), 0)
	var column := _build()
	_select_world(_world_index)
	_play_intro(column)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		_go_back()


func _go_back() -> void:
	get_tree().change_scene_to_file(MENU)


func _build() -> Control:
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 40
	column.offset_right = -40
	column.offset_top = 24
	column.offset_bottom = -36
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	var back := MenuStyle.link("‹  Voltar", 22)
	back.custom_minimum_size = Vector2(140, 42)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(_go_back)
	column.add_child(back)

	column.add_child(MenuStyle.heading("Escolha a fase", 52))

	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 36)
	tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(tabs)
	for i in catalog.worlds.size():
		var world := catalog.worlds[i]
		var tab := MenuStyle.link("Mundo %d · %s   ★ %d/%d" % [i + 1, world.title,
				ProgressStore.world_stars(world), world.levels.size() * 3], 22)
		tab.pressed.connect(_select_world.bind(i))
		tabs.add_child(tab)
		_tabs.append(tab)
	for k in catalog.upcoming_worlds:
		var soon := MenuStyle.link("Mundo %d · em breve" % (catalog.worlds.size() + k + 1), 22)
		soon.set_available(false)
		tabs.add_child(soon)

	_map = LevelMap.new()
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.mouse_filter = Control.MOUSE_FILTER_PASS
	_map.level_chosen.connect(_on_level_chosen)
	column.add_child(_map)
	return column


func _select_world(index: int) -> void:
	_world_index = index
	for i in _tabs.size():
		_tabs[i].selected = i == index
	_map.show_world(catalog.worlds[index])


func _on_level_chosen(index: int) -> void:
	GameSession.world = catalog.worlds[_world_index]
	GameSession.level_index = index
	get_tree().change_scene_to_file(MAIN)


## Entrada suave, no mesmo ritmo do menu inicial.
func _play_intro(column: Control) -> void:
	column.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(column, "modulate:a", 1.0, 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
