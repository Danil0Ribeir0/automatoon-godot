extends Control

## Menu inicial minimalista: título e opções em texto direto sobre o fundo animado.
const LEVEL_SELECT := "res://scenes/menu/LevelSelect.tscn"
const OPTIONS_SCENE := preload("res://scenes/ui/OptionsMenu.tscn")

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

	column.add_child(MenuStyle.heading("automatoon", 76))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 28)
	column.add_child(spacer)

	var play := MenuStyle.link("Jogar")
	play.pressed.connect(_on_play)
	column.add_child(play)
	var options := MenuStyle.link("Opções")
	options.pressed.connect(_open_options)
	column.add_child(options)
	var quit := MenuStyle.link("Sair")
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

