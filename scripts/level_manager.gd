extends Node3D

enum BuildTool { RAIL, STATION }

@onready var camera: Camera3D = $Camera3D
@onready var grid_system: GridSystem = $GridSystem
@onready var board_plane: StaticBody3D = $BoardPlane
@onready var train: Train = $Train

# Referências dos botões da UI
@onready var rail_btn: Button = $HUD/MarginContainer/HBoxContainer/RailToolButton
@onready var station_btn: Button = $HUD/MarginContainer/HBoxContainer/StationToolButton

var current_tool: BuildTool = BuildTool.RAIL
var current_station_symbol: String = "1" # Símbolo padrão ao colocar estação

var hovered_coords: Vector2i = Vector2i(-999, -999)
var cursor_visual: MeshInstance3D
var cursor_material: StandardMaterial3D

var is_dragging_build: bool = false
var is_dragging_erase: bool = false
var drag_path: Array[Vector2i] = []
var start_incoming_dir: int = -1
var is_simulating: bool = false

func _ready() -> void:
	_setup_board_collider()
	_create_cursor_highlight()
	train.arrived_at_exit.connect(_on_train_completed)
	
	# Conecta os cliques nos botões da UI
	rail_btn.pressed.connect(func(): select_tool(BuildTool.RAIL))
	station_btn.pressed.connect(func(): select_tool(BuildTool.STATION))
	
	# Inicia com a ferramenta de Trilho selecionada
	select_tool(BuildTool.RAIL)

func _process(_delta: float) -> void:
	var previous_coords := hovered_coords
	_update_hovered_cell()
	
	if hovered_coords != previous_coords and grid_system.is_inside_playable_grid(hovered_coords):
		if is_dragging_build and current_tool == BuildTool.RAIL:
			_on_drag_step(hovered_coords)
		elif is_dragging_erase:
			grid_system.clear_tile(hovered_coords)

func _unhandled_input(event: InputEvent) -> void:
	# ESC volta para o Menu Principal
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return
		
	# ESPAÇO inicia ou reseta a simulação do trem
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if not is_simulating:
			_try_run_simulation()
		else:
			_reset_simulation()
		return
		
	if is_simulating:
		return
		
	# ATALHOS DE TECLADO: Tecla 1 (Trilho) e Tecla 2 (Estação)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1 or event.keycode == KEY_KP_1:
			select_tool(BuildTool.RAIL)
			return
		elif event.keycode == KEY_2 or event.keycode == KEY_KP_2:
			select_tool(BuildTool.STATION)
			return
			
	# CLIQUES DO MOUSE NO GRID
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and grid_system.is_inside_playable_grid(hovered_coords):
				if current_tool == BuildTool.RAIL:
					_start_drag_build(hovered_coords)
				elif current_tool == BuildTool.STATION:
					grid_system.place_or_rotate_station(hovered_coords, current_station_symbol)
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

# Alterna entre Trilho (1) e Estação (2), atualizando a UI e a cor do cursor 3D
func select_tool(new_tool: BuildTool) -> void:
	current_tool = new_tool
	is_dragging_build = false
	drag_path.clear()
	
	if current_tool == BuildTool.RAIL:
		rail_btn.modulate = Color(0.4, 0.9, 1.0)   # Destaca botão 1 em Azul
		station_btn.modulate = Color(0.7, 0.7, 0.7) # Apaga botão 2
		if cursor_material:
			cursor_material.albedo_color = Color(0.2, 0.8, 1.0, 0.35) # Cursor Azul
	else:
		rail_btn.modulate = Color(0.7, 0.7, 0.7)   # Apaga botão 1
		station_btn.modulate = Color(1.0, 0.85, 0.2) # Destaca botão 2 em Amarelo
		if cursor_material:
			cursor_material.albedo_color = Color(1.0, 0.8, 0.1, 0.45) # Cursor Amarelo

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

func _setup_board_collider() -> void:
	var total_w := grid_system.grid_size.x * grid_system.cell_size
	var total_h := grid_system.grid_size.y * grid_system.cell_size
	board_plane.position = Vector3(total_w * 0.5, 0.0, total_h * 0.5)
	
	var col_shape: CollisionShape3D = board_plane.get_node_or_null("CollisionShape3D")
	if col_shape and col_shape.shape is BoxShape3D:
		col_shape.shape.size = Vector3(total_w, 0.1, total_h)

func _create_cursor_highlight() -> void:
	cursor_visual = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(grid_system.cell_size * 0.96, 0.02, grid_system.cell_size * 0.96)
	
	cursor_material = StandardMaterial3D.new()
	cursor_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cursor_material.albedo_color = Color(0.2, 0.8, 1.0, 0.35)
	box.material = cursor_material
	
	cursor_visual.mesh = box
	cursor_visual.visible = false
	add_child(cursor_visual)

func _try_run_simulation() -> void:
	var result: Dictionary = grid_system.validate_automaton_path()
	
	if result["accepted"]:
		is_simulating = true
		cursor_visual.visible = false
		var curve: Curve3D = grid_system.generate_smooth_curve(result["path"])
		train.spawn_train(grid_system.train_wagons, curve)
		train.start_run()
	else:
		print("Não foi possível iniciar a viagem: ", result["reason"])

func _on_train_completed() -> void:
	print("🎉 FASE CONCLUÍDA: Todos os vagões foram entregues com sucesso!")
	await get_tree().create_timer(1.2).timeout
	_reset_simulation()

func _reset_simulation() -> void:
	is_simulating = false
	train.stop_run()
	for w in train.wagons:
		w.visible = false
