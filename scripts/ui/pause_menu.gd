class_name PauseMenu
extends CanvasLayer

## Pausa da fase: congela a árvore (get_tree().paused) e mostra Retomar / Opções /
## Menu inicial em texto solto (visual do menu inicial) sobre um blur da própria cena.
## Roda com process_mode ALWAYS.
## Só pede: quem troca de cena é o LevelManager.

signal main_menu_requested
signal settings_changed

const OPTIONS_SCENE := preload("res://scenes/ui/OptionsMenu.tscn")
const BLUR_SHADER := preload("res://shaders/screen_blur.gdshader")

var _root: Control
var _blur: ColorRect
var _content: Control
var _options: OptionsMenu
var _tween: Tween


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.hide()


func is_open() -> bool:
	return _root.visible


func open() -> void:
	if is_open():
		return
	get_tree().paused = true
	_content.show()
	_options.hide()
	_root.show()
	_animate(1.0)


func resume() -> void:
	if not is_open():
		return
	_options.close()
	get_tree().paused = false
	_root.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open() or _options.visible:
		return # com Opções aberta, o Esc é dela (volta para a pausa)
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		resume()


func _animate(target: float) -> void:
	if _tween:
		_tween.kill()
	var mat := _blur.material as ShaderMaterial
	mat.set_shader_parameter("amount", 0.0)
	_content.modulate.a = 0.0
	_tween = create_tween().set_parallel()
	_tween.tween_method(func(v: float): mat.set_shader_parameter("amount", v), 0.0, target, 0.2)
	_tween.tween_property(_content, "modulate:a", 1.0, 0.2)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP # nada de clique na grid por trás
	add_child(_root)

	_blur = ColorRect.new()
	_blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = BLUR_SHADER
	# Véu um pouco mais forte que o padrão: sem cartão, o texto precisa de contraste.
	mat.set_shader_parameter("tint", Color(0.03, 0.09, 0.15, 0.6))
	_blur.material = mat
	_root.add_child(_blur)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)
	_content = column

	column.add_child(MenuStyle.heading("Pausado", 64))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	column.add_child(spacer)

	var resume_link := MenuStyle.link("Retomar")
	resume_link.pressed.connect(resume)
	column.add_child(resume_link)
	var options_link := MenuStyle.link("Opções")
	options_link.pressed.connect(_open_options)
	column.add_child(options_link)
	var menu_link := MenuStyle.link("Menu inicial")
	menu_link.pressed.connect(func():
		get_tree().paused = false
		main_menu_requested.emit())
	column.add_child(menu_link)

	var hint_gap := Control.new()
	hint_gap.custom_minimum_size = Vector2(0, 20)
	column.add_child(hint_gap)
	column.add_child(MenuStyle.heading("Esc para retomar", 16, MenuLink.DIM))

	_options = OPTIONS_SCENE.instantiate()
	_root.add_child(_options)
	_options.closed.connect(func(): _content.show())
	_options.settings_changed.connect(func(): settings_changed.emit())


func _open_options() -> void:
	_content.hide()
	_options.open()
