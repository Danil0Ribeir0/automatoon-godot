class_name ToolButton
extends Button

## Número do atalho mostrado na bolinha do canto superior direito.
@export var key_hint: String = "1"
## Mostra o quadradinho do símbolo no canto superior esquerdo.
@export var show_symbol_badge := false

@export_group("Estilo")
@export var font: Font
@export var font_size := 30
@export var corner_radius := 18
@export var badge_size := 34.0
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

var _key_badge: Panel
var _symbol_badge: Panel
var _symbol_label: Label
var _pulse: Tween


func _ready() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE # teclas não "clicam" o botão focado
	_apply_button_style()
	_key_badge = _make_badge(key_hint, true, true)[0]
	if show_symbol_badge:
		var parts := _make_badge("", false, false)
		_symbol_badge = parts[0]
		_symbol_label = parts[1]


## Disponível = clicável e colorido. Indisponível = acinzentado e travado.
func set_available(available: bool) -> void:
	disabled = not available
	var tint := Color.WHITE if available else Color(0.65, 0.65, 0.65)
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
	box.set_content_margin_all(16)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 4
	box.shadow_offset = Vector2(0, 3)
	return box


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

	var anchor := 1.0 if top_right else 0.0
	panel.anchor_left = anchor
	panel.anchor_right = anchor
	panel.offset_left = -s * 0.65 if top_right else -s * 0.35
	panel.offset_right = s * 0.35 if top_right else s * 0.65
	panel.offset_top = -s * 0.35
	panel.offset_bottom = s * 0.65
	panel.pivot_offset = Vector2(s, s) * 0.5

	var label := Label.new()
	label.text = text
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", badge_text_color)
	label.add_theme_font_size_override("font_size", int(s * 0.55))
	if font:
		label.add_theme_font_override("font", font)

	panel.add_child(label)
	add_child(panel)
	return [panel, label]
