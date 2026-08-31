extends CharacterBody2D
## Jugador. H1 tareas 3-6 (movimiento, apuntado, Basico encadenable, chakra)
## + tareas 7-11 de esta tanda: Proyectil/Agarre, Zona/Lanzamiento, Impulso,
## Fisico completo con Puertas, y el enganche de las combinaciones de suelo
## (la logica de la combinacion en si vive en ground_zone.gd; aqui solo se
## colocan las Zonas).
##
## Red: mismo patron ya establecido por el Basico -- el cliente pide la
## accion via rpc_id(1, ...), el HOST valida (multiplayer.is_server(), que
## quien pide sea el dueno del personaje) y calcula el resultado
## autoritativo, y luego confirma con un segundo RPC (@rpc("any_peer",
## "call_local","reliable")) que aplica el resultado igual en todos los
## peers. Sigue sin haber reconciliacion/rollback: con 1 solo peer
## conectado (este playtest) host y jugador son el mismo peer -- con un
## segundo jugador real el flujo ya esta listo.
##
## Ayuda de playtest, NO es una mecanica real del juego: las teclas 1/2/3
## cambian el estilo del propio jugador en caliente (Fuego/Viento/Fisico).
## Sirve para poder probar los tres estilos -- incluida la combinacion
## Viento sobre Fuego -- con un solo teclado conectado. La eleccion de
## estilo real (pantalla del hub) es tarea futura y no tiene nada que ver
## con esto.

const SPEED := 220.0
const DEFAULT_STYLE_PATH := "res://resources/styles/fuego.tres"
const GRUPO_JUGADORES := "jugadores"
const GRUPO_ENEMIGOS := "enemigos"

@export var style_data: StyleData

@onready var _legs: Node2D = $Visuals/Legs
@onready var _torso: Node2D = $Visuals/Torso
@onready var _camera: Camera2D = $Camera2D

## Chakra actual. Lo fija el host via confirm_*(); nunca sube solo con el
## tiempo (no hay _process que lo regenere). En Fisico se queda siempre a 0
## (chakra_max = 0 en su StyleData): no tiene Proyectil ni Zona que gastarlo.
var chakra_current: float = 0.0
## Golpe actual dentro de la cadena del Basico (0 = sin combo activo).
var combo_count: int = 0
## Vida del jugador. No existia hasta esta tanda (los enemigos ya llamaban
## a recibir_daño() pero el metodo no existia, asi que nunca hacian nada).
## Se anade aqui porque las Puertas del Fisico necesitan un concepto de
## vida real para el drenaje y la vulnerabilidad; no incluye muerte ni
## respawn de jugador, eso queda fuera de esta tanda.
var vida_actual: float = 100.0

var _combo_window_timer: float = 0.0

# --- Proyectil (Fuego/Viento) / Agarre (Fisico) ---
## NodePath absoluto (get_path()) al enemigo agarrado, o vacio si ninguno.
## Los enemigos no estan en red todavia (son estaticos en TestRoom, iguales
## en todos los peers), asi que un NodePath absoluto resuelve al mismo nodo
## local en cada peer -- el mismo truco que ya usa el Basico al mandar un
## Vector2 de impacto en vez de una referencia de nodo.
var grabbed_enemy_path: NodePath = NodePath("")

# --- Zona (Fuego/Viento) / Lanzamiento (Fisico) ---
var _zone_charging: bool = false
var _zone_charge_time: float = 0.0
var _zone_preview: Node2D = null

# --- Impulso ---
var _impulse_cooldown_remaining: float = 0.0
var _impulse_active_time: float = 0.0
var _impulse_from: Vector2
var _impulse_to: Vector2
## Viento: mientras > 0, el jugador ignora colisiones (salto largo que
## ignora desniveles).
var _collision_ignore_remaining: float = 0.0

# --- Puertas (solo Fisico) ---
## 0 = cerradas. 1-3 = nivel actual. Lo fija el host via confirm_puertas_*()
## para que sea el mismo valor que usan submit_throw/submit_impulse al
## calcular danio (ver _current_damage_multiplier).
var puertas_nivel: int = 0
var _puertas_tiempo_en_nivel: float = 0.0
var _puertas_tiempo_abierto_total: float = 0.0
## Vulnerabilidad tras cerrar las Puertas: mientras > 0, el danio recibido
## se multiplica por _vulnerabilidad_multiplicador.
var _vulnerabilidad_restante: float = 0.0
var _vulnerabilidad_multiplicador: float = 1.0

# --- Potenciador (E) -- recibido de un aliado, nunca de uno mismo ---
## "" = sin buff activo, o "fuego"/"viento" segun quien lo lanzo.
var _potenciador_active_element: String = ""
var _potenciador_time_remaining: float = 0.0
## Peer id de quien lo lanzo. Se usa para el bonus de Fisico (devolver
## chakra tras un Agarre exitoso).
var _potenciador_caster_id: int = 0
## Bonus de dano del Basico mientras el buff de Fuego este activo.
var _potenciador_damage_bonus: float = 0.0
var _potenciador_dash_active_time: float = 0.0
var _potenciador_dash_total_time: float = 0.0
var _potenciador_dash_from: Vector2
var _potenciador_dash_to: Vector2

func _ready() -> void:
	if style_data == null:
		style_data = load(DEFAULT_STYLE_PATH)
	_apply_style_reset()
	# Sin esto, los enemigos nunca encontraban a ningun jugador: su
	# _buscar_jugador_mas_cercano() ya buscaba en este grupo desde la tanda
	# anterior, pero nadie se registraba en el. Tambien lo necesita el
	# cono de Agarre del Fisico y el Basico para saber a quien golpean.
	add_to_group(GRUPO_JUGADORES)
	if is_multiplayer_authority():
		_camera.enabled = true
		_camera.make_current()

## Reinicia todo el estado dependiente de estilo. Se llama al arrancar y
## cada vez que el debug de playtest cambia de estilo en caliente.
func _apply_style_reset() -> void:
	chakra_current = 0.0
	vida_actual = style_data.vida_maxima
	combo_count = 0
	puertas_nivel = 0
	_puertas_tiempo_en_nivel = 0.0
	_puertas_tiempo_abierto_total = 0.0
	_vulnerabilidad_restante = 0.0
	_vulnerabilidad_multiplicador = 1.0
	_impulse_cooldown_remaining = 0.0
	_impulse_active_time = 0.0
	_collision_ignore_remaining = 0.0
	_potenciador_active_element = ""
	_potenciador_time_remaining = 0.0
	_potenciador_caster_id = 0
	_potenciador_damage_bonus = 0.0
	_potenciador_dash_active_time = 0.0
	set_collision_mask_value(1, true)
	if _zone_preview != null:
		_zone_preview.queue_free()
		_zone_preview = null
	_zone_charging = false
	grabbed_enemy_path = NodePath("")

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		_handle_debug_style_switch()
		_handle_combo_timer(delta)
		_handle_vulnerability(delta)
		_handle_impulse_cooldown(delta)
		_handle_collision_ignore(delta)
		_handle_potenciador_timer(delta)
		_process_impulse_motion(delta)
		_process_potenciador_dash(delta)
		_handle_movement()
		_handle_aim()
		if style_data.melee_only:
			_handle_puertas(delta)
		_handle_zone_input(delta)
		_process_grab_hold()
		if Input.is_action_just_pressed("attack_basic"):
			_request_basic_attack()
		if Input.is_action_just_pressed("attack_projectile"):
			if style_data.melee_only:
				_request_grab()
			else:
				_request_projectile_attack()
		if Input.is_action_just_pressed("impulse") and _impulse_cooldown_remaining <= 0.0 and _impulse_active_time <= 0.0:
			_request_impulse()
		if Input.is_action_just_pressed("potenciador") and not style_data.melee_only:
			_request_potenciador()
	move_and_slide()

func _handle_movement() -> void:
	if _impulse_active_time > 0.0 or _potenciador_dash_active_time > 0.0:
		# El Impulso (y el dash del Potenciador de Viento) mueven al jugador
		# directamente por posicion; el WASD no debe pelearse con el dash.
		velocity = Vector2.ZERO
		return
	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if input_dir.length() > 0.0:
		input_dir = input_dir.normalized()
		_legs.rotation = input_dir.angle()
	velocity = input_dir * SPEED * _current_speed_multiplier()

func _handle_aim() -> void:
	var to_cursor := get_global_mouse_position() - global_position
	if to_cursor.length() > 0.001:
		_torso.rotation = to_cursor.angle()

func _handle_combo_timer(delta: float) -> void:
	if combo_count > 0:
		_combo_window_timer -= delta
		if _combo_window_timer <= 0.0:
			combo_count = 0

func _handle_vulnerability(delta: float) -> void:
	if _vulnerabilidad_restante > 0.0:
		_vulnerabilidad_restante -= delta
		if _vulnerabilidad_restante <= 0.0:
			_vulnerabilidad_multiplicador = 1.0

func _handle_impulse_cooldown(delta: float) -> void:
	if _impulse_cooldown_remaining > 0.0:
		_impulse_cooldown_remaining -= delta

func _handle_collision_ignore(delta: float) -> void:
	if _collision_ignore_remaining > 0.0:
		_collision_ignore_remaining -= delta
		if _collision_ignore_remaining <= 0.0:
			set_collision_mask_value(1, true)

## Prediccion local (igual que el resto de timers de estado): cuenta atras
## del buff recibido. No hace falta ir al host, solo apaga el flag local.
func _handle_potenciador_timer(delta: float) -> void:
	if _potenciador_time_remaining > 0.0:
		_potenciador_time_remaining -= delta
		if _potenciador_time_remaining <= 0.0:
			_potenciador_active_element = ""
			_potenciador_caster_id = 0
			_potenciador_damage_bonus = 0.0

func _process_potenciador_dash(delta: float) -> void:
	if _potenciador_dash_active_time <= 0.0:
		return
	_potenciador_dash_active_time -= delta
	var t: float = 1.0 - clamp(_potenciador_dash_active_time / max(_potenciador_dash_total_time, 0.001), 0.0, 1.0)
	global_position = _potenciador_dash_from.lerp(_potenciador_dash_to, t)
	if _potenciador_dash_active_time <= 0.0:
		global_position = _potenciador_dash_to

## Ayuda de playtest solo local (no pasa por red): cambia style_data del
## propio jugador. Ver comentario de cabecera.
func _handle_debug_style_switch() -> void:
	var new_path := ""
	if Input.is_action_just_pressed("debug_style_fuego"):
		new_path = "res://resources/styles/fuego.tres"
	elif Input.is_action_just_pressed("debug_style_viento"):
		new_path = "res://resources/styles/viento.tres"
	elif Input.is_action_just_pressed("debug_style_fisico"):
		new_path = "res://resources/styles/fisico.tres"
	if new_path != "":
		style_data = load(new_path)
		_apply_style_reset()

func _current_speed_multiplier() -> float:
	if not style_data.melee_only or puertas_nivel <= 0:
		return 1.0
	return 1.0 + puertas_nivel * style_data.puertas_speed_multiplier_per_level

func _current_damage_multiplier() -> float:
	if not style_data.melee_only or puertas_nivel <= 0:
		return 1.0
	return 1.0 + puertas_nivel * style_data.puertas_damage_multiplier_per_level

## Con las Puertas abiertas, cualquier Potenciador que este jugador reciba
## dura el doble. Usado por submit_potenciador() del que lo lanza.
func potenciador_duration_multiplier() -> float:
	if style_data.melee_only and puertas_nivel > 0:
		return style_data.puertas_potenciador_duration_multiplier
	return 1.0

func _basic_damage_type() -> String:
	match style_data.element_name:
		"fuego":
			return "quemadura"
		"viento":
			return "cortante"
		"fisico":
			return "contundente"
		_:
			return "contundente"

## Enemigos dentro de un cono estrecho frente a `facing_dir`, usado tanto
## por el Basico (arco corto) como por el Agarre del Fisico (autoapuntado
## suave: no hace falta apuntar con precision, basta con encarar mas o
## menos al objetivo).
func _find_enemies_in_cone(range_max: float, cone_degrees: float, facing_dir: Vector2) -> Array:
	var result: Array = []
	var half_angle: float = deg_to_rad(cone_degrees * 0.5)
	for enemigo in get_tree().get_nodes_in_group(GRUPO_ENEMIGOS):
		if not (enemigo is Node2D):
			continue
		var to_enemy: Vector2 = enemigo.global_position - global_position
		var dist: float = to_enemy.length()
		if dist > range_max or dist < 0.001:
			continue
		if abs(facing_dir.angle_to(to_enemy)) <= half_angle:
			result.append(enemigo)
	return result

## Igual que _find_enemies_in_cone pero sobre el grupo de jugadores,
## excluyendose a si mismo -- el Potenciador nunca se lo lanza uno a si
## mismo (brief 2.1).
func _find_allies_in_cone(range_max: float, cone_degrees: float, facing_dir: Vector2) -> Array:
	var result: Array = []
	var half_angle: float = deg_to_rad(cone_degrees * 0.5)
	for jugador in get_tree().get_nodes_in_group(GRUPO_JUGADORES):
		if jugador == self or not (jugador is Node2D):
			continue
		var to_ally: Vector2 = jugador.global_position - global_position
		var dist: float = to_ally.length()
		if dist > range_max or dist < 0.001:
			continue
		if abs(facing_dir.angle_to(to_ally)) <= half_angle:
			result.append(jugador)
	return result

func _get_grabbed_enemy() -> EnemigoSimple:
	if grabbed_enemy_path == NodePath(""):
		return null
	return get_node_or_null(grabbed_enemy_path) as EnemigoSimple

func _validate_sender() -> bool:
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id() # llamada local del propio host
	return sender_id == get_multiplayer_authority()

## Pedido del cliente que controla este personaje. Se manda siempre al host
## (peer 1); si el peer local YA es el host, Godot resuelve la llamada en
## local sin red de por medio.
func _request_basic_attack() -> void:
	var aim_point := get_global_mouse_position()
	submit_basic_attack.rpc_id(1, aim_point)

## Se ejecuta SOLO en el host (autoridad de la accion). Valida que quien
## pide el golpe es el dueno de este personaje, calcula el resultado
## (combo + chakra recuperada + si toca soltar etiqueta + danio real a los
## enemigos en el arco) y lo retransmite a todos los peers, incluido el que
## lo pidio.
@rpc("any_peer", "call_local", "reliable")
func submit_basic_attack(aim_point: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id() # llamada local del propio host
	if sender_id != get_multiplayer_authority():
		return # alguien pidiendo un golpe con un personaje que no controla

	var next_combo := (combo_count % 3) + 1
	var recovered: float = style_data.chakra_recovered_per_hit
	var new_chakra: float = min(chakra_current + recovered, style_data.chakra_max)
	var spawn_tag := next_combo == 3

	# Danio real del golpe -- la tanda anterior dejaba el Basico sin pegar a
	# nadie (solo combo+chakra); se completa aqui porque sin esto el
	# combate entero no se puede probar de verdad. Mismo cono que el Agarre.
	var facing_dir: Vector2 = aim_point - global_position
	if facing_dir.length() < 0.001:
		facing_dir = Vector2.RIGHT.rotated(_torso.rotation)
	facing_dir = facing_dir.normalized()
	var targets := _find_enemies_in_cone(style_data.basic_range, style_data.basic_cone_degrees, facing_dir)
	var damage_type := _basic_damage_type()
	var damage: float = style_data.basic_damage * _current_damage_multiplier()
	# Potenciador de Fuego recibido: puños ardientes -- bonus de dano y
	# fuerza el tipo "quemadura" aunque el propio estilo sea otro.
	if _potenciador_active_element == "fuego":
		damage += _potenciador_damage_bonus
		damage_type = "quemadura"
	for enemigo in targets:
		if enemigo.has_method("recibir_daño"):
			enemigo.recibir_daño(damage_type, damage)

	confirm_basic_attack.rpc(next_combo, new_chakra, spawn_tag, aim_point)

## Resultado confirmado por el host. Se aplica en todos los peers por igual.
@rpc("any_peer", "call_local", "reliable")
func confirm_basic_attack(combo_index: int, new_chakra: float, spawn_tag: bool, aim_point: Vector2) -> void:
	combo_count = combo_index
	chakra_current = new_chakra
	_combo_window_timer = style_data.basic_combo_window
	if spawn_tag:
		_spawn_status_tag(aim_point)

func _spawn_status_tag(pos: Vector2) -> void:
	var effects_root: Node = NetworkManager.effects_root
	if effects_root == null:
		return
	var tag_scene: PackedScene = preload("res://scenes/combat/status_tag.tscn")
	var tag := tag_scene.instantiate()
	tag.element = style_data.element_name
	tag.lifetime = style_data.basic_tag_duration
	effects_root.add_child(tag)
	tag.global_position = pos

# =========================================================================
# Proyectil (Fuego/Viento) -- clic derecho.
# =========================================================================

func _request_projectile_attack() -> void:
	var aim_point := get_global_mouse_position()
	submit_projectile_attack.rpc_id(1, aim_point)

@rpc("any_peer", "call_local", "reliable")
func submit_projectile_attack(aim_point: Vector2) -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	if chakra_current < style_data.projectile_chakra_cost:
		return # sin chakra suficiente, se ignora la peticion (sin penalizar)
	var new_chakra: float = chakra_current - style_data.projectile_chakra_cost
	confirm_projectile_attack.rpc(new_chakra, aim_point)

@rpc("any_peer", "call_local", "reliable")
func confirm_projectile_attack(new_chakra: float, aim_point: Vector2) -> void:
	chakra_current = new_chakra
	var effects_root: Node = NetworkManager.effects_root
	if effects_root == null:
		return
	var dir: Vector2 = aim_point - global_position
	if dir.length() < 0.001:
		dir = Vector2.RIGHT.rotated(_torso.rotation)
	dir = dir.normalized()
	var scene: PackedScene = preload("res://scenes/combat/projectiles/projectile.tscn")
	var proj: Projectile = scene.instantiate()
	# Configurar ANTES de add_child: _ready() lee estos valores al entrar en
	# el arbol (p.ej. para orientar la rotacion inicial).
	proj.direction = dir
	proj.element = style_data.element_name
	proj.speed = style_data.projectile_speed
	proj.damage = style_data.projectile_damage
	proj.max_distance = style_data.projectile_max_distance
	proj.explosion_radius = style_data.projectile_explosion_radius
	proj.pierces = style_data.projectile_pierces
	effects_root.add_child(proj)
	proj.global_position = global_position + dir * 24.0

# =========================================================================
# Agarre (solo Fisico, sustituye al Proyectil) -- clic derecho.
# =========================================================================

func _request_grab() -> void:
	submit_grab_attempt.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func submit_grab_attempt() -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	if _get_grabbed_enemy() != null:
		return # ya tiene algo agarrado
	var facing_dir: Vector2 = Vector2.RIGHT.rotated(_torso.rotation)
	var candidates := _find_enemies_in_cone(style_data.grab_range, style_data.grab_cone_degrees, facing_dir)
	if candidates.is_empty():
		return
	var target: Node2D = candidates[0]
	var best_dist: float = global_position.distance_to(target.global_position)
	for c in candidates:
		var d: float = global_position.distance_to(c.global_position)
		if d < best_dist:
			best_dist = d
			target = c
	# Bonus de Fisico (brief 2.1): tras un Agarre exitoso con un Potenciador
	# activo, devuelve chakra al aliado que lo lanzo y consume el buff.
	var consume_potenciador := false
	if style_data.melee_only and _potenciador_active_element != "" and _potenciador_caster_id != 0:
		var caster: Node = null
		if NetworkManager.players_root != null:
			caster = NetworkManager.players_root.get_node_or_null(str(_potenciador_caster_id))
		if caster != null and caster.has_method("confirm_potenciador_chakra_return"):
			var new_caster_chakra: float = min(caster.chakra_current + style_data.potenciador_grab_chakra_return, caster.style_data.chakra_max)
			caster.confirm_potenciador_chakra_return.rpc(new_caster_chakra)
			consume_potenciador = true
	confirm_grab.rpc(target.get_path(), consume_potenciador)

@rpc("any_peer", "call_local", "reliable")
func confirm_grab(path: NodePath, consume_potenciador: bool) -> void:
	var target := get_node_or_null(path) as EnemigoSimple
	if target == null or not is_instance_valid(target):
		return
	target.agarrado_por = self
	grabbed_enemy_path = path
	if consume_potenciador:
		_potenciador_active_element = ""
		_potenciador_caster_id = 0
		_potenciador_damage_bonus = 0.0
	if multiplayer.is_server():
		_schedule_grab_release(target, style_data.grab_hold_duration)

## Suelta el agarre solo si nadie lo ha lanzado antes de grab_hold_duration.
## Solo lo programa el host (que es quien decide cuando confirmar cosas);
## el resultado se retransmite igual que cualquier otra confirmacion.
func _schedule_grab_release(target: EnemigoSimple, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(target) and target.agarrado_por == self:
		confirm_release_grab.rpc()

@rpc("any_peer", "call_local", "reliable")
func confirm_release_grab() -> void:
	var target := _get_grabbed_enemy()
	if target != null and is_instance_valid(target):
		target.agarrado_por = null
	grabbed_enemy_path = NodePath("")

## Mientras haya alguien agarrado, se mantiene delante del jugador. Solo lo
## mueve la autoridad del personaje (ver _physics_process), igual que el
## resto del movimiento del jugador.
func _process_grab_hold() -> void:
	if not style_data.melee_only:
		return
	var target := _get_grabbed_enemy()
	if target == null or not is_instance_valid(target):
		return
	target.global_position = global_position + Vector2.RIGHT.rotated(_torso.rotation) * style_data.grab_hold_offset

# =========================================================================
# Zona (Fuego/Viento) -- mantener Q carga, soltar coloca.
# =========================================================================

func _handle_zone_input(delta: float) -> void:
	if style_data.melee_only:
		if Input.is_action_just_pressed("zone_cast") and _get_grabbed_enemy() != null:
			_request_throw(get_global_mouse_position())
		return
	if Input.is_action_just_pressed("zone_cast"):
		_start_zone_charge()
	if _zone_charging:
		_zone_charge_time = min(_zone_charge_time + delta, style_data.zone_charge_time_max)
		_update_zone_preview()
		if Input.is_action_just_released("zone_cast"):
			_release_zone_charge()

func _start_zone_charge() -> void:
	_zone_charging = true
	_zone_charge_time = 0.0
	var preview_scene: PackedScene = preload("res://scenes/combat/zones/zone_preview.tscn")
	_zone_preview = preview_scene.instantiate()
	_zone_preview.element = style_data.element_name
	get_tree().current_scene.add_child(_zone_preview)
	_update_zone_preview()

func _update_zone_preview() -> void:
	if _zone_preview == null:
		return
	var ratio: float = _zone_charge_time / style_data.zone_charge_time_max
	_zone_preview.global_position = get_global_mouse_position()
	_zone_preview.radius = lerp(style_data.zone_radius_min, style_data.zone_radius_max, ratio)

func _release_zone_charge() -> void:
	_zone_charging = false
	var ratio: float = _zone_charge_time / style_data.zone_charge_time_max
	if _zone_preview != null:
		_zone_preview.queue_free()
		_zone_preview = null
	submit_zone_cast.rpc_id(1, get_global_mouse_position(), ratio)

@rpc("any_peer", "call_local", "reliable")
func submit_zone_cast(cast_pos: Vector2, charge_ratio: float) -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	# El host recalcula radio/coste desde el ratio de carga en vez de
	# confiar en valores ya calculados por el cliente -- igual de barato,
	# pero el cliente no puede mentir sobre cuanto pago.
	var ratio: float = clamp(charge_ratio, 0.0, 1.0)
	var cost: float = lerp(style_data.zone_chakra_cost_min, style_data.zone_chakra_cost_max, ratio)
	if chakra_current < cost:
		return
	var new_chakra: float = chakra_current - cost
	var radius: float = lerp(style_data.zone_radius_min, style_data.zone_radius_max, ratio)
	confirm_zone_cast.rpc(new_chakra, cast_pos, radius)

@rpc("any_peer", "call_local", "reliable")
func confirm_zone_cast(new_chakra: float, cast_pos: Vector2, radius: float) -> void:
	chakra_current = new_chakra
	var effects_root: Node = NetworkManager.effects_root
	if effects_root == null:
		return
	var scene: PackedScene = preload("res://scenes/combat/zones/ground_zone.tscn")
	var zone: GroundZone = scene.instantiate()
	# Configurar ANTES de add_child: _ready() decide con estos valores si
	# hay que buscar una combinacion de suelo (ver ground_zone.gd).
	zone.element = style_data.element_name
	zone.radius = radius
	zone.duration = style_data.zone_duration
	if style_data.element_name == "fuego":
		zone.damage_per_second = style_data.zone_damage_per_second
	elif style_data.element_name == "viento":
		zone.pull_force = style_data.zone_pull_force
	effects_root.add_child(zone)
	zone.global_position = cast_pos

# =========================================================================
# Lanzamiento (solo Fisico, sustituye a la Zona) -- Q.
# =========================================================================

func _request_throw(cursor_pos: Vector2) -> void:
	submit_throw.rpc_id(1, cursor_pos)

@rpc("any_peer", "call_local", "reliable")
func submit_throw(cursor_pos: Vector2) -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	var target := _get_grabbed_enemy()
	if target == null or not is_instance_valid(target):
		return
	var dir: Vector2 = cursor_pos - target.global_position
	if dir.length() < 0.001:
		dir = Vector2.RIGHT
	dir = dir.normalized()
	confirm_throw.rpc(target.get_path(), dir)

@rpc("any_peer", "call_local", "reliable")
func confirm_throw(path: NodePath, dir: Vector2) -> void:
	grabbed_enemy_path = NodePath("")
	var target := get_node_or_null(path) as EnemigoSimple
	if target == null or not is_instance_valid(target):
		return
	var damage: float = style_data.throw_damage * _current_damage_multiplier()
	target.lanzar(dir, style_data.throw_speed, damage)

# =========================================================================
# Impulso -- Espacio, recarga corta.
# =========================================================================

func _request_impulse() -> void:
	var dir: Vector2 = Vector2.RIGHT.rotated(_torso.rotation)
	submit_impulse.rpc_id(1, global_position, dir)

@rpc("any_peer", "call_local", "reliable")
func submit_impulse(from_pos: Vector2, dir: Vector2) -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	var to_pos: Vector2 = from_pos + dir * style_data.impulse_distance
	confirm_impulse.rpc(from_pos, to_pos)

@rpc("any_peer", "call_local", "reliable")
func confirm_impulse(from_pos: Vector2, to_pos: Vector2) -> void:
	_impulse_cooldown_remaining = style_data.impulse_cooldown
	_impulse_from = from_pos
	_impulse_to = to_pos
	_impulse_active_time = style_data.impulse_travel_time
	if style_data.element_name == "viento":
		_collision_ignore_remaining = style_data.impulse_ignore_collision_duration
		set_collision_mask_value(1, false)
	if style_data.melee_only:
		if multiplayer.is_server():
			_apply_impulse_pierce_damage(from_pos, to_pos)
	elif style_data.element_name == "fuego":
		_spawn_impulse_trail(from_pos, to_pos)

func _process_impulse_motion(delta: float) -> void:
	if _impulse_active_time <= 0.0:
		return
	_impulse_active_time -= delta
	var t: float = 1.0 - clamp(_impulse_active_time / max(style_data.impulse_travel_time, 0.001), 0.0, 1.0)
	global_position = _impulse_from.lerp(_impulse_to, t)
	if _impulse_active_time <= 0.0:
		global_position = _impulse_to

## Fisico: embestida, atraviesa enemigos en el camino. Solo se llama cuando
## multiplayer.is_server() es true (dentro de confirm_impulse), asi el
## danio siempre lo decide el host.
func _apply_impulse_pierce_damage(from_pos: Vector2, to_pos: Vector2) -> void:
	var damage: float = style_data.impulse_pierce_damage * _current_damage_multiplier()
	for enemigo in get_tree().get_nodes_in_group(GRUPO_ENEMIGOS):
		if not (enemigo is Node2D):
			continue
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemigo.global_position, from_pos, to_pos)
		if enemigo.global_position.distance_to(closest) <= style_data.impulse_pierce_width and enemigo.has_method("recibir_daño"):
			enemigo.recibir_daño("contundente", damage)

## Fuego: paso ardiente, deja un rastro de fuego. Se llama en todos los
## peers (visual identico en todos); el danio real de cada fragmento lo
## sigue filtrando GroundZone con multiplayer.is_server() internamente.
func _spawn_impulse_trail(from_pos: Vector2, to_pos: Vector2) -> void:
	var effects_root: Node = NetworkManager.effects_root
	if effects_root == null:
		return
	var zone_scene: PackedScene = preload("res://scenes/combat/zones/ground_zone.tscn")
	var pieces := 4
	for i in range(pieces):
		var t: float = float(i) / float(max(pieces - 1, 1))
		var zone: GroundZone = zone_scene.instantiate()
		zone.element = "fuego"
		zone.radius = 28.0
		zone.duration = style_data.impulse_trail_duration
		zone.damage_per_second = style_data.impulse_trail_damage_per_second
		# El rastro no debe disparar la combinacion viento+fuego solo por
		# pasar de refilon junto a una zona ajena.
		zone.participates_in_combo = false
		effects_root.add_child(zone)
		zone.global_position = from_pos.lerp(to_pos, t)

# =========================================================================
# Puertas (solo Fisico) -- mantener F.
# =========================================================================

func _handle_puertas(delta: float) -> void:
	if Input.is_action_just_pressed("puertas") and puertas_nivel == 0:
		submit_puertas_open.rpc_id(1)
	if Input.is_action_pressed("puertas") and puertas_nivel > 0:
		_puertas_tiempo_en_nivel += delta
		_puertas_tiempo_abierto_total += delta
		# Drena vida mientras este abierto. Se calcula local/prediccion (no
		# hace falta ir al host: es un coste propio, no un danio a un
		# recurso compartido); se deja un minimo de 1.0 porque no hay
		# muerte/respawn de jugador implementado todavia.
		vida_actual = max(vida_actual - style_data.puertas_life_drain_per_second_per_level * puertas_nivel * delta, 1.0)
		if puertas_nivel < style_data.puertas_niveles_max and _puertas_tiempo_en_nivel >= style_data.puertas_tiempo_por_nivel:
			_puertas_tiempo_en_nivel = 0.0
			submit_puertas_level_up.rpc_id(1)
	if Input.is_action_just_released("puertas") and puertas_nivel > 0:
		submit_puertas_close.rpc_id(1, _puertas_tiempo_abierto_total)

@rpc("any_peer", "call_local", "reliable")
func submit_puertas_open() -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	confirm_puertas_state.rpc(1)

@rpc("any_peer", "call_local", "reliable")
func submit_puertas_level_up() -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	if puertas_nivel <= 0 or puertas_nivel >= style_data.puertas_niveles_max:
		return
	confirm_puertas_state.rpc(puertas_nivel + 1)

@rpc("any_peer", "call_local", "reliable")
func confirm_puertas_state(nivel: int) -> void:
	puertas_nivel = nivel

@rpc("any_peer", "call_local", "reliable")
func submit_puertas_close(tiempo_abierto: float) -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	var vulnerabilidad: float = tiempo_abierto * style_data.puertas_vulnerability_factor
	confirm_puertas_close.rpc(vulnerabilidad)

@rpc("any_peer", "call_local", "reliable")
func confirm_puertas_close(vulnerabilidad_segundos: float) -> void:
	puertas_nivel = 0
	_puertas_tiempo_en_nivel = 0.0
	_puertas_tiempo_abierto_total = 0.0
	_vulnerabilidad_restante = vulnerabilidad_segundos
	_vulnerabilidad_multiplicador = style_data.puertas_vulnerability_damage_multiplier

# =========================================================================
# Potenciador -- E. Se lanza sobre un aliado, nunca sobre uno mismo. Solo
# Fuego/Viento tienen chakra para lanzarlo (Fisico no tiene Potenciador
# propio, brief 2.1); Fisico si puede RECIBIRLO -- ver bonus en Agarre.
# =========================================================================

func _request_potenciador() -> void:
	submit_potenciador.rpc_id(1)

## El host busca el aliado mas cercano en el mismo cono que ya usa el
## Agarre (autoapuntado suave); el cliente no elige el objetivo, solo pide
## la accion, igual que el resto del kit.
@rpc("any_peer", "call_local", "reliable")
func submit_potenciador() -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	if style_data.melee_only:
		return
	if chakra_current < style_data.potenciador_chakra_cost:
		return
	var facing_dir: Vector2 = Vector2.RIGHT.rotated(_torso.rotation)
	var candidates := _find_allies_in_cone(style_data.potenciador_range, style_data.potenciador_cone_degrees, facing_dir)
	if candidates.is_empty():
		return
	var target: Node2D = candidates[0]
	var best_dist: float = global_position.distance_to(target.global_position)
	for c in candidates:
		var d: float = global_position.distance_to(c.global_position)
		if d < best_dist:
			best_dist = d
			target = c
	var new_chakra: float = chakra_current - style_data.potenciador_chakra_cost
	var duration: float = style_data.potenciador_duration
	if target.has_method("potenciador_duration_multiplier"):
		duration *= target.potenciador_duration_multiplier()
	var damage_bonus := 0.0
	var dash_distance := 0.0
	var dash_travel_time := 0.0
	if style_data.element_name == "fuego":
		damage_bonus = style_data.potenciador_fuego_damage_bonus
	elif style_data.element_name == "viento":
		dash_distance = style_data.potenciador_viento_dash_distance
		dash_travel_time = style_data.potenciador_viento_dash_travel_time
	confirm_potenciador_cast.rpc(new_chakra)
	# RPC sobre OTRO nodo replicado (el objetivo, no self) -- mismo truco que
	# ya usa el Agarre/Lanzamiento para aplicar el resultado donde toca.
	target.confirm_potenciador_received.rpc(style_data.element_name, duration, get_multiplayer_authority(), damage_bonus, dash_distance, dash_travel_time, global_position)

@rpc("any_peer", "call_local", "reliable")
func confirm_potenciador_cast(new_chakra: float) -> void:
	chakra_current = new_chakra

## Se ejecuta en el jugador OBJETIVO (no en quien lo lanzo). caster_pos es
## la posicion del que lo lanzo en el momento del cast, usada solo por el
## dash de Viento.
@rpc("any_peer", "call_local", "reliable")
func confirm_potenciador_received(element: String, duration: float, caster_id: int, damage_bonus: float, dash_distance: float, dash_travel_time: float, caster_pos: Vector2) -> void:
	_potenciador_active_element = element
	_potenciador_time_remaining = duration
	_potenciador_caster_id = caster_id
	_potenciador_damage_bonus = damage_bonus
	if element == "viento" and dash_distance > 0.0:
		_start_potenciador_dash(caster_pos, dash_distance, dash_travel_time)

## Viento: dash instantaneo hacia quien lanzo el Potenciador (cierra
## distancia volando). Se detiene un poco antes de llegar encima del
## aliado en vez de solaparse con el.
func _start_potenciador_dash(caster_pos: Vector2, distance: float, travel_time: float) -> void:
	var to_caster: Vector2 = caster_pos - global_position
	var dist: float = to_caster.length()
	if dist < 1.0:
		return
	var dir: Vector2 = to_caster / dist
	var travel_dist: float = min(distance, max(dist - 20.0, 0.0))
	if travel_dist <= 0.0:
		return
	_potenciador_dash_from = global_position
	_potenciador_dash_to = global_position + dir * travel_dist
	_potenciador_dash_total_time = travel_time
	_potenciador_dash_active_time = travel_time

@rpc("any_peer", "call_local", "reliable")
func confirm_potenciador_chakra_return(new_chakra: float) -> void:
	chakra_current = new_chakra

# =========================================================================
# Vida / danio entrante.
# =========================================================================

## Llamado por enemy_simple.gd cuando ataca cuerpo a cuerpo. Nota: los
## enemigos no estan en red todavia, asi que en una partida con un segundo
## jugador real cada peer simula sus propios enemigos por separado y esto
## puede desincronizarse -- limitacion conocida, fuera de esta tanda
## (queda para la tarea de "enemigos en red" / segundo jugador real).
func recibir_daño(_tipo_daño: String, cantidad: float) -> void:
	vida_actual = max(vida_actual - cantidad * _vulnerabilidad_multiplicador, 0.0)
