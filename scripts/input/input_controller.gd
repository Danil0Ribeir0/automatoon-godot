class_name InputController
extends Node

signal primary_pressed(cell: Vector2i)
signal secondary_pressed(cell: Vector2i)
signal cursor_moved(cell: Vector2i)
signal released

## O mouse mudou de célula SEM botão pressionado. Também é emitido ao soltar
## um botão, para o preview reaparecer já atualizado.
signal hover_changed(cell: Vector2i)

signal rail_tool_requested
signal station_tool_requested
signal switch_tool_requested
## +1 = próximo símbolo, -1 = anterior.
signal symbol_scrolled(step: int)
signal test_requested
signal restart_requested

@export var picker: GridPicker
## Quanto o trackpad precisa rolar (dois dedos) para trocar um símbolo.
@export var pan_step := 1.0

var _pan_accum := 0.0
var _active_button := MOUSE_BUTTON_NONE
var _last_cell := GridPicker.NO_CELL
var _hover_cell := GridPicker.NO_CELL


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		_handle_key(event)
	elif event is InputEventMouseButton:
		_handle_button(event)
	elif event is InputEventPanGesture:
		_handle_pan(event)
	elif event is InputEventMouseMotion:
		if _active_button == MOUSE_BUTTON_NONE:
			_update_hover(event.position)
		else:
			var cell := picker.cell_at_screen(event.position)
			if cell != GridPicker.NO_CELL and cell != _last_cell:
				_last_cell = cell
				cursor_moved.emit(cell)


func _update_hover(screen_pos: Vector2) -> void:
	var cell := picker.cell_at_screen(screen_pos)
	if cell != _hover_cell:
		_hover_cell = cell
		hover_changed.emit(cell)


func _handle_key(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_1:
			rail_tool_requested.emit()
		KEY_2:
			station_tool_requested.emit()
		KEY_3:
			switch_tool_requested.emit()
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER: # Espaço é o principal; Enter por instinto
			test_requested.emit()
		KEY_R:
			restart_requested.emit()


## Trackpad do Mac: rolar com dois dedos chega como gesto, não como roda do mouse.
## Acumula o deslocamento e troca um símbolo a cada pan_step.
func _handle_pan(event: InputEventPanGesture) -> void:
	if _active_button != MOUSE_BUTTON_NONE:
		return
	_pan_accum += event.delta.y
	while absf(_pan_accum) >= pan_step:
		var step := 1 if _pan_accum > 0 else -1
		_pan_accum -= step * pan_step
		symbol_scrolled.emit(step)


func _handle_button(event: InputEventMouseButton) -> void:
	if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if event.pressed and _active_button == MOUSE_BUTTON_NONE:
			symbol_scrolled.emit(1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
		return

	if event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return
	if event.pressed and _active_button == MOUSE_BUTTON_NONE:
		var cell := picker.cell_at_screen(event.position)
		if cell == GridPicker.NO_CELL:
			return
		_active_button = event.button_index
		_last_cell = cell
		if _active_button == MOUSE_BUTTON_LEFT:
			primary_pressed.emit(cell)
		else:
			secondary_pressed.emit(cell)
	elif not event.pressed and event.button_index == _active_button:
		_active_button = MOUSE_BUTTON_NONE
		_last_cell = GridPicker.NO_CELL
		released.emit()
		# Sempre emite: a célula pode ser a mesma, mas o modelo acabou de mudar.
		_hover_cell = picker.cell_at_screen(event.position)
		hover_changed.emit(_hover_cell)
