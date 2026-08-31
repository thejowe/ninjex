extends Node
## Autoload (singleton "NetworkManager"). Arquitectura de red minima para H1:
## host-autoritativo desde el primer commit.
##
## Esta tanda solo se hace playtest con UN peer conectado como host, pero la
## arquitectura ya contempla un segundo actor: cualquier peer que se conecte
## a este servidor se spawnea automaticamente igual que el host.

const PORT := 7777
const MAX_PLAYERS := 4 # tope de diseno del juego completo (2-4 jugadores)

## Asignados por main.gd en _ready() antes de llamar a host_game().
var players_root: Node = null
var effects_root: Node = null
## Raiz donde EnemigoSimple instancia los cadaveres al morir (H2). Ver
## EnemigoSimple._spawn_cadaver().
var cadavers_root: Node = null
## Puntos de spawn de jugadores del mapa actual (Marker2D). Si esta vacio,
## los jugadores caen en (0,0) -- eso es lo que pasaba antes de fijar esto:
## (0,0) es la esquina de la sala de pruebas, la camara se centraba ahi y
## la mayor parte de la pantalla quedaba fuera de la sala (se veia vacio).
var spawn_points: Array[Node2D] = []

## Dinero "manchado" (H2): pool compartido entre todos los jugadores desde
## ya -- la votacion de boveda es H4, no esta implementada, pero no pasa
## nada por que el pool ya sea unico ahora mismo. Solo lo muta el host,
## siempre desde dentro de un RPC call_local (player.gd confirm_vender),
## asi que el valor llega igual a todos los peers sin necesitar su propio
## RPC de replicacion.
var dinero_manchado: float = 0.0

## Dinero "limpio" (H3): mismo patron de pool compartido que dinero_manchado
## de arriba -- se llena cambiando manchado en el Cambista (comision 15%,
## ver cambista.gd) y se apuesta en la Mesa de Dados (ver mesa_dados.gd).
## Solo lo muta el host, siempre desde dentro de un RPC call_local
## (player.gd confirm_cambiar_dinero / confirm_apostar_dados).
var dinero_limpio: float = 0.0

## Deuda con el Usurero (H4 recortado a solo el Usurero -- decision del
## usuario, sin votacion ni Modo Mesa Alta; ver usurero.gd para el trigger).
## Importe REAL pendiente de pagar (monto del prestamo + interes), no un
## contador de transacciones -- se muestra en negativo en el HUD (pedido
## explicito del usuario: "que salga el dinero en negativo") y baja con
## cada transaccion que genera dinero (venta exitosa o apuesta ganada)
## hasta llegar a 0. Solo lo muta el host, siempre desde dentro de un RPC
## call_local (player.gd confirm_pedir_prestamo_usurero/confirm_vender/
## confirm_apostar_dados), mismo patron que dinero_manchado/dinero_limpio.
var usurero_deuda_pendiente: float = 0.0

## Porcentaje de recorte vigente para la deuda activa de arriba, copiado del
## Usurero.recorte_porcentaje del nodo con el que se pidio el prestamo en el
## momento de pedirlo -- asi las transacciones que lo pagan despues no
## necesitan estar cerca de ningun Usurero ni volver a consultar el nodo.
var usurero_deuda_recorte_porcentaje: float = 0.0

## Contador de ids de cadaver, solo lo incrementa el host (siempre desde
## EnemigoSimple.recibir_daño(), que ya esta filtrado por
## is_multiplayer_authority()). El id resultante viaja como argumento del
## RPC morir() para que todos los peers instancien el cadaver con el mismo
## nombre de nodo -- sin esto no seria direccionable por NodePath despues.
var _next_cadaver_id: int = 1

func next_cadaver_id() -> int:
	_next_cadaver_id += 1
	return _next_cadaver_id - 1

## Nivel de Forja (H5 tarea 2) de CADA jugador -- peer_id -> nivel (0-3).
## A diferencia de dinero_manchado/dinero_limpio (pools compartidos), esto es
## POR JUGADOR: cada peer_id mejora su propia arma con dinero limpio del pool
## compartido. Sin entrada en el Dictionary == nivel 0 (sin mejorar). Solo lo
## muta el host, siempre desde dentro de un RPC call_local
## (player.gd confirm_mejorar_forja), mismo patron que el resto de estado
## compartido. Player._current_damage_multiplier() lo lee cada vez que
## calcula daño real.
var forja_nivel: Dictionary = {}

## Brindis de la Taberna (H5 tarea 4): buff de GRUPO temporal, activo para
## TODOS los jugadores conectados mientras dure -- Player._current_damage_multiplier()
## multiplica por brindis_damage_multiplier sin importar quien pago la ronda
## (brief seccion 4: "los bonus de comida y casa se aplican a todo el grupo,
## no solo a quien pago"). Arranca via el RPC call_local de Taberna (ver
## player.gd submit_brindis/confirm_brindis mas abajo); el contador en si se
## decrementa localmente en cada peer via _process() de este autoload -- no
## hace falta que el segundo exacto en que expira coincida entre peers, es
## un buff temporal de sabor, no un recurso compartido que se pueda gastar
## mal si diverge un frame.
var brindis_time_remaining: float = 0.0
var brindis_damage_multiplier: float = 1.0

func _process(delta: float) -> void:
	if brindis_time_remaining > 0.0:
		brindis_time_remaining -= delta
		if brindis_time_remaining <= 0.0:
			brindis_time_remaining = 0.0
			brindis_damage_multiplier = 1.0

## Confirma el brindis igual en todos los peers: descuenta el coste del pool
## compartido de dinero limpio y activa el buff de grupo. Vive aqui (en el
## autoload, no en player.gd) porque afecta a TODOS los jugadores conectados
## a la vez, no a un unico personaje -- a diferencia del resto de
## confirm_*() de esta tanda (Forja/Herboristeria), que son mejoras
## individuales y por eso viven en player.gd. Lo llama el host desde
## player.gd submit_brindis(), nunca el cliente directamente (mismo patron
## de confianza que el resto de confirm_* del proyecto: solo el submit_ que
## lo precede esta filtrado por multiplayer.is_server()+_validate_sender()).
@rpc("any_peer", "call_local", "reliable")
func confirm_brindis(nuevo_limpio: float, duracion: float, multiplicador: float) -> void:
	dinero_limpio = nuevo_limpio
	brindis_time_remaining = duracion
	brindis_damage_multiplier = multiplicador

func host_game() -> void:
	# multiplayer.multiplayer_peer NUNCA es null por defecto: Godot le pone un
	# OfflineMultiplayerPeer de por si. Comprobar "!= null" no detecta ese caso
	# y por tanto nunca deja pasar la primera llamada real.
	if not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		return
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		push_error("NetworkManager: no se pudo crear el servidor (error %s)" % err)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	# El host es siempre el peer 1 y se spawnea en cuanto el servidor existe,
	# sin esperar a peer_connected (esa senal no llega para uno mismo).
	_spawn_player(1)

func join_game(ip: String) -> void:
	if not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		return
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		push_error("NetworkManager: no se pudo crear el cliente hacia %s (error %s)" % [ip, err])
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	# No se spawnea aqui: el host detecta la conexion via peer_connected y
	# llama a _spawn_player, que replica al nuevo jugador a todos los peers
	# (incluido este cliente) via el MultiplayerSpawner.

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		_spawn_player(id)

func _on_peer_disconnected(id: int) -> void:
	if players_root == null:
		return
	var node := players_root.get_node_or_null(str(id))
	if node != null:
		node.queue_free()

func _spawn_player(id: int) -> void:
	if players_root == null:
		push_warning("NetworkManager: players_root no asignado todavia, no se puede spawnear peer %d" % id)
		return
	if players_root.has_node(str(id)):
		return
	var player_scene: PackedScene = preload("res://scenes/player/player.tscn")
	var player := player_scene.instantiate()
	player.name = str(id)
	# add_child en el servidor es lo que dispara la replicacion automatica
	# via el MultiplayerSpawner de la escena main (player.tscn esta en su
	# lista de escenas auto-spawneables).
	players_root.add_child(player, true)
	player.set_multiplayer_authority(id)
	player.global_position = _spawn_position_for(id)

func _spawn_position_for(id: int) -> Vector2:
	if spawn_points.is_empty():
		return Vector2.ZERO
	var index := (id - 1) % spawn_points.size()
	return spawn_points[index].global_position
