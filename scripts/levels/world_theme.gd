class_name WorldTheme
extends Resource

## Visual de um mundo. Campo vazio = usa o padrão da cena do jogo (Fazenda).
@export var scenery_scene: PackedScene
@export var terminal_scene: PackedScene
@export var wagon_scene: PackedScene
@export var obstacle_scene: PackedScene
@export var ground_color := Color(0.78, 0.84, 0.78)
@export var line_color := Color(0.15, 0.2, 0.15)
