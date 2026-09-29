class_name AutomataPalette
extends RefCounted

const DIGIT_COLORS: Dictionary = {
	"0": Color("#7f8c8d"),
	"1": Color("#e74c3c"),
	"2": Color("#3498db"),
	"3": Color("#2ecc71"),
	"4": Color("#f1c40f"),
	"5": Color("#9b59b6"),
	"6": Color("#e67e22"),
	"7": Color("#1abc9c"),
	"8": Color("#e84393"),
	"9": Color("#ffffff")
}

static func get_symbol_color(symbol: String, default_color: Color = Color.WHITE) -> Color:
	return DIGIT_COLORS.get(symbol, default_color)
