class_name RouteOrientation
extends RefCounted

## Desempate geométrico quando os dois vizinhos estão à mesma distância do Exit.
const TIE_ORDER := [
	GridModel.Dir.EAST,
	GridModel.Dir.SOUTH,
	GridModel.Dir.NORTH,
	GridModel.Dir.WEST,
]


## Lado "depois" de um trilho com 2 ligações (o que segue rumo ao Exit).
## 1) rota a partir do Spawn; 2) trecho ligado ao Exit; 3) vizinho mais perto do Exit.
static func after_dir(model: GridModel, cell: Vector2i) -> int:
	var links := model.connected_dirs(cell)
	if GridModel.bit_count(links) != 2:
		return 0

	var entry := _entry_side(model, model.spawn_cell, cell)
	if entry != 0:
		return links & ~entry

	entry = _entry_side(model, model.exit_cell, cell)
	if entry != 0:
		return entry

	return _closest_to_exit(model, cell, links)


## Caminha pelas ligações a partir de `from` e devolve o lado por onde
## entrou em `target` (0 se não chegou).
static func _entry_side(model: GridModel, from: Vector2i, target: Vector2i) -> int:
	var visited := {}
	var cell := from
	var entry := 0
	while not visited.has(Vector3i(cell.x, cell.y, entry)):
		visited[Vector3i(cell.x, cell.y, entry)] = true
		var out := _next_dir(model, cell, entry)
		if out == 0:
			return 0
		var offset: Vector2i = GridModel.DIR_OFFSETS[out]
		cell += offset
		entry = GridModel.OPPOSITE[out]
		if cell == target:
			return entry
	return 0


## Saída de uma célula dado o lado de entrada. Estação com 4 ligações cruza
static func _next_dir(model: GridModel, cell: Vector2i, entry: int) -> int:
	return maxi(PathWalker.next_dir(model, cell, entry), 0)


static func _closest_to_exit(model: GridModel, cell: Vector2i, links: int) -> int:
	var best := 0
	var best_dist := 0
	for dir in TIE_ORDER:
		if (links & dir) == 0:
			continue
		var offset: Vector2i = GridModel.DIR_OFFSETS[dir]
		var d := (cell + offset - model.exit_cell).abs()
		var dist := d.x + d.y
		if best == 0 or dist < best_dist:
			best = dir
			best_dist = dist
	return best
