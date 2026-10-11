class_name RailPiece
extends Node3D

const _N := GridModel.Dir.NORTH
const _E := GridModel.Dir.EAST
const _S := GridModel.Dir.SOUTH
const _W := GridModel.Dir.WEST

const _SHAPES := {
	GridModel.HORIZONTAL: [false, 90.0],
	GridModel.VERTICAL: [false, 0.0],
	_N | _E: [true, 0.0],
	_E | _S: [true, -90.0],
	_S | _W: [true, 180.0],
	_W | _N: [true, 90.0],
}

@onready var _straight: Node3D = $Straight
@onready var _curve: Node3D = $Curve

func apply_shape(shape: int) -> void:
	var data: Array = _SHAPES.get(shape, _SHAPES[GridModel.HORIZONTAL])
	_curve.visible = data[0]
	_straight.visible = not data[0]
	rotation_degrees.y = data[1]
