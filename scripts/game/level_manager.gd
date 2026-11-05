class_name LevelManager
extends Node

## Carrega as fases de um mundo, uma de cada vez. Repetir e avançar são a mesma
## operação: libera o GameWorld atual e cria um novo com a fase escolhida.

@export var world: WorldData
@export var game_scene: PackedScene
## Fase inicial (0 = primeira). Útil para testar uma fase específica.
@export var start_level := 0

@onready var _panel: LevelCompletePanel = $LevelCompletePanel

var _index := 0
var _game: Node


func _ready() -> void:
	_panel.retry_requested.connect(func(): load_level(_index))
	_panel.next_requested.connect(_on_next)
	load_level(start_level)


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
	var is_last := _index >= world.levels.size() - 1
	load_level(0 if is_last else _index + 1)
