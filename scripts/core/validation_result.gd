class_name ValidationResult
extends RefCounted

enum Failure {
	NONE,
	BROKEN_TRACK,
	AMBIGUOUS_STATION,
	WRONG_SYMBOL,
	TOO_MANY_STATIONS,
	MISSING_SYMBOLS,
	LOOP,
}

var success := false
var failure: Failure = Failure.NONE
var error_cell := Vector2i.ZERO
## Símbolo que o trem esperava (só em WRONG_SYMBOL).
var expected_symbol: StringName = &""
var consumed := 0
var word_size := 0
## Percurso feito, do Spawn até o Exit ou até o ponto da falha.
var steps: Array[PathStep] = []


func fail(p_failure: Failure, cell: Vector2i) -> ValidationResult:
	failure = p_failure
	error_cell = cell
	return self
