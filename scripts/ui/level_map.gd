class_name LevelMap
extends Control

## Mapa de fases de um mundo: cada fase é uma estação numa linha em zigue-zague.
## Concluída = estado de aceitação (anel duplo) com as estrelas; bloqueada = cinza.

signal level_chosen(index: int)

@export var columns := 5
@export var node_size := 86.0
@export var spacing := Vector2(175, 165)
@export var rail_color := Color(0.85, 0.91, 0.96, 0.6)
@export var ring_color := Color("f3e7b3")
@export var star_on := Color("ffd23f")
@export var star_off := Color(1, 1, 1, 0.25)

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
		var unlocked := ProgressStore.is_unlocked(world.id, i)
		_done.append(best > 0)
		var button := _make_node(i, unlocked, best)
		add_child(button)
		_buttons.append(button)
		var stars := Label.new()
		stars.text = "★".repeat(best) + "☆".repeat(3 - best) if unlocked else ""
		stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stars.add_theme_font_size_override("font_size", 22)
		stars.add_theme_color_override("font_color", star_on if best > 0 else star_off)
		stars.add_theme_constant_override("outline_size", 6)
		stars.add_theme_color_override("font_outline_color", Color("17345a"))
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
		_stars[i].position = points[i] + Vector2(-(node_size + 40) * 0.5, node_size * 0.5 + 4)
	queue_redraw()


func _draw() -> void:
	var points := _positions()
	for i in range(points.size() - 1):
		RailSketch.draw_rail(self, PackedVector2Array([points[i], points[i + 1]]), rail_color, 5.0, 13.0, 2.0)
	for i in points.size():
		if i < _done.size() and _done[i]:
			draw_arc(points[i], node_size * 0.5 + 9.0, 0, TAU, 48, ring_color, 3.0, true)


func _make_node(index: int, unlocked: bool, best: int) -> Button:
	var button := Button.new()
	button.text = str(index + 1)
	button.custom_minimum_size = Vector2.ONE * node_size
	button.size = Vector2.ONE * node_size
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not unlocked
	button.tooltip_text = _world.levels[index].title if unlocked else "Conclua a fase anterior"
	var fill := Color("2f7fd0") if best == 0 else Color("2c9a5a")
	button.add_theme_stylebox_override("normal", _circle(fill, ring_color))
	button.add_theme_stylebox_override("hover", _circle(fill.lightened(0.15), Color.WHITE))
	button.add_theme_stylebox_override("pressed", _circle(fill.darkened(0.1), Color.WHITE))
	button.add_theme_stylebox_override("disabled", _circle(Color("4b5563"), Color("7b8494")))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_size_override("font_size", 34)
	button.add_theme_constant_override("outline_size", 8)
	button.add_theme_color_override("font_outline_color", Color("17345a"))
	button.add_theme_color_override("font_disabled_color", Color(0.75, 0.75, 0.78))
	button.pressed.connect(func(): level_chosen.emit(index))
	return button


func _circle(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(4)
	box.set_corner_radius_all(int(node_size * 0.5))
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 5
	box.shadow_offset = Vector2(0, 3)
	return box
