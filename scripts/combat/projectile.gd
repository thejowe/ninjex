extends Area2D
class_name Projectile
## Proyectil de Fuego o Viento (clic derecho). Se instancia igual en todos
## los peers via confirm_projectile_attack() en player.gd; el daño solo lo
## aplica el host (multiplayer.is_server()) para no duplicarlo el dia que
## los enemigos tengan su propia replicacion -- hoy con 1 solo peer host es
## el unico jugador, asi que esto ya es correcto sin cambios.
##
## Fuego: bola que estalla al impactar (daño en area, se destruye).
## Viento: cuchilla de aire que atraviesa varios enemigos en linea, no se
## destruye al primer impacto (pierces = true), sigue hasta el alcance
## maximo.

const GRUPO_ENEMIGOS := "enemigos"

@export var element: String = "fuego"
@export var speed: float = 500.0
@export var damage: float = 14.0
@export var max_distance: float = 600.0
## Fuego: radio de la explosion al impactar. 0 = golpe puntual (viento).
@export var explosion_radius: float = 0.0
## Viento: no se destruye al primer impacto, atraviesa varios enemigos.
@export var pierces: bool = false
## Peer que disparo este proyectil (get_multiplayer_authority() del jugador
## que lo lanzo, fijado por player.gd al instanciar). Solo se usa para el
## screen shake local del propio tirador al conectar -- no cambia el calculo
## de daño, que sigue siendo exclusivo del host (multiplayer.is_server()).
@export var shooter_peer_id: int = 0

## Direccion normalizada de vuelo, la fija quien lo instancia (player.gd).
var direction: Vector2 = Vector2.RIGHT

var _traveled: float = 0.0
var _hit_enemies: Array = []

func _ready() -> void:
	rotation = direction.angle()
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _physics_process(delta: float) -> void:
	var step: Vector2 = direction * speed * delta
	global_position += step
	_traveled += step.length()
	queue_redraw()
	if _traveled >= max_distance:
		queue_free()

func _draw() -> void:
	if element == "viento":
		# Forma alargada para sugerir "cuchilla de aire".
		draw_rect(Rect2(-4.0, -14.0, 34.0, 28.0), Color(0.75, 0.95, 0.78, 0.9), true)
	elif element == "rayo":
		# Igual de alargado que Viento (tambien pierces = true, "cadena"),
		# pero color/tono distinto para no confundirlos a simple vista.
		draw_rect(Rect2(-4.0, -12.0, 30.0, 24.0), Color(0.95, 0.9, 0.3, 0.95), true)
	elif element == "agua":
		draw_circle(Vector2.ZERO, 7.0, Color(0.25, 0.6, 0.95, 0.95))
	elif element == "tierra":
		# Roca: mas grande que el resto (explosion_radius > 0, golpe pesado).
		draw_circle(Vector2.ZERO, 12.0, Color(0.5, 0.38, 0.2, 0.95))
	else:
		draw_circle(Vector2.ZERO, 9.0, Color(1.0, 0.5, 0.1, 0.95))

func _on_body_entered(body: Node) -> void:
	if not (body is Node2D) or not body.is_in_group(GRUPO_ENEMIGOS):
		return
	if _hit_enemies.has(body):
		return
	# El impacto se detecta localmente en CADA peer (fisica local sobre la
	# posicion ya sincronizada del enemigo), no solo en el host -- por eso el
	# screen shake del tirador se puede disparar aqui sin esperar a ningun
	# RPC de vuelta, tanto si el tirador es el host como si es un cliente.
	_trigger_shooter_shake()
	if not multiplayer.is_server():
		# Los peers que no son host solo ven el proyectil volar; el daño
		# real lo decide el host, igual que el resto de acciones del plan.
		if not pierces:
			queue_free()
		return
	_hit_enemies.append(body)
	var damage_type := _damage_type_for_element()
	if explosion_radius > 0.0:
		_apply_explosion(body.global_position, damage_type)
	elif body.has_method("recibir_daño"):
		body.recibir_daño(damage_type, damage)
	if not pierces:
		queue_free()

## Screen shake local (leve) del jugador que disparo este proyectil, si
## coincide con este peer -- ver comentario de shooter_peer_id arriba.
func _trigger_shooter_shake() -> void:
	if shooter_peer_id == 0 or shooter_peer_id != multiplayer.get_unique_id():
		return
	var players_root: Node = NetworkManager.players_root
	if players_root == null:
		return
	var shooter := players_root.get_node_or_null(str(shooter_peer_id))
	if shooter != null and shooter.has_method("trigger_hit_shake"):
		shooter.trigger_hit_shake()

## Taxonomia de H2 (cortante/contundente/quemadura/electrico/aplastamiento/
## veneno): antes solo Fuego/Viento existian, ahora cada estilo de H6 mapea
## a un tipo distinto para que el estado de conservacion del cadaver siga
## reflejando con que estilo se dio el golpe final.
func _damage_type_for_element() -> String:
	match element:
		"fuego":
			return "quemadura"
		"viento":
			return "cortante"
		"rayo":
			return "electrico"
		"agua":
			return "veneno"
		"tierra":
			return "aplastamiento"
		_:
			return "contundente"

func _apply_explosion(center: Vector2, damage_type: String) -> void:
	for enemigo in get_tree().get_nodes_in_group(GRUPO_ENEMIGOS):
		if enemigo is Node2D and enemigo.global_position.distance_to(center) <= explosion_radius:
			if enemigo.has_method("recibir_daño"):
				enemigo.recibir_daño(damage_type, damage)
