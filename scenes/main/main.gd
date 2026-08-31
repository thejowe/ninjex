extends Node2D
## Escena raiz. Conecta el MultiplayerSpawner con NetworkManager y arranca
## host o cliente segun argumento de arranque (tarea "unirse como cliente"):
## --server fuerza host, --client=IP se une a esa IP, sin argumentos cae en
## host por defecto (mismo comportamiento que antes, para no romper el
## playtest de un solo peer). Placeholder de vertical slice: no hay menu,
## para probar con 2 instancias reales se lanzan 2 .exe con distintos args.

func _ready() -> void:
	NetworkManager.players_root = $Players
	NetworkManager.effects_root = $Effects
	NetworkManager.spawn_points.assign($TestRoom/PlayerSpawns.get_children())
	var client_ip := _client_ip_from_args()
	if client_ip != "":
		NetworkManager.join_game(client_ip)
	else:
		NetworkManager.host_game()

func _client_ip_from_args() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--client="):
			return arg.trim_prefix("--client=")
	return ""
