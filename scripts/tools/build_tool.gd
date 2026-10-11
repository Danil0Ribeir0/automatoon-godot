class_name BuildTool
extends RefCounted

## Interface das ferramentas acionadas por um traço do mouse.
func begin(_cell: Vector2i) -> void:
	pass


func move_to(_cell: Vector2i) -> void:
	pass


func end_stroke() -> void:
	pass


## Um passo ortogonal de `from` em direção a `to` (preenche saltos do mouse).
static func step_toward(from: Vector2i, to: Vector2i) -> Vector2i:
	var d := to - from
	if absi(d.x) >= absi(d.y):
		return from + Vector2i(signi(d.x), 0)
	return from + Vector2i(0, signi(d.y))
