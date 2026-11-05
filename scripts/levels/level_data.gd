class_name LevelData
extends Resource

## Trilhos a mais que o par ainda valendo 2 estrelas.
const TWO_STAR_MARGIN := 2

@export var title := ""
@export var grid_size: Vector2i = Vector2i(5, 5)
## Células com obstáculo: nada pode ser construído nelas.
@export var blocked_cells: Array[Vector2i] = []

@export_group("Estações")
@export var station_tool_enabled: bool = true
@export var available_symbols: Array[SymbolDefinition] = []
@export var fixed_stations: Array[StationPlacement] = []

@export_group("Trem")
@export var train: TrainDefinition

@export_group("Estrelas")
## Menor número de trilhos possível (★★★ até aqui). 0 = sempre 3 estrelas.
@export var par_rails := 0


func get_spawn_cell() -> Vector2i:
	return Vector2i(-1, floori(grid_size.y / 2.0))


func get_exit_cell() -> Vector2i:
	return Vector2i(grid_size.x, floori(grid_size.y / 2.0))


func get_symbol_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for def in available_symbols:
		ids.append(def.id)
	return ids


func stars_for(rails: int) -> int:
	if par_rails <= 0 or rails <= par_rails:
		return 3
	if rails <= par_rails + TWO_STAR_MARGIN:
		return 2
	return 1
