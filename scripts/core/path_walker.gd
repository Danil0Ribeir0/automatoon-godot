class_name PathWalker
extends RefCounted

const AMBIGUOUS := -1

static func next_dir(model: GridModel, cell: Vector2i, entry: int) -> int:
	var others := model.connected_dirs(cell) & ~entry
	match GridModel.bit_count(others):
		1:
			return others # trilho, ou estação com 2 ligações
		2:
			return AMBIGUOUS if model.has_station(cell) else 0
		3:
			# Estação com 4 ligações = cruzamento: segue em linha reta.
			return GridModel.OPPOSITE[entry] if entry != 0 else 0
	return 0
