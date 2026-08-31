class_name EnemigoSimple
extends CharacterBody2D
## Enemigo de comportamiento simple para la sala de prueba (H1).
##
## IA mínima: patrulla entre dos puntos cuando no ve a ningún jugador,
## persigue al jugador más cercano si entra en el rango de detección,
## y ataca cuerpo a cuerpo con daño por temporizador cuando está en rango.
##
## Red: host-autoritativo, igual que player.gd pero sin fase submit_/confirm_
## previa porque nadie "pide" mover a un enemigo -- el host decide solo.
## La IA completa (_physics_process) corre unicamente si is_multiplayer_authority()
## (el enemigo es un nodo estatico de escena, autoridad por defecto = peer 1 =
## host). Position/vida_actual/estado se replican a los clientes via el
## MultiplayerSynchronizer de enemy_simple.tscn -- los clientes NUNCA simulan
## su propia copia, solo pintan lo que llega. recibir_daño() lo puede seguir
## llamando cualquier peer local (Basico, Proyectil, Impulso, Lanzamiento,
## _atacar), pero solo tiene efecto si quien llama es el host (mismo guard que
## usa player.gd en sus submit_*); la muerte se confirma via RPC (morir.rpc())
## para que queue_free() se ejecute igual en todos los peers, no solo en el
## host.
##
## El sistema de combate real (estilos, daño elemental) se construye en otra
## tarea en paralelo y llamará a `recibir_daño(tipo_daño, cantidad)` para
## aplicar daño a este enemigo; aquí solo se resta la cantidad a la vida.

enum Estado { PATRULLA, PERSIGUE, ATACA }

## Nombre del grupo en el que deben registrarse los jugadores (add_to_group)
## para que este enemigo pueda detectarlos y perseguirlos.
const GRUPO_JUGADORES := "jugadores"
## Grupo propio: asi Proyectil/Zona/Impulso/Agarre (tanda H1 7-11) encuentran
## enemigos sin acoplarse a esta clase concreta.
const GRUPO_ENEMIGOS := "enemigos"

@export_group("Vida")
@export var vida_maxima: float = 50.0

@export_group("Movimiento")
@export var velocidad_patrulla: float = 60.0
@export var velocidad_persecucion: float = 110.0

@export_group("Detección y ataque")
@export var rango_deteccion: float = 250.0
@export var rango_ataque: float = 40.0
@export var daño_ataque: float = 8.0
@export var cooldown_ataque: float = 1.0

@export_group("Economía (H2)")
## Valor base del cadaver antes de los multiplicadores de tipo de daño y de
## ponderacion del comprador (ver economia_cadaveres.gd / comprador.gd). Un
## numero simple por enemigo -- no hace falta un Resource aparte todavia,
## a diferencia de los estilos, que si necesitan iterarse en playtest.
@export var valor_cadaver_base: float = 20.0

var vida_actual: float
var estado: Estado = Estado.PATRULLA
var objetivo_jugador: Node2D = null
## Tipo de daño del ULTIMO golpe recibido antes de morir. El cadaver usa
## este valor, no el daño acumulado durante el combate (ver recibir_daño()):
## un golpe final de fuego carboniza el cuerpo aunque el resto de la pelea
## haya sido con cortes limpios.
var _ultimo_tipo_dano: String = "contundente"

## Jugador (Fisico) que tiene a este enemigo agarrado. Mientras no sea null,
## la IA se congela por completo y la posicion la controla quien agarra
## (ver player.gd _process_grab_hold). Lo pone/quita el host via las RPC de
## agarre/lanzamiento/suelta -- ver submit_grab_attempt / confirm_throw /
## confirm_release_grab en player.gd.
var agarrado_por: Node2D = null
## Tras un lanzamiento, breve ventana donde la IA no pisa el velocity del
## impacto (si no, _procesar_persecucion lo sobreescribe el mismo frame).
var _aturdido_restante: float = 0.0

var _tiempo_ataque_restante: float = 0.0
var _punto_patrulla_a: Vector2
var _punto_patrulla_b: Vector2
var _patrullando_hacia_b: bool = true

## Emitida cada vez que el enemigo recibe daño (para barras de vida, feedback, etc.).
signal daño_recibido(cantidad: float, vida_restante: float)
## Emitida justo antes de eliminar al enemigo de la escena.
signal murio(enemigo: Node2D)

@onready var _marcador_a: Marker2D = $PuntoPatrullaA
@onready var _marcador_b: Marker2D = $PuntoPatrullaB


func _ready() -> void:
	vida_actual = vida_maxima
	_punto_patrulla_a = _marcador_a.global_position if _marcador_a else global_position
	_punto_patrulla_b = _marcador_b.global_position if _marcador_b else global_position
	add_to_group(GRUPO_ENEMIGOS)


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		# Cliente: la posicion/vida/estado llegan por MultiplayerSynchronizer,
		# no se simula IA local (evitaria desincronizarse del host).
		return

	if vida_actual <= 0.0:
		return

	if agarrado_por != null:
		# Congelado mientras el Fisico lo sostiene: la posicion la fija
		# player.gd cada frame (agarre delante del jugador).
		velocity = Vector2.ZERO
		return

	if _aturdido_restante > 0.0:
		# Deja que el impulso del lanzamiento se vea antes de que la IA
		# retome el control (si no, _procesar_persecucion pisaria el
		# velocity del lanzamiento en el mismo frame).
		_aturdido_restante -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 800.0 * delta)
		move_and_slide()
		return

	objetivo_jugador = _buscar_jugador_mas_cercano()

	match estado:
		Estado.PATRULLA:
			_procesar_patrulla()
		Estado.PERSIGUE:
			_procesar_persecucion()
		Estado.ATACA:
			_procesar_ataque(delta)

	move_and_slide()


func _buscar_jugador_mas_cercano() -> Node2D:
	var jugadores := get_tree().get_nodes_in_group(GRUPO_JUGADORES)
	var mas_cercano: Node2D = null
	var distancia_minima: float = INF

	for jugador in jugadores:
		if not (jugador is Node2D):
			continue
		var distancia: float = global_position.distance_to(jugador.global_position)
		if distancia < distancia_minima:
			distancia_minima = distancia
			mas_cercano = jugador

	if mas_cercano != null and distancia_minima <= rango_deteccion:
		return mas_cercano
	return null


func _procesar_patrulla() -> void:
	if objetivo_jugador != null:
		estado = Estado.PERSIGUE
		return

	var destino: Vector2 = _punto_patrulla_b if _patrullando_hacia_b else _punto_patrulla_a
	if global_position.distance_to(destino) < 8.0:
		_patrullando_hacia_b = not _patrullando_hacia_b
		destino = _punto_patrulla_b if _patrullando_hacia_b else _punto_patrulla_a

	velocity = global_position.direction_to(destino) * velocidad_patrulla


func _procesar_persecucion() -> void:
	if objetivo_jugador == null:
		estado = Estado.PATRULLA
		velocity = Vector2.ZERO
		return

	var distancia: float = global_position.distance_to(objetivo_jugador.global_position)
	if distancia <= rango_ataque:
		estado = Estado.ATACA
		velocity = Vector2.ZERO
		return

	velocity = global_position.direction_to(objetivo_jugador.global_position) * velocidad_persecucion


func _procesar_ataque(delta: float) -> void:
	velocity = Vector2.ZERO

	if objetivo_jugador == null:
		estado = Estado.PATRULLA
		return

	var distancia: float = global_position.distance_to(objetivo_jugador.global_position)
	if distancia > rango_ataque:
		estado = Estado.PERSIGUE
		return

	_tiempo_ataque_restante -= delta
	if _tiempo_ataque_restante <= 0.0:
		_tiempo_ataque_restante = cooldown_ataque
		_atacar(objetivo_jugador)


func _atacar(jugador: Node2D) -> void:
	# Daño por contacto simple. Se asume que el jugador expondrá la misma
	# interfaz recibir_daño(tipo_daño, cantidad); si todavía no existe,
	# el ataque no hace nada (evita errores mientras esa parte se construye
	# en paralelo).
	if jugador.has_method("recibir_daño"):
		jugador.recibir_daño("fisico", daño_ataque)


## Interfaz pública que usará el sistema de combate real (estilos, daño
## elemental). De momento solo resta `cantidad` a la vida; no procesa
## `tipo_daño` (resistencias, tipos elementales, etc. no son parte de esta
## tarea).
func recibir_daño(tipo_daño: String, cantidad: float) -> void:
	if not is_multiplayer_authority():
		# Solo el host aplica daño real; a los clientes les llega el
		# vida_actual resultante via el MultiplayerSynchronizer.
		return
	if vida_actual <= 0.0:
		return

	vida_actual -= cantidad
	# H2: se trackea el tipo del golpe que acaba de llegar en CADA llamada
	# (no solo la que mata) para que, cuando toque morir un par de lineas
	# mas abajo, este siempre sea el tipo del golpe final real.
	_ultimo_tipo_dano = tipo_daño
	daño_recibido.emit(cantidad, vida_actual)

	if vida_actual <= 0.0:
		# El id lo genera el host UNA vez aqui y viaja como argumento del RPC
		# -- asi todos los peers instancian el cadaver con el mismo nombre de
		# nodo (ver _spawn_cadaver), en vez de que cada uno intente generar
		# su propio id y se desincronicen.
		morir.rpc(NetworkManager.next_cadaver_id(), _ultimo_tipo_dano)


## Solo el host decide morir (llamado desde recibir_daño), pero el RPC se
## retransmite a todos los peers para que queue_free() borre el enemigo en
## todos por igual -- si no, los clientes se quedan con un cadaver fantasma
## que ya no recibe posicion/vida nuevas del synchronizer.
## H2: ademas de borrar al enemigo, deja un Cadaver en su lugar -- ver
## _spawn_cadaver(). Se hace aqui (dentro del mismo RPC call_local) en vez
## de en un RPC aparte porque morir() ya corre identico en todos los peers;
## no hace falta coordinacion extra para que el spawn tambien lo haga.
@rpc("any_peer", "call_local", "reliable")
func morir(cadaver_id: int, tipo_dano_final: String) -> void:
	murio.emit(self)
	_spawn_cadaver(cadaver_id, tipo_dano_final)
	queue_free()


## Instancia el Cadaver igual en todos los peers. No hay MultiplayerSpawner
## para esto (los cadaveres nacen en posiciones variables, no se pueden
## pre-registrar como el jugador) -- en vez de eso se aprovecha que morir()
## ya es un RPC call_local reliable: basta con que el nombre del nodo
## (via cadaver_id) coincida en todos los peers para que sea direccionable
## despues por NodePath, igual que ya hace el Agarre del Fisico con los
## propios enemigos (ver grabbed_enemy_path en player.gd).
func _spawn_cadaver(cadaver_id: int, tipo_dano_final: String) -> void:
	var root: Node = NetworkManager.cadavers_root
	if root == null:
		push_warning("EnemigoSimple: cadavers_root no asignado, no se puede spawnear el cadaver")
		return
	var scene: PackedScene = preload("res://scenes/cadavers/cadaver.tscn")
	var cadaver: Cadaver = scene.instantiate()
	# Configurar ANTES de add_child: Cadaver._ready() lee estado_conservacion
	# para elegir el color de debug nada mas entrar en el arbol.
	cadaver.estado_conservacion = tipo_dano_final
	cadaver.valor_base = valor_cadaver_base
	cadaver.name = "cadaver_%d" % cadaver_id
	root.add_child(cadaver)
	cadaver.global_position = global_position


## Lanzamiento del Fisico (ranura Zona sustituida): lo llama confirm_throw()
## en player.gd cuando el host confirma el lanzamiento. Suelta el agarre,
## empuja al enemigo hacia `direccion` y aplica dano de tipo "aplastamiento"
## (coincide con la taxonomia de danos de H2: cortante/contundente/quemadura/
## electrico/aplastamiento/veneno -- deja el terreno preparado para esa
## tanda aunque el estado de conservacion del cadaver no exista todavia).
## Nota de diseno emergente: si el enemigo aterriza sobre una GroundZone al
## ser empujado, la propia Area2D de la zona lo detecta igual que a
## cualquier otro cuerpo -- asi se cumple sin codigo extra que "el Fisico es
## el unico que puede meter enemigos dentro de las zonas de otros".
func lanzar(direccion: Vector2, velocidad: float, daño: float) -> void:
	agarrado_por = null
	_aturdido_restante = 0.35
	velocity = direccion * velocidad
	recibir_daño("aplastamiento", daño)
