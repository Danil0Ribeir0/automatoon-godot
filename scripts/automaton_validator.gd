class_name AutomatonValidator
extends RefCounted

static func validate_path(grid_data: Dictionary, spawn_coords: Vector2i, expected_wagons: Array[String]) -> Dictionary:
	print("\n--- INICIANDO VALIDAÇÃO DO AUTÔMATO ---")
	print("Palavra esperada (Vagões): ", expected_wagons)
	
	var current_coords: Vector2i = spawn_coords
	var spawn_tile: RailTileData = grid_data[spawn_coords]
	var exit_dir: int = spawn_tile.get_active_connections()[0]
	
	var path_coords: Array[Vector2i] = [current_coords]
	var read_symbols: Array[String] = []
	var max_steps: int = 100
	var steps: int = 0
	
	while steps < max_steps:
		steps += 1
		var next_coords: Vector2i = current_coords + RailTileData.dir_to_vector(exit_dir)
		
		if not grid_data.has(next_coords):
			print("FALHA: Trilho saiu para fora do mapa em ", next_coords)
			return {"accepted": false, "path": path_coords, "reason": "Saiu do mapa"}
			
		var next_tile: RailTileData = grid_data[next_coords]
		var required_entry_dir: int = RailTileData.opposite_dir(exit_dir)
		var next_connections: Array = next_tile.get_active_connections()
		
		if not (required_entry_dir in next_connections):
			print("FALHA: Trilho desconectado ou interrompido em ", next_coords)
			return {"accepted": false, "path": path_coords, "reason": "Trilho desconectado"}
			
		path_coords.append(next_coords)
		current_coords = next_coords
		
		if next_tile.type == RailTileData.TileType.STATION:
			var wagon_idx := read_symbols.size()
			read_symbols.append(next_tile.symbol)
			print(" -> Passou pela Estação '", next_tile.symbol, "' em ", current_coords)
			
			if wagon_idx >= expected_wagons.size():
				print("REJEITADO: O trem passou por mais estações do que o número de vagões!")
				return {"accepted": false, "path": path_coords, "reason": "Estações excedentes"}
			elif expected_wagons[wagon_idx] != next_tile.symbol:
				print("REJEITADO: Vagão esperava estação '", expected_wagons[wagon_idx], "', mas passou pela '", next_tile.symbol, "'!")
				return {"accepted": false, "path": path_coords, "reason": "Símbolo incorreto"}
				
		if next_tile.type == RailTileData.TileType.EXIT:
			if read_symbols == expected_wagons:
				print("PALAVRA ACEITA! O trem validou todos os vagões ", read_symbols, " e chegou ao destino!")
				return {"accepted": true, "path": path_coords, "reason": "Palavra Aceita"}
			else:
				print("REJEITADO: O trem chegou ao fim, mas leu apenas ", read_symbols, " de ", expected_wagons)
				return {"accepted": false, "path": path_coords, "reason": "Faltaram vagões/estações"}
				
		for conn_dir in next_connections:
			if conn_dir != required_entry_dir:
				exit_dir = conn_dir
				break
				
	return {"accepted": false, "path": path_coords, "reason": "Loop infinito"}

static func build_smooth_curve(path_coords: Array[Vector2i], cell_size: float) -> Curve3D:
	var curve := Curve3D.new()
	if path_coords.size() < 2:
		return curve
		
	var half_cell := cell_size * 0.5
	var bezier_handle := half_cell * 0.55228
	
	curve.add_point(_coords_to_world(path_coords[0], cell_size))
	
	for i in range(1, path_coords.size() - 1):
		var prev := path_coords[i - 1]
		var curr := path_coords[i]
		var next := path_coords[i + 1]
		
		var in_dir := curr - prev
		var out_dir := next - curr
		var curr_world := _coords_to_world(curr, cell_size)
		
		if in_dir == out_dir:
			curve.add_point(curr_world)
		else:
			var entry_world := curr_world - Vector3(in_dir.x, 0, in_dir.y) * half_cell
			var entry_out := Vector3(in_dir.x, 0, in_dir.y) * bezier_handle
			curve.add_point(entry_world, Vector3.ZERO, entry_out)
			
			var exit_world := curr_world + Vector3(out_dir.x, 0, out_dir.y) * half_cell
			var exit_in := -Vector3(out_dir.x, 0, out_dir.y) * bezier_handle
			curve.add_point(exit_world, exit_in, Vector3.ZERO)
			
	curve.add_point(_coords_to_world(path_coords.back(), cell_size))
	return curve

static func _coords_to_world(coords: Vector2i, cell_size: float) -> Vector3:
	return Vector3((coords.x + 0.5) * cell_size, 0.0, (coords.y + 0.5) * cell_size)
