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
	else:
		draw_circle(Vector2.ZERO, 9.0, Color(1.0, 0.5, 0.1, 0.95))

func _on_body_entered(body: Node) -> void:
	if not (body is Node2D) or not body.is_in_group(GRUPO_ENEMIGOS):
		return
	if _hit_enemies.has(body):
		return
	if not multiplayer.is_server():
		# Los peers que no son host solo ven el proyectil volar; el daño
		# real lo decide el host, igual que el resto de acciones del plan.
		if not pierces:
			queue_free()
		return
	_hit_enemies.append(body)
	var damage_type := "quemadura" if element == "fuego" else "cortante"
	if explosion_radius > 0.0:
		_apply_explosion(body.global_position, damage_type)
	elif body.has_method("recibir_daño"):
		body.recibir_daño(damage_type, damage)
	if not pierces:
		queue_free()

func _apply_explosion(center: Vector2, damage_type: String) -> void:
	for enemigo in get_tree().get_nodes_in_group(GRUPO_ENEMIGOS):
		if enemigo is Node2D and enemigo.global_position.distance_to(center) <= explosion_radius:
			if enemigo.has_method("recibir_daño"):
				enemigo.recibir_daño(damage_type, damage)
