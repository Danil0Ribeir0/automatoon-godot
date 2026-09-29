extends Node3D
class_name Train

@export var wagon_scene: PackedScene = preload("res://scenes/wagon.tscn")
@export var train_speed: float = 2.5 # Metros por segundo na grid
@export var wagon_spacing: float = 0.7 # Distância em metros entre o centro de cada vagão

@onready var train_path: Path3D = $TrainPath

var wagons: Array[Wagon] = []
var is_moving: bool = false
var lead_distance: float = 0.0 # Distância percorrida pela locomotiva líder
var total_curve_length: float = 0.0

signal reached_station(station_symbol: String)
signal arrived_at_exit
signal derailed

func _process(delta: float) -> void:
	if not is_moving or wagons.is_empty():
		return
		
	lead_distance += train_speed * delta
	
	# Atualiza a posição física de cada vagão ao longo da curva usando metros (progress)
	for i in range(wagons.size()):
		var wagon := wagons[i]
		var wagon_target_dist := lead_distance - (i * wagon_spacing)
		
		if wagon_target_dist >= 0:
			wagon.visible = true
			wagon.progress = wagon_target_dist
		else:
			# Vagão ainda não saiu do Spawn externo
			wagon.visible = false
			wagon.progress = 0.0
			
	# Verifica se o último vagão da fila chegou ao fim da linha
	var last_wagon_dist := lead_distance - ((wagons.size() - 1) * wagon_spacing)
	if last_wagon_dist >= total_curve_length:
		is_moving = false
		arrived_at_exit.emit()

# Monta a composição de acordo com a palavra de entrada (ex: ["1", "3", "0"])
func spawn_train(symbols: Array[String], curve: Curve3D) -> void:
	# Limpa qualquer trem anterior
	for w in wagons:
		w.queue_free()
	wagons.clear()
	
	train_path.curve = curve
	total_curve_length = curve.get_baked_length()
	lead_distance = 0.0
	is_moving = false
	
	# Instancia cada vagão como filho do TrainPath
	for s in symbols:
		var wagon_instance: Wagon = wagon_scene.instantiate()
		train_path.add_child(wagon_instance)
		wagon_instance.setup(s)
		wagon_instance.visible = false
		wagons.append(wagon_instance)

func start_run() -> void:
	is_moving = true

func stop_run() -> void:
	is_moving = false
