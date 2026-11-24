class_name MenuLink
extends Button

## Opção de menu em texto puro: o visual minimalista de todos os menus.
## No hover o texto acende e um trilho creme cresce embaixo; `selected` mantém
## o trilho aceso (ex.: a aba do mundo escolhido).

const CREAM := Color("f3e7b3")
const SOFT := Color(0.85, 0.91, 0.96, 0.7)
const DIM := Color(0.85, 0.91, 0.96, 0.28)

var selected := false:
	set(value):
		selected = value
		_refresh()

var _rail := ColorRect.new()
var _hovered := false
var _tween: Tween


func _init(label := "", font_size := 26) -> void:
	text = label
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(180, 46)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_theme_font_size_override("font_size", font_size)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	add_theme_color_override("font_hover_color", CREAM)
	add_theme_color_override("font_pressed_color", Color.WHITE)
	add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	add_theme_color_override("font_disabled_color", DIM)

	_rail.color = CREAM
	_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rail.anchor_left = 0.3
	_rail.anchor_right = 0.7
	_rail.anchor_top = 1.0
	_rail.anchor_bottom = 1.0
	_rail.offset_top = -6.0
	_rail.offset_bottom = -3.0
	add_child(_rail)
	_rail.resized.connect(func(): _rail.pivot_offset = _rail.size * 0.5)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	_refresh()


## Liga/desliga a opção (desligada fica apagada e sem cursor de mão).
func set_available(on: bool) -> void:
	disabled = not on
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if on else Control.CURSOR_ARROW
	_refresh()


func _set_hovered(on: bool) -> void:
	_hovered = on
	_refresh()


func _refresh() -> void:
	add_theme_color_override("font_color", CREAM if selected else SOFT)
	var target := 1.0 if selected or (_hovered and not disabled) else 0.0
	if _tween:
		_tween.kill()
	if not is_inside_tree():
		_rail.scale.x = target
		return
	_tween = create_tween()
	_tween.tween_property(_rail, "scale:x", target, 0.22) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
