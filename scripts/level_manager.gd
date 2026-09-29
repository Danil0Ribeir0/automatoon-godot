extends Node3D

enum BuildTool { RAIL, STATION }

@onready var camera: Camera3D = $Camera3D
@onready var grid_system: GridSystem = $GridSystem
@onready var board_plane: StaticBody3D = $BoardPlane
@onready var train: Train = $Train

@onready var rail_btn: Button = $HUD/MarginContainer/HBoxContainer/RailToolButton
@onready var station_btn: Button = $HUD/MarginContainer/HBoxContainer/StationToolButton

var drag_builder: TrackDragBuilder
var current_tool: BuildTool = BuildTool.RAIL
var current_station_symbol: String = "1"

var hovered_coords: Vector2i = Vector2i(-999, -999)
var cursor_visual: MeshInstance3D
var cursor_material: StandardMaterial3D
var is_simulating: bool = false

func _ready() -> void:
	drag_builder = TrackDragBuilder.new(grid_system)
	
	_setup_board_collider()
	_setup_camera()
	_create_cursor_highlight()
	
	train.arrived_at_exit.connect(_on_train_completed)
	rail_btn.pressed.connect(func(): select_tool(BuildTool.RAIL))
	station_btn.pressed.connect(func(): select_tool(BuildTool.STATION))
	
	select_tool(BuildTool.RAIL)

func _process(_delta: float) -> void:
	var previous_coords := hovered_coords
	_update_hovered_cell()
	
	if hovered_coords != previous_coords:
		if current_tool == BuildTool.RAIL:
			drag_builder.step_build(hovered_coords)
		drag_builder.step_erase(hovered_coords)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
			return
		elif event.keycode == KEY_SPACE:
			if not is_simulating:
				_try_run_simulation()
			else:
				_reset_simulation()
			return
			
	if is_simulating:
		return
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1 or event.keycode == KEY_KP_1:
			select_tool(BuildTool.RAIL)
		elif event.keycode == KEY_2 or event.keycode == KEY_KP_2:
			select_tool(BuildTool.STATION)
			
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and grid_system.is_inside_playable_grid(hovered_coords):
				if current_tool == BuildTool.RAIL:
					drag_builder.start_build(hovered_coords)
				elif current_tool == BuildTool.STATION:
					grid_system.place_or_rotate_station(hovered_coords, current_station_symbol)
			elif not event.pressed:
				drag_builder.stop_build()
				
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				drag_builder.start_erase(hovered_coords)
			else:
				drag_builder.stop_erase()

func select_tool(new_tool: BuildTool) -> void:
	current_tool = new_tool
	drag_builder.cancel_all()
	
	if current_tool == BuildTool.RAIL:
		rail_btn.modulate = Color(0.4, 0.9, 1.0)
		station_btn.modulate = Color(0.7, 0.7, 0.7)
		if cursor_material:
			cursor_material.albedo_color = Color(0.2, 0.8, 1.0, 0.35)
	else:
		rail_btn.modulate = Color(0.7, 0.7, 0.7)
		station_btn.modulate = Color(1.0, 0.85, 0.2)
		if cursor_material:
			cursor_material.albedo_color = Color(1.0, 0.8, 0.1, 0.45)

func _try_run_simulation() -> void:
	drag_builder.cancel_all()
	var result: Dictionary = AutomatonValidator.validate_path(
		grid_system.grid_data,
		grid_system.spawn_coords,
		grid_system.train_wagons
	)
	
	if result["accepted"]:
		is_simulating = true
		cursor_visual.visible = false
		var curve: Curve3D = AutomatonValidator.build_smooth_curve(result["path"], grid_system.cell_size)
		train.spawn_train(grid_system.train_wagons, curve)
		train.start_run()
	else:
		print("Não foi possível iniciar a viagem: ", result["reason"])

func _on_train_completed() -> void:
	print("🎉 FASE CONCLUÍDA: Todos os vagões foram entregues com sucesso!")
	await get_tree().create_timer(1.2).timeout
	_reset_simulation()

func _reset_simulation() -> void:
	is_simulating = false
	train.stop_run()
	for w in train.wagons:
		w.visible = false

func _update_hovered_cell() -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_end := ray_origin + camera.project_ray_normal(mouse_pos) * 100.0
	
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	
	if result:
		var hit_pos: Vector3 = result.position
		var coords := Vector2i(
			floori(hit_pos.x / grid_system.cell_size),
			floori(hit_pos.z / grid_system.cell_size)
		)
		if grid_system.is_inside_playable_grid(coords):
			hovered_coords = coords
			cursor_visual.visible = not is_simulating
			cursor_visual.position = grid_system.grid_to_world(coords) + Vector3(0, 0.02, 0)
			return
			
	hovered_coords = Vector2i(-999, -999)
	cursor_visual.visible = false

func _setup_board_collider() -> void:
	var total_w := grid_system.grid_size.x * grid_system.cell_size
	var total_h := grid_system.grid_size.y * grid_system.cell_size
	board_plane.position = Vector3(total_w * 0.5, 0.0, total_h * 0.5)
	
	var col_shape: CollisionShape3D = board_plane.get_node_or_null("CollisionShape3D")
	if col_shape and col_shape.shape is BoxShape3D:
		col_shape.shape.size = Vector3(total_w, 0.1, total_h)

func _setup_camera() -> void:
	var total_w := grid_system.grid_size.x * grid_system.cell_size
	var total_h := grid_system.grid_size.y * grid_system.cell_size
	var max_dim := maxf(total_w, total_h)
	var center_x := total_w * 0.5
	var center_z := total_h * 0.5
	
	camera.position = Vector3(center_x, max_dim * 1.15, center_z + (max_dim * 0.95))
	camera.look_at(Vector3(center_x, 0.0, center_z + (total_h * 0.12)), Vector3.UP)

func _create_cursor_highlight() -> void:
	cursor_visual = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(grid_system.cell_size * 0.96, 0.02, grid_system.cell_size * 0.96)
	
	cursor_material = StandardMaterial3D.new()
	cursor_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cursor_material.albedo_color = Color(0.2, 0.8, 1.0, 0.35)
	box.material = cursor_material
	
	cursor_visual.mesh = box
	cursor_visual.visible = false
	add_child(cursor_visual)
