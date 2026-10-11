extends Node3D

@export var level: LevelData

@export_group("Camera")
@export_range(30.0, 80.0) var camera_pitch_degrees: float = 55.0
@export_range(20.0, 70.0) var camera_fov: float = 45.0
@export_range(1.0, 2.0) var camera_fit_margin: float = 1.25

@onready var _board: GridBoard = $GridBoard
@onready var _camera: Camera3D = $Camera3D
@onready var _input: InputController = $InputController

var _model: GridModel
var _builder: RailBuilder


func _ready() -> void:
	_model = GridModel.new(level.grid_size, level.get_spawn_cell(), level.get_exit_cell())
	_board.setup(_model)

	_builder = RailBuilder.new(_model)
	_input.build_started.connect(_builder.begin_build)
	_input.erase_started.connect(_builder.begin_erase)
	_input.cursor_moved.connect(_builder.move_to)
	_input.stroke_ended.connect(_builder.end_stroke)

	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()


func _fit_camera() -> void:
	var extent := maxf(level.grid_size.x + 2, level.grid_size.y) * _board.cell_size
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
