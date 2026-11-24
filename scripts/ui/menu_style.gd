class_name MenuStyle
extends RefCounted

## Visual comum dos menus, para todos ficarem iguais.
## Minimalista (menu inicial, fases, pausa): heading() + link(), texto solto sobre o fundo.
## Cartão (opções): card() + label() + button().
const TOOL_BUTTON := preload("res://scenes/ui/ToolButton.tscn")
const CREAM := Color("f3e7b3")
const OUTLINE := Color("17345a")


## Título solto sobre o fundo, com sombra.
static func heading(text: String, font_size: int, color := CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	l.add_theme_constant_override("shadow_offset_y", 4)
	l.add_theme_constant_override("shadow_offset_x", 0)
	return l


## Opção em texto puro com trilho no hover (ver MenuLink).
static func link(text: String, font_size := 26) -> MenuLink:
	return MenuLink.new(text, font_size)


static func card(margin := 36) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.14, 0.23, 0.88)
	box.border_color = CREAM
	box.set_border_width_all(3)
	box.set_corner_radius_all(22)
	box.set_content_margin_all(margin)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 8
	panel.add_theme_stylebox_override("panel", box)
	return panel


static func label(text: String, font_size: int, color := CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 12)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	return l


static func button(text: String, key := "", width := 320.0) -> ToolButton:
	var b: ToolButton = TOOL_BUTTON.instantiate()
	b.text = text
	b.key_hint = key
	b.toggleable = false
	b.custom_minimum_size = Vector2(width, 70)
	return b
