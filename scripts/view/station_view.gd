class_name StationView
extends Node3D

@export var platform_color := Color(0.85, 0.85, 0.85)
@export var locked_platform_color := Color(0.4, 0.4, 0.45)

@onready var _platform: MeshInstance3D = $Platform
@onready var _marker: MeshInstance3D = $Marker


func apply(definition: SymbolDefinition, locked: bool) -> void:
	_marker.material_override = _flat(definition.color if definition else Color.MAGENTA)
	_platform.material_override = _flat(locked_platform_color if locked else platform_color)


func _flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat
