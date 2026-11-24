class_name SwitchView
extends Node3D

## Agulha vista de cima: trilho reto + trilho em curva saindo do tronco,
## chapa de manobra e um marcador (cor + número) na ponta de cada ramo.

@export var rail_piece_scene: PackedScene
@export var plate_color := Color(0.43, 0.34, 0.26)
@export var locked_darken := 0.45
@export_range(0.1, 1.0) var ghost_alpha := 0.45

var _plate: MeshInstance3D
var _lever: MeshInstance3D
var _straight: RailPiece
var _curve: RailPiece
var _markers := {} # "straight"/"diverge" -> {disc, label}


func _ready() -> void:
	_plate = _mesh(BoxMesh.new(), Vector3(0.94, 0.012, 0.94), Vector3(0, 0.006, 0))
	if rail_piece_scene:
		_straight = rail_piece_scene.instantiate() as RailPiece
		_curve = rail_piece_scene.instantiate() as RailPiece
		add_child(_straight)
		add_child(_curve)
	_lever = _mesh(BoxMesh.new(), Vector3(0.05, 0.18, 0.05), Vector3.ZERO)
	for key in ["straight", "diverge"]:
		var disc := CylinderMesh.new()
		disc.top_radius = 0.11
		disc.bottom_radius = 0.11
		disc.height = 0.02
		disc.radial_segments = 12
		disc.rings = 0
		var disc_node := _mesh(disc, Vector3.ONE, Vector3.ZERO)
		var label := Label3D.new()
		label.pixel_size = 0.004
		label.font_size = 56
		label.outline_size = 14
		label.rotation_degrees.x = -90.0 # deitado, legível de cima
		add_child(label)
		_markers[key] = {"disc": disc_node, "label": label}


func apply(sw: SwitchData, symbols: Dictionary, locked: bool) -> void:
	if _straight:
		_straight.apply_shape(sw.trunk | sw.straight())
		_curve.apply_shape(sw.trunk | sw.diverge)
	_plate.material_override = _flat(plate_color.darkened(locked_darken) if locked else plate_color)
	_place_marker("straight", sw.straight(), sw.straight_symbol, symbols)
	_place_marker("diverge", sw.diverge, sw.diverge_symbol(), symbols)
	# Alavanca no canto do tronco, do lado oposto ao desvio.
	var corner := _vec(sw.trunk) * 0.36 - _vec(sw.diverge) * 0.36
	_lever.position = corner + Vector3(0, 0.09, 0)
	_lever.material_override = _flat(Color(0.25, 0.25, 0.27))


## Fantasma de colocação: tudo numa só cor translúcida.
func apply_ghost(tint: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(tint.r, tint.g, tint.b, ghost_alpha)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 0.35
	for node in _all_meshes(self):
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for key in _markers:
		_markers[key]["label"].visible = false


func _place_marker(key: String, dir: int, symbol: StringName, symbols: Dictionary) -> void:
	var pos := _vec(dir) * 0.34 + Vector3(0, 0.1, 0)
	var definition: SymbolDefinition = symbols.get(symbol)
	var color := definition.color if definition else Color.MAGENTA
	var disc: MeshInstance3D = _markers[key]["disc"]
	disc.position = pos
	disc.material_override = _flat(color)
	var label: Label3D = _markers[key]["label"]
	label.position = pos + Vector3(0, 0.015, 0)
	label.text = String(symbol)
	label.visible = true


func _mesh(mesh: PrimitiveMesh, scale_v: Vector3, pos: Vector3) -> MeshInstance3D:
	if mesh is BoxMesh:
		mesh.size = scale_v
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	add_child(node)
	return node


func _all_meshes(root: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for child in root.get_children():
		if child is MeshInstance3D:
			found.append(child)
		found.append_array(_all_meshes(child))
	return found


static func _vec(dir: int) -> Vector3:
	var o: Vector2i = GridModel.DIR_OFFSETS[dir]
	return Vector3(o.x, 0.0, o.y)


func _flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	return mat
