class_name RailSketch
extends RefCounted

## Desenho 2D de trilho (dois carris + dormentes) ao longo de uma polilinha.
## Chamar de dentro do _draw() do CanvasItem.

static func draw_rail(canvas: CanvasItem, points: PackedVector2Array, color: Color,
		gauge := 4.0, sleeper_step := 11.0, width := 1.6) -> void:
	if points.size() < 2:
		return
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in points.size():
		var a := points[maxi(i - 1, 0)]
		var b := points[mini(i + 1, points.size() - 1)]
		var n := (b - a).orthogonal().normalized()
		left.append(points[i] + n * gauge)
		right.append(points[i] - n * gauge)
	# dormentes
	var sleeper := Color(color, color.a * 0.6)
	var carry := 0.0
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var seg := a.distance_to(b)
		if seg <= 0.0:
			continue
		var n := (b - a).orthogonal() / seg
		var d := sleeper_step - carry
		while d <= seg:
			var p := a.lerp(b, d / seg)
			canvas.draw_line(p + n * gauge * 1.7, p - n * gauge * 1.7, sleeper, width + 0.8)
			d += sleeper_step
		carry = seg - (d - sleeper_step)
	canvas.draw_polyline(left, color, width, true)
	canvas.draw_polyline(right, color, width, true)


static func arrow_head(canvas: CanvasItem, tip: Vector2, dir: Vector2, color: Color, size := 11.0) -> void:
	var n := dir.orthogonal()
	canvas.draw_colored_polygon(PackedVector2Array([tip, tip - dir * size + n * size * 0.55,
			tip - dir * size - n * size * 0.55]), color)
