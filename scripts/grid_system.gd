extends Node3D
class_name GridSystem

@export var grid_size: Vector2i = Vector2i(5, 5)
@export var cell_size: float = 2.0
@export var train_wagons: Array[String] = ["1"]

var grid_data: Dictionary = {}
var tile_visuals: Dictionary = {}

var spawn_coords: Vector2i = Vector2i(-1, 2)
var exit_coords: Vector2i = Vector2i(5, 2)

# Carrega uma fase completa a partir de um LevelConfig
func load_from_config(config: LevelConfig) -> void:
	grid_size = config.grid_size
	spawn_coords = config.spawn_coords
	exit_coords = config.exit_coords
	train_wagons = config.train_wagons.duplicate()
	
	# 1. Remove todos os modelos 3D da fase anterior
	for node in tile_visuals.values():
		if is_instance_valid(node):
			node.queue_free()
	tile_visuals.clear()
	grid_data.clear()
	
	# 2. Cria as células vazias do tamanho exato da fase (5x5, 7x7, etc.)
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			grid_data[Vector2i(x, y)] = RailTileData.new(RailTileData.TileType.EMPTY)
			
	# 3. Posiciona as estações fixas obrigatórias (usado na Fase 1 do Tutorial)
	for coords in config.preplaced_stations.keys():
		var sym: String = config.preplaced_stations[coords]
		grid_data[coords] = RailTileData.new(RailTileData.TileType.STATION, 1, true, sym)
		
	# 4. Cria o SPAWN e o EXIT nas bordas configuradas
	var spawn_label := "Trem:\n[" + ",".join(train_wagons) + "]"
	grid_data[spawn_coords] = RailTileData.new(RailTileData.TileType.SPAWN, 3, true, spawn_label)
	grid_data[exit_coords] = RailTileData.new(RailTileData.TileType.EXIT, 1, true, "FIM")
	
	rebuild_all_visuals()

func grid_to_world(coords: Vector2i) -> Vector3:
	return Vector3((coords.x + 0.5) * cell_size, 0.0, (coords.y + 0.5) * cell_size)

func is_inside_playable_grid(coords: Vector2i) -> bool:
	return coords.x >= 0 and coords.x < grid_size.x and coords.y >= 0 and coords.y < grid_size.y

func rebuild_all_visuals() -> void:
	for coords in grid_data.keys():
		update_tile_visual(coords)

func update_tile_visual(coords: Vector2i) -> void:
	if tile_visuals.has(coords) and is_instance_valid(tile_visuals[coords]):
		tile_visuals[coords].queue_free()
	
	var tile: RailTileData = grid_data[coords]
	var visual_node: Node3D = TileMeshBuilder.build_tile_visual(tile, cell_size)
	
	add_child(visual_node)
	visual_node.position = grid_to_world(coords)
	tile_visuals[coords] = visual_node

func get_direction_between(from_coords: Vector2i, to_coords: Vector2i) -> int:
	return RailTileData.vector_to_dir(to_coords - from_coords)

func set_tile_single_dir(coords: Vector2i, dir: int) -> void:
	if not is_inside_playable_grid(coords) or dir == -1:
		return
	var tile: RailTileData = grid_data[coords]
	if tile.is_locked or tile.type == RailTileData.TileType.STATION:
		return
	tile.type = RailTileData.TileType.STRAIGHT
	tile.rotation_steps = dir % 2
	tile._setup_base_connections()
	update_tile_visual(coords)

func set_tile_two_dirs(coords: Vector2i, dir_a: int, dir_b: int) -> void:
	if not is_inside_playable_grid(coords) or dir_a == -1 or dir_b == -1 or dir_a == dir_b:
		return
	var tile: RailTileData = grid_data[coords]
	if tile.is_locked or tile.type == RailTileData.TileType.STATION:
		return
	if RailTileData.opposite_dir(dir_a) == dir_b:
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
	for dir in [RailTileData.Dir.NORTH, RailTileData.Dir.EAST, RailTileData.Dir.SOUTH, RailTileData.Dir.WEST]:
		var neighbor_coords: Vector2i = coords + RailTileData.dir_to_vector(dir)
		if grid_data.has(neighbor_coords):
			var neighbor: RailTileData = grid_data[neighbor_coords]
			if RailTileData.opposite_dir(dir) in neighbor.get_active_connections():
				return dir
	return -1

func place_or_rotate_station(coords: Vector2i, station_symbol: String = "1") -> void:
	if not is_inside_playable_grid(coords):
		return
	var tile: RailTileData = grid_data[coords]
	if tile.is_locked:
		return
	if tile.type == RailTileData.TileType.STATION:
		tile.rotation_steps = (tile.rotation_steps + 1) % 2
		tile.symbol = station_symbol
		update_tile_visual(coords)
		return
	var incoming_dir := find_incoming_neighbor_dir(coords)
	var start_rot := 1
	if incoming_dir != -1:
		start_rot = incoming_dir % 2
	tile.type = RailTileData.TileType.STATION
	tile.rotation_steps = start_rot
	tile.symbol = station_symbol
	tile._setup_base_connections()
	update_tile_visual(coords)

func clear_tile(coords: Vector2i) -> void:
	if not is_inside_playable_grid(coords):
		return
	var tile: RailTileData = grid_data[coords]
	if tile.is_locked:
		return
	tile.type = RailTileData.TileType.EMPTY
	tile.rotation_steps = 0
	tile.symbol = ""
	tile._setup_base_connections()
	update_tile_visual(coords)
