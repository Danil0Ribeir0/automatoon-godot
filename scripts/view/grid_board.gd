class_name GridBoard
extends Node3D

@export var cell_size: float = 1.0
@export var rail_piece_scene: PackedScene
@export var station_scene: PackedScene
@export var symbols: Array[SymbolDefinition] = []

@export_group("Cores")
@export var ground_color := Color(0.78, 0.84, 0.78)
@export var line_color := Color(0.15, 0.2, 0.15)
@export var spawn_color := Color(0.2, 0.6, 0.3)
@export var exit_color := Color(0.75, 0.25, 0.2)

var _model: GridModel
var _pieces: Dictionary = {}
var _station_views: Dictionary = {}
var _symbol_lookup: Dictionary = {}

@onready var _ground: MeshInstance3D = $Ground
@onready var _lines: MeshInstance3D = $Lines
@onready var _cells: Node3D = $Cells


func setup(model: GridModel) -> void:
	_model = model
	for def in symbols:
		_symbol_lookup[def.id] = def
	_model.cell_changed.connect(_on_cell_changed)
	_build_ground()
	_build_lines()
	_build_terminals()


func cell_to_world(cell: Vector2i) -> Vector3:
	return to_global(_cell_to_local(cell))


## Célula sob um ponto global, SEM checar limites. O modelo decide se é válida.
func world_to_cell(world_pos: Vector3) -> Vector2i:
	var local := to_local(world_pos)
	var half := Vector2(_model.size) * 0.5
	return Vector2i(
		floori(local.x / cell_size + half.x),
		floori(local.z / cell_size + half.y))


func _cell_to_local(cell: Vector2i) -> Vector3:
	var half := Vector2(_model.size) * 0.5
	return Vector3(
		(cell.x + 0.5 - half.x) * cell_size,
		0.0,
		(cell.y + 0.5 - half.y) * cell_size)


func _on_cell_changed(cell: Vector2i) -> void:
	if _model.is_terminal(cell):
		return
	_sync_rail(cell)
	_sync_station(cell)


func _sync_rail(cell: Vector2i) -> void:
	if not _model.has_rail(cell):
		_free_view(_pieces, cell)
		return
	var piece: RailPiece = _pieces.get(cell)
	if piece == null:
		piece = _spawn_view(rail_piece_scene, cell)
		_pieces[cell] = piece
	piece.apply_shape(_model.get_shape(cell))


func _sync_station(cell: Vector2i) -> void:
	var station := _model.get_station(cell)
	if station == null:
		_free_view(_station_views, cell)
		return
	var view: StationView = _station_views.get(cell)
	if view == null:
		view = _spawn_view(station_scene, cell)
		_station_views[cell] = view
	view.apply(_symbol_lookup.get(station.symbol), _model.is_locked(cell))


func _spawn_view(scene: PackedScene, cell: Vector2i) -> Node3D:
	var view: Node3D = scene.instantiate()
	view.position = _cell_to_local(cell)
	view.scale = Vector3.ONE * cell_size
	_cells.add_child(view)
	return view


func _free_view(views: Dictionary, cell: Vector2i) -> void:
	if views.has(cell):
		views[cell].queue_free()
		views.erase(cell)


func _build_terminals() -> void:
	_add_marker(_model.spawn_cell, spawn_color)
	_add_marker(_model.exit_cell, exit_color)


func _add_marker(cell: Vector2i, color: Color) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.8, 0.4, 0.8) * cell_size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	box.material = mat
	var marker := MeshInstance3D.new()
	marker.mesh = box
	marker.position = _cell_to_local(cell) + Vector3(0, 0.2 * cell_size, 0)
	add_child(marker)


func _build_ground() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(_model.size) * cell_size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ground_color
	mesh.material = mat
	_ground.mesh = mesh


func _build_lines() -> void:
	var half := Vector2(_model.size) * cell_size * 0.5
	var y := 0.01
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
