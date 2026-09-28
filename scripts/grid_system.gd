extends Node3D
class_name GridSystem

@export var grid_size: Vector2i = Vector2i(5, 5)
@export var cell_size: float = 1.0

var grid_data: Dictionary = {}
var tile_visuals: Dictionary = {}

var spawn_coords: Vector2i = Vector2i(-1, 2)
var exit_coords: Vector2i = Vector2i(5, 2)

func _ready() -> void:
	init_level()
	rebuild_all_visuals()
	_debug_print_grid()

func init_level() -> void:
	grid_data.clear()
	
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			grid_data[Vector2i(x, y)] = RailTileData.new(RailTileData.TileType.EMPTY)
	
	grid_data[spawn_coords] = RailTileData.new(RailTileData.TileType.SPAWN, 3, true)
	
	grid_data[exit_coords] = RailTileData.new(RailTileData.TileType.EXIT, 1, true)
	
	grid_data[Vector2i(2, 1)] = RailTileData.new(RailTileData.TileType.STATION, 1, true)

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
		
		var center_hub := _make_box(Vector3(0.24, 0.08, 0.24), rail_color)
		center_hub.position.y = 0.04
		root.add_child(center_hub)
		
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
			
	if tile.type == RailTileData.TileType.STATION:
		var station_roof := _make_box(Vector3(0.35, 0.3, 0.25), Color(0.95, 0.8, 0.2))
		station_roof.position = Vector3(0.0, 0.15, -0.3)
		root.add_child(station_roof)
		
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

func _debug_print_grid() -> void:
	print("=== MAPA LÓGICO E VISUAL INICIALIZADO ===")
	print("Total de células renderizadas: ", tile_visuals.size())

# === SISTEMA DE AUTO-TILING (ARRASTAR TRILHOS) ===

# Descobre qual é a direção cardeal para ir de 'from_coords' até 'to_coords'
func get_direction_between(from_coords: Vector2i, to_coords: Vector2i) -> int:
	var diff := to_coords - from_coords
	if diff == Vector2i(0, -1): return RailTileData.Dir.NORTH # 0
	if diff == Vector2i(1, 0):  return RailTileData.Dir.EAST  # 1
	if diff == Vector2i(0, 1):  return RailTileData.Dir.SOUTH # 2
	if diff == Vector2i(-1, 0): return RailTileData.Dir.WEST  # 3
	return -1

# Configura um tile como RETO apenas com base em uma direção de movimento
func set_tile_single_dir(coords: Vector2i, dir: int) -> void:
	if not is_inside_playable_grid(coords) or dir == -1:
		return
	var tile: RailTileData = grid_data[coords]
	if tile.is_locked:
		return
		
	tile.type = RailTileData.TileType.STRAIGHT
	# Se dir for Norte(0) ou Sul(2), rot = 0. Se for Leste(1) ou Oeste(3), rot = 1.
	tile.rotation_steps = dir % 2
	tile._setup_base_connections()
	update_tile_visual(coords)

# Configura um tile conectando DUAS direções (decide sozinho se é Reta ou Curva e a rotação)
func set_tile_two_dirs(coords: Vector2i, dir_a: int, dir_b: int) -> void:
	if not is_inside_playable_grid(coords) or dir_a == -1 or dir_b == -1 or dir_a == dir_b:
		return
	var tile: RailTileData = grid_data[coords]
	if tile.is_locked:
		return
		
	# Caso 1: Direções opostas (ex: Norte e Sul, ou Leste e Oeste) -> TRILHO RETO
	if (dir_a + 2) % 4 == dir_b:
		tile.type = RailTileData.TileType.STRAIGHT
		tile.rotation_steps = dir_a % 2
	# Caso 2: Direções perpendiculares (90 graus) -> TRILHO CURVO
	else:
		tile.type = RailTileData.TileType.CURVE
		# Na nossa classe RailTileData, a CURVE base conecta NORTH(0) e EAST(1).
		# Logo, na rotação 'r', ela conecta 'r' e '(r + 1) % 4'.
		if (dir_a + 1) % 4 == dir_b:
			tile.rotation_steps = dir_a
		else:
			tile.rotation_steps = dir_b
			
	tile._setup_base_connections()
	update_tile_visual(coords)

# Procura se algum vizinho (como Spawn, Estação, Exit ou trilho já existente) aponta para esta célula
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
			# Se o vizinho tem uma ponta virada para nós, retornamos essa direção!
			if opposite_dir in neighbor.get_active_connections():
				return dir
	return -1

# Apaga o trilho da célula (usado no botão direito ou ao voltar o arraste)
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
