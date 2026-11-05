class_name PathWalker
extends RefCounted

const AMBIGUOUS := -1


## Lado por onde o trem sai de `cell`, tendo entrado por `entry`.
## `next_symbol` = próximo vagão (vazio se a palavra acabou); só a agulha o usa.
## Retorna 0 se o caminho termina ali (ponta solta) ou AMBIGUOUS.
static func next_dir(model: GridModel, cell: Vector2i, entry: int, next_symbol: StringName = &"") -> int:
	var sw := model.get_switch(cell)
	if sw:
		# Pelo tronco: decide pelo símbolo espiado. Por um ramo: junção, sai pelo tronco.
		var out := sw.branch_for(next_symbol) if entry == sw.trunk else sw.trunk
		return out if (model.connected_dirs(cell) & out) != 0 else 0

	var shape := model.get_shape(cell)
	if GridModel.is_junction(shape):
		# T: pela perna, vira para o braço da curva; por um braço, segue reto.
		var t_out: int = GridModel.junction_arm(shape) if entry == GridModel.junction_stem(shape) \
				else GridModel.OPPOSITE[entry]
		return t_out if (model.connected_dirs(cell) & t_out) != 0 else 0

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
