extends Node3D

@export var level: LevelData

@export_group("Camera")
@export_range(30.0, 80.0) var camera_pitch_degrees: float = 55.0
@export_range(20.0, 70.0) var camera_fov: float = 45.0
@export_range(1.0, 2.0) var camera_fit_margin: float = 1.25

@onready var _board: GridBoard = $GridBoard
@onready var _camera: Camera3D = $Camera3D
@onready var _picker: GridPicker = $GridPicker

var _model: GridModel


func _ready() -> void:
	_model = GridModel.new(level.grid_size)
	_board.setup(_model)
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()


func _fit_camera() -> void:
	var extent := maxf(level.grid_size.x, level.grid_size.y) * _board.cell_size
	var pitch := deg_to_rad(camera_pitch_degrees)
	var vfov := deg_to_rad(camera_fov)
	var aspect := get_viewport().get_visible_rect().size.aspect()
	var hfov := 2.0 * atan(tan(vfov * 0.5) * aspect)

	var half := extent * 0.5 * camera_fit_margin
	var distance := maxf(half / tan(hfov * 0.5), half / tan(vfov * 0.5))

	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = camera_fov
	_camera.rotation = Vector3(-pitch, 0.0, 0.0)
	_camera.position = Vector3(0.0, sin(pitch), cos(pitch)) * distance


# TEMPORÁRIO: validação do raycast.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var cell := _picker.cell_at_screen(event.position)
		if cell != GridBoard.NO_CELL:
			print("Célula: ", cell)
