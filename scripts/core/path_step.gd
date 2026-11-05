class_name PathStep
extends RefCounted

var cell: Vector2i
## Lado por onde o trem entrou (0 no Spawn).
var entry_dir: int
## Lado por onde saiu (0 no Exit ou onde o percurso parou).
var exit_dir := 0
## Símbolo lido nesta passagem (vazio se não for estação).
var symbol: StringName = &""
## Qual vagão foi consumido aqui (-1 se nenhum). Útil para animar o trem depois.
var wagon_index := -1


func _init(p_cell: Vector2i, p_entry: int) -> void:
	cell = p_cell
	entry_dir = p_entry
