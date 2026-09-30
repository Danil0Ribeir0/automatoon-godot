extends Node3D
class_name Train

@export var wagon_scene: PackedScene = preload("res://scenes/wagon.tscn")
@export var train_speed: float = 4.5
@export var wagon_spacing: float = 1.2

@onready var train_path: Path3D = $TrainPath

var wagons: Array[Wagon] = []
var move_tween: Tween

signal arrived_at_exit

func spawn_train(symbols: Array[String], curve: Curve3D) -> void:
	stop_run()
	for w in wagons:
		w.queue_free()
	wagons.clear()
	train_path.curve = curve
	
	for s in symbols:
		var w: Wagon = wagon_scene.instantiate()
		train_path.add_child(w)
		w.setup(s)
		w.visible = false
		wagons.append(w)

func start_run() -> void:
	# Distância total = tamanho da pista + comprimento da fila de vagões
	var total_dist := train_path.curve.get_baked_length() + (wagons.size() - 1) * wagon_spacing
	
	move_tween = create_tween()
	move_tween.tween_method(_update_wagons, 0.0, total_dist, total_dist / train_speed)
	move_tween.finished.connect(arrived_at_exit.emit)

func stop_run() -> void:
	if move_tween and move_tween.is_running():
		move_tween.kill()
	for w in wagons:
		w.visible = false

func _update_wagons(lead_dist: float) -> void:
	for i in wagons.size():
		var dist := lead_dist - (i * wagon_spacing)
		wagons[i].visible = dist >= 0.0
		wagons[i].progress = maxf(0.0, dist)
