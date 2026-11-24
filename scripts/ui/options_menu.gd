class_name OptionsMenu
extends Control

## Tela de opções, usada no menu inicial e na pausa. Só mexe em GameSettings;
## quem precisa reagir (ex.: sombras da fase) escuta `settings_changed`.

signal closed
signal settings_changed

var _volume: HSlider
var _volume_label: Label
var _fullscreen: Button
var _vsync: Button
var _shadows: Button
var _syncing := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP # bloqueia o que está atrás
	_build()
	hide()


func open() -> void:
	GameSettings.ensure_loaded()
	_syncing = true
	_volume.value = round(GameSettings.master_volume * 100.0)
	_fullscreen.button_pressed = GameSettings.fullscreen
	_vsync.button_pressed = GameSettings.vsync
	_shadows.button_pressed = GameSettings.shadows
	_syncing = false
	_update_volume_label()
	show()


func close() -> void:
	if not visible:
		return
	GameSettings.save()
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.3)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := MenuStyle.card()
	center.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	card.add_child(column)
	column.add_child(MenuStyle.label("Opções", 48))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 16)
	column.add_child(grid)

	grid.add_child(_row_label("Volume geral"))
	var volume_box := HBoxContainer.new()
	volume_box.add_theme_constant_override("separation", 12)
	_volume = HSlider.new()
	_volume.min_value = 0
	_volume.max_value = 100
	_volume.step = 5
	_volume.custom_minimum_size = Vector2(240, 32)
	_style_slider(_volume)
	_volume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_volume.value_changed.connect(_on_volume)
	volume_box.add_child(_volume)
	_volume_label = MenuStyle.label("80%", 22, Color.WHITE)
	_volume_label.custom_minimum_size = Vector2(64, 0)
	volume_box.add_child(_volume_label)
	grid.add_child(volume_box)

	grid.add_child(_row_label("Tela cheia"))
	_fullscreen = _toggle(func(on: bool): GameSettings.fullscreen = on)
	grid.add_child(_fullscreen)
	grid.add_child(_row_label("Sincronização vertical"))
	_vsync = _toggle(func(on: bool): GameSettings.vsync = on)
	grid.add_child(_vsync)
	grid.add_child(_row_label("Sombras"))
	_shadows = _toggle(func(on: bool): GameSettings.shadows = on)
	grid.add_child(_shadows)

	var back := MenuStyle.button("Voltar", "Esc", 260)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(close)
	column.add_child(back)


func _row_label(text: String) -> Label:
	var l := MenuStyle.label(text, 26, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l


## Interruptor "Ligado / Desligado" no visual dos botões do jogo.
func _toggle(setter: Callable) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(170, 46)
	b.add_theme_font_size_override("font_size", 22)
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		var on: bool = state.contains("pressed")
		var box := StyleBoxFlat.new()
		box.bg_color = Color("2f7fd0") if on else Color(0.18, 0.24, 0.3)
		if state.begins_with("hover"):
			box.bg_color = box.bg_color.lightened(0.12)
		box.border_color = MenuStyle.CREAM if on else Color(0.45, 0.5, 0.55)
		box.set_border_width_all(2)
		box.set_corner_radius_all(12)
		b.add_theme_stylebox_override(state, box)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(color_name, Color.WHITE)
	b.toggled.connect(func(on: bool):
		b.text = "Ligado" if on else "Desligado"
		if _syncing:
			return
		setter.call(on)
		_changed())
	b.text = "Desligado"
	return b


func _style_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.18, 0.24, 0.3)
	track.set_corner_radius_all(6)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	slider.add_theme_stylebox_override("slider", track)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = Color("3d9bf5")
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := GradientTexture2D.new() # bolinha creme desenhada por gradiente radial
	knob.width = 26
	knob.height = 26
	knob.fill = GradientTexture2D.FILL_RADIAL
	knob.fill_from = Vector2(0.5, 0.5)
	knob.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.8, 0.86])
	g.colors = PackedColorArray([MenuStyle.CREAM, MenuStyle.CREAM, Color(MenuStyle.CREAM, 0.0)])
	knob.gradient = g
	slider.add_theme_icon_override("grabber", knob)
	slider.add_theme_icon_override("grabber_highlight", knob)


func _on_volume(value: float) -> void:
	_update_volume_label()
	if _syncing:
		return
	GameSettings.master_volume = value / 100.0
	_changed()


func _update_volume_label() -> void:
	_volume_label.text = "%d%%" % int(_volume.value)


func _changed() -> void:
	GameSettings.apply()
	settings_changed.emit()
