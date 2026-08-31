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
## Puntos de spawn de jugadores del mapa actual (Marker2D). Si esta vacio,
## los jugadores caen en (0,0) -- eso es lo que pasaba antes de fijar esto:
## (0,0) es la esquina de la sala de pruebas, la camara se centraba ahi y
## la mayor parte de la pantalla quedaba fuera de la sala (se veia vacio).
var spawn_points: Array[Node2D] = []

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
