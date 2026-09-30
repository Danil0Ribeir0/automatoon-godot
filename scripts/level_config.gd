class_name LevelConfig
extends Resource

@export var level_title: String = "Fase 1: Primeiros Trilhos"
@export_multiline var tutorial_hint: String = "Arraste o mouse com o Botão Esquerdo para ligar o Trem à Estação e até o FIM."

@export var grid_size: Vector2i = Vector2i(5, 5)
@export var spawn_coords: Vector2i = Vector2i(-1, 2)
@export var exit_coords: Vector2i = Vector2i(5, 2)

@export var train_wagons: Array[String] = ["1"]
@export var allow_placing_stations: bool = false
@export var available_symbols: Array[String] = ["1"]

@export var preplaced_stations: Dictionary = {}

static func create_tutorial_levels() -> Array[LevelConfig]:
	var lvl1 := LevelConfig.new()
	lvl1.level_title = "Tutorial 1/3: Transições (Trilhos)"
	lvl1.tutorial_hint = "A Estação [1] já está no mapa! Arraste os trilhos para passar por ela e chegar ao FIM. (Espaço = Testar)"
	lvl1.grid_size = Vector2i(5, 5)
	lvl1.spawn_coords = Vector2i(-1, 2)
	lvl1.exit_coords = Vector2i(5, 2)
	lvl1.train_wagons = ["1"]
	lvl1.allow_placing_stations = false
	lvl1.available_symbols = []
	lvl1.preplaced_stations = { Vector2i(2, 1): "1" }
	
	var lvl2 := LevelConfig.new()
	lvl2.level_title = "Tutorial 2/3: Estados (Estações)"
	lvl2.tutorial_hint = "Use a Tecla [2] para colocar as Estações na ordem dos vagões do trem e a Tecla [1] para ligar os trilhos!"
	lvl2.grid_size = Vector2i(5, 5)
	lvl2.spawn_coords = Vector2i(-1, 2)
	lvl2.exit_coords = Vector2i(5, 2)
	lvl2.train_wagons = ["1", "2"]
	lvl2.allow_placing_stations = true
	lvl2.available_symbols = ["1", "2"]
	lvl2.preplaced_stations = {}
	
	var lvl3 := LevelConfig.new()
	lvl3.level_title = "Tutorial 3/3: Construindo a Linguagem"
	lvl3.tutorial_hint = "Mapa expandido (7x7)! Monte os estados e transições para reconhecer todos os 4 vagões na ordem correta."
	lvl3.grid_size = Vector2i(7, 7)
	lvl3.spawn_coords = Vector2i(-1, 3)
	lvl3.exit_coords = Vector2i(7, 3)
	lvl3.train_wagons = ["1", "0", "2", "1"]
	lvl3.allow_placing_stations = true
	lvl3.available_symbols = ["0", "1", "2"]
	lvl3.preplaced_stations = {}
	
	return [lvl1, lvl2, lvl3]
