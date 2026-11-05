class_name StationView
extends Node3D

## Parada rural sem cobertura: o centro da célula fica livre para o trem
## entrar e sair por qualquer lado; os detalhes ficam só nos cantos.
## - SymbolParts: pintado com a cor do símbolo (Trim* usa platform_color).
## - Deck: escurece quando a estação é fixa (travada).
## - Todo Label3D mostra o id do símbolo.

## Quanto o assoalho escurece quando a estação é fixa (travada).
@export_range(0.0, 1.0) var locked_darken: float = 0.45
## Opacidade do fantasma de colocação.
@export_range(0.1, 1.0) var ghost_alpha: float = 0.45

@onready var _symbol_parts: Node = get_node_or_null("SymbolParts")
@onready var _deck: Node = get_node_or_null("Deck")

var _base_scale := Vector3.ONE
var _pulse_tween: Tween
## Cor original de cada peça do assoalho (para escurecer e voltar).
var _deck_colors := {}


func _ready() -> void:
	_base_scale = scale # o GridBoard define a escala antes de adicionar à árvore
	for mesh in _meshes_in(_deck):
		var mat := mesh.get_active_material(0) as StandardMaterial3D
		_deck_colors[mesh] = mat.albedo_color if mat else Color.WHITE


## Pulso de leitura: cresce e volta, só por escala.
func pulse(factor := 1.2, duration := 0.25) -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	scale = _base_scale * factor
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(self, "scale", _base_scale, duration) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func apply(definition: SymbolDefinition, locked: bool) -> void:
	if not _has_parts():
		return
	var main_color := definition.color if definition else Color.MAGENTA
	var trim_color := definition.platform_color if definition else Color.MAGENTA
	var main_mat := _flat(main_color)
	var trim_mat := _flat(trim_color)
	for mesh in _meshes_in(_symbol_parts):
		mesh.material_override = trim_mat if String(mesh.name).begins_with("Trim") else main_mat

	for mesh in _meshes_in(_deck):
		mesh.material_override = _flat(_deck_colors[mesh].darkened(locked_darken)) if locked else null

	for label in _labels_in(self):
		label.text = String(definition.id) if definition else "?"
		label.visible = true


## Fantasma: a estrutura inteira numa só cor translúcida (verde = pode, vermelho = não pode).
func apply_ghost(tint: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(tint.r, tint.g, tint.b, ghost_alpha)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 0.35
	for mesh in _meshes_in(self):
		mesh.material_override = mat
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for label in _labels_in(self):
		label.visible = false # o símbolo ativo já aparece no botão do HUD


func _has_parts() -> bool:
	if _symbol_parts == null or _deck == null:
		push_error("Station.tscn precisa dos nós 'SymbolParts' e 'Deck'")
		return false
	return true


func _meshes_in(root: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if root == null:
		return found
	for child in root.get_children():
		if child is MeshInstance3D:
			found.append(child)
		found.append_array(_meshes_in(child))
	return found


func _labels_in(root: Node) -> Array[Label3D]:
	var found: Array[Label3D] = []
	for child in root.get_children():
		if child is Label3D:
			found.append(child)
		found.append_array(_labels_in(child))
	return found


func _flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	return mat
