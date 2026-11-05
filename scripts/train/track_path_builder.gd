class_name TrackPathBuilder
extends RefCounted

## Tamanho da alça de Bézier que aproxima um quarto de círculo de raio 0,5.
const _HANDLE := 0.5 * 0.5523


## `lead` = quanto a curva se estende antes do Spawn e depois do fim,
## para caber o trem inteiro escondido.
static func build(steps: Array[PathStep], board: GridBoard, lead: float, height: float) -> TrackPath:
	var path := TrackPath.new()
	if steps.is_empty():
		return path
	var size := board.cell_size
	var up := Vector3.UP * height
	var curve := path.curve
	curve.bake_interval = 0.05 # arcos suaves (o padrão 0.2 deixa as curvas "quebradas")

	var first_entry := _entry_of(steps[0])
	var start := board.cell_to_world(steps[0].cell) + _vec(first_entry) * 0.5 * size + up
	curve.add_point(start + _vec(first_entry) * lead) # onde fica a cauda do trem, escondida
	curve.add_point(start)

	for step in steps:
		var entry := _entry_of(step)
		var exit := _exit_of(step)
		var before := curve.get_baked_length()
		var out_point := board.cell_to_world(step.cell) + _vec(exit) * 0.5 * size + up
		if exit == GridModel.OPPOSITE[entry]:
			curve.add_point(out_point) # reta
		else:
			curve.set_point_out(curve.point_count - 1, -_vec(entry) * _HANDLE * size)
			curve.add_point(out_point, -_vec(exit) * _HANDLE * size) # curva
		path.step_distances.append((before + curve.get_baked_length()) * 0.5)

	var tail := curve.get_point_position(curve.point_count - 1)
	curve.add_point(tail + _vec(_exit_of(steps[-1])) * lead)

	path.appear_at = path.step_distances[0]
	path.vanish_at = path.step_distances[-1]
	return path


## Lado por onde o trem entra. No Spawn (entry = 0), o oposto da saída.
static func _entry_of(step: PathStep) -> int:
	return step.entry_dir if step.entry_dir != 0 else GridModel.OPPOSITE[step.exit_dir]


## Lado por onde sai. No Exit ou no ponto da falha (exit = 0), segue reto.
static func _exit_of(step: PathStep) -> int:
	return step.exit_dir if step.exit_dir != 0 else GridModel.OPPOSITE[_entry_of(step)]


static func _vec(dir: int) -> Vector3:
	var o: Vector2i = GridModel.DIR_OFFSETS[dir]
	return Vector3(o.x, 0.0, o.y)
