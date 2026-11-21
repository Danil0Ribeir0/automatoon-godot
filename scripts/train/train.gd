class_name Train
extends Node3D

signal finished
## A frente do trem chegou ao meio do passo `step_index` do percurso.
signal step_reached(step_index: int)

@export var wagon_scene: PackedScene
## Velocidade em células por segundo.
@export var speed := 1.5
## Distância entre o começo de um vagão e o do próximo (o vagão tem 0,56 de comprimento).
@export var wagon_spacing := 0.65
## Altura da curva sobre o chão: ajuste até as rodas encostarem no trilho.
@export var ride_height := 0.0

@onready var _path: Path3D = $Path3D

var _track: TrackPath
var _follows: Array[PathFollow3D] = []
var _next_step := 0
var _tween: Tween
## Distância da curva onde fica a frente do trem estacionado (boca do túnel do Spawn).
var _park_at := 0.0
## Já está estacionado: editar o tabuleiro não precisa recriar os vagões.
var _parked := false


## Trem parado nos trilhos antes do Spawn, esperando o teste.
## `spawn_step` = passo do Spawn com exit_dir apontando para dentro da grid.
func park(spawn_step: PathStep, wagons: Array[SymbolDefinition], board: GridBoard) -> void:
	if _parked:
		return
	_build([spawn_step], wagons, board)
	_set_distance(_park_at)
	_parked = true


## Retorna false se não há o que animar (o chamador não deve esperar `finished`).
func run(steps: Array[PathStep], wagons: Array[SymbolDefinition], board: GridBoard, success: bool) -> bool:
	if steps.size() < 2 or wagons.is_empty() or wagon_scene == null:
		return false
	_build(steps, wagons, board)
	_parked = false

	# Sucesso: o trem inteiro entra no Exit. Falha: a frente para no meio da célula do erro.
	var stop_at := _track.curve.get_baked_length() if success else _track.vanish_at
	var duration := maxf((stop_at - _park_at) / (speed * board.cell_size), 0.01)

	_next_step = 0
	_set_distance(_park_at)
	_tween = create_tween()
	_tween.tween_method(_set_distance, _park_at, stop_at, duration)
	_tween.finished.connect(func(): finished.emit())
	return true


## Acelera (ou volta ao normal) o trem já em movimento. 1.0 = velocidade normal.
func set_speed_multiplier(multiplier: float) -> void:
	if _tween and _tween.is_valid():
		_tween.set_speed_scale(multiplier)


func is_running() -> bool:
	return _tween != null and _tween.is_running()


func clear() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	for follow in _follows:
		follow.queue_free()
	_follows.clear()
	_path.curve = null
	_track = null
	_parked = false
	visible = false


## Monta curva e vagões. Park e run usam a mesma geometria inicial,
## então o trem não "pula" ao começar a andar.
func _build(steps: Array[PathStep], wagons: Array[SymbolDefinition], board: GridBoard) -> void:
	clear()
	if wagons.is_empty() or wagon_scene == null:
		return
	var lead := wagons.size() * wagon_spacing + board.cell_size
	_track = TrackPathBuilder.build(steps, board, lead, ride_height)
	_path.curve = _track.curve
	# Frente do 1º vagão um pouco antes da boca do túnel (o vagão tem 0,56 de comprimento).
	_park_at = lead - 0.4 * board.cell_size

	for definition in wagons:
		var follow := PathFollow3D.new()
		follow.loop = false
		follow.rotation_mode = PathFollow3D.ROTATION_Y
		_path.add_child(follow)
		var wagon := wagon_scene.instantiate()
		follow.add_child(wagon)
		if wagon is WagonView:
			wagon.apply(definition)
		_follows.append(follow)
	visible = true


func _set_distance(distance: float) -> void:
	if _track == null:
		return
	for i in _follows.size():
		var progress := distance - i * wagon_spacing
		_follows[i].progress = maxf(progress, 0.0)
		# Some depois de entrar no Exit.
		_follows[i].visible = progress >= 0.0 and progress <= _track.vanish_at
	while _next_step < _track.step_distances.size() and distance >= _track.step_distances[_next_step]:
		step_reached.emit(_next_step)
		_next_step += 1
