class_name TileMeshBuilder
extends RefCounted

static func build_tile_visual(tile: RailTileData, cell_size: float) -> Node3D:
	var root := Node3D.new()
	var s := cell_size
	
	var base_color := Color(0.22, 0.24, 0.28)
	match tile.type:
		RailTileData.TileType.SPAWN:
			base_color = Color(0.15, 0.55, 0.25)
		RailTileData.TileType.EXIT:
			base_color = Color(0.7, 0.2, 0.2)
		RailTileData.TileType.STATION:
			base_color = AutomataPalette.get_symbol_color(tile.symbol, Color(0.75, 0.55, 0.15)).darkened(0.35)
			
	var floor_box := _make_box(Vector3(s * 0.92, 0.1 * s, s * 0.92), base_color)
	floor_box.position.y = -0.05 * s
	root.add_child(floor_box)
	
	var active_dirs := tile.get_active_connections()
	if not active_dirs.is_empty():
		var rail_color := Color(0.75, 0.75, 0.8)
		var center_hub := _make_box(Vector3(s * 0.24, 0.08 * s, s * 0.24), rail_color)
		center_hub.position.y = 0.04 * s
		root.add_child(center_hub)
		
		for dir in active_dirs:
			var arm_size := Vector3(s * 0.2, 0.08 * s, s * 0.5)
			var arm_offset := Vector3.ZERO
			match dir:
				RailTileData.Dir.NORTH:
					arm_offset = Vector3(0, 0.04 * s, -s * 0.25)
				RailTileData.Dir.SOUTH:
					arm_offset = Vector3(0, 0.04 * s, s * 0.25)
				RailTileData.Dir.EAST:
					arm_size = Vector3(s * 0.5, 0.08 * s, s * 0.2)
					arm_offset = Vector3(s * 0.25, 0.04 * s, 0)
				RailTileData.Dir.WEST:
					arm_size = Vector3(s * 0.5, 0.08 * s, s * 0.2)
					arm_offset = Vector3(-s * 0.25, 0.04 * s, 0)
					
			var arm := _make_box(arm_size, rail_color)
			arm.position = arm_offset
			root.add_child(arm)
			
	if tile.type == RailTileData.TileType.STATION:
		var roof_color := AutomataPalette.get_symbol_color(tile.symbol, Color(0.95, 0.8, 0.2))
		var station_roof := _make_box(Vector3(s * 0.35, 0.3 * s, s * 0.25), roof_color)
		station_roof.position = Vector3(0.0, 0.15 * s, -0.3 * s)
		root.add_child(station_roof)
		
	if tile.symbol != "":
		var lbl := Label3D.new()
		lbl.text = tile.symbol
		lbl.pixel_size = 0.005 * s
		lbl.font_size = 48
		lbl.outline_size = 12
		lbl.position = Vector3(0, 0.45 * s, 0)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		root.add_child(lbl)
		
	return root

static func _make_box(box_size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	box.material = mat
	mesh_inst.mesh = box
	return mesh_inst
