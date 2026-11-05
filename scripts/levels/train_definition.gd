class_name TrainDefinition
extends Resource

## Vagões em ordem: o primeiro é o primeiro símbolo lido.
@export var wagons: Array[SymbolDefinition] = []


func get_word() -> Array[StringName]:
	var word: Array[StringName] = []
	for wagon in wagons:
		if wagon != null:
			word.append(wagon.id)
	return word
