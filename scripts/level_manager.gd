extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var grid_system: GridSystem = $GridSystem

var hovered_coords: Vector2i = Vector2i(-999, -999)
var cursor_visual: MeshInstance3D

# Controle de arraste (Drag)
var is_dragging_build: bool = false
var is_dragging_erase: bool = false
var drag_path: Array[Vector2i] = []
var start_incoming_dir: int = -1 # Guarda se o 1º tile do arraste se conectou ao Spawn/Estação/Trilho

func _ready() -> void:
	_create_cursor_highlight()

func _process(_delta: float) -> void:
	var previous_coords := hovered_coords
	_update_hovered_cell()
	
	# Se o mouse mudou de célula enquanto está segurando o botão:
	if hovered_coords != previous_coords and grid_system.is_inside_playable_grid(hovered_coords):
		if is_dragging_build:
			_on_drag_step(hovered_coords)
		elif is_dragging_erase:
			grid_system.clear_tile(hovered_coords)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# BOTÃO ESQUERDO: Iniciar / Parar construção por arraste
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and grid_system.is_inside_playable_grid(hovered_coords):
				_start_drag_build(hovered_coords)
			elif not event.pressed:
				is_dragging_build = false
				drag_path.clear()
				
		# BOTÃO DIREITO: Borracha (Apagar clicando ou arrastando)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				is_dragging_erase = true
				if grid_system.is_inside_playable_grid(hovered_coords):
					grid_system.clear_tile(hovered_coords)
			else:
				is_dragging_erase = false

func _start_drag_build(start_coords: Vector2i) -> void:
	is_dragging_build = true
	drag_path = [start_coords]
	
	# Checa se onde clicamos já existe um vizinho apontando para cá (ex: o Spawn em (-1, 2)!)
	start_incoming_dir = grid_system.find_incoming_neighbor_dir(start_coords)
	if start_incoming_dir != -1:
		grid_system.set_tile_single_dir(start_coords, start_incoming_dir)
	else:
		# Se começou no meio do nada, coloca um trilho reto padrão até o mouse se mover
		grid_system.set_tile_single_dir(start_coords, RailTileData.Dir.EAST)

func _on_drag_step(new_coords: Vector2i) -> void:
	if drag_path.is_empty():
		return
		
	var last_coords: Vector2i = drag_path.back()
	
	# 1. Verifica se o jogador voltou o mouse para a casa anterior (Desfazer / Backtrack)
	if drag_path.size() >= 2 and new_coords == drag_path[drag_path.size() - 2]:
		grid_system.clear_tile(last_coords)
		drag_path.pop_back()
		_refresh_tile_in_path(drag_path.size() - 1)
		return
		
	# 2. Só avança se a nova célula for vizinha ortogonal (distância Manhattan == 1)
	var diff: Vector2i = (new_coords - last_coords).abs()
	if diff.x + diff.y != 1:
		return
		
	# Evita cruzar o próprio caminho no mesmo arraste
	if new_coords in drag_path:
		return
		
	# 3. Adiciona a nova célula ao caminho e atualiza o penúltimo e o último trilho!
	drag_path.append(new_coords)
	_refresh_tile_in_path(drag_path.size() - 2) # Rotaciona/curva o penúltimo trilho
	_refresh_tile_in_path(drag_path.size() - 1) # Cria o novo trilho na ponta

# Atualiza o formato (Reta ou Curva) do trilho no índice 'idx' do rastro atual
func _refresh_tile_in_path(idx: int) -> void:
	if idx < 0 or idx >= drag_path.size():
		return
		
	var current_coords: Vector2i = drag_path[idx]
	var in_dir: int = -1
	var out_dir: int = -1
	
	# Descobre de onde o trilho vem (in_dir)
	if idx > 0:
		in_dir = grid_system.get_direction_between(current_coords, drag_path[idx - 1])
	else:
		in_dir = start_incoming_dir
		
	# Descobre para onde o trilho vai (out_dir)
	if idx < drag_path.size() - 1:
		out_dir = grid_system.get_direction_between(current_coords, drag_path[idx + 1])
	else:
		# Se for a ponta final do arraste, olha se tem uma Estação ou Exit bem na frente para já conectar!
		var neighbor_dir := grid_system.find_incoming_neighbor_dir(current_coords)
		if neighbor_dir != -1 and neighbor_dir != in_dir:
			out_dir = neighbor_dir
			
	# Aplica no GridSystem
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
