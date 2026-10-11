class_name InputController
extends Node

signal primary_pressed(cell: Vector2i)
signal secondary_pressed(cell: Vector2i)
signal cursor_moved(cell: Vector2i)
signal released

@export var picker: GridPicker

var _active_button := MOUSE_BUTTON_NONE
var _last_cell := GridPicker.NO_CELL


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_button(event)
	elif event is InputEventMouseMotion and _active_button != MOUSE_BUTTON_NONE:
		var cell := picker.cell_at_screen(event.position)
		if cell != GridPicker.NO_CELL and cell != _last_cell:
			_last_cell = cell
			cursor_moved.emit(cell)


func _handle_button(event: InputEventMouseButton) -> void:
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
