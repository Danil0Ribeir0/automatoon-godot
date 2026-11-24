class_name GameCatalog
extends Resource

## Todos os mundos do jogo, na ordem em que aparecem no menu de fases.
@export var worlds: Array[WorldData] = []
## Abas de "em breve" mostradas depois dos mundos prontos.
@export var upcoming_worlds := 1
