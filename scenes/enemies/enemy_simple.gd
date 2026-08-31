class_name EnemigoSimple
extends CharacterBody2D
## Enemigo de comportamiento simple para la sala de prueba (H1).
##
## IA mínima: patrulla entre dos puntos cuando no ve a ningún jugador,
## persigue al jugador más cercano si entra en el rango de detección,
## y ataca cuerpo a cuerpo con daño por temporizador cuando está en rango.
##
## Este script NO implementa red/multiplayer ni tipos de daño elemental.
## El sistema de combate real (estilos, daño elemental) se construye en otra
## tarea en paralelo y llamará a `recibir_daño(tipo_daño, cantidad)` para
## aplicar daño a este enemigo; aquí solo se resta la cantidad a la vida.

enum Estado { PATRULLA, PERSIGUE, ATACA }

## Nombre del grupo en el que deben registrarse los jugadores (add_to_group)
## para que este enemigo pueda detectarlos y perseguirlos.
const GRUPO_JUGADORES := "jugadores"

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

var vida_actual: float
var estado: Estado = Estado.PATRULLA
var objetivo_jugador: Node2D = null

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


func _physics_process(delta: float) -> void:
	if vida_actual <= 0.0:
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
	if vida_actual <= 0.0:
		return

	vida_actual -= cantidad
	daño_recibido.emit(cantidad, vida_actual)

	if vida_actual <= 0.0:
		morir()


func morir() -> void:
	murio.emit(self)
	queue_free()
