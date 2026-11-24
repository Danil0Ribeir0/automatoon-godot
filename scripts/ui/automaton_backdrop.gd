class_name AutomatonBackdrop
extends Control

## Fundo animado "planta do engenheiro": um autômato desenhado como malha ferroviária.
## Estados = estações (q0…, aceitação com anel duplo), transições = trilhos com o
## símbolo lido. Trens percorrem a malha escolhendo, em cada estação, o trilho do
## símbolo do próximo vagão. O trilho acende enquanto o trem passa e a estação
## solta uma onda ao recebê-lo. Animado por um Tween em laço (sem _process).
##
## Desempenho: desenho em camadas. Só a camada `_live` (trilhos acesos, ondas,
## estações brilhando e trens) é redesenhada a cada frame. Fundo + grade, a malha
## em repouso e o véu são desenhados uma vez (e de novo só ao redimensionar).
## O parallax move a camada `_world` em vez de redesenhar.

@export var bg_color := Color("0f2c45")
@export var bg_edge_color := Color("08182a")
@export var grid_color := Color(1, 1, 1, 0.07)
@export var rail_color := Color(0.85, 0.91, 0.96, 0.22)
@export var lit_color := Color("f3e7b3")
@export var state_color := Color("f3e7b3")
@export var symbol_colors: Array[Color] = [Color("ee7330"), Color("3d9bf5")]
@export var train_count := 4
@export var train_speed := 85.0
@export var grid_step := 44.0
## Quanto o desenho acompanha o mouse (px). 0 = parado.
@export var parallax := 14.0
## Escurece o centro da tela para o texto do menu ler bem (0 = nada).
@export_range(0.0, 1.0) var focus := 0.0
## Véu da cor de fundo por cima do desenho (0 = nítido, 1 = some). Atenua atrás de menus cheios.
@export_range(0.0, 1.0) var veil := 0.0
## Cor do véu. Mais escura que o fundo = atenua e escurece ao mesmo tempo.
@export var veil_color := Color("0f2c45")

## Estados em coordenadas normalizadas da tela, em anel pela borda (centro livre
## para o texto do menu). Cada estado liga aos dois vizinhos do anel, nos dois
## sentidos: os pares de trilhos formam "lentes" entre as estações.
static var STATES := _ring_states()
## Elipse onde ficam as estações (centro e raios, normalizados pela tela).
const RING_CENTER := Vector2(0.5, 0.5)
const RING_RADII := Vector2(0.41, 0.37)
const ACCEPTING := [2, 5]
## [de, para, símbolo, lado do arco] — sentido horário lê 0, anti-horário lê 1.
static var EDGES := _ring_edges()
## Afastamento do arco em relação à reta entre as estações (px).
const BOW := 30.0
const STATE_RADIUS := 28.0
const WAGON_SPACING := 21.0
const RIPPLE_TIME := 1.1

var _paths: Array[PackedVector2Array] = []
var _lengths: Array[PackedFloat32Array] = []
var _trains: Array[Dictionary] = []
var _heat := {} # aresta -> brilho 0..1 (trilho aceso pelo trem)
var _ripples: Array[Dictionary] = [] # ondas saindo das estações
var _rng := RandomNumberGenerator.new()
var _last_v := 0.0
var _time := 0.0
var _offset := Vector2.ZERO
var _tween: Tween
var _wagon_boxes := {}
var _vignette: GradientTexture2D
var _focus_tex: GradientTexture2D
var _mids := PackedVector2Array() # ponto médio de cada transição (selo do símbolo)
var _world: Control # malha em repouso; anda com o parallax
var _live: Control # filha de _world: só o que muda a cada frame
var _overlay: Control # vinheta, foco e véu (estáticos)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 7
	_vignette = _radial([Color(bg_edge_color, 0.0), Color(bg_edge_color, 0.0), Color(bg_edge_color, 0.85)],
			[0.0, 0.45, 1.0])
	_focus_tex = _radial([Color(bg_edge_color, 0.85), Color(bg_edge_color, 0.5), Color(bg_edge_color, 0.0)],
			[0.0, 0.45, 1.0], Vector2(1.0, 0.5)) # some antes da borda do retângulo
	_world = _layer(self, _draw_world)
	_live = _layer(_world, _draw_live)
	_overlay = _layer(self, _draw_overlay)
	resized.connect(_rebuild)
	_rebuild()
	for i in train_count:
		# Mais 0 que 1: o trem avança pelo anel e de vez em quando volta uma estação.
		var word: Array[int] = [0, 0]
		for k in _rng.randi_range(0, 3):
			word.insert(_rng.randi() % word.size(), 1 if k == 0 else 0)
		var edge := (i * EDGES.size()) / train_count # espalhados pelo anel
		edge -= edge % 2 # começa num trilho horário
		_trains.append({"edge": edge, "prev": edge, "dist": _rng.randf() * 60.0, "word": word, "read": 0,
				"speed": train_speed * _rng.randf_range(0.85, 1.15)})
	_tween = create_tween().set_loops()
	_tween.tween_method(_tick, 0.0, 1.0, 1.0)


func _tick(v: float) -> void:
	var dt := v - _last_v
	if dt < 0.0:
		dt += 1.0
	_last_v = v
	_time += dt
	_advance(dt)
	# Parallax suave: segue o mouse devagar e "respira" um pouco sozinho.
	var target := Vector2(sin(_time * 0.21), cos(_time * 0.17)) * parallax * 0.35
	if parallax > 0.0 and size.x > 0.0:
		var m := get_local_mouse_position() / size - Vector2(0.5, 0.5)
		if absf(m.x) <= 0.5 and absf(m.y) <= 0.5:
			target -= m * parallax * 2.0
	_offset = _offset.lerp(target, minf(dt * 2.5, 1.0))
	_world.position = _offset
	_live.queue_redraw()


func _advance(dt: float) -> void:
	if _paths.is_empty():
		return
	for edge in _heat.keys():
		_heat[edge] -= dt * 0.45
		if _heat[edge] <= 0.0:
			_heat.erase(edge)
	for i in range(_ripples.size() - 1, -1, -1):
		_ripples[i]["t"] += dt / RIPPLE_TIME
		if _ripples[i]["t"] >= 1.0:
			_ripples.remove_at(i)
	for train in _trains:
		train["dist"] += float(train["speed"]) * dt
		_heat[train["edge"]] = 1.0
		var length := _edge_length(train["edge"])
		while train["dist"] > length:
			train["dist"] -= length
			var arrived: int = EDGES[train["edge"]][1]
			_ripples.append({"state": arrived, "t": 0.0})
			train["prev"] = train["edge"]
			train["edge"] = _choose_edge(arrived, train)
			length = _edge_length(train["edge"])


## Como um autômato: segue o trilho com o símbolo do próximo vagão.
func _choose_edge(state: int, train: Dictionary) -> int:
	var word: Array = train["word"]
	var wanted: int = word[train["read"] % word.size()]
	train["read"] += 1
	var options: Array[int] = []
	var any: Array[int] = []
	for i in EDGES.size():
		if EDGES[i][0] == state:
			any.append(i)
			if EDGES[i][2] == wanted:
				options.append(i)
	var pool := options if not options.is_empty() else any
	return pool[_rng.randi() % pool.size()]


func _rebuild() -> void:
	_paths.clear()
	_lengths.clear()
	for e in EDGES:
		var a := _state_pos(e[0])
		var b := _state_pos(e[1])
		var d := b - a
		var ctrl := (a + b) * 0.5 + d.orthogonal().normalized() * BOW * 2.0 * float(e[3])
		var pts := PackedVector2Array()
		for i in 41:
			var t := i / 40.0
			var p := a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)
			if p.distance_to(a) > STATE_RADIUS + 4.0 and p.distance_to(b) > STATE_RADIUS + 6.0:
				pts.append(p)
		var cum := PackedFloat32Array([0.0])
		for i in range(1, pts.size()):
			cum.append(cum[i - 1] + pts[i - 1].distance_to(pts[i]))
		_paths.append(pts)
		_lengths.append(cum)
	_mids.clear()
	for i in EDGES.size():
		_mids.append(_sample(i, _edge_length(i) * 0.5)[0] if _paths[i].size() > 0 else Vector2.ZERO)
	for layer in [_world, _live, _overlay]:
		layer.size = size
		layer.queue_redraw()
	queue_redraw()


func _state_pos(i: int) -> Vector2:
	var s: Vector2 = STATES[i]
	return Vector2(s.x * size.x, s.y * size.y)


func _edge_length(edge: int) -> float:
	var cum := _lengths[edge]
	return maxf(cum[cum.size() - 1], 1.0) if cum.size() > 0 else 1.0


## Posição e ângulo a `dist` pixels do começo da transição.
func _sample(edge: int, dist: float) -> Array:
	var pts := _paths[edge]
	var cum := _lengths[edge]
	if pts.size() < 2:
		return [pts[0] if pts.size() > 0 else Vector2.ZERO, 0.0]
	dist = clampf(dist, 0.0, cum[cum.size() - 1])
	for i in range(1, pts.size()):
		if cum[i] >= dist:
			var seg := cum[i] - cum[i - 1]
			var t := (dist - cum[i - 1]) / seg if seg > 0.0 else 0.0
			return [pts[i - 1].lerp(pts[i], t), (pts[i] - pts[i - 1]).angle()]
	return [pts[pts.size() - 1], (pts[pts.size() - 1] - pts[pts.size() - 2]).angle()]


## Desacelera ao chegar na estação e acelera ao sair (sem parar de vez).
func _eased(edge: int, dist: float) -> float:
	var length := _edge_length(edge)
	var p := clampf(dist / length, 0.0, 1.0)
	return length * lerpf(p, p * p * (3.0 - 2.0 * p), 0.55)


func _layer(parent: Control, painter: Callable) -> Control:
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(layer)
	layer.draw.connect(painter.bind(layer))
	return layer


## Fundo + grade de pontos (planta). Estático e sem parallax.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), bg_color)
	var y := grid_step * 0.5
	while y < size.y:
		var x := grid_step * 0.5
		while x < size.x:
			draw_circle(Vector2(x, y), 1.4, grid_color)
			x += grid_step
		y += grid_step


## Malha em repouso: trilhos apagados, seta de início e estações. Estática.
func _draw_world(c: CanvasItem) -> void:
	if _paths.is_empty():
		return
	for i in EDGES.size():
		_draw_edge(c, i, 0.0)
	var q0 := _state_pos(0)
	c.draw_line(q0 - Vector2(STATE_RADIUS + 44, 0), q0 - Vector2(STATE_RADIUS + 8, 0), Color(state_color, 0.7), 2.5, true)
	RailSketch.arrow_head(c, q0 - Vector2(STATE_RADIUS + 4, 0), Vector2.RIGHT, Color(state_color, 0.7), 10.0)
	for i in STATES.size():
		_draw_state(c, i, 0.0)


## Só o que muda: trilhos acesos, ondas, estações brilhando e trens (por cima da malha).
func _draw_live(c: CanvasItem) -> void:
	if _paths.is_empty():
		return
	for edge in _heat:
		_draw_edge(c, edge, _heat[edge])

	var glow := {}
	for r in _ripples:
		var t: float = r["t"]
		var state: int = r["state"]
		var big := 1.6 if state in ACCEPTING else 1.0
		var e := 1.0 - pow(1.0 - t, 3.0)
		c.draw_arc(_state_pos(state), STATE_RADIUS + 34.0 * big * e, 0, TAU, 48, Color(state_color, 0.45 * (1.0 - t)), 2.0, true)
		glow[state] = maxf(glow.get(state, 0.0), 1.0 - t)
	for state in glow:
		_draw_state(c, state, glow[state])

	# Trens: locomotiva creme na frente, vagões coloridos pelo símbolo
	for train in _trains:
		var word: Array = train["word"]
		var lead := _eased(train["edge"], train["dist"])
		for w in range(-1, word.size()):
			var d: float = lead - (w + 1) * WAGON_SPACING
			var edge: int = train["edge"]
			if d < 0.0:
				edge = train["prev"]
				d += _edge_length(edge)
				if d < 0.0:
					continue
			var s := _sample(edge, d)
			c.draw_set_transform(s[0], s[1])
			if w < 0:
				c.draw_circle(Vector2(12, 0), 9.0, Color(lit_color, 0.18)) # farol
				c.draw_style_box(_box(lit_color), Rect2(-9, -6.5, 19, 13))
				c.draw_rect(Rect2(-7, -4, 6, 8), bg_color.darkened(0.2))
			else:
				c.draw_style_box(_box(symbol_colors[word[w]]), Rect2(-8.5, -6, 17, 12))
	c.draw_set_transform(Vector2.ZERO, 0.0)


func _draw_overlay(c: CanvasItem) -> void:
	c.draw_texture_rect(_vignette, Rect2(Vector2.ZERO, size), false)
	if focus > 0.0:
		var r := Vector2(size.x * 0.62, size.y * 0.72)
		c.draw_texture_rect(_focus_tex, Rect2(size * 0.5 - r * 0.5, r), false, Color(1, 1, 1, focus))
	if veil > 0.0:
		c.draw_rect(Rect2(Vector2.ZERO, size), Color(veil_color, veil))


## Transição com o selo do símbolo; `heat` > 0 = acesa pelo trem.
func _draw_edge(c: CanvasItem, i: int, heat: float) -> void:
	var pts := _paths[i]
	if pts.size() < 2:
		return
	var color := rail_color.lerp(Color(lit_color, 0.75), heat * 0.8)
	if heat > 0.0:
		c.draw_polyline(pts, Color(lit_color, 0.10 * heat), 14.0, true)
	RailSketch.draw_rail(c, pts, color)
	RailSketch.arrow_head(c, pts[pts.size() - 1],
			(pts[pts.size() - 1] - pts[pts.size() - 2]).normalized(), color, 9.0)
	var symbol: int = EDGES[i][2]
	c.draw_circle(_mids[i], 9.0, Color(symbol_colors[symbol], 0.55 + 0.45 * heat))
	var font := get_theme_default_font()
	var text := str(symbol)
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	c.draw_string(font, _mids[i] + Vector2(-ts.x * 0.5, ts.y * 0.32), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)


## Estação; `glow` > 0 = acabou de receber um trem.
func _draw_state(c: CanvasItem, i: int, glow: float) -> void:
	var pos := _state_pos(i)
	c.draw_circle(pos, STATE_RADIUS, bg_color.lerp(state_color, 0.06 + 0.16 * glow))
	c.draw_arc(pos, STATE_RADIUS, 0, TAU, 48, Color(state_color, 0.75 + 0.25 * glow), 2.5, true)
	if i in ACCEPTING:
		c.draw_arc(pos, STATE_RADIUS - 6.0, 0, TAU, 48, Color(state_color, 0.75 + 0.25 * glow), 1.6, true)
	var font := get_theme_default_font()
	var label := "q%d" % i
	var ls := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	c.draw_string(font, pos + Vector2(-ls.x * 0.5, ls.y * 0.3), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, state_color)


func _box(color: Color) -> StyleBoxFlat:
	if not _wagon_boxes.has(color):
		var b := StyleBoxFlat.new()
		b.bg_color = color
		b.set_corner_radius_all(4)
		b.anti_aliasing = true
		_wagon_boxes[color] = b
	return _wagon_boxes[color]


## 8 estações igualmente espaçadas na elipse, q0 à esquerda, em sentido horário.
static func _ring_states() -> Array:
	var states := []
	for i in 8:
		var angle := PI + TAU * i / 8.0
		states.append(RING_CENTER + Vector2(cos(angle) * RING_RADII.x, sin(angle) * RING_RADII.y))
	return states


static func _ring_edges() -> Array:
	var edges := []
	var n := STATES.size()
	for i in n:
		edges.append([i, (i + 1) % n, 0, 1.0])
		edges.append([i, (i + n - 1) % n, 1, 1.0])
	return edges


static func _radial(colors: Array, offsets: Array, reach := Vector2(1.0, 1.0)) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = reach
	tex.width = 256
	tex.height = 256
	return tex
