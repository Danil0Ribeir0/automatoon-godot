class_name MineScenery
extends RuralScenery

## Cenário da Mina: mesmo terreno/cerca/trilhos do RuralScenery, com construções
## e vegetação trocadas — castelete (torre de extração), boca de mina no morro,
## montes de minério, carrinhos, cristais e pedregulhos.

@export_group("Mina")
@export var timber_color := Color("7a5534")
@export var iron_color := Color("4a4a50")
@export var gold_color := Color("f2b134")
@export var crystal_color := Color("5fb8ff")
@export var crystal_count := 45

var _headframe_pos := Vector2.ZERO
var _entrance_pos := Vector2.ZERO
var _ore_pos := Vector2.ZERO
var _carts_pos := Vector2.ZERO


func _build_environment() -> void:
	super._build_environment()
	var env: Environment = get_node("WorldEnvironment").environment
	var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
	sky_mat.sky_top_color = Color("6a9fd0")
	sky_mat.sky_horizon_color = Color("f0d9b5")
	sky_mat.ground_horizon_color = Color("f0d9b5")
	sky_mat.ground_bottom_color = Color("7d6a50")
	env.fog_light_color = Color("e8cfa8")


func _plan_landmarks() -> void:
	_headframe_pos = Vector2(-_fence.x - 3.0, -_fence.y - 2.6)
	_entrance_pos = Vector2(_fence.x + 3.3, -_fence.y - 2.7)
	_ore_pos = Vector2(-_fence.x - 2.4, _fence.y + 1.9)
	_carts_pos = Vector2(_fence.x + 2.6, _fence.y + 1.9)
	_reserve(_headframe_pos, 2.2)
	_reserve(_entrance_pos, 2.4)
	_reserve(_ore_pos, 1.6)
	_reserve(_carts_pos, 1.6)


func _build_farm() -> void:
	# Castelete: torre de madeira com a roda da polia no alto.
	var h := _headframe_pos
	var yaw := 0.2
	for x in [-0.6, 0.6]:
		for z in [-0.6, 0.6]:
			_local("box", h, yaw, Vector3(x, 1.5, z), Vector3(0.12, 3.0, 0.12), timber_color)
	for y in [1.0, 2.0]:
		for z in [-0.6, 0.6]:
			_local("box", h, yaw, Vector3(0, y, z), Vector3(1.32, 0.09, 0.09), timber_color.darkened(0.15))
		for x in [-0.6, 0.6]:
			_local("box", h, yaw, Vector3(x, y, 0), Vector3(0.09, 0.09, 1.32), timber_color.darkened(0.15))
	_local("box", h, yaw, Vector3(0, 3.02, 0), Vector3(1.5, 0.1, 1.5), timber_color.darkened(0.25))
	var standing := Basis(Vector3(1, 0, 0), PI * 0.5) # roda em pé, virada para a câmera
	_local("drum", h, yaw, Vector3(0, 3.5, 0), Vector3(0.55, 0.07, 0.55), iron_color, standing)
	_local("drum", h, yaw, Vector3(0, 3.5, 0), Vector3(0.12, 0.12, 0.12), iron_color.darkened(0.3), standing)
	_local("box", h, yaw, Vector3(0.9, 0.4, 1.0), Vector3(1.0, 0.8, 0.9), barn_color.darkened(0.2))
	_local("prism", h, yaw, Vector3(0.9, 0.95, 1.0), Vector3(1.1, 0.3, 1.0), roof_color)

	# Boca de mina num morro de pedra.
	var e := _entrance_pos
	yaw = -0.25
	_local("blob", e, yaw, Vector3(0, 0, 0), Vector3(2.6, 2.3, 2.0), rock_color.darkened(0.1))
	_local("box", e, yaw, Vector3(0, 0.42, 0.9), Vector3(0.75, 0.84, 0.05), Color(0.05, 0.04, 0.04))
	for x in [-0.45, 0.45]:
		_local("box", e, yaw, Vector3(x, 0.48, 0.95), Vector3(0.12, 0.96, 0.12), timber_color)
	_local("box", e, yaw, Vector3(0, 0.98, 0.95), Vector3(1.1, 0.13, 0.14), timber_color.darkened(0.15))
	_local("box", e, yaw, Vector3(0, 0.03, 1.6), Vector3(0.45, 0.04, 1.3), dirt_color.darkened(0.2))

	# Montes de minério (ouro e cristal) — baixos, do lado da câmera.
	var o := _ore_pos
	_local("cone", o, 0.0, Vector3(-0.4, 0.3, 0), Vector3(1.4, 0.75, 1.4), gold_color)
	_local("cone", o, 0.0, Vector3(0.55, 0.25, 0.2), Vector3(1.1, 0.62, 1.1), crystal_color)
	for i in 6:
		var a := TAU * i / 6.0
		_local("rock", o, a, Vector3(cos(a) * 1.0, 0.05, sin(a) * 0.8), Vector3.ONE * 0.8, _vary(rock_color))

	# Carrinhos de mina parados.
	var c := _carts_pos
	for i in 2:
		var off := Vector3(-0.4 + i * 0.75, 0, 0)
		_local("box", c, 0.15, off + Vector3(0, 0.2, 0), Vector3(0.45, 0.22, 0.6), iron_color)
		_local("blob", c, 0.15, off + Vector3(0, 0.33, 0), Vector3(0.45, 0.2, 0.55), gold_color if i == 0 else crystal_color)
		for x in [-0.24, 0.24]:
			for z in [-0.2, 0.2]:
				_local("drum", c, 0.15, off + Vector3(x, 0.07, z), Vector3(0.07, 0.04, 0.07), iron_color.darkened(0.3),
						Basis(Vector3(0, 0, 1), PI * 0.5))


func _scatter() -> void:
	# Pedregulhos (bem mais que na fazenda).
	for _i in rock_count * 3:
		var spot: Variant = _spot(0.35, false, true)
		if spot == null:
			continue
		var s := _rng.randf_range(0.8, 2.6)
		_put("rock", Vector3(spot.x, _ground_y(spot.x, spot.y) + 0.05 * s, spot.y), _rng.randf() * TAU,
				Vector3(1.0, 0.75, 1.1) * s, _vary(rock_color, 0.12))
	# Cristais azuis em tufos.
	for _i in crystal_count:
		var spot: Variant = _spot(0.3, false, true)
		if spot == null:
			continue
		var y := _ground_y(spot.x, spot.y)
		for k in 3:
			var tilt := Basis(Vector3(1, 0, 0), _rng.randf_range(-0.35, 0.35))
			var size := _rng.randf_range(0.18, 0.3)
			var t := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU) * tilt * Basis.from_scale(Vector3(size, size * 2.4, size)),
					Vector3(spot.x + _rng.randf_range(-0.12, 0.12), y + size * 0.9, spot.y + _rng.randf_range(-0.12, 0.12)))
			_add("cone", t, _vary(crystal_color, 0.15))
	# Poucos pinheiros e arbustos secos.
	for _i in tree_count / 4:
		var spot: Variant = _spot(0.55, true, true)
		if spot != null:
			_tree_pine(spot, _rng.randf_range(0.8, 1.2))
	for _i in bush_count:
		var spot: Variant = _spot(0.3, false, true)
		if spot == null:
			continue
		var s := _rng.randf_range(0.3, 0.5)
		_put("blob", Vector3(spot.x, _ground_y(spot.x, spot.y) + 0.2 * s, spot.y), _rng.randf() * TAU,
				Vector3(1.0, 0.7, 1.0) * s, _vary(leaf_color, 0.1))
	for _i in tuft_count / 2:
		var spot: Variant = _spot(0.0, false, false)
		if spot == null:
			continue
		var s := _rng.randf_range(0.6, 1.2)
		_put("tuft", Vector3(spot.x, _ground_y(spot.x, spot.y) + 0.09 * s, spot.y), _rng.randf() * TAU,
				Vector3.ONE * s, _vary(grass_color.darkened(0.15), 0.1))
