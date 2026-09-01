extends Node2D
## Escena raiz. Conecta el MultiplayerSpawner con NetworkManager.
##
## Flujo normal (lobby-agent): pantalla de inicio -> lobby (crear sala/unirse
## a sala, ver scripts/ui/menu_inicio.gd y lobby.gd) -> el host pulsa
## "Iniciar partida" -> prologo -> eleccion de estilo -> submit_style_choice.
## host_game()/join_game() ya se llamaron dentro del lobby ANTES de llegar
## aqui -- _run_intro_flow ya NO conecta nada, solo asume que la conexion
## esta lista (mismo criterio que el resto del proyecto: NetworkManager es
## quien decide cuando se conecta, la UI solo se lo pide).
##
## --server/--client=<lobby_id> siguen existiendo como ATAJO DE TEST (arrancar
## dos instancias desde terminal sin pasar por la UI del lobby a mano) --
## saltan directamente el menu/lobby enteros y van al flujo antiguo. El flujo
## normal para un jugador real es siempre via UI. TRANSPORTE: Steam P2P (ver
## cabecera de network_manager.gd) -- --client ya NO acepta una IP, acepta el
## id de lobby de Steam (numerico) que imprime el host por consola al arrancar
## con --server. OJO: este atajo sigue necesitando el cliente de Steam abierto
## y logueado en cada maquina que lo use, exactamente igual que el flujo de
## UI -- no hay forma de esquivar esa dependencia con Steam P2P.
##
## H6: antes de conectar se muestra el prologo y la pantalla de eleccion de
## estilo (ver scripts/ui/prologo.gd y seleccion_estilo.gd) -- cada peer las
## ve solo en su pantalla, no viajan por red. El estilo elegido se manda al
## host via NetworkManager.submit_style_choice en cuanto la conexion esta
## lista; el host ya no spawnea automaticamente al conectar (ver
## NetworkManager.host_game/_on_peer_connected), espera a ese RPC.

const MENU_INICIO_SCENE := preload("res://scenes/ui/menu_inicio.tscn")
const LOBBY_SCENE := preload("res://scenes/ui/lobby.tscn")
const PROLOGO_SCENE := preload("res://scenes/ui/prologo.tscn")
const SELECCION_ESTILO_SCENE := preload("res://scenes/ui/seleccion_estilo.tscn")

func _ready() -> void:
	NetworkManager.players_root = $Players
	NetworkManager.effects_root = $Effects
	NetworkManager.cadavers_root = $Cadavers
	NetworkManager.spawn_points.assign($TestRoom/PlayerSpawns.get_children())
	# H6: contenedor de la escena de mision activa (ver
	# NetworkManager.confirm_iniciar_mision/confirm_volver_hub) y spawn_points
	# del Hub para poder volver a ellos tras la primera mision.
	NetworkManager.mission_root = $Misiones
	NetworkManager.hub_spawn_points.assign($Hub/Muelle/PlayerSpawns.get_children())

	var client_lobby_id := _client_lobby_id_from_args()
	if client_lobby_id > 0:
		if not await _conectar_atajo_test(func(): NetworkManager.join_game(client_lobby_id)):
			return
		_run_intro_flow()
		return
	if _server_flag_from_args():
		if not await _conectar_atajo_test(func(): NetworkManager.host_game()):
			return
		print("NetworkManager: sala de Steam creada, id = %s (usa --client=%s en la otra instancia)" % [NetworkManager.steam_lobby_id, NetworkManager.steam_lobby_id])
		_run_intro_flow()
		return

	_run_menu_flow()

## Helper comun a --server/--client=<lobby_id>: host_game()/join_game() son
## asincronos con el transporte de Steam (ver cabecera), asi que este atajo
## de test tiene que esperar el mismo NetworkManager.lobby_ready/
## lobby_join_failed que ya espera scripts/ui/lobby.gd en el flujo normal, en
## vez de asumir que la conexion esta lista al volver de la llamada (eso
## funcionaba con ENetMultiplayerPeer, ya no). Devuelve true si conecto bien.
func _conectar_atajo_test(iniciar: Callable) -> bool:
	var resultado := {}
	var on_ready := func(_is_host: bool): resultado["ok"] = true
	var on_failed := func(reason: String): resultado["ok"] = false; resultado["motivo"] = reason
	NetworkManager.lobby_ready.connect(on_ready, CONNECT_ONE_SHOT)
	NetworkManager.lobby_join_failed.connect(on_failed, CONNECT_ONE_SHOT)
	iniciar.call()
	while resultado.is_empty():
		await get_tree().process_frame
	if NetworkManager.lobby_ready.is_connected(on_ready):
		NetworkManager.lobby_ready.disconnect(on_ready)
	if NetworkManager.lobby_join_failed.is_connected(on_failed):
		NetworkManager.lobby_join_failed.disconnect(on_failed)
	if not resultado["ok"]:
		push_error("main.gd: fallo el atajo de test de conexion Steam: %s" % resultado.get("motivo", "?"))
	return resultado["ok"]

## Titulo -> lobby -> (si el usuario cancela, vuelve al titulo; si el host
## inicia la partida, sigue al prologo). Bucle en vez de flujo lineal porque
## "Volver al titulo"/"Salir de la sala" del lobby tienen que poder volver
## aqui sin reiniciar el proceso entero.
func _run_menu_flow() -> void:
	while true:
		var menu := MENU_INICIO_SCENE.instantiate()
		add_child(menu)
		await menu.jugar_pressed
		menu.queue_free()

		var lobby := LOBBY_SCENE.instantiate()
		add_child(lobby)
		var iniciar: bool = await lobby.finished
		lobby.queue_free()
		if iniciar:
			break
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

	NetworkManager.submit_style_choice.rpc_id(1, estilo_path)

func _client_lobby_id_from_args() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--client="):
			var valor := arg.trim_prefix("--client=")
			if valor.is_valid_int():
				return int(valor)
			push_error("main.gd: --client= necesita el id de lobby de Steam (numero), no una IP -- recibido %s" % valor)
			return 0
	return 0

func _server_flag_from_args() -> bool:
	return OS.get_cmdline_user_args().has("--server")
