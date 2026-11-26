class_name ProgressStore
extends RefCounted

## Melhores estrelas de cada fase, salvas em user://progress.cfg.
const PATH := "user://progress.cfg"


static func best_stars(world_id: StringName, index: int) -> int:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return 0
	return int(cfg.get_value(String(world_id), _key(index), 0))


static func record(world_id: StringName, index: int, stars: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH) # se ainda não existe, começa vazio
	var section := String(world_id)
	if stars > int(cfg.get_value(section, _key(index), 0)):
		cfg.set_value(section, _key(index), stars)
		cfg.save(PATH)


## Liberada se não depende de nada ou se a fase exigida (WorldData.unlock_after) foi concluída.
static func is_unlocked(world: WorldData, index: int) -> bool:
	var req := world.required_level(index)
	return req < 0 or best_stars(world.id, req) > 0


static func world_stars(world: WorldData) -> int:
	var total := 0
	for i in world.levels.size():
		total += best_stars(world.id, i)
	return total


static func _key(index: int) -> String:
	return "level_%02d" % (index + 1)
