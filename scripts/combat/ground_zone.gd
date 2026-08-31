extends Area2D
class_name GroundZone
## Efecto de Zona colocado en el suelo (tecla Q) o generado por una
## combinacion de suelo. Siempre plano/visto desde arriba: este juego ya es
## top-down por defecto, asi que la restriccion de "sin perspectiva" del
## plan se cumple sin nada especial.
##
## Fuego: brasas persistentes, daño por segundo a quien las pise.
## Viento: torbellino, arrastra enemigos hacia el centro.
## Agua: charco, ralentiza. Rayo: chispas, daño por segundo. Tierra: terreno
## dificil, ralentiza (H6).
##
## Combinaciones de suelo (ver _check_ground_combo / _combo_id_for /
## _trigger_combo): Viento+Fuego = tormenta_ignea (radio y daño mayores que
## las dos zonas por separado -- la prueba de fuego del criterio de "hecho"
## de H1). H6 añade Rayo+Agua = charco_electrificado, Tierra+Agua = barro,
## Fuego+Agua = vapor_ciego, Viento+Tierra = polvo.

const GRUPO_ENEMIGOS := "enemigos"
const GRUPO_ZONAS := "zonas_suelo"
const TICK_INTERVAL := 0.5
## Cuanto dura activo slow_multiplier/cegado_restante en el enemigo tras
## refrescarse: mayor que un frame de physics para que no parpadee mientras
## sigue dentro, pero corto para que se note la salida de la zona casi al
## instante (mismo criterio que TICK_INTERVAL, pero por fotograma no por
## medio segundo -- el efecto de moverse/ver es continuo, el daño no).
const EFFECT_REFRESH_TIME := 0.25

@export var element: String = "fuego"
@export var radius: float = 90.0:
	set(value):
		radius = value
		if is_inside_tree():
			_apply_shape()
@export var duration: float = 6.0
## Default 0.0 a proposito (BUG encontrado en H6, no solo cosmetico): antes
## era 12.0, asi que cualquier Zona que no lo fijara explicitamente al
## instanciarla (el Torbellino de Viento, y ahora Agua/Tierra y las
## combinaciones barro/polvo, que no deben hacer daño) heredaba el mismo
## daño por segundo que las brasas de Fuego sin que nadie lo pidiera. Quien
## SI quiere daño (Fuego, Rayo, tormenta_ignea, charco_electrificado,
## vapor_ciego) ya lo fija explicito en player.gd/ground_zone.gd.
@export var damage_per_second: float = 0.0
## Tipo de daño que aplica damage_per_second (taxonomia de H2: cortante/
## contundente/quemadura/electrico/aplastamiento/veneno). Antes iba
## hardcodeado a "quemadura" en _apply_burn_tick porque solo Fuego lo usaba;
## H6 añade Rayo y las combinaciones (charco electrificado, vapor) con tipos
## distintos, asi que ahora lo fija quien coloca la zona.
@export var damage_type: String = "quemadura"
@export var pull_force: float = 0.0
## H6 (Agua/Tierra y sus combinaciones barro/polvo): multiplica la velocidad
## de los enemigos dentro. 1.0 = sin efecto. Ver _apply_slow().
@export var slow_factor: float = 1.0
## H6 (combinaciones vapor_ciego/polvo): mientras un enemigo este dentro,
## pierde de vista a los jugadores. Ver _apply_blind().
@export var blinds: bool = false
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
	if slow_factor < 1.0:
		_apply_slow()
	if blinds:
		_apply_blind()
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
			body.recibir_daño(damage_type, damage_per_second * TICK_INTERVAL)

func _apply_pull(delta: float) -> void:
	for body in get_overlapping_bodies():
		if body is Node2D and body.is_in_group(GRUPO_ENEMIGOS):
			body.global_position = body.global_position.move_toward(global_position, pull_force * delta)

## Charco/barro (Agua, Tierra, combinacion barro): ralentiza a los enemigos
## dentro. No hace falta guard de is_server() -- igual que _apply_pull, es
## movimiento determinista sobre el propio enemigo (host-autoritativo via
## enemy_simple.gd), no una mutacion de un recurso compartido.
func _apply_slow() -> void:
	for body in get_overlapping_bodies():
		if body.is_in_group(GRUPO_ENEMIGOS) and body.has_method("aplicar_slow"):
			body.aplicar_slow(slow_factor, EFFECT_REFRESH_TIME)

## Vapor/polvo (combinaciones Fuego+Agua y Viento+Tierra): ciega a los
## enemigos dentro mientras esten pisando la nube. Mismo criterio que
## _apply_slow -- se refresca cada frame que el enemigo sigue dentro.
func _apply_blind() -> void:
	for body in get_overlapping_bodies():
		if body is EnemigoSimple:
			body.cegado_restante = EFFECT_REFRESH_TIME

## Al colocar una Zona nueva, mira si se solapa con una Zona activa de otro
## elemento. H1 solo tenia Viento+Fuego; H6 completa el resto de la tabla del
## brief 2.1 (combinaciones de suelo): Rayo+Agua, Tierra+Agua, Fuego+Agua,
## Viento+Tierra. Se resuelve por pares en vez de un if/elif por combinacion
## para que añadir una combinacion nueva sea una entrada en _combo_id_for(),
## no un metodo _trigger_* entero duplicado.
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
		var combo_id := _combo_id_for(element, other.element)
		if combo_id != "":
			_trigger_combo(other, combo_id)
			return

## Nombre de la combinacion para el par de elementos, u "" si esos dos no
## combinan. Ordena el par antes de mirar la tabla para no tener que listar
## cada combinacion dos veces (A+B y B+A).
func _combo_id_for(elem_a: String, elem_b: String) -> String:
	var par := [elem_a, elem_b]
	par.sort()
	match "%s+%s" % [par[0], par[1]]:
		"fuego+viento":
			return "tormenta_ignea"
		"agua+rayo":
			return "charco_electrificado"
		"agua+tierra":
			return "barro"
		"agua+fuego":
			return "vapor_ciego"
		"tierra+viento":
			return "polvo"
		_:
			return ""

func _trigger_combo(other: GroundZone, combo_id: String) -> void:
	var a: GroundZone = self
	var b: GroundZone = other
	var storm_scene: PackedScene = preload("res://scenes/combat/zones/ground_zone.tscn")
	var storm: GroundZone = storm_scene.instantiate()
	# Configurar ANTES de add_child: _ready() lee is_combo/element de forma
	# sincrona nada mas entrar en el arbol para decidir si anima la
	# expansion o busca otra combinacion -- si se pone despues, _ready() ya
	# habria tomado la decision equivocada con los valores por defecto.
	storm.element = combo_id
	storm.is_combo = true
	match combo_id:
		"tormenta_ignea":
			var fuego_zone: GroundZone = a if a.element == "fuego" else b
			var viento_zone: GroundZone = a if a.element == "viento" else b
			storm.radius = max(fuego_zone.radius, viento_zone.radius) * 1.7
			storm.duration = max(fuego_zone.duration, viento_zone.duration) * 1.3
			storm.damage_per_second = max(fuego_zone.damage_per_second, 12.0) * 2.0
			storm.damage_type = "quemadura"
			storm.pull_force = viento_zone.pull_force * 0.5
		"charco_electrificado":
			# Rayo sobre Agua: el charco conduce, mas daño que cualquiera de
			# las dos zonas por separado -- misma logica de "la combinacion
			# pega mas fuerte que sus partes" que tormenta_ignea.
			storm.radius = max(a.radius, b.radius) * 1.5
			storm.duration = max(a.duration, b.duration) * 1.1
			storm.damage_per_second = 22.0
			storm.damage_type = "electrico"
		"barro":
			# Tierra sobre Agua: sin daño, solo ralentiza -- pero mas fuerte
			# y en area mayor que el charco de Agua base.
			storm.radius = max(a.radius, b.radius) * 1.6
			storm.duration = max(a.duration, b.duration) * 1.4
			storm.slow_factor = 0.25
		"vapor_ciego":
			# Fuego sobre Agua: quemadura leve (es vapor, no brasas) mas
			# ceguera -- el efecto real es que el enemigo deja de perseguir.
			storm.radius = max(a.radius, b.radius) * 1.4
			storm.duration = max(a.duration, b.duration)
			storm.damage_per_second = 5.0
			storm.damage_type = "quemadura"
			storm.blinds = true
		"polvo":
			# Viento sobre Tierra: nube ancha y breve, ciega y ralentiza un
			# poco (tierra removida) pero sin daño.
			storm.radius = max(a.radius, b.radius) * 1.8
			storm.duration = max(a.duration, b.duration) * 0.8
			storm.slow_factor = 0.7
			storm.blinds = true
	get_parent().add_child(storm)
	storm.global_position = a.global_position.lerp(b.global_position, 0.5)
	a.queue_free()
	b.queue_free()

func _draw() -> void:
	var color: Color
	match element:
		"fuego":
			color = Color(0.95, 0.35, 0.05, 0.35)
		"viento":
			color = Color(0.55, 0.85, 0.55, 0.30)
		"agua":
			color = Color(0.2, 0.55, 0.95, 0.35)
		"rayo":
			color = Color(0.95, 0.9, 0.25, 0.35)
		"tierra":
			color = Color(0.55, 0.4, 0.2, 0.4)
		"tormenta_ignea", "charco_electrificado", "vapor_ciego":
			# Pulso de color para que se note a simple vista que son
			# combinaciones, distintas de cualquier zona base.
			var pulse: float = 0.55 + 0.25 * sin(_elapsed * 6.0)
			match element:
				"tormenta_ignea":
					color = Color(1.0, 0.25, 0.0, pulse)
				"charco_electrificado":
					color = Color(0.3, 0.85, 1.0, pulse)
				_:
					color = Color(0.85, 0.85, 0.9, pulse * 0.8)
		"barro":
			color = Color(0.35, 0.24, 0.1, 0.55)
		"polvo":
			color = Color(0.75, 0.68, 0.5, 0.4)
		_:
			color = Color(0.8, 0.8, 0.8, 0.3)
	draw_circle(Vector2.ZERO, radius, color)
	if element == "tormenta_ignea" or element == "charco_electrificado":
		draw_circle(Vector2.ZERO, radius * 0.55, Color(1.0, 0.7, 0.1, 0.5) if element == "tormenta_ignea" else Color(0.7, 0.95, 1.0, 0.5))
