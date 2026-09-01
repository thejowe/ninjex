extends CanvasLayer
## Lobby de sala (flujo de red visible al jugador, ver main.gd _run_menu_flow):
## Crear sala / Unirse a sala -> lista de jugadores en vivo -> "Iniciar
## partida" (solo host). Es el UNICO sitio del proyecto donde se llama
## NetworkManager.host_game()/join_game() en el flujo normal -- antes esto
## dependia del argumento de linea de comandos --client=IP/--server (ver
## main.gd _client_ip_from_args, que ahora solo sobrevive como atajo de test).
##
## Arquitectura host-autoritativo (igual que el resto del proyecto, ver
## network_manager.gd): el boton "Iniciar partida" solo lo ve/pulsa el host
## (multiplayer.is_server()); dispara NetworkManager.submit_iniciar_partida,
## que el host confirma a todos los peers via confirm_iniciar_partida/
## game_started (ver network_manager.gd). Este script escucha esa señal para
## saber cuando salir del lobby, tanto en el host como en cada cliente.
##
## TRANSPORTE: Steam P2P (ver cabecera de network_manager.gd), no ENet/IP.
## host_game()/join_game() son ASINCRONOS (createLobby/joinLobby de Steam son
## un round-trip contra los servidores de Steam) -- este script espera las
## señales NetworkManager.lobby_ready/lobby_join_failed en vez de asumir que
## la conexion esta lista al volver de la llamada, como podia hacerse con
## ENetMultiplayerPeer.
##
## Tres paneles, uno visible a la vez (nunca una escena de Godot aparte por
## panel: es mas simple mostrar/ocultar dentro de la misma escena, mismo
## criterio que seleccion_estilo.gd usa una sola escena para toda su pantalla):
## - PanelModo: Crear sala / Unirse a sala / Volver al titulo.
## - PanelUnirse: campo de ID DE SALA DE STEAM + Conectar. Sustituye al campo
##   de IP que tenia el flujo de ENet -- sigue existiendo como atajo util para
##   testear sin tener que aceptar una invitacion real de Steam (dos cuentas
##   compartiendo el id a mano por Discord/voz), no como un segundo sistema de
##   conexion paralelo: sigue usando join_game(lobby_id) exactamente igual que
##   aceptar una invitacion, solo cambia como se consigue el id.
## - PanelSala: id de sala + "Invitar amigos" (solo host, abre el overlay de
##   Steam) + lista de jugadores en vivo + "Iniciar partida" (solo host) /
##   "Esperando..." (clientes) + Salir.

signal finished(started: bool)

@onready var _panel_modo: Control = $PanelModo
@onready var _crear_sala_button: Button = $PanelModo/MarginContainer/VBox/CrearSalaButton
@onready var _unirse_sala_button: Button = $PanelModo/MarginContainer/VBox/UnirseSalaButton
@onready var _estado_modo_label: Label = $PanelModo/MarginContainer/VBox/EstadoLabel
@onready var _volver_titulo_button: Button = $PanelModo/MarginContainer/VBox/VolverButton

@onready var _panel_unirse: Control = $PanelUnirse
@onready var _lobby_id_edit: LineEdit = $PanelUnirse/MarginContainer/VBox/LobbyIdEdit
@onready var _conectar_button: Button = $PanelUnirse/MarginContainer/VBox/ConectarButton
@onready var _estado_unirse_label: Label = $PanelUnirse/MarginContainer/VBox/EstadoLabel
@onready var _volver_modo_button: Button = $PanelUnirse/MarginContainer/VBox/VolverButton

@onready var _panel_sala: Control = $PanelSala
@onready var _titulo_sala_label: Label = $PanelSala/MarginContainer/VBox/TituloLabel
@onready var _info_sala_label: Label = $PanelSala/MarginContainer/VBox/InfoSalaLabel
@onready var _invitar_button: Button = $PanelSala/MarginContainer/VBox/InvitarButton
@onready var _lista_jugadores: VBoxContainer = $PanelSala/MarginContainer/VBox/ListaJugadores
@onready var _iniciar_button: Button = $PanelSala/MarginContainer/VBox/IniciarButton
@onready var _esperando_label: Label = $PanelSala/MarginContainer/VBox/EsperandoLabel
@onready var _salir_sala_button: Button = $PanelSala/MarginContainer/VBox/SalirSalaButton

## Señal interna que unifica NetworkManager.lobby_ready/lobby_join_failed en
## un solo punto de espera (ver _esperar_resultado_lobby() mas abajo) -- las
## dos llegan con firmas distintas (bool vs String) y solo una de las dos
## dispara por cada intento de host_game()/join_game().
signal _resultado_lobby(exito: bool, mensaje: String)

func _ready() -> void:
	_crear_sala_button.pressed.connect(_on_crear_sala_pressed)
	_unirse_sala_button.pressed.connect(_on_unirse_sala_pressed)
	_volver_titulo_button.pressed.connect(_volver_a_titulo)

	_conectar_button.pressed.connect(_on_conectar_pressed)
	_volver_modo_button.pressed.connect(_volver_a_modo)

	_invitar_button.pressed.connect(_on_invitar_pressed)
	_iniciar_button.pressed.connect(_on_iniciar_pressed)
	_salir_sala_button.pressed.connect(_volver_a_titulo)

	NetworkManager.game_started.connect(_on_game_started)
	NetworkManager.invite_received.connect(_on_invite_received)

	_mostrar_panel(_panel_modo)

	# Si el jugador acepto una invitacion de Steam (o "Unirse a la partida"
	# desde la lista de amigos) mientras el juego ya estaba corriendo, antes
	# de que este lobby existiera, NetworkManager guardo el lobby_id -- nos
	# unimos directamente sin que el jugador tenga que pulsar nada mas.
	if NetworkManager.pending_invite_lobby_id > 0:
		var lobby_id := NetworkManager.pending_invite_lobby_id
		NetworkManager.pending_invite_lobby_id = 0
		_on_invite_received(lobby_id)

func _mostrar_panel(panel: Control) -> void:
	_panel_modo.visible = panel == _panel_modo
	_panel_unirse.visible = panel == _panel_unirse
	_panel_sala.visible = panel == _panel_sala

# =========================================================================
# Espera comun a host_game()/join_game() -- ver signal _resultado_lobby.
# =========================================================================

func _conectar_espera_lobby() -> void:
	NetworkManager.lobby_ready.connect(_on_lobby_ready_wrapper, CONNECT_ONE_SHOT)
	NetworkManager.lobby_join_failed.connect(_on_lobby_failed_wrapper, CONNECT_ONE_SHOT)

func _on_lobby_ready_wrapper(_is_host: bool) -> void:
	if NetworkManager.lobby_join_failed.is_connected(_on_lobby_failed_wrapper):
		NetworkManager.lobby_join_failed.disconnect(_on_lobby_failed_wrapper)
	_resultado_lobby.emit(true, "")

func _on_lobby_failed_wrapper(reason: String) -> void:
	if NetworkManager.lobby_ready.is_connected(_on_lobby_ready_wrapper):
		NetworkManager.lobby_ready.disconnect(_on_lobby_ready_wrapper)
	_resultado_lobby.emit(false, reason)

# =========================================================================
# PanelModo
# =========================================================================

func _on_crear_sala_pressed() -> void:
	_estado_modo_label.text = "Creando sala..."
	_crear_sala_button.disabled = true
	_unirse_sala_button.disabled = true
	_conectar_espera_lobby()
	NetworkManager.host_game()
	var resultado: Array = await _resultado_lobby
	_crear_sala_button.disabled = false
	_unirse_sala_button.disabled = false
	if resultado[0]:
		_estado_modo_label.text = ""
		_entrar_en_sala("Sala creada")
	else:
		_estado_modo_label.text = String(resultado[1]) if resultado[1] != "" else "No se pudo crear la sala."

func _on_unirse_sala_pressed() -> void:
	_estado_unirse_label.text = ""
	_lobby_id_edit.text = ""
	_mostrar_panel(_panel_unirse)
	_lobby_id_edit.grab_focus()

# =========================================================================
# PanelUnirse
# =========================================================================

func _on_conectar_pressed() -> void:
	var texto := _lobby_id_edit.text.strip_edges()
	if texto == "" or not texto.is_valid_int():
		_estado_unirse_label.text = "Escribe el id de sala (numero, te lo pasa el host)."
		return
	_intentar_unirse(int(texto))

## Unico punto que llama a NetworkManager.join_game() -- usado tanto por el
## boton "Conectar" de arriba como por _on_invite_received() (aceptar una
## invitacion de Steam), asi no hay dos caminos de union mantenidos por
## separado.
func _intentar_unirse(lobby_id: int) -> void:
	_conectar_button.disabled = true
	_estado_unirse_label.text = "Conectando a la sala %s..." % lobby_id
	_conectar_espera_lobby()
	NetworkManager.join_game(lobby_id)
	var resultado: Array = await _resultado_lobby
	_conectar_button.disabled = false
	if resultado[0]:
		_estado_unirse_label.text = ""
		_entrar_en_sala("Conectado")
	else:
		_estado_unirse_label.text = String(resultado[1]) if resultado[1] != "" else "No se pudo conectar. Revisa el id e intentalo de nuevo."

## Llega en cualquier momento que el jugador acepte una invitacion de Steam o
## pulse "Unirse a la partida" en la lista de amigos mientras el juego esta
## corriendo (ver NetworkManager.invite_received / _on_join_requested). Si ya
## estamos conectados a algo (en PanelSala), NetworkManager ya ignoro la
## invitacion antes de emitir esta señal, asi que aqui siempre estamos en
## PanelModo o PanelUnirse.
func _on_invite_received(lobby_id: int) -> void:
	_mostrar_panel(_panel_unirse)
	_intentar_unirse(lobby_id)

# =========================================================================
# PanelSala -- comun a host y cliente tras host_game()/join_game() exitoso.
# =========================================================================

func _entrar_en_sala(titulo: String) -> void:
	_titulo_sala_label.text = titulo
	if multiplayer.is_server():
		_info_sala_label.visible = true
		_info_sala_label.text = "Id de sala (compartelo con tu grupo): %s" % NetworkManager.steam_lobby_id
		_invitar_button.visible = true
		_iniciar_button.visible = true
		_esperando_label.visible = false
	else:
		_info_sala_label.visible = false
		_invitar_button.visible = false
		_iniciar_button.visible = false
		_esperando_label.visible = true
	if not multiplayer.peer_connected.is_connected(_on_lobby_peer_connected):
		multiplayer.peer_connected.connect(_on_lobby_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_lobby_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_lobby_peer_disconnected)
	_refrescar_lista_jugadores()
	_mostrar_panel(_panel_sala)

func _on_lobby_peer_connected(_id: int) -> void:
	_refrescar_lista_jugadores()

func _on_lobby_peer_disconnected(_id: int) -> void:
	_refrescar_lista_jugadores()

## Recalcula la lista entera desde multiplayer.get_peers() + el propio id en
## vez de ir sumando/restando entradas -- evita depender del orden exacto en
## que peer_connected llega respecto a connected_to_server al unirse (ver
## comentario de cabecera), un simple refresco completo es mas robusto.
func _refrescar_lista_jugadores() -> void:
	for hijo in _lista_jugadores.get_children():
		hijo.queue_free()
	var ids: Array = Array(multiplayer.get_peers())
	ids.append(multiplayer.get_unique_id())
	ids.sort()
	for id in ids:
		var etiqueta := "Jugador %d" % id
		if id == 1:
			etiqueta += " (host)"
		if id == multiplayer.get_unique_id():
			etiqueta += " (tu)"
		var label := Label.new()
		label.text = etiqueta
		_lista_jugadores.add_child(label)
	# Habilitado con 1 o mas jugadores conectados -- el propio host ya cuenta
	# como 1, asi que esto es "siempre habilitado" a proposito: debe poder
	# arrancar solo, para no romper el playtest de un unico peer que ya existe.
	if multiplayer.is_server():
		_iniciar_button.disabled = ids.is_empty()

func _on_invitar_pressed() -> void:
	if not multiplayer.is_server():
		return
	NetworkManager.invite_friends()

func _on_iniciar_pressed() -> void:
	if not multiplayer.is_server():
		return
	_iniciar_button.disabled = true
	NetworkManager.submit_iniciar_partida.rpc_id(1)

## game_started llega a TODOS los peers (host incluido, call_local) desde
## NetworkManager.confirm_iniciar_partida -- este es el unico punto de salida
## "con exito" del lobby.
func _on_game_started() -> void:
	_teardown_lobby_signals()
	finished.emit(true)

# =========================================================================
# Volver / cancelar
# =========================================================================

## Desde PanelUnirse antes de conectar (o tras un fallo de conexion): no hay
## sala que abandonar todavia, solo se vuelve a la eleccion de modo. Se
## desconecta por si acaso (defensivo: un intento de conexion podria seguir
## en curso en segundo plano).
func _volver_a_modo() -> void:
	NetworkManager.disconnect_game()
	_conectar_button.disabled = false
	_mostrar_panel(_panel_modo)

## Desde PanelSala (crear sala o ya conectado como cliente): desconecta
## limpio y sale del lobby de vuelta al titulo (ver main.gd _run_menu_flow).
func _volver_a_titulo() -> void:
	_teardown_lobby_signals()
	NetworkManager.disconnect_game()
	finished.emit(false)

## Desconecta las señales que este script conecto por su cuenta (ademas de
## las que NetworkManager.host_game/join_game ya gestionan solas) -- evita
## refrescar una lista de jugadores que ya no existe tras salir del lobby.
func _teardown_lobby_signals() -> void:
	if multiplayer.peer_connected.is_connected(_on_lobby_peer_connected):
		multiplayer.peer_connected.disconnect(_on_lobby_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_lobby_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_lobby_peer_disconnected)
