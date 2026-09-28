extends Node3D

# Se os seus nós tiverem exatamente esses nomes na cena, o @onready já pega sozinho:
@onready var camera: Camera3D = $Camera3D
@onready var grid_system: GridSystem = $GridSystem

var hovered_coords: Vector2i = Vector2i(-999, -999)
var cursor_visual: MeshInstance3D

func _ready() -> void:
	_create_cursor_highlight()

func _process(_delta: float) -> void:
	_update_hovered_cell()

func _unhandled_input(event: InputEvent) -> void:
	# Se o mouse não estiver sobre a grid 5x5, ignora cliques
	if not grid_system.is_inside_playable_grid(hovered_coords):
		return
		
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			grid_system.cycle_tile_type(hovered_coords)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			grid_system.rotate_tile(hovered_coords)

	# Atalho extra: Tecla 'R' também gira a peça sob o mouse
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		grid_system.rotate_tile(hovered_coords)

# Lança o Raycast da câmera até o BoardPlane e descobre a coordenada (X, Y)
func _update_hovered_cell() -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_end := ray_origin + camera.project_ray_normal(mouse_pos) * 100.0
	
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	
	if result:
		var hit_pos: Vector3 = result.position
		var gx := floori(hit_pos.x / grid_system.cell_size)
		var gy := floori(hit_pos.z / grid_system.cell_size)
		var coords := Vector2i(gx, gy)
		
		if grid_system.is_inside_playable_grid(coords):
			hovered_coords = coords
			cursor_visual.visible = true
			cursor_visual.position = grid_system.grid_to_world(coords) + Vector3(0, 0.02, 0)
			return
			
	# Se não acertou a área 5x5, esconde o cursor
	hovered_coords = Vector2i(-999, -999)
	cursor_visual.visible = false

# Cria um quadrado azul translúcido para mostrar onde o mouse está mirando
func _create_cursor_highlight() -> void:
	cursor_visual = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(grid_system.cell_size * 0.96, 0.02, grid_system.cell_size * 0.96)
	
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.8, 1.0, 0.35) # Azul claro transparente
	box.material = mat
	
	cursor_visual.mesh = box
	cursor_visual.visible = false
	add_child(cursor_visual)
