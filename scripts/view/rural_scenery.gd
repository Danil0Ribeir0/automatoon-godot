class_name RuralScenery
extends Node3D

## Cenário rural low poly gerado por código em volta da área jogável.
## O que se repete (árvores, pedras, cerca, capim...) vai em MultiMesh:
## poucos nós na árvore, muitas instâncias desenhadas de uma vez.
## Não conhece regras do jogo: só o tamanho da grid e onde ficam Spawn e Exit.

@export var scenery_seed := 7
## Até onde o cenário se espalha a partir do centro da grid.
@export var radius := 15.0
## Trilhos decorativos que saem do Spawn e do Exit para fora da cena.
@export var rail_scene: PackedScene
@export var lane_length := 12

@export_group("Quantidades")
@export var tree_count := 70
@export var bush_count := 40
@export var rock_count := 25
@export var tuft_count := 260
@export var flower_count := 80

@export_group("Relevo")
@export var hill_height := 1.4
@export var hill_frequency := 0.08

@export_group("Atmosfera")
@export var fog_density := 0.006

@export_group("Cores")
@export var grass_color := Color("86b85a")
@export var dirt_color := Color("b89466")
@export var trunk_color := Color("6b4a2f")
@export var leaf_color := Color("5e9e43")
@export var pine_color := Color("2f6b3a")
@export var rock_color := Color("9a9a92")
@export var barn_color := Color("b23a2e")
@export var roof_color := Color("5a3b2a")
@export var wall_color := Color("efe2c4")
@export var silo_color := Color("c9cfd4")
@export var fence_color := Color("a0764c")
@export var hay_color := Color("e3c165")
@export var soil_color := Color("7f5233")
@export var crop_color := Color("9ccf55")
@export var water_color := Color("4aa3c7")
@export var window_color := Color("8fc7e0")

const _GROUND_Y := -0.02
const _FLOWER_COLORS := [Color("fff6e0"), Color("ffd84a"), Color("f08fb0"), Color("b48cf0")]

var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
## Meia-largura e meia-profundidade da cerca (grid + células de Spawn/Exit).
var _fence := Vector2.ZERO
var _lane_z := 0.0
## Círculos ocupados (x, z, raio) para os objetos não se sobreporem.
var _occupied: Array[Vector3] = []
## Áreas planas reservadas às construções (x, z, raio).
var _flat_spots: Array[Vector3] = []
var _meshes := {}
var _batches := {}
var _instance_material: StandardMaterial3D

var _barn_pos := Vector2.ZERO
var _house_pos := Vector2.ZERO
var _field_pos := Vector2.ZERO
var _pond_pos := Vector2.ZERO


func build(board: GridBoard, level: LevelData) -> void:
	_clear()
	global_transform = Transform3D(Basis.IDENTITY, board.global_position)
	_rng.seed = scenery_seed
	_noise.seed = scenery_seed
	_noise.frequency = hill_frequency

	var cell := board.cell_size
	var half := Vector2(level.grid_size) * cell * 0.5 + Vector2(cell, 0.0) # inclui Spawn e Exit
	_fence = half + Vector2(0.3, 0.4) * cell
	_lane_z = to_local(board.cell_to_world(level.get_spawn_cell())).z

	_instance_material = StandardMaterial3D.new()
	_instance_material.vertex_color_use_as_albedo = true
	_instance_material.vertex_color_is_srgb = true
	_instance_material.roughness = 1.0
	_make_meshes()

	_build_environment()
	_plan_landmarks()
	_build_ground()
	_build_farm()
	_build_fence()
	_build_lane(board, level)
	_scatter()
	_flush_batches()


# --- Terreno e atmosfera -----------------------------------------------------

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("5fa8e0")
	sky_mat.sky_horizon_color = Color("d4ecf7")
	sky_mat.ground_horizon_color = Color("d4ecf7")
	sky_mat.ground_bottom_color = Color("6f9a4a")
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0 # com o branco padrão (1.0) o Filmic estoura as cores
	env.fog_enabled = fog_density > 0.0
	env.fog_light_color = Color("d4ecf7")
	env.fog_density = fog_density
	env.fog_sky_affect = 0.0

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)


func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius * 3.0
	plane.subdivide_width = 56
	plane.subdivide_depth = 56
	var arrays := plane.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		var v := verts[i]
		v.y = _ground_y(v.x, v.z)
		verts[i] = v
	arrays[Mesh.ARRAY_VERTEX] = verts

	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = _faceted_arrays(arrays)
	ground.material_override = _flat_material(grass_color)
	add_child(ground)

	# Base de terra batida sob a grid e os terminais.
	_put("box", Vector3(0, -0.03, 0), 0.0,
			Vector3(_fence.x * 2.0 + 0.6, 0.04, _fence.y * 2.0 + 0.6), dirt_color)


## Altura do relevo: plano perto da grid, do corredor dos trilhos e das construções.
func _height(x: float, z: float) -> float:
	var dx := maxf(absf(x) - _fence.x - 1.0, 0.0)
	var dz := maxf(absf(z) - _fence.y - 1.0, 0.0)
	var ramp := clampf(Vector2(dx, dz).length() / 5.0, 0.0, 1.0)
	if absf(x) > _fence.x:
		ramp *= clampf((absf(z - _lane_z) - 1.0) / 2.5, 0.0, 1.0)
	for spot in _flat_spots:
		ramp *= clampf((Vector2(x, z).distance_to(Vector2(spot.x, spot.y)) - spot.z) / 2.0, 0.0, 1.0)
	if z > _fence.y:
		ramp *= 0.35 # do lado da câmera, morros baixos para não tapar a grid
	return (_noise.get_noise_2d(x, z) * 0.5 + 0.5) * hill_height * ramp


func _ground_y(x: float, z: float) -> float:
	return _height(x, z) + _GROUND_Y


# --- Construções -------------------------------------------------------------

func _plan_landmarks() -> void:
	# Construções altas ficam atrás da grid (lado oposto à câmera).
	_barn_pos = Vector2(-_fence.x - 3.2, -_fence.y - 2.8)
	_house_pos = Vector2(_fence.x + 3.4, -_fence.y - 2.4)
	# Do lado da câmera, só coisas baixas.
	_field_pos = Vector2(-_fence.x - 2.6, _fence.y + 2.0)
	_pond_pos = Vector2(_fence.x + 2.8, _fence.y + 2.0)
	_reserve(_barn_pos + Vector2(0.5, 0.0), 2.6)
	_reserve(_house_pos, 1.8)
	_reserve(_field_pos, 2.0)
	_reserve(_pond_pos, 1.9)


func _reserve(p: Vector2, r: float) -> void:
	_occupied.append(Vector3(p.x, p.y, r))
	_flat_spots.append(Vector3(p.x, p.y, r))


func _build_farm() -> void:
	# Celeiro
	var b := _barn_pos
	var yaw := 0.25
	_local("box", b, yaw, Vector3(0, 0.55, 0), Vector3(1.4, 1.1, 2.0), barn_color)
	_local("prism", b, yaw, Vector3(0, 1.45, 0), Vector3(1.6, 0.7, 2.2), roof_color)
	_local("box", b, yaw, Vector3(0, 0.43, 1.003), Vector3(0.72, 0.86, 0.02), wall_color)
	_local("box", b, yaw, Vector3(0, 0.38, 1.01), Vector3(0.6, 0.76, 0.02), roof_color.darkened(0.2))
	_local("box", b, yaw, Vector3(0, 1.3, 1.105), Vector3(0.34, 0.24, 0.02), wall_color)
	_local("drum", b, yaw, Vector3(1.35, 0.9, -0.4), Vector3(0.4, 1.8, 0.4), silo_color)
	_local("ball", b, yaw, Vector3(1.35, 1.8, -0.4), Vector3(0.4, 0.3, 0.4), silo_color.darkened(0.15))
	var lying := Basis(Vector3(0, 0, 1), PI * 0.5)
	for offset in [Vector3(-1.3, 0.22, 0.95), Vector3(-1.3, 0.22, 0.45), Vector3(-1.3, 0.6, 0.7)]:
		_local("drum", b, yaw, offset, Vector3(0.22, 0.42, 0.22), _vary(hay_color), lying)

	# Casa da fazenda
	var h := _house_pos
	yaw = -0.3
	_local("box", h, yaw, Vector3(0, 0.4, 0), Vector3(1.2, 0.8, 1.0), wall_color)
	_local("prism", h, yaw, Vector3(0, 1.1, 0), Vector3(1.4, 0.6, 1.2), barn_color.darkened(0.25))
	_local("box", h, yaw, Vector3(0.25, 0.3, 0.505), Vector3(0.28, 0.6, 0.02), roof_color)
	_local("box", h, yaw, Vector3(-0.3, 0.5, 0.505), Vector3(0.3, 0.24, 0.02), window_color)
	_local("box", h, yaw, Vector3(0.35, 1.2, -0.2), Vector3(0.15, 0.4, 0.15), rock_color)

	# Plantação
	var f := _field_pos
	yaw = 0.1
	_local("box", f, yaw, Vector3(0, 0.03, 0), Vector3(2.6, 0.06, 1.8), soil_color)
	for row in 5:
		for col in 10:
			var offset := Vector3(-1.08 + col * 0.24, 0.15, -0.7 + row * 0.35)
			_local("tuft", f, yaw, offset, Vector3(1.3, 1.3, 1.3), _vary(crop_color, 0.1))

	# Lagoa
	var p := _pond_pos
	_local("disc", p, 0.0, Vector3(0, -0.005, 0), Vector3(1.5, 0.5, 1.1), dirt_color)
	_local("disc", p, 0.0, Vector3(0, 0.0, 0), Vector3(1.3, 1.0, 0.9), water_color)
	for i in 8:
		var angle := TAU * i / 8.0 + _rng.randf() * 0.3
		var rock := p + Vector2(cos(angle) * 1.45, sin(angle) * 1.05)
		_put("rock", Vector3(rock.x, _GROUND_Y + 0.05, rock.y), _rng.randf() * TAU,
				Vector3(0.6, 0.5, 0.7) * _rng.randf_range(0.8, 1.2), _vary(rock_color))
	for _i in 7:
		var angle := _rng.randf() * TAU
		var reed := p + Vector2(cos(angle) * 1.2, sin(angle) * 0.8)
		_put("tuft", Vector3(reed.x, _GROUND_Y + 0.2, reed.y), 0.0,
				Vector3(0.8, 2.4, 0.8), _vary(pine_color, 0.1))


# --- Cerca e corredor dos trilhos --------------------------------------------

func _build_fence() -> void:
	var f := _fence
	var gap := 0.7 # abertura por onde passam os trilhos do Spawn e do Exit
	_fence_line(Vector2(-f.x, -f.y), Vector2(f.x, -f.y))
	_fence_line(Vector2(-f.x, f.y), Vector2(f.x, f.y))
	for side in [-1.0, 1.0]:
		_fence_line(Vector2(side * f.x, -f.y), Vector2(side * f.x, _lane_z - gap))
		_fence_line(Vector2(side * f.x, _lane_z + gap), Vector2(side * f.x, f.y))


func _fence_line(a: Vector2, b: Vector2) -> void:
	var length := a.distance_to(b)
	if length < 0.05:
		return
	var n := maxi(roundi(length / 0.6), 1)
	var d := (b - a) / n
	var yaw := atan2(-d.y, d.x)
	for i in n + 1:
		var post := a + d * i
		_put("box", Vector3(post.x, _GROUND_Y + 0.15, post.y), 0.0,
				Vector3(0.06, 0.3, 0.06), _vary(fence_color, 0.06))
	for i in n:
		var mid := a + d * (i + 0.5)
		for height in [0.12, 0.23]:
			_put("box", Vector3(mid.x, _GROUND_Y + height, mid.y), yaw,
					Vector3(d.length(), 0.03, 0.025), fence_color)


func _build_lane(board: GridBoard, level: LevelData) -> void:
	var spawn := level.get_spawn_cell()
	var exit := level.get_exit_cell()
	for i in range(1, lane_length + 1):
		_lane_piece(board, spawn + Vector2i(-i, 0))
		_lane_piece(board, exit + Vector2i(i, 0))
	# Faixa de cascalho embaixo dos trilhos decorativos.
	var cell := board.cell_size
	var far := lane_length * cell
	var left := to_local(board.cell_to_world(spawn)).x - 0.5 * cell
	var right := to_local(board.cell_to_world(exit)).x + 0.5 * cell
	var gravel := dirt_color.darkened(0.15)
	_put("box", Vector3(left - far * 0.5, _GROUND_Y + 0.005, _lane_z), 0.0, Vector3(far, 0.02, 0.8 * cell), gravel)
	_put("box", Vector3(right + far * 0.5, _GROUND_Y + 0.005, _lane_z), 0.0, Vector3(far, 0.02, 0.8 * cell), gravel)


func _lane_piece(board: GridBoard, cell: Vector2i) -> void:
	if rail_scene == null:
		return
	var piece := rail_scene.instantiate() as Node3D
	if piece == null:
		return
	piece.position = to_local(board.cell_to_world(cell))
	piece.scale = Vector3.ONE * board.cell_size
	add_child(piece)
	if piece.has_method("apply_shape"):
		piece.apply_shape(GridModel.HORIZONTAL)


# --- Vegetação e pedras espalhadas -------------------------------------------

func _scatter() -> void:
	for _i in tree_count:
		var spot: Variant = _spot(0.55, true, true)
		if spot == null:
			continue
		var size := _rng.randf_range(0.8, 1.35)
		if _rng.randf() < 0.55:
			_tree_pine(spot, size)
		else:
			_tree_round(spot, size)

	for _i in bush_count:
		var spot: Variant = _spot(0.35, false, true)
		if spot == null:
			continue
		var s := _rng.randf_range(0.35, 0.6)
		var y := _ground_y(spot.x, spot.y)
		_put("blob", Vector3(spot.x, y + 0.25 * s, spot.y), _rng.randf() * TAU,
				Vector3(1.0, 0.8, 1.0) * s, _vary(leaf_color, 0.12))

	for _i in rock_count:
		var spot: Variant = _spot(0.3, false, true)
		if spot == null:
			continue
		var s := _rng.randf_range(0.6, 1.6)
		_put("rock", Vector3(spot.x, _ground_y(spot.x, spot.y) + 0.05 * s, spot.y), _rng.randf() * TAU,
				Vector3(1.0, 0.7, 1.1) * s, _vary(rock_color, 0.1))

	for _i in tuft_count:
		var spot: Variant = _spot(0.0, false, false)
		if spot == null:
			continue
		var s := _rng.randf_range(0.7, 1.4)
		_put("tuft", Vector3(spot.x, _ground_y(spot.x, spot.y) + 0.09 * s, spot.y), _rng.randf() * TAU,
				Vector3.ONE * s, _vary(grass_color.darkened(0.12), 0.1))

	for _i in flower_count:
		var spot: Variant = _spot(0.0, false, false)
		if spot == null:
			continue
		var color: Color = _FLOWER_COLORS[_rng.randi() % _FLOWER_COLORS.size()]
		_put("flower", Vector3(spot.x, _ground_y(spot.x, spot.y) + 0.05, spot.y), 0.0, Vector3.ONE, color)


func _tree_pine(p: Vector2, s: float) -> void:
	var y := _ground_y(p.x, p.y)
	var yaw := _rng.randf() * TAU
	_put("trunk", Vector3(p.x, y + 0.3 * s, p.y), yaw, Vector3.ONE * s, _vary(trunk_color))
	var green := _vary(pine_color, 0.12)
	for i in 3:
		var k := 1.0 - i * 0.22
		_put("cone", Vector3(p.x, y + (0.65 + i * 0.38) * s, p.y), yaw + i,
				Vector3.ONE * k * s, green.lightened(i * 0.05))


func _tree_round(p: Vector2, s: float) -> void:
	var y := _ground_y(p.x, p.y)
	var yaw := _rng.randf() * TAU
	_put("trunk", Vector3(p.x, y + 0.3 * s, p.y), yaw, Vector3.ONE * s, _vary(trunk_color))
	var leaves := _vary(leaf_color, 0.12)
	_put("blob", Vector3(p.x, y + 0.9 * s, p.y), yaw, Vector3(1.0, 0.95, 1.0) * s, leaves)
	_put("blob", Vector3(p.x + 0.18 * s, y + 1.2 * s, p.y - 0.1 * s), yaw,
			Vector3.ONE * 0.6 * s, leaves.lightened(0.06))


## Sorteia um ponto livre (ou null). `tall` = objeto alto, que não pode
## ficar entre a câmera e a grid. `check_props` = desvia de árvores/pedras.
func _spot(clearance: float, tall: bool, check_props: bool) -> Variant:
	for _attempt in 40:
		var p := Vector2(_rng.randf_range(-radius, radius), _rng.randf_range(-radius, radius))
		if _blocked(p, clearance, tall, check_props):
			continue
		if check_props:
			_occupied.append(Vector3(p.x, p.y, clearance))
		return p
	return null


func _blocked(p: Vector2, r: float, tall: bool, check_props: bool) -> bool:
	if absf(p.x) < _fence.x + 0.6 + r and absf(p.y) < _fence.y + 0.6 + r:
		return true # área jogável e cerca
	if absf(p.x) > _fence.x and absf(p.y - _lane_z) < 0.8 + r:
		return true # corredor dos trilhos
	if tall and p.y > _fence.y - 1.0 and absf(p.x) < _fence.x + 4.0:
		return true # na frente da câmera taparia a grid
	for o in (_occupied if check_props else _flat_spots):
		if p.distance_to(Vector2(o.x, o.y)) < o.z + r:
			return true
	return false


# --- Malhas e lotes (MultiMesh) ----------------------------------------------

func _make_meshes() -> void:
	_meshes.clear()
	_meshes["trunk"] = _faceted(_cylinder(0.06, 0.09, 0.6, 5))
	_meshes["cone"] = _faceted(_cylinder(0.0, 0.45, 0.8, 6))
	_meshes["blob"] = _faceted(_sphere(0.45, 0.8, 7, 4))
	_meshes["ball"] = _faceted(_sphere(1.0, 2.0, 8, 4))
	_meshes["rock"] = _faceted(_sphere(0.25, 0.35, 5, 3))
	_meshes["tuft"] = _faceted(_cylinder(0.0, 0.05, 0.18, 3))
	_meshes["flower"] = _faceted(_sphere(0.035, 0.07, 4, 2))
	_meshes["box"] = _faceted(BoxMesh.new())
	_meshes["prism"] = _faceted(PrismMesh.new())
	_meshes["disc"] = _faceted(_cylinder(1.0, 1.0, 0.04, 10))
	_meshes["drum"] = _faceted(_cylinder(1.0, 1.0, 1.0, 8))


func _put(key: String, pos: Vector3, yaw: float, scale_v: Vector3, color: Color) -> void:
	_add(key, Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(scale_v), pos), color)


## Parte de uma construção: `offset` no espaço local da construção.
func _local(key: String, origin: Vector2, yaw: float, offset: Vector3, scale_v: Vector3,
		color: Color, tilt := Basis.IDENTITY) -> void:
	var rot := Basis(Vector3.UP, yaw)
	var pos := Vector3(origin.x, _GROUND_Y, origin.y) + rot * offset
	_add(key, Transform3D(rot * tilt * Basis.from_scale(scale_v), pos), color)


func _add(key: String, xform: Transform3D, color: Color) -> void:
	if not _batches.has(key):
		_batches[key] = {"xforms": [], "colors": []}
	_batches[key]["xforms"].append(xform)
	_batches[key]["colors"].append(color)


func _flush_batches() -> void:
	for key in _batches:
		var data: Dictionary = _batches[key]
		var xforms: Array = data["xforms"]
		var colors: Array = data["colors"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _meshes[key]
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
			mm.set_instance_color(i, colors[i])
		var node := MultiMeshInstance3D.new()
		node.name = "Batch_" + String(key)
		node.multimesh = mm
		node.material_override = _instance_material
		add_child(node)
	_batches.clear()


func _clear() -> void:
	for child in get_children():
		child.queue_free()
	_batches.clear()
	_occupied.clear()
	_flat_spots.clear()


func _vary(color: Color, amount := 0.08) -> Color:
	var t := _rng.randf_range(-amount, amount)
	return color.lightened(t) if t > 0.0 else color.darkened(-t)


func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	return mat


static func _cylinder(top: float, bottom: float, height: float, segments: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 0
	return mesh


static func _sphere(r: float, height: float, segments: int, rings: int) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = rings
	return mesh


## Visual low poly: cada triângulo ganha a própria normal (faces chapadas).
static func _faceted(mesh: PrimitiveMesh) -> ArrayMesh:
	return _faceted_arrays(mesh.get_mesh_arrays())


static func _faceted_arrays(arrays: Array) -> ArrayMesh:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		indices = arrays[Mesh.ARRAY_INDEX]
	var indexed := not indices.is_empty()
	var count := indices.size() if indexed else verts.size()

	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	for t in range(0, count - 2, 3):
		var i0: int = indices[t] if indexed else t
		var i1: int = indices[t + 1] if indexed else t + 1
		var i2: int = indices[t + 2] if indexed else t + 2
		var a := verts[i0]
		var b := verts[i1]
		var c := verts[i2]
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-10:
			continue
		n = n.normalized()
		if n.dot(normals[i0] + normals[i1] + normals[i2]) < 0.0:
			n = -n
		for v in [a, b, c]:
			out_v.append(v)
			out_n.append(n)

	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = out_v
	out[Mesh.ARRAY_NORMAL] = out_n
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return result
