extends Node2D
## Escena raiz. H1 tarea 2: conecta el MultiplayerSpawner con NetworkManager
## y arranca el host. Con un solo peer jugando (este playtest) el host se
## spawnea solo; en cuanto se conecte un segundo peer real, NetworkManager
## ya lo spawnea igual sin cambios aqui.

func _ready() -> void:
	NetworkManager.players_root = $Players
	NetworkManager.effects_root = $Effects
	NetworkManager.spawn_points.assign($TestRoom/PlayerSpawns.get_children())
	NetworkManager.host_game()
