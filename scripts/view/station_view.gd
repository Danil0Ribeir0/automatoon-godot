class_name StationView
extends Node3D

## Quanto a plataforma escurece quando a estação é fixa (travada).
@export_range(0.0, 1.0) var locked_darken: float = 0.45
## Opacidade do fantasma de colocação.
@export_range(0.1, 1.0) var ghost_alpha: float = 0.5

@onready var _platform: MeshInstance3D = get_node_or_null("Platform")
@onready var _marker: MeshInstance3D = get_node_or_null("Marker")


func apply(definition: SymbolDefinition, locked: bool) -> void:
	if not _has_parts():
		return
	var marker_color := definition.color if definition else Color.MAGENTA
	var platform_color := definition.platform_color if definition else Color.MAGENTA
	if locked:
		platform_color = platform_color.darkened(locked_darken)
	_marker.material_override = _flat(marker_color)
	_platform.material_override = _flat(platform_color)


## Fantasma: estrutura inteira numa só cor semitransparente.
func apply_ghost(tint: Color) -> void:
	if not _has_parts():
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(tint.r, tint.g, tint.b, ghost_alpha)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_platform.material_override = mat
	_marker.material_override = mat


func _has_parts() -> bool:
	if _platform == null or _marker == null:
		push_error("Station.tscn precisa ter os filhos diretos 'Platform' e 'Marker' (MeshInstance3D)")
		return false
	return true


func _flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat
