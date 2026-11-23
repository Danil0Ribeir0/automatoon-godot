class_name GameSettings
extends RefCounted

## Opções do jogador, salvas em user://settings.cfg e aplicadas ao abrir o jogo.
## Classe estática (sem autoload): menu e jogo chamam ensure_loaded() ao iniciar.
const PATH := "user://settings.cfg"

static var master_volume := 0.8 # 0..1
static var fullscreen := false
static var vsync := true
static var shadows := true
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		master_volume = float(cfg.get_value("audio", "master_volume", master_volume))
		fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
		vsync = bool(cfg.get_value("video", "vsync", vsync))
		shadows = bool(cfg.get_value("video", "shadows", shadows))
	apply()


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("video", "shadows", shadows)
	cfg.save(PATH)


## Volume, janela e VSync valem para o jogo todo. Sombras são aplicadas pela
## cena do jogo (GameWorld.apply_settings), porque dependem da luz da fase.
static func apply() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(bus, master_volume <= 0.0)
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
			else DisplayServer.WINDOW_MODE_MAXIMIZED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync
			else DisplayServer.VSYNC_DISABLED)
