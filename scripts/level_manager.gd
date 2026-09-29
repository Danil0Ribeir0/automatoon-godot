extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var grid_system: GridSystem = $GridSystem
@onready var train: Train = $Train
@onready var board_plane: StaticBody3D = $BoardPlane

var hovered_coords: Vector2i = Vector2i(-999, -999)
var cursor_visual: MeshInstance3D

var is_simulating: bool = false
var is_dragging_build: bool = false
var is_dragging_erase: bool = false
var drag_path: Array[Vector2i] = []
var start_incoming_dir: int = -1

func _ready() -> void:
	_setup_board_collider()
	_create_cursor_highlight()
	train.arrived_at_exit.connect(_on_train_completed)

func _process(_delta: float) -> void:
	var previous_coords := hovered_coords
	_update_hovered_cell()
	
	if hovered_coords != previous_coords and grid_system.is_inside_playable_grid(hovered_coords):
		if is_dragging_build:
			_on_drag_step(hovered_coords)
		elif is_dragging_erase:
			grid_system.clear_tile(hovered_coords)

func _unhandled_input(event: InputEvent) -> void:
	if is_simulating:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and grid_system.is_inside_playable_grid(hovered_coords):
				_start_drag_build(hovered_coords)
			elif not event.pressed:
				is_dragging_build = false
				drag_path.clear()
				
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				is_dragging_erase = true
				if grid_system.is_inside_playable_grid(hovered_coords):
					grid_system.clear_tile(hovered_coords)
			else:
				is_dragging_erase = false

	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if not is_simulating:
			_try_run_simulation()
		else:
			_reset_simulation()
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

func _start_drag_build(start_coords: Vector2i) -> void:
	is_dragging_build = true
	drag_path = [start_coords]
	
	start_incoming_dir = grid_system.find_incoming_neighbor_dir(start_coords)
	if start_incoming_dir != -1:
		grid_system.set_tile_single_dir(start_coords, start_incoming_dir)
	else:
		grid_system.set_tile_single_dir(start_coords, RailTileData.Dir.EAST)

func _on_drag_step(new_coords: Vector2i) -> void:
	if drag_path.is_empty():
		return
		
	var last_coords: Vector2i = drag_path.back()
	
	if drag_path.size() >= 2 and new_coords == drag_path[drag_path.size() - 2]:
		grid_system.clear_tile(last_coords)
		drag_path.pop_back()
		_refresh_tile_in_path(drag_path.size() - 1)
		return
		
	var diff: Vector2i = (new_coords - last_coords).abs()
	if diff.x + diff.y != 1:
		return
		
	if new_coords in drag_path:
		return
		
	drag_path.append(new_coords)
	_refresh_tile_in_path(drag_path.size() - 2)
	_refresh_tile_in_path(drag_path.size() - 1)

func _refresh_tile_in_path(idx: int) -> void:
	if idx < 0 or idx >= drag_path.size():
		return
		
	var current_coords: Vector2i = drag_path[idx]
	var in_dir: int = -1
	var out_dir: int = -1
	
	if idx > 0:
		in_dir = grid_system.get_direction_between(current_coords, drag_path[idx - 1])
	else:
		in_dir = start_incoming_dir
		
	if idx < drag_path.size() - 1:
		out_dir = grid_system.get_direction_between(current_coords, drag_path[idx + 1])
	else:
		var neighbor_dir := grid_system.find_incoming_neighbor_dir(current_coords)
		if neighbor_dir != -1 and neighbor_dir != in_dir:
			out_dir = neighbor_dir
			
	if in_dir != -1 and out_dir != -1:
		grid_system.set_tile_two_dirs(current_coords, in_dir, out_dir)
	elif in_dir != -1:
		grid_system.set_tile_single_dir(current_coords, in_dir)
	elif out_dir != -1:
		grid_system.set_tile_single_dir(current_coords, out_dir)

func _update_hovered_cell() -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_end := ray_origin + camera.project_ray_normal(mouse_pos) * 100.0
	
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	
	if result:
		var hit_pos: Vector3 = result.position
		var gx := floori(hit_pos.x / grid_system.cell_size)
		var gy := floori(hit_pos.z / grid_system.cell_size)
		var coords := Vector2i(gx, gy)
		
		if grid_system.is_inside_playable_grid(coords):
			hovered_coords = coords
			cursor_visual.visible = true
			cursor_visual.position = grid_system.grid_to_world(coords) + Vector3(0, 0.02, 0)
			return
			
	hovered_coords = Vector2i(-999, -999)
	cursor_visual.visible = false

func _create_cursor_highlight() -> void:
	cursor_visual = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(grid_system.cell_size * 0.96, 0.02, grid_system.cell_size * 0.96)
	
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.8, 1.0, 0.35)
	box.material = mat
	
	cursor_visual.mesh = box
	cursor_visual.visible = false
	add_child(cursor_visual)

func _try_run_simulation() -> void:
	var result: Dictionary = grid_system.validate_automaton_path()
	
	if result["accepted"]:
		is_simulating = true
		cursor_visual.visible = false
		
		# 1. Gera a curva 3D suave do trajeto
		var curve: Curve3D = grid_system.generate_smooth_curve(result["path"])
		
		# 2. Configura a fila de vagões com base na palavra atual do nível
		train.spawn_train(grid_system.train_wagons, curve)
		
		# 3. Dá partida no trem
		train.start_run()
	else:
		print("Não foi possível iniciar a viagem: ", result["reason"])

func _on_train_completed() -> void:
	print("🎉 FASE CONCLUÍDA: Todos os vagões foram entregues com sucesso!")
	# Aguarda 1 segundo e permite reiniciar ou ir para o próximo nível
	await get_tree().create_timer(1.2).timeout
	_reset_simulation()

func _reset_simulation() -> void:
	is_simulating = false
	train.stop_run()
	# Limpa os vagões da pista
	for w in train.wagons:
		w.visible = false

func _setup_board_collider() -> void:
	var total_w := grid_system.grid_size.x * grid_system.cell_size
	var total_h := grid_system.grid_size.y * grid_system.cell_size
	
	# Centraliza o StaticBody3D no meio exato da grid
	board_plane.position = Vector3(total_w * 0.5, 0.0, total_h * 0.5)
	
	# Ajusta o tamanho do BoxShape3D filho
	var col_shape: CollisionShape3D = board_plane.get_node_or_null("CollisionShape3D")
	if col_shape and col_shape.shape is BoxShape3D:
		col_shape.shape.size = Vector3(total_w, 0.1, total_h)
