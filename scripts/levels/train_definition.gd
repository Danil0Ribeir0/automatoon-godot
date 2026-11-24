class_name TrainDefinition
extends Resource

## Vagões em ordem: o primeiro é o primeiro símbolo lido.
@export var wagons: Array[SymbolDefinition] = []
## true = o trem precisa chegar à Chegada; false = precisa ser barrado no caminho.
@export var expect_accept := true


func get_word() -> Array[StringName]:
	var word: Array[StringName] = []
	for wagon in wagons:
		if wagon != null:
			word.append(wagon.id)
	return word
