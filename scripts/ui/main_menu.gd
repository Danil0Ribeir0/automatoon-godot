extends Control

## Menu inicial minimalista: título e opções em texto direto sobre o fundo animado.
const LEVEL_SELECT := "res://scenes/menu/LevelSelect.tscn"
const OPTIONS_SCENE := preload("res://scenes/ui/OptionsMenu.tscn")
const CREAM := Color("f3e7b3")
const SOFT := Color(0.85, 0.91, 0.96, 0.7)

var _menu: Control
var _options: OptionsMenu


func _ready() -> void:
	GameSettings.ensure_loaded()
	_menu = CenterContainer.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_menu)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_menu.add_child(column)

	column.add_child(_label("automatoon", 76, CREAM))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 28)
	column.add_child(spacer)

	var play := _link("Jogar")
	play.pressed.connect(_on_play)
	column.add_child(play)
	var options := _link("Opções")
	options.pressed.connect(_open_options)
	column.add_child(options)
	var quit := _link("Sair")
	quit.pressed.connect(func(): get_tree().quit())
	column.add_child(quit)

	_options = OPTIONS_SCENE.instantiate()
	add_child(_options)
	_options.closed.connect(func(): _menu.show())
	_play_intro(column)


func _unhandled_input(event: InputEvent) -> void:
	if _options.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_on_play()


func _on_play() -> void:
	get_tree().change_scene_to_file(LEVEL_SELECT)


func _open_options() -> void:
	_menu.hide()
	_options.open()


## Entrada: cada linha aparece em sequência, subindo um pouco.
func _play_intro(column: Control) -> void:
	var tween := create_tween().set_parallel()
	var i := 0
	for child in column.get_children():
		if not child is CanvasItem:
			continue
		child.modulate.a = 0.0
		tween.tween_property(child, "modulate:a", 1.0, 0.6).set_delay(0.12 * i) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		i += 1
	_menu.position.y = 18.0
	tween.tween_property(_menu, "position:y", 0.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	label.add_theme_constant_override("shadow_offset_y", 4)
	label.add_theme_constant_override("shadow_offset_x", 0)
	return label


## Opção em texto puro. No hover, o texto acende e um trilho creme cresce embaixo.
func _link(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(180, 46)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 26)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", SOFT)
	button.add_theme_color_override("font_hover_color", CREAM)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_hover_pressed_color", Color.WHITE)

	var rail := ColorRect.new()
	rail.color = CREAM
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.anchor_left = 0.3
	rail.anchor_right = 0.7
	rail.anchor_top = 1.0
	rail.anchor_bottom = 1.0
	rail.offset_top = -6.0
	rail.offset_bottom = -3.0
	rail.scale.x = 0.0
	button.add_child(rail)
	rail.resized.connect(func(): rail.pivot_offset = rail.size * 0.5)

	var anim := [null]
	var slide := func(to: float) -> void:
		if anim[0]:
			anim[0].kill()
		anim[0] = button.create_tween()
		anim[0].tween_property(rail, "scale:x", to, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	button.mouse_entered.connect(slide.bind(1.0))
	button.mouse_exited.connect(slide.bind(0.0))
	return button
