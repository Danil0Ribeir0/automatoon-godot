class_name LevelCompletePanel
extends CanvasLayer

## Tela de fase concluída: estrelas, trilhos usados/meta, melhor resultado,
## Repetir [R] e Próxima [Espaço/Enter, as mesmas teclas do Partir].
## Só pede; quem troca de fase é o LevelManager.

signal retry_requested
signal next_requested
signal menu_requested

const TOOL_BUTTON := preload("res://scenes/ui/ToolButton.tscn")
const STAR_ON := Color("ffd23f")
const STAR_OFF := Color(1, 1, 1, 0.25)

var _root: Control
var _title: Label
var _stars: Array[Label] = []
var _rails_count: Label
var _rails_par: Label
var _best: Label
var _retry: ToolButton
var _next: ToolButton
var _menu: ToolButton
var _tween: Tween


func _ready() -> void:
	layer = 10
	_build()
	hide_panel()


func show_result(stars: int, rails: int, par: int, best: int, is_last: bool) -> void:
	_title.text = "Mundo concluído!" if is_last else "Fase concluída!"
	# Mesmo formato do HUD: "usados / meta", na cor das estrelas.
	_rails_count.text = str(rails)
	_rails_count.add_theme_color_override("font_color", HUD.rails_color(rails, par))
	_rails_par.text = "/ %d" % par
	_rails_par.visible = par > 0
	_best.text = "Recorde: " + "★".repeat(best) + "☆".repeat(3 - best)
	_next.visible = not is_last
	_root.visible = true

	if _tween:
		_tween.kill()
	_tween = create_tween()
	for i in _stars.size():
		var star := _stars[i]
		star.pivot_offset = star.size * 0.5
		star.add_theme_color_override("font_color", STAR_ON if i < stars else STAR_OFF)
		star.scale = Vector2.ZERO if i < stars else Vector2.ONE
		if i < stars:
			_tween.tween_property(star, "scale", Vector2.ONE, 0.25) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func is_open() -> bool:
	return _root != null and _root.visible


func hide_panel() -> void:
	if _root:
		_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible or not event is InputEventKey:
		return
	if event.pressed and not event.echo and event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		next_requested.emit()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP # bloqueia cliques na grid
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("2f7fd0")
	box.border_color = Color("f3e7b3")
	box.set_border_width_all(4)
	box.set_corner_radius_all(18)
	box.set_content_margin_all(32)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 6
	panel.add_theme_stylebox_override("panel", box)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)

	_title = _label(40)
	column.add_child(_title)

	var star_row := HBoxContainer.new()
	star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	star_row.add_theme_constant_override("separation", 14)
	for i in 3:
		var star := _label(64)
		star.text = "★"
		_stars.append(star)
		star_row.add_child(star)
	column.add_child(star_row)

	var rails_block := VBoxContainer.new()
	rails_block.add_theme_constant_override("separation", 0)
	var caption := _label(18)
	caption.text = "TRILHOS"
	caption.add_theme_color_override("font_color", Color("f3e7b3"))
	rails_block.add_child(caption)
	var rails_row := HBoxContainer.new()
	rails_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rails_row.add_theme_constant_override("separation", 8)
	_rails_count = _label(44)
	rails_row.add_child(_rails_count)
	_rails_par = _label(28)
	_rails_par.add_theme_color_override("font_color", Color("f3e7b3"))
	_rails_par.size_flags_vertical = Control.SIZE_SHRINK_END # apoia na base do número
	rails_row.add_child(_rails_par)
	rails_block.add_child(rails_row)
	column.add_child(rails_block)

	_best = _label(20)
	_best.add_theme_color_override("font_color", Color("f3e7b3"))
	column.add_child(_best)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 40)
	_menu = _button("Fases", "Esc")
	_retry = _button("Repetir", "R")
	_next = _button("Próxima", "Espaço")
	buttons.add_child(_menu)
	buttons.add_child(_retry)
	buttons.add_child(_next)
	_menu.pressed.connect(func(): menu_requested.emit())
	column.add_child(buttons)
	_retry.pressed.connect(func(): retry_requested.emit())
	_next.pressed.connect(func(): next_requested.emit())


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 10)
	label.add_theme_color_override("font_outline_color", Color("17345a"))
	return label


func _button(text: String, key: String) -> ToolButton:
	var button: ToolButton = TOOL_BUTTON.instantiate()
	button.text = text
	button.key_hint = key
	button.toggleable = false
	return button
