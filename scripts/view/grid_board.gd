class_name GridBoard
extends Node3D

const NO_CELL := Vector2i(-1, -1)

@export var cell_size: float = 1.0
@export var ground_color := Color(0.78, 0.84, 0.78)
@export var line_color := Color(0.15, 0.2, 0.15)

var _model: GridModel

@onready var _ground: MeshInstance3D = $Ground
@onready var _lines: MeshInstance3D = $Lines


func setup(model: GridModel) -> void:
	_model = model
	_build_ground()
	_build_lines()


## Centro da célula em coordenadas globais.
func cell_to_world(cell: Vector2i) -> Vector3:
	var half := Vector2(_model.size) * 0.5
	var local := Vector3(
		(cell.x + 0.5 - half.x) * cell_size,
		0.0,
		(cell.y + 0.5 - half.y) * cell_size)
	return to_global(local)


## Célula sob um ponto global, ou NO_CELL se estiver fora da grid.
func world_to_cell(world_pos: Vector3) -> Vector2i:
	var local := to_local(world_pos)
	var half := Vector2(_model.size) * 0.5
	var cell := Vector2i(
		floori(local.x / cell_size + half.x),
		floori(local.z / cell_size + half.y))
	return cell if _model.in_bounds(cell) else NO_CELL


func _build_ground() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(_model.size) * cell_size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ground_color
	mesh.material = mat
	_ground.mesh = mesh


func _build_lines() -> void:
	var half := Vector2(_model.size) * cell_size * 0.5
	var y := 0.01 # evita z-fighting com o chão
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for x in range(_model.size.x + 1):
		var px := x * cell_size - half.x
		im.surface_add_vertex(Vector3(px, y, -half.y))
		im.surface_add_vertex(Vector3(px, y, half.y))
	for z in range(_model.size.y + 1):
		var pz := z * cell_size - half.y
		im.surface_add_vertex(Vector3(-half.x, y, pz))
		im.surface_add_vertex(Vector3(half.x, y, pz))
	im.surface_end()

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = line_color
	_lines.material_override = mat
	_lines.mesh = im
