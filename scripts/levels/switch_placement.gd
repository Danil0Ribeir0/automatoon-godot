class_name SwitchPlacement
extends Resource

## Agulha pré-colocada pela fase.
@export var cell: Vector2i
@export var trunk: GridModel.Dir = GridModel.Dir.WEST
@export var diverge: GridModel.Dir = GridModel.Dir.NORTH
@export var straight_symbol: StringName = &"0"
## true = totalmente travada; false = fica no lugar, mas o jogador pode girar e trocar 0/1.
@export var locked := true
