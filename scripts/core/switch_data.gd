class_name SwitchData
extends RefCounted

## Agulha: tronco + ramo reto (oposto ao tronco) + ramo de desvio (a 90°).
## Entrando pelo tronco, o trem ESPIA o próximo vagão e segue o ramo desse
## símbolo (sem consumir). Entrando por um ramo, sai pelo tronco (junção).

var trunk: int
var diverge: int
## Símbolo do ramo reto; o desvio leva o outro.
var straight_symbol: StringName


func _init(p_trunk: int, p_diverge: int, p_straight_symbol: StringName) -> void:
	trunk = p_trunk
	diverge = p_diverge
	straight_symbol = p_straight_symbol


func straight() -> int:
	return GridModel.OPPOSITE[trunk]


func openings() -> int:
	return trunk | straight() | diverge


func diverge_symbol() -> StringName:
	return &"1" if straight_symbol == &"0" else &"0"


## Ramo escolhido pelo símbolo espiado. Palavra acabou (vazio) = ramo reto.
func branch_for(symbol: StringName) -> int:
	if symbol.is_empty() or symbol == straight_symbol:
		return straight()
	return diverge
