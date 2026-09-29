extends Node3D
class_name GridSystem

@export var grid_size: Vector2i = Vector2i(5, 5)
@export var cell_size: float = 1.5

@export var train_wagons: Array[String] = ["1"]

var grid_data: Dictionary = {}
var tile_visuals: Dictionary = {}

var spawn_coords: Vector2i = Vector2i(-1, 2)
var exit_coords: Vector2i = Vector2i(5, 2)

func _ready() -> void:
	init_level()
	rebuild_all_visuals()

func init_level() -> void:
	grid_data.clear()
	
	# 1. Preenche a grid 5x5 com tiles vazios
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			grid_data[Vector2i(x, y)] = RailTileData.new(RailTileData.TileType.EMPTY)
	
	# 2. Cria o SPAWN fora da grid (-1, 2) mostrando os vagões do trem
	var spawn_label := "Trem:\n[" + ",".join(train_wagons) + "]"
	grid_data[spawn_coords] = RailTileData.new(RailTileData.TileType.SPAWN, 3, true, spawn_label)
	
	# 3. Cria o EXIT fora da grid (5, 2) como estado final (qf)
	grid_data[exit_coords] = RailTileData.new(RailTileData.TileType.EXIT, 1, true, "FIM")
	
	# 4. Cria a ESTAÇÃO "1" fixa em (2, 1) na horizontal (rotação 1)
	grid_data[Vector2i(2, 1)] = RailTileData.new(RailTileData.TileType.STATION, 1, true, "1")

func grid_to_world(coords: Vector2i) -> Vector3:
	return Vector3(
		(coords.x + 0.5) * cell_size,
		0.0,
		(coords.y + 0.5) * cell_size
	)

func rebuild_all_visuals() -> void:
	for coords in grid_data.keys():
		update_tile_visual(coords)

func update_tile_visual(coords: Vector2i) -> void:
	if tile_visuals.has(coords) and is_instance_valid(tile_visuals[coords]):
		tile_visuals[coords].queue_free()
	
	var tile: RailTileData = grid_data[coords]
	var visual_node: Node3D = _create_placeholder_mesh(tile)
	
	add_child(visual_node)
	visual_node.position = grid_to_world(coords)
	tile_visuals[coords] = visual_node

func _create_placeholder_mesh(tile: RailTileData) -> Node3D:
	var root := Node3D.new()
	var s := cell_size # Atalho de escala para manter tudo proporcional
	
	var base_color := Color(0.22, 0.24, 0.28)
	if tile.type == RailTileData.TileType.SPAWN:
		base_color = Color(0.15, 0.55, 0.25)
	elif tile.type == RailTileData.TileType.EXIT:
		base_color = Color(0.7, 0.2, 0.2)
	elif tile.type == RailTileData.TileType.STATION:
		base_color = Color(0.75, 0.55, 0.15)
		
	var floor_box := _make_box(Vector3(s * 0.92, 0.1 * s, s * 0.92), base_color)
	floor_box.position.y = -0.05 * s
	root.add_child(floor_box)
	
	var active_dirs := tile.get_active_connections()
	if not active_dirs.is_empty():
		var rail_color := Color(0.75, 0.75, 0.8)
		var center_hub := _make_box(Vector3(s * 0.24, 0.08 * s, s * 0.24), rail_color)
		center_hub.position.y = 0.04 * s
		root.add_child(center_hub)
		
		for dir in active_dirs:
			var arm_size := Vector3(s * 0.2, 0.08 * s, s * 0.5)
			var arm_offset := Vector3.ZERO
			match dir:
				RailTileData.Dir.NORTH:
					arm_offset = Vector3(0, 0.04 * s, -s * 0.25)
				RailTileData.Dir.SOUTH:
					arm_offset = Vector3(0, 0.04 * s, s * 0.25)
				RailTileData.Dir.EAST:
					arm_size = Vector3(s * 0.5, 0.08 * s, s * 0.2)
					arm_offset = Vector3(s * 0.25, 0.04 * s, 0)
				RailTileData.Dir.WEST:
					arm_size = Vector3(s * 0.5, 0.08 * s, s * 0.2)
					arm_offset = Vector3(-s * 0.25, 0.04 * s, 0)
					
			var arm := _make_box(arm_size, rail_color)
			arm.position = arm_offset
			root.add_child(arm)
			
	if tile.type == RailTileData.TileType.STATION:
		var station_roof := _make_box(Vector3(s * 0.35, 0.3 * s, s * 0.25), Color(0.95, 0.8, 0.2))
		station_roof.position = Vector3(0.0, 0.15 * s, -0.3 * s)
		root.add_child(station_roof)
		
	if tile.symbol != "":
		var lbl := Label3D.new()
		lbl.text = tile.symbol
		lbl.pixel_size = 0.005 * s
		lbl.font_size = 48
		lbl.outline_size = 12
		lbl.position = Vector3(0, 0.45 * s, 0)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		root.add_child(lbl)
		
	return root

func _make_box(box_size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	box.material = mat
	mesh_inst.mesh = box
	return mesh_inst

func is_inside_playable_grid(coords: Vector2i) -> bool:
	return coords.x >= 0 and coords.x < grid_size.x and coords.y >= 0 and coords.y < grid_size.y

# === SISTEMA DE AUTO-TILING (ARRASTAR TRILHOS) ===

func get_direction_between(from_coords: Vector2i, to_coords: Vector2i) -> int:
	var diff := to_coords - from_coords
	if diff == Vector2i(0, -1): return RailTileData.Dir.NORTH
	if diff == Vector2i(1, 0):  return RailTileData.Dir.EAST
	if diff == Vector2i(0, 1):  return RailTileData.Dir.SOUTH
	if diff == Vector2i(-1, 0): return RailTileData.Dir.WEST
	return -1

func set_tile_single_dir(coords: Vector2i, dir: int) -> void:
	if not is_inside_playable_grid(coords) or dir == -1:
		return
	var tile: RailTileData = grid_data[coords]
	if tile.is_locked:
		return
	tile.type = RailTileData.TileType.STRAIGHT
	tile.rotation_steps = dir % 2
	tile._setup_base_connections()
	update_tile_visual(coords)

func set_tile_two_dirs(coords: Vector2i, dir_a: int, dir_b: int) -> void:
	if not is_inside_playable_grid(coords) or dir_a == -1 or dir_b == -1 or dir_a == dir_b:
		return
	var tile: RailTileData = grid_data[coords]
	if tile.is_locked:
		return
	if (dir_a + 2) % 4 == dir_b:
		tile.type = RailTileData.TileType.STRAIGHT
		tile.rotation_steps = dir_a % 2
	else:
		tile.type = RailTileData.TileType.CURVE
		if (dir_a + 1) % 4 == dir_b:
			tile.rotation_steps = dir_a
		else:
			tile.rotation_steps = dir_b
	tile._setup_base_connections()
	update_tile_visual(coords)

func find_incoming_neighbor_dir(coords: Vector2i) -> int:
	var offsets := {
		RailTileData.Dir.NORTH: Vector2i(0, -1),
		RailTileData.Dir.EAST:  Vector2i(1, 0),
		RailTileData.Dir.SOUTH: Vector2i(0, 1),
		RailTileData.Dir.WEST:  Vector2i(-1, 0)
	}
	for dir in offsets.keys():
		var neighbor_coords: Vector2i = coords + offsets[dir]
		if grid_data.has(neighbor_coords):
			var neighbor: RailTileData = grid_data[neighbor_coords]
			var opposite_dir: int = (dir + 2) % 4
			if opposite_dir in neighbor.get_active_connections():
				return dir
	return -1

func clear_tile(coords: Vector2i) -> void:
	if not is_inside_playable_grid(coords):
		return
	var tile: RailTileData = grid_data[coords]
	if tile.is_locked:
		return
	tile.type = RailTileData.TileType.EMPTY
	tile.rotation_steps = 0
	tile._setup_base_connections()
	update_tile_visual(coords)

# === PASSO 4: VALIDADOR DO AUTÔMATO E ROTA ===

func dir_to_vector(dir: int) -> Vector2i:
	match dir:
		RailTileData.Dir.NORTH: return Vector2i(0, -1)
		RailTileData.Dir.EAST:  return Vector2i(1, 0)
		RailTileData.Dir.SOUTH: return Vector2i(0, 1)
		RailTileData.Dir.WEST:  return Vector2i(-1, 0)
	return Vector2i.ZERO

func validate_automaton_path() -> Dictionary:
	print("\n--- INICIANDO VALIDAÇÃO DO AUTÔMATO ---")
	print("Palavra esperada (Vagões): ", train_wagons)
	
	var current_coords: Vector2i = spawn_coords
	var spawn_tile: RailTileData = grid_data[spawn_coords]
	var exit_dir: int = spawn_tile.get_active_connections()[0]
	
	var path_coords: Array[Vector2i] = [current_coords]
	var read_symbols: Array[String] = [] # Símbolos lidos nas estações pelo caminho
	var max_steps: int = 100
	var steps: int = 0
	
	while steps < max_steps:
		steps += 1
		var next_coords: Vector2i = current_coords + dir_to_vector(exit_dir)
		
		# 1. Verifica se o próximo tile existe no mapa
		if not grid_data.has(next_coords):
			print("❌ FALHA: Trilho saiu para fora do mapa em ", next_coords)
			return {"accepted": false, "path": path_coords, "reason": "Saiu do mapa"}
			
		var next_tile: RailTileData = grid_data[next_coords]
		var required_entry_dir: int = (exit_dir + 2) % 4 # Direção oposta
		var next_connections: Array = next_tile.get_active_connections()
		
		# 2. Verifica se o próximo tile conecta com a saída do tile atual
		if not (required_entry_dir in next_connections):
			print("❌ FALHA: Trilho desconectado ou interrompido em ", next_coords)
			return {"accepted": false, "path": path_coords, "reason": "Trilho desconectado"}
			
		# O trem conseguiu entrar no next_coords!
		path_coords.append(next_coords)
		current_coords = next_coords
		
		# 3. Se for uma ESTAÇÃO, o autômato lê/consome o símbolo dela!
		if next_tile.type == RailTileData.TileType.STATION:
			var wagon_idx := read_symbols.size()
			read_symbols.append(next_tile.symbol)
			print(" -> Passou pela Estação '", next_tile.symbol, "' em ", current_coords)
			
			# Já valida na hora se o vagão atual bate com a estação!
			if wagon_idx >= train_wagons.size():
				print("❌ REJEITADO: O trem passou por mais estações do que o número de vagões!")
				return {"accepted": false, "path": path_coords, "reason": "Estações excedentes"}
			elif train_wagons[wagon_idx] != next_tile.symbol:
				print("❌ REJEITADO: Vagão esperava estação '", train_wagons[wagon_idx], "', mas passou pela '", next_tile.symbol, "'!")
				return {"accepted": false, "path": path_coords, "reason": "Símbolo incorreto"}
				
		# 4. Verifica se chegou no tile final (EXIT / Estado de Aceitação)
		if next_tile.type == RailTileData.TileType.EXIT:
			if read_symbols == train_wagons:
				print("✅ PALAVRA ACEITA! O trem validou todos os vagões ", read_symbols, " e chegou ao destino!")
				return {"accepted": true, "path": path_coords, "reason": "Palavra Aceita"}
			else:
				print("❌ REJEITADO: O trem chegou ao fim, mas leu apenas ", read_symbols, " de ", train_wagons)
				return {"accepted": false, "path": path_coords, "reason": "Faltaram vagões/estações"}
				
		# 5. Descobre qual é a ponta de saída do tile atual para continuar andando
		for conn_dir in next_connections:
			if conn_dir != required_entry_dir:
				exit_dir = conn_dir
				break
				
	return {"accepted": false, "path": path_coords, "reason": "Loop infinito"}

# Gera uma curva 3D suave com arcos arredondados nas curvas de 90 graus
# Gera uma curva 3D suave com arcos arredondados nas curvas de 90 graus
func generate_smooth_curve(path_coords: Array[Vector2i]) -> Curve3D:
	var curve := Curve3D.new()
	if path_coords.size() < 2:
		return curve
		
	var half_cell := cell_size * 0.5
	var bezier_handle := half_cell * 0.55228 # Constante cúbica para aproximação circular
	
	# Ponto inicial (centro do Spawn)
	var start_world := grid_to_world(path_coords[0])
	curve.add_point(start_world)
	
	for i in range(1, path_coords.size() - 1):
		var prev := path_coords[i - 1]
		var curr := path_coords[i]
		var next := path_coords[i + 1]
		
		var in_dir := curr - prev   # Vetor de entrada
		var out_dir := next - curr  # Vetor de saída
		var curr_world := grid_to_world(curr)
		
		# CASO 1: Trecho Reto (entrada e saída na mesma direção)
		if in_dir == out_dir:
			curve.add_point(curr_world)
			
		# CASO 2: Curva de 90 graus -> Constrói arco suave
		else:
			# Ponto onde o trem toca a borda de entrada da célula
			var entry_world := curr_world - Vector3(in_dir.x, 0, in_dir.y) * half_cell
			var entry_out := Vector3(in_dir.x, 0, in_dir.y) * bezier_handle
			curve.add_point(entry_world, Vector3.ZERO, entry_out)
			
			# Ponto onde o trem sai pela borda da célula
			var exit_world := curr_world + Vector3(out_dir.x, 0, out_dir.y) * half_cell
			var exit_in := -Vector3(out_dir.x, 0, out_dir.y) * bezier_handle
			curve.add_point(exit_world, exit_in, Vector3.ZERO)
			
	# Ponto final (centro do Exit)
	var end_world := grid_to_world(path_coords.back())
	curve.add_point(end_world)
	
	return curve
