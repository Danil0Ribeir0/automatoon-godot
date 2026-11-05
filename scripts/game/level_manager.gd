class_name LevelManager
extends Node

## Carrega as fases de um mundo, uma de cada vez. Repetir e avançar são a mesma
## operação: libera o GameWorld atual e cria um novo com a fase escolhida.

@export var world: WorldData
@export var game_scene: PackedScene
## Fase inicial (0 = primeira). Útil para testar uma fase específica.
@export var start_level := 0

const LEVEL_SELECT := "res://scenes/menu/LevelSelect.tscn"
const MAIN_MENU := "res://scenes/menu/MainMenu.tscn"

@onready var _panel: LevelCompletePanel = $LevelCompletePanel
@onready var _pause: PauseMenu = $PauseMenu

var _index := 0
var _game: Node


func _ready() -> void:
	GameSettings.ensure_loaded()
	if GameSession.world: # veio do menu de fases
		world = GameSession.world
		start_level = GameSession.level_index
	_panel.retry_requested.connect(func(): load_level(_index))
	_panel.next_requested.connect(_on_next)
	_panel.menu_requested.connect(_go_to_level_select)
	_pause.main_menu_requested.connect(_go_to_main_menu)
	_pause.settings_changed.connect(func():
		if _game and _game.has_method("apply_settings"):
			_game.apply_settings())
	load_level(start_level)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _panel.is_open():
			_go_to_level_select() # fase vencida: Esc = "Fases", como no painel
		else:
			_pause.open() # com a pausa aberta, o próprio PauseMenu trata o Esc


func _go_to_main_menu() -> void:
	GameSession.world = world
	GameSession.level_index = _index
	get_tree().change_scene_to_file(MAIN_MENU)


func _go_to_level_select() -> void:
	GameSession.world = world
	GameSession.level_index = _index
	get_tree().change_scene_to_file(LEVEL_SELECT)


func load_level(index: int) -> void:
	if world == null or world.levels.is_empty() or game_scene == null:
		push_error("LevelManager: configure 'world' e 'game_scene' no Inspetor")
		return
	_index = clampi(index, 0, world.levels.size() - 1)
	_panel.hide_panel()
	if _game:
		remove_child(_game)
		_game.queue_free()
	_game = game_scene.instantiate()
	_game.set("level", world.levels[_index])
	_game.set("level_number", _index + 1)
	_game.set("theme", world.theme)
	_game.connect("level_completed", _on_level_completed)
	_game.connect("restart_requested", func(): load_level(_index))
	add_child(_game)
	move_child(_game, 0)


func _on_level_completed(stars: int, rails: int) -> void:
	ProgressStore.record(world.id, _index, stars)
	var is_last := _index >= world.levels.size() - 1
	_panel.show_result(stars, rails, world.levels[_index].par_rails,
			ProgressStore.best_stars(world.id, _index), is_last)


func _on_next() -> void:
	if _index >= world.levels.size() - 1:
		_go_to_level_select() # fim do mundo
	else:
		load_level(_index + 1)
