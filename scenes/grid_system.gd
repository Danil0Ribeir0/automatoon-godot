extends Node3D
class_name GridSystem

@export var grid_size: Vector2i = Vector2i(5, 5)
@export var cell_size: float = 1.0

# Chave: Vector2i -> Valor: RailTileData
var grid_data: Dictionary = {}
# Chave: Vector2i -> Valor: Node3D (referência visual na cena)
var tile_visuals: Dictionary = {}

var spawn_coords: Vector2i = Vector2i(-1, 2)
var exit_coords: Vector2i = Vector2i(5, 2)

func _ready() -> void:
	init_level()
	rebuild_all_visuals()
	_debug_print_grid()

func init_level() -> void:
	grid_data.clear()
	
	# 1. Preenche a grid 5x5 com tiles vazios
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			grid_data[Vector2i(x, y)] = RailTileData.new(RailTileData.TileType.EMPTY)
	
	# 2. Cria o SPAWN fora da grid (-1, 2) apontando para LESTE (1)
	grid_data[spawn_coords] = RailTileData.new(RailTileData.TileType.SPAWN, 3, true)
	
	# 3. Cria o EXIT fora da grid (5, 2) recebendo por OESTE (3)
	grid_data[exit_coords] = RailTileData.new(RailTileData.TileType.EXIT, 1, true)
	
	# 4. Cria a ESTAÇÃO fixa em (2, 1) na horizontal
	grid_data[Vector2i(2, 1)] = RailTileData.new(RailTileData.TileType.STATION, 1, true)

# Converte coordenada da Grid (Vector2i) para posição 3D centralizada na célula
func grid_to_world(coords: Vector2i) -> Vector3:
	return Vector3(
		(coords.x + 0.5) * cell_size,
		0.0,
		(coords.y + 0.5) * cell_size
	)

# Reconstrói todos os blocos 3D do tabuleiro
func rebuild_all_visuals() -> void:
	for coords in grid_data.keys():
		update_tile_visual(coords)

# Atualiza (ou cria) o visual 3D de uma única coordenada
func update_tile_visual(coords: Vector2i) -> void:
	# Se já existir um bloco 3D nessa coordenada, remove o antigo
	if tile_visuals.has(coords) and is_instance_valid(tile_visuals[coords]):
		tile_visuals[coords].queue_free()
	
	var tile: RailTileData = grid_data[coords]
	var visual_node: Node3D = _create_placeholder_mesh(tile)
	
	add_child(visual_node)
	visual_node.position = grid_to_world(coords)
	tile_visuals[coords] = visual_node

# Gera blocos 3D provisórios ("Greybox") para enxergarmos o jogo
func _create_placeholder_mesh(tile: RailTileData) -> Node3D:
	var root := Node3D.new()
	
	# 1. Placa de chão da célula (0.92 para deixar uma fresta visível entre os pisos)
	var base_color := Color(0.22, 0.24, 0.28)
	if tile.type == RailTileData.TileType.SPAWN:
		base_color = Color(0.15, 0.55, 0.25) # Verde
	elif tile.type == RailTileData.TileType.EXIT:
		base_color = Color(0.7, 0.2, 0.2)    # Vermelho
	elif tile.type == RailTileData.TileType.STATION:
		base_color = Color(0.75, 0.55, 0.15) # Amarelo/Dourado
		
	var floor_box := _make_box(Vector3(cell_size * 0.92, 0.1, cell_size * 0.92), base_color)
	floor_box.position.y = -0.05
	root.add_child(floor_box)
	
	# 2. Desenha os "braços" dos trilhos nas direções ativas da peça
	var active_dirs := tile.get_active_connections()
	if not active_dirs.is_empty():
		var rail_color := Color(0.75, 0.75, 0.8)
		
		# Pequeno bloco central unindo as conexões
		var center_hub := _make_box(Vector3(0.24, 0.08, 0.24), rail_color)
		center_hub.position.y = 0.04
		root.add_child(center_hub)
		
		# Cria um braço para cada direção que essa peça conecta
		for dir in active_dirs:
			var arm_size := Vector3(0.2, 0.08, cell_size * 0.5)
			var arm_offset := Vector3.ZERO
			
			match dir:
				RailTileData.Dir.NORTH:
					arm_offset = Vector3(0, 0.04, -cell_size * 0.25)
				RailTileData.Dir.SOUTH:
					arm_offset = Vector3(0, 0.04, cell_size * 0.25)
				RailTileData.Dir.EAST:
					arm_size = Vector3(cell_size * 0.5, 0.08, 0.2)
					arm_offset = Vector3(cell_size * 0.25, 0.04, 0)
				RailTileData.Dir.WEST:
					arm_size = Vector3(cell_size * 0.5, 0.08, 0.2)
					arm_offset = Vector3(-cell_size * 0.25, 0.04, 0)
					
			var arm := _make_box(arm_size, rail_color)
			arm.position = arm_offset
			root.add_child(arm)
			
	# 3. Detalhe extra: um mini "prédio" ao lado se for Estação
	if tile.type == RailTileData.TileType.STATION:
		var station_roof := _make_box(Vector3(0.35, 0.3, 0.25), Color(0.95, 0.8, 0.2))
		station_roof.position = Vector3(0.0, 0.15, -0.3)
		root.add_child(station_roof)
		
	return root

# Função auxiliar para criar caixas coloridas rapidamente
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

func _debug_print_grid() -> void:
	print("=== MAPA LÓGICO E VISUAL INICIALIZADO ===")
	print("Total de células renderizadas: ", tile_visuals.size())

# Alterna o tipo de peça na coordenada (Vazio -> Reta -> Curva -> Vazio)
func cycle_tile_type(coords: Vector2i) -> void:
	if not is_inside_playable_grid(coords):
		return
		
	var tile: RailTileData = grid_data[coords]
	if tile.is_locked:
		print("Este bloco é fixo do nível (Estação)!")
		return
		
	match tile.type:
		RailTileData.TileType.EMPTY:
			tile.type = RailTileData.TileType.STRAIGHT
			tile.rotation_steps = 0
		RailTileData.TileType.STRAIGHT:
			tile.type = RailTileData.TileType.CURVE
			tile.rotation_steps = 0
		RailTileData.TileType.CURVE:
			tile.type = RailTileData.TileType.EMPTY
			tile.rotation_steps = 0
			
	tile._setup_base_connections()
	update_tile_visual(coords)

# Gira a peça em 90 graus (sentido horário)
func rotate_tile(coords: Vector2i) -> void:
	if not is_inside_playable_grid(coords):
		return
		
	var tile: RailTileData = grid_data[coords]
	# Não gira se for fixo ou se estiver vazio
	if tile.is_locked or tile.type == RailTileData.TileType.EMPTY:
		return
		
	tile.rotation_steps = (tile.rotation_steps + 1) % 4
	update_tile_visual(coords)
