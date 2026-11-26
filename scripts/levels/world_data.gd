class_name WorldData
extends Resource

## Identificador usado no progresso salvo (não mude depois de lançar).
@export var id: StringName = &"world_1"
@export var title := ""
@export var levels: Array[LevelData] = []
## Desbloqueio: para cada fase, o índice da fase que precisa ser concluída antes.
## -1 (ou posição faltando) = liberada desde o início. Ex.: [-1, 0, -1, 2, -1].
@export var unlock_after: PackedInt32Array = []
## Visual do mundo (cenário, terminais, vagões, obstáculos). Vazio = Fazenda.
@export var theme: WorldTheme


## Índice da fase que libera `index`, ou -1 se ela já começa liberada.
func required_level(index: int) -> int:
	if index < 0 or index >= unlock_after.size():
		return -1
	var req := unlock_after[index]
	return req if req >= 0 and req < levels.size() and req != index else -1
