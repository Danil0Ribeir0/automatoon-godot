class_name ToolButton
extends Button

## Número do atalho mostrado na bolinha do canto superior direito.
@export var key_hint: String = "1"
## Mostra o quadradinho do símbolo no canto superior esquerdo.
@export var show_symbol_badge := false
## false = botão de ação (não fica pressionado). Ex.: "Partir".
@export var toggleable := true

@export_group("Estilo")
@export var font: Font
@export var font_size := 26
@export var corner_radius := 16
## Espaço entre a borda e o texto/ícone.
@export var content_margin := 10
@export var badge_size := 28.0
@export var fill_color := Color("2f7fd0")
@export var fill_active_color := Color("3d9bf5")
@export var border_color := Color("f3e7b3")
@export var border_active_color := Color.WHITE
@export var disabled_fill_color := Color("6b6f78")
@export var disabled_border_color := Color("9a9ea6")
@export var text_outline_color := Color("17345a")
@export var badge_text_color := Color("1b1b1b")

@export_group("Pulso")
@export var pulse_scale := 1.35
@export var pulse_duration := 0.22

@export_group("Modelo 3D")
## Se definido, o modelo é renderizado e usado como ícone do botão (apague o Text).
@export var icon_model: PackedScene
## Giro do modelo em torno do próprio eixo vertical (graus). 90 = trilho na horizontal.
@export var model_yaw := 90.0
## Inclinação em direção à câmera (graus). 90 = visto de cima, 0 = visto de lado.
@export var model_tilt := 55.0
## Resolução da imagem renderizada. A proporção define o formato do ícone.
@export var model_render_size := Vector2i(320, 120)
## Folga em volta do modelo (1.0 = encostado na borda).
@export var model_padding := 1.1
## Esconde textos 3D (Label3D) do modelo, ex.: o "?" da estação.
@export var model_hide_labels := true

var _key_badge: Panel
var _icon_model_instance: Node3D
var _symbol_badge: Panel
var _symbol_label: Label
var _pulse: Tween


func _ready() -> void:
	toggle_mode = toggleable
	focus_mode = Control.FOCUS_NONE # teclas não "clicam" o botão focado
	_apply_button_style()
	if icon_model:
		_setup_model_icon()
	if not key_hint.is_empty(): # sem atalho = sem bolinha
		_key_badge = _make_badge(key_hint, true, true)[0]
	if show_symbol_badge:
		var parts := _make_badge("", false, false)
		_symbol_badge = parts[0]
		_symbol_label = parts[1]


## Disponível = clicável e colorido. Indisponível = acinzentado e travado.
func set_available(available: bool) -> void:
	disabled = not available
	var tint := Color.WHITE if available else Color(0.65, 0.65, 0.65)
	if _key_badge:
		_key_badge.modulate = tint
	if _symbol_badge:
		_symbol_badge.modulate = tint


## Atualiza o quadradinho do símbolo. Só pulsa quando o símbolo muda de fato.
func set_symbol(text: String, animate: bool) -> void:
	if _symbol_label == null or _symbol_label.text == text:
		return
	_symbol_label.text = text
	if animate:
		_play_pulse()


func _play_pulse() -> void:
	if _pulse:
		_pulse.kill()
	_symbol_badge.scale = Vector2.ONE * pulse_scale
	_pulse = create_tween()
	_pulse.tween_property(_symbol_badge, "scale", Vector2.ONE, pulse_duration) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Construção visual ------------------------------------------------------

func _apply_button_style() -> void:
	var normal := _make_box(fill_color, border_color)
	var active := _make_box(fill_active_color, border_active_color)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", active)
	add_theme_stylebox_override("pressed", active)
	add_theme_stylebox_override("hover_pressed", active)
	add_theme_stylebox_override("disabled", _make_box(disabled_fill_color, disabled_border_color))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	if font:
		add_theme_font_override("font", font)
	add_theme_font_size_override("font_size", font_size)
	add_theme_constant_override("outline_size", 8)
	add_theme_color_override("font_outline_color", text_outline_color)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		add_theme_color_override(state, Color.WHITE)
	add_theme_color_override("font_disabled_color", Color(0.85, 0.85, 0.85))


func _make_box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(4)
	box.set_corner_radius_all(corner_radius)
	box.set_content_margin_all(content_margin)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 4
	box.shadow_offset = Vector2(0, 3)
	return box


## Instância do icon_model renderizada no botão (null se não houver).
## Mexer nela (ex.: cor) atualiza o ícone na hora.
func get_icon_model() -> Node3D:
	return _icon_model_instance


## Renderiza icon_model num mundo 3D próprio e usa a imagem como ícone do botão.
func _setup_model_icon() -> void:
	var viewport := SubViewport.new()
	viewport.size = model_render_size
	viewport.transparent_bg = true
	viewport.own_world_3d = true # não enxerga o tabuleiro do jogo
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.6
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	viewport.add_child(light)

	# tilt (inclina pra câmera) > yaw (gira no chão) > modelo centralizado
	var tilt := Node3D.new()
	tilt.rotation_degrees.x = model_tilt
	viewport.add_child(tilt)
	var yaw := Node3D.new()
	yaw.rotation_degrees.y = model_yaw
	tilt.add_child(yaw)
	var model: Node3D = icon_model.instantiate()
	yaw.add_child(model)
	_icon_model_instance = model
	if model_hide_labels:
		for label in model.find_children("*", "Label3D", true, false):
			label.queue_free() # sai também do cálculo de enquadramento abaixo
			label.get_parent().remove_child(label)

	var bounds := _local_bounds(model)
	model.position = -bounds.get_center()

	# Enquadra: caixa do modelo já girada, projetada no plano da câmera.
	var to_view := tilt.transform * yaw.transform
	var min_v := Vector2(INF, INF)
	var max_v := Vector2(-INF, -INF)
	var centered := AABB(bounds.position - bounds.get_center(), bounds.size)
	for i in 8:
		var p := to_view * centered.get_endpoint(i)
		min_v = min_v.min(Vector2(p.x, p.y))
		max_v = max_v.max(Vector2(p.x, p.y))
	var extent := max_v - min_v
	var aspect := float(model_render_size.x) / model_render_size.y

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(extent.y, extent.x / aspect) * model_padding # altura visível
	camera.position = Vector3((min_v.x + max_v.x) * 0.5, (min_v.y + max_v.y) * 0.5, 10.0)
	viewport.add_child(camera)
	camera.make_current()

	icon = viewport.get_texture()
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER


## Caixa que envolve todas as malhas do modelo, no espaço local dele.
func _local_bounds(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var inv := root.global_transform.affine_inverse()
	for node in root.find_children("*", "VisualInstance3D", true, false):
		var vi := node as VisualInstance3D
		var box: AABB = (inv * vi.global_transform) * vi.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


## Retorna [Panel, Label]. A bolinha "vaza" para fora do canto do botão.
func _make_badge(text: String, top_right: bool, round: bool) -> Array:
	var s := badge_size
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box := StyleBoxFlat.new()
	box.bg_color = Color.WHITE
	box.border_color = text_outline_color
	box.set_border_width_all(2)
	box.set_corner_radius_all(int(s * 0.5) if round else 6)
	panel.add_theme_stylebox_override("panel", box)

	# Texto de 1 letra = bolinha redonda. Texto maior (ex.: "Espaço") = pílula
	# que cresce para dentro do botão, com fonte um pouco menor.
	var font_px := int(s * 0.55) if text.length() <= 1 else int(s * 0.45)
	var used_font: Font = font if font else ThemeDB.fallback_font
	var w := maxf(s, used_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x + s * 0.6)

	var anchor := 1.0 if top_right else 0.0
	panel.anchor_left = anchor
	panel.anchor_right = anchor
	panel.offset_left = -(w - s * 0.35) if top_right else -s * 0.35
	panel.offset_right = s * 0.35 if top_right else w - s * 0.35
	panel.offset_top = -s * 0.35
	panel.offset_bottom = s * 0.65
	panel.pivot_offset = Vector2(w, s) * 0.5

	var label := Label.new()
	label.text = text
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", badge_text_color)
	label.add_theme_font_size_override("font_size", font_px)
	if font:
		label.add_theme_font_override("font", font)

	panel.add_child(label)
	add_child(panel)
	return [panel, label]
