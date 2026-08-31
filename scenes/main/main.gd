extends Node2D
## Escena raiz. Conecta el MultiplayerSpawner con NetworkManager y arranca
## host o cliente segun argumento de arranque (tarea "unirse como cliente"):
## --server fuerza host, --client=IP se une a esa IP, sin argumentos cae en
## host por defecto (mismo comportamiento que antes, para no romper el
## playtest de un solo peer).
##
## H6: antes de conectar se muestra el prologo y la pantalla de eleccion de
## estilo (ver scripts/ui/prologo.gd y seleccion_estilo.gd) -- cada peer las
## ve solo en su pantalla, no viajan por red. El estilo elegido se manda al
## host via NetworkManager.submit_style_choice en cuanto la conexion esta
## lista; el host ya no spawnea automaticamente al conectar (ver
## NetworkManager.host_game/_on_peer_connected), espera a ese RPC.

const PROLOGO_SCENE := preload("res://scenes/ui/prologo.tscn")
const SELECCION_ESTILO_SCENE := preload("res://scenes/ui/seleccion_estilo.tscn")

func _ready() -> void:
	NetworkManager.players_root = $Players
	NetworkManager.effects_root = $Effects
	NetworkManager.cadavers_root = $Cadavers
	NetworkManager.spawn_points.assign($TestRoom/PlayerSpawns.get_children())
	_run_intro_flow()

func _run_intro_flow() -> void:
	var prologo := PROLOGO_SCENE.instantiate()
	add_child(prologo)
	await prologo.finished
	prologo.queue_free()

	var seleccion := SELECCION_ESTILO_SCENE.instantiate()
	add_child(seleccion)
	var estilo_path: String = await seleccion.estilo_elegido
	seleccion.queue_free()

	var client_ip := _client_ip_from_args()
	if client_ip != "":
		NetworkManager.join_game(client_ip)
		await multiplayer.connected_to_server
	else:
		NetworkManager.host_game()
	NetworkManager.submit_style_choice.rpc_id(1, estilo_path)

func _client_ip_from_args() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--client="):
			return arg.trim_prefix("--client=")
	return ""
