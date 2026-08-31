extends Area2D
class_name GroundZone
## Efecto de Zona colocado en el suelo (tecla Q) o generado por una
## combinacion de suelo. Siempre plano/visto desde arriba: este juego ya es
## top-down por defecto, asi que la restriccion de "sin perspectiva" del
## plan se cumple sin nada especial.
##
## Fuego: brasas persistentes, daño por segundo a quien las pise.
## Viento: torbellino, arrastra enemigos hacia el centro.
## "tormenta_ignea": combinacion viento-sobre-fuego (ver _check_ground_combo
## / _trigger_tormenta_ignea) -- radio mayor y daño mayor que cualquiera de
## las dos zonas por separado, con color/animacion claramente distintos.
## Es la prueba de fuego del criterio de "hecho" de H1.

const GRUPO_ENEMIGOS := "enemigos"
const GRUPO_ZONAS := "zonas_suelo"
const TICK_INTERVAL := 0.5

@export var element: String = "fuego"
@export var radius: float = 90.0:
	set(value):
		radius = value
		if is_inside_tree():
			_apply_shape()
@export var duration: float = 6.0
@export var damage_per_second: float = 12.0
@export var pull_force: float = 0.0
## true si esta zona nacio de una combinacion: no vuelve a buscar mas
## combos (evita encadenar tormentas sobre tormentas) y se anima
## "expandiendose" al nacer.
@export var is_combo: bool = false
## false para los fragmentos de rastro del Impulso de fuego: pasar de
## refilon por una zona ajena no debe disparar la combinacion.
@export var participates_in_combo: bool = true

var _elapsed: float = 0.0
var _tick_accum: float = 0.0

@onready var _collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group(GRUPO_ZONAS)
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1
	_apply_shape()
	if is_combo:
		scale = Vector2(0.5, 0.5)
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector2.ONE, 0.9)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	elif participates_in_combo:
		call_deferred("_check_ground_combo")
	queue_redraw()

func _apply_shape() -> void:
	if _collision == null:
		return
	var shape := _collision.shape as CircleShape2D
	if shape == null:
		shape = CircleShape2D.new()
		_collision.shape = shape
	shape.radius = radius

func _physics_process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _elapsed >= duration:
		queue_free()
		return
	if pull_force > 0.0:
		_apply_pull(delta)
	_tick_accum += delta
	if _tick_accum >= TICK_INTERVAL:
		_tick_accum -= TICK_INTERVAL
		if damage_per_second > 0.0:
			_apply_burn_tick()

func _apply_burn_tick() -> void:
	if not multiplayer.is_server():
		return # el danio siempre lo decide el host, igual que el resto del plan
	for body in get_overlapping_bodies():
		if body.is_in_group(GRUPO_ENEMIGOS) and body.has_method("recibir_daño"):
			body.recibir_daño("quemadura", damage_per_second * TICK_INTERVAL)

func _apply_pull(delta: float) -> void:
	for body in get_overlapping_bodies():
		if body is Node2D and body.is_in_group(GRUPO_ENEMIGOS):
			body.global_position = body.global_position.move_toward(global_position, pull_force * delta)

## Al colocar una Zona nueva, mira si se solapa con una Zona activa de otro
## elemento. Con los 3 estilos de H1 la unica combinacion posible es Viento
## sobre Fuego -> tormenta ignea (las demas del diseno completo llegan con
## Agua/Rayo/Tierra en H6).
func _check_ground_combo() -> void:
	if not is_instance_valid(self) or is_queued_for_deletion():
		return
	for other in get_tree().get_nodes_in_group(GRUPO_ZONAS):
		if other == self or not (other is GroundZone):
			continue
		if other.is_combo or other.element == element:
			continue
		if global_position.distance_to(other.global_position) > radius + other.radius:
			continue
		if (element == "viento" and other.element == "fuego") or (element == "fuego" and other.element == "viento"):
			_trigger_tormenta_ignea(other)
			return

func _trigger_tormenta_ignea(other: GroundZone) -> void:
	var fuego_zone: GroundZone = self if element == "fuego" else other
	var viento_zone: GroundZone = self if element == "viento" else other
	var storm_scene: PackedScene = preload("res://scenes/combat/zones/ground_zone.tscn")
	var storm: GroundZone = storm_scene.instantiate()
	# Configurar ANTES de add_child: _ready() lee is_combo/element de forma
	# sincrona nada mas entrar en el arbol para decidir si anima la
	# expansion o busca otra combinacion -- si se pone despues, _ready() ya
	# habria tomado la decision equivocada con los valores por defecto.
	storm.element = "tormenta_ignea"
	storm.radius = max(fuego_zone.radius, viento_zone.radius) * 1.7
	storm.duration = max(fuego_zone.duration, viento_zone.duration) * 1.3
	storm.damage_per_second = max(fuego_zone.damage_per_second, 12.0) * 2.0
	storm.pull_force = viento_zone.pull_force * 0.5
	storm.is_combo = true
	get_parent().add_child(storm)
	storm.global_position = fuego_zone.global_position.lerp(viento_zone.global_position, 0.5)
	fuego_zone.queue_free()
	viento_zone.queue_free()

func _draw() -> void:
	var color: Color
	match element:
		"fuego":
			color = Color(0.95, 0.35, 0.05, 0.35)
		"viento":
			color = Color(0.55, 0.85, 0.55, 0.30)
		"tormenta_ignea":
			# Pulso de color para que se note a simple vista que es otra
			# cosa distinta de una brasa o un torbellino normales.
			var pulse: float = 0.55 + 0.25 * sin(_elapsed * 6.0)
			color = Color(1.0, 0.25, 0.0, pulse)
		_:
			color = Color(0.8, 0.8, 0.8, 0.3)
	draw_circle(Vector2.ZERO, radius, color)
	if element == "tormenta_ignea":
		draw_circle(Vector2.ZERO, radius * 0.55, Color(1.0, 0.7, 0.1, 0.5))
