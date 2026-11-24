extends Node3D

## Uma fase em jogo. Só avisa o resultado; quem decide a próxima fase é o LevelManager.
## Rodando sozinha (F6), a fase funciona e R recarrega a cena.
signal level_completed(stars: int, rails: int)
signal restart_requested

@export var level: LevelData
## Número mostrado no HUD ("Fase 3 · ..."). 0 = só o título.
@export var level_number := 0
## Visual do mundo; vazio = o que já está na cena (Fazenda).
@export var theme: WorldTheme

## Velocidade do trem enquanto o jogador segura Espaço/Enter.
@export_range(1.0, 3.0) var fast_forward_multiplier := 2.0
## Tempo segurando que conta como "aprendeu a acelerar" (a dica some).
const FAST_LEARN_TIME := 0.4

@export_group("Camera")
@export_range(30.0, 80.0) var camera_pitch_degrees: float = 55.0
@export_range(20.0, 70.0) var camera_fov: float = 45.0
@export_range(1.0, 2.0) var camera_fit_margin: float = 1.25

@onready var _board: GridBoard = $GridBoard
@onready var _camera: Camera3D = $Camera3D
@onready var _router: ToolRouter = $ToolRouter
@onready var _hud: HUD = $HUD
@onready var _input: InputController = $InputController
@onready var _train: Train = $Train
@onready var _scenery: RuralScenery = get_node_or_null("RuralScenery")

var _model: GridModel
var _last_result: ValidationResult
## A fase foi vencida: edição fica travada até repetir/avançar.
var _completed := false
## Há quanto tempo Espaço/Enter está segurado durante o percurso.
var _fast_held := 0.0


func _ready() -> void:
	_apply_theme()
	apply_settings()
	_model = GridModel.new(level.grid_size, level.get_spawn_cell(), level.get_exit_cell())
	_board.setup(_model)
	if _scenery:
		_scenery.build(_board, level)
	for cell in level.blocked_cells:
		_model.block_cell(cell)
	_apply_fixed_stations()
	_apply_fixed_switches()

	_router.setup(_model, level.station_tool_enabled, level.get_symbol_ids(), level.switch_tool_enabled)
	_hud.setup(level.get_symbol_ids(), level.station_tool_enabled, level.switch_tool_enabled,
			level.available_symbols)
	_hud.show_level(_level_title(), level.get_trains(), level.par_rails)
	_hud.show_rail_count(_model.rail_count())
	_hud.tool_requested.connect(_router.request_tool)
	_router.tool_changed.connect(_hud.show_active_tool)
	_router.request_tool(ToolRouter.ToolId.RAIL)
	_router.preview_changed.connect(_board.show_preview)
	_hud.test_requested.connect(_run_validation)
	_input.test_requested.connect(_run_validation)
	_input.restart_requested.connect(_on_restart)
	_hud.restart_requested.connect(_on_restart)
	_model.cell_changed.connect(_on_model_changed)
	_train.step_reached.connect(_on_train_step)
	_park_train(0)

	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()


## Opções que dependem da cena da fase (hoje: sombras da luz principal).
func apply_settings() -> void:
	GameSettings.ensure_loaded()
	var sun := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sun:
		sun.shadow_enabled = GameSettings.shadows


func _apply_theme() -> void:
	if theme == null:
		return
	if theme.terminal_scene:
		_board.terminal_scene = theme.terminal_scene
	if theme.obstacle_scene:
		_board.obstacle_scene = theme.obstacle_scene
	if theme.wagon_scene:
		_train.wagon_scene = theme.wagon_scene
	_board.ground_color = theme.ground_color
	_board.line_color = theme.line_color
	if theme.scenery_scene:
		if _scenery:
			remove_child(_scenery)
			_scenery.queue_free()
		_scenery = theme.scenery_scene.instantiate() as RuralScenery
		if _scenery:
			add_child(_scenery)


func _apply_fixed_stations() -> void:
	for placement in level.fixed_stations:
		if placement.symbol == null:
			push_warning("Estação fixa sem símbolo em %s" % placement.cell)
			continue
		if not _model.place_station(placement.cell, placement.symbol.id):
			push_warning("Estação fixa recusada em %s (fora da grid, obstáculo ou colada em outra estação)" % placement.cell)
			continue
		_model.lock_cell(placement.cell)


func _apply_fixed_switches() -> void:
	for placement in level.fixed_switches:
		if not _model.place_switch(placement.cell, placement.trunk, placement.diverge, placement.straight_symbol):
			push_warning("Agulha fixa recusada em %s" % placement.cell)
			continue
		if placement.locked:
			_model.lock_cell(placement.cell)
		else:
			_model.pin_cell(placement.cell)


func _fit_camera() -> void:
	var extent := maxf(level.grid_size.x + 2, level.grid_size.y) * _board.cell_size
	var pitch := deg_to_rad(camera_pitch_degrees)
	var vfov := deg_to_rad(camera_fov)
	var aspect := get_viewport().get_visible_rect().size.aspect()
	var hfov := 2.0 * atan(tan(vfov * 0.5) * aspect)
	var half := extent * 0.5 * camera_fit_margin
	var distance := maxf(half / tan(hfov * 0.5), half / tan(vfov * 0.5))

	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = camera_fov
	_camera.rotation = Vector3(-pitch, 0.0, 0.0)
	_camera.position = Vector3(0.0, sin(pitch), cos(pitch)) * distance


## Segurar Espaço/Enter acelera o trem enquanto ele anda.
func _process(delta: float) -> void:
	if not _train.is_running():
		return
	var fast := Input.is_physical_key_pressed(KEY_SPACE) \
			or Input.is_physical_key_pressed(KEY_ENTER) \
			or Input.is_physical_key_pressed(KEY_KP_ENTER)
	_train.set_speed_multiplier(fast_forward_multiplier if fast else 1.0)
	_fast_held = _fast_held + delta if fast else 0.0
	if _fast_held >= FAST_LEARN_TIME:
		_hud.speed_hint_learned()


func _run_validation() -> void:
	if _completed or _train.is_running() or _router.is_busy():
		return
	var trains := level.get_trains()
	if trains.is_empty():
		push_warning("A fase não tem trem configurado (LevelData > Trem)")
		return

	_clear_run()
	_set_editing(false)
	_fast_held = 0.0
	_hud.show_speed_hint(true)
	# Um trem de cada vez; a fase só é vencida se TODOS baterem com o esperado.
	for i in trains.size():
		var t := trains[i]
		_hud.mark_train(i, HUD.Mark.RUNNING)
		if i > 0:
			_park_train(i)
			await get_tree().create_timer(0.35).timeout
		_last_result = AutomatonValidator.validate(_model, t.get_word())
		_print_route(_last_result)
		if _train.run(_last_result.steps, t.wagons, _board, _last_result.success):
			await _train.finished
		var ok := _last_result.success == t.expect_accept
		_hud.mark_train(i, HUD.Mark.PASSED if ok else HUD.Mark.FAILED)
		if not ok:
			_hud.show_speed_hint(false)
			_hud.show_result(_last_result, i, t.expect_accept, trains.size())
			if not _last_result.success:
				_board.show_error(_last_result.error_cell)
			_set_editing(true)
			return
		await get_tree().create_timer(0.3).timeout

	_hud.show_speed_hint(false)
	_hud.show_result(_last_result, -1, true, trains.size())
	_completed = true # edição continua travada: a fase acabou
	var rails := _model.rail_count()
	level_completed.emit(level.stars_for(rails), rails)


func _on_train_step(index: int) -> void:
	var step := _last_result.steps[index]
	var is_failure_point := not _last_result.success and index == _last_result.steps.size() - 1
	if step.symbol != &"" and not is_failure_point:
		_board.pulse_station(step.cell)


## Qualquer edição apaga o resultado e devolve o trem para a estação de partida.
func _on_model_changed(_cell: Vector2i) -> void:
	_clear_run()
	_hud.show_rail_count(_model.rail_count())


func _on_restart() -> void:
	if restart_requested.get_connections().is_empty():
		get_tree().reload_current_scene() # rodando a fase sozinha
	else:
		restart_requested.emit()


func _clear_run() -> void:
	_board.hide_error()
	_hud.clear_result()
	_hud.clear_marks()
	_park_train(0)


## Estaciona o trem `index` da fila na frente da Partida.
func _park_train(index: int) -> void:
	var trains := level.get_trains()
	if index >= trains.size():
		_train.clear()
		return
	var spawn_step := PathStep.new(_model.spawn_cell, 0)
	spawn_step.exit_dir = _model.get_shape(_model.spawn_cell) # aponta para dentro da grid
	_train.park(spawn_step, trains[index].wagons, _board)


func _set_editing(enabled: bool) -> void:
	_router.set_enabled(enabled)
	_hud.set_editing_enabled(enabled)


func _level_title() -> String:
	if level_number > 0:
		return "Fase %d · %s" % [level_number, level.title]
	return level.title


func _print_route(result: ValidationResult) -> void:
	var parts := PackedStringArray()
	for step in result.steps:
		var label := str(step.cell)
		if step.symbol != &"":
			label += "[%s]" % step.symbol
		parts.append(label)
	print(" → ".join(parts))
