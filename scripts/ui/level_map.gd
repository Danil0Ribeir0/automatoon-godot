class_name LevelMap
extends Control

## Mapa de fases de um mundo: cada fase é uma estação numa linha em zigue-zague.
## Visual minimalista: estados só em contorno. Concluída = estado de aceitação
## (anel duplo, creme) com as estrelas; bloqueada = contorno apagado.

signal level_chosen(index: int)

@export var columns := 5
@export var node_size := 72.0
@export var spacing := Vector2(170, 155)
@export var rail_color := Color(0.85, 0.91, 0.96, 0.3)
@export var ring_color := MenuLink.CREAM
@export var soft_color := MenuLink.SOFT
@export var locked_color := MenuLink.DIM
@export var fill_color := Color(0.05, 0.14, 0.23, 0.45)

var _world: WorldData
var _buttons: Array[Button] = []
var _stars: Array[Label] = []
var _done: Array[bool] = []


func _ready() -> void:
	resized.connect(_layout)


func show_world(world: WorldData) -> void:
	_world = world
	for child in get_children():
		child.queue_free()
	_buttons.clear()
	_stars.clear()
	_done.clear()
	for i in world.levels.size():
		var best := ProgressStore.best_stars(world.id, i)
		var unlocked := ProgressStore.is_unlocked(world, i)
		_done.append(best > 0)
		var button := _make_node(i, unlocked, best)
		add_child(button)
		_buttons.append(button)
		var stars := Label.new()
		stars.text = "★".repeat(best) + "☆".repeat(3 - best) if unlocked else ""
		stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stars.add_theme_font_size_override("font_size", 16)
		stars.add_theme_color_override("font_color", ring_color if best > 0 else locked_color)
		stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(stars)
		_stars.append(stars)
	_layout()


func _positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	if _world == null:
		return result
	var count := _world.levels.size()
	var rows := ceili(count / float(columns))
	var used := Vector2((mini(count, columns) - 1) * spacing.x, (rows - 1) * spacing.y)
	var origin := (size - used) * 0.5
	for i in count:
		var row := i / columns
		var col := i % columns
		if row % 2 == 1:
			col = columns - 1 - col # zigue-zague, como uma linha de trem
		result.append(origin + Vector2(col * spacing.x, row * spacing.y))
	return result


func _layout() -> void:
	var points := _positions()
	for i in _buttons.size():
		_buttons[i].position = points[i] - Vector2.ONE * node_size * 0.5
		_stars[i].size = Vector2(node_size + 40, 30)
		_stars[i].position = points[i] + Vector2(-(node_size + 40) * 0.5, node_size * 0.5 + 10)
	queue_redraw()


func _draw() -> void:
	var points := _positions()
	for i in range(points.size() - 1):
		RailSketch.draw_rail(self, PackedVector2Array([points[i], points[i + 1]]), rail_color, 4.0, 13.0, 1.5)
	for i in points.size():
		if i < _done.size() and _done[i]:
			draw_arc(points[i], node_size * 0.5 + 7.0, 0, TAU, 48, ring_color, 2.0, true)


func _make_node(index: int, unlocked: bool, best: int) -> Button:
	var done := best > 0
	var tone := ring_color if done else soft_color
	var button := Button.new()
	button.text = str(index + 1)
	button.custom_minimum_size = Vector2.ONE * node_size
	button.size = Vector2.ONE * node_size
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not unlocked
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if unlocked else Control.CURSOR_ARROW
	button.tooltip_text = _world.levels[index].title if unlocked \
			else "Conclua a fase %d" % (_world.required_level(index) + 1)
	button.add_theme_stylebox_override("normal", _circle(fill_color, tone))
	button.add_theme_stylebox_override("hover", _circle(Color(fill_color, 0.75), Color.WHITE))
	button.add_theme_stylebox_override("pressed", _circle(fill_color.darkened(0.3), Color.WHITE))
	button.add_theme_stylebox_override("disabled", _circle(Color(fill_color, 0.15), locked_color))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_color_override("font_color", tone)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", locked_color)
	button.pressed.connect(func(): level_chosen.emit(index))
	return button


func _circle(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(int(node_size * 0.5))
	box.anti_aliasing = true
	return box
