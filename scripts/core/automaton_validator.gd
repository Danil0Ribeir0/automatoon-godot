class_name AutomatonValidator
extends RefCounted

## Valida UM trem. Não guarda estado: com vários trens, chame uma vez por trem.
static func validate(model: GridModel, word: Array[StringName]) -> ValidationResult:
	var result := ValidationResult.new()
	result.word_size = word.size()

	var cell := model.spawn_cell
	var entry := 0
	# Com as regras atuais o percurso nunca entra em laço. Isto é só um teto de segurança.
	var max_steps := model.size.x * model.size.y * 4 + 2

	for _i in max_steps:
		var step := PathStep.new(cell, entry)
		result.steps.append(step)

		# 1) Estação: consome o próximo vagão (cada passagem conta).
		if model.has_station(cell):
			var symbol := model.get_station(cell).symbol
			step.symbol = symbol
			if result.consumed >= word.size():
				return result.fail(ValidationResult.Failure.TOO_MANY_STATIONS, cell)
			if word[result.consumed] != symbol:
				result.expected_symbol = word[result.consumed]
				return result.fail(ValidationResult.Failure.WRONG_SYMBOL, cell)
			step.wagon_index = result.consumed
			result.consumed += 1

		# 2) Chegou ao destino.
		if cell == model.exit_cell:
			if result.consumed < word.size():
				return result.fail(ValidationResult.Failure.MISSING_SYMBOLS, cell)
			result.success = true
			return result

		# 3) Próxima célula.
		var out := PathWalker.next_dir(model, cell, entry)
		if out == PathWalker.AMBIGUOUS:
			return result.fail(ValidationResult.Failure.AMBIGUOUS_STATION, cell)
		if out == 0:
			return result.fail(ValidationResult.Failure.BROKEN_TRACK, cell)
		step.exit_dir = out
		var offset: Vector2i = GridModel.DIR_OFFSETS[out]
		cell += offset
		entry = GridModel.OPPOSITE[out]

	return result.fail(ValidationResult.Failure.LOOP, cell)
