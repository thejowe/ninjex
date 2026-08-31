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
@onready var _torso_rect: ColorRect = $Visuals/Torso/TorsoRect
@onready var _legs_rect: ColorRect = $Visuals/Legs/LegsRect
@onready var _vulnerability_indicator: ColorRect = $Visuals/FX/VulnerabilityIndicator
@onready var _potenciador_indicator: ColorRect = $Visuals/FX/PotenciadorIndicator
@onready var _health_bar_fill: ColorRect = $Visuals/StatusBars/HealthBarFill
@onready var _chakra_bar_bg: ColorRect = $Visuals/StatusBars/ChakraBarBg
@onready var _chakra_bar_fill: ColorRect = $Visuals/StatusBars/ChakraBarFill
@onready var _camera: Camera2D = $Camera2D
## Sin HUD real todavia (vertical slice): confirm_vender/confirm_cambiar_dinero/
## confirm_apostar_dados solo hacian print() en consola, invisible si se
## juega el .exe sin terminal abierta. Este Label minimo es el unico
## feedback en pantalla del dinero compartido -- no es la UI final del
## hub/taberna (eso es H5), solo lo justo para poder probar H2/H3 sin
## depender de la consola.
@onready var _money_label: Label = $HUD/MoneyLabel
## Ultimo resultado/aviso del casino (exito o fallo silencioso -- "no hay
## cambista cerca", "no tienes dinero manchado", etc.). Antes esto solo
## salia por print(), indistinguible en pantalla de que la tecla no hiciera
## nada. Ver confirm_casino_mensaje().
@onready var _status_label: Label = $HUD/StatusLabel
## Aviso de "que tecla pulsar" cuando estas cerca de un punto de interaccion
## (Comprador/Cambista/MesaDados/Usurero/Forja/Herboristeria/Taberna) --
## antes no habia forma de saber que tecla usaba cada cuadrado sin mirar el
## codigo. Se recalcula cada frame en _update_interaction_hint(), separado
## de _status_label (que es para resultados/avisos puntuales, no un aviso
## persistente mientras estas de pie al lado de algo).
@onready var _interaction_label: Label = $HUD/InteractionLabel

# Colores base de TorsoRect/LegsRect. Antes eran los mismos const fijos que
# trae player.tscn (siempre verde/azul, sin importar el estilo); ahora son
# variables porque _apply_style_reset() los recalcula segun
# style_data.element_name (ver _style_base_colors()) -- se guardan aqui para
# poder interpolar hacia el rojo de las Puertas y volver sin depender de
# leerlos de vuelta del nodo, exactamente igual que antes, solo que el punto
# de partida ya no es siempre el mismo.
var _torso_color_base := Color(0.24, 0.36, 0.62, 1.0)
var _legs_color_base := Color(0.28, 0.55, 0.28, 1.0)
const PUERTAS_COLOR_MAX := Color(0.9, 0.15, 0.15, 1.0)
const PUERTAS_SCALE_PER_LEVEL := 0.12

const POTENCIADOR_COLOR_FUEGO := Color(1.0, 0.55, 0.1, 0.55)
const POTENCIADOR_COLOR_VIENTO := Color(0.35, 0.9, 0.45, 0.55)
const POTENCIADOR_COLOR_AGUA := Color(0.3, 0.65, 0.95, 0.55)
const POTENCIADOR_COLOR_RAYO := Color(0.95, 0.9, 0.3, 0.55)
const POTENCIADOR_COLOR_TIERRA := Color(0.55, 0.4, 0.2, 0.55)

# --- Barras de vida/chakra (Visuals/StatusBars en player.tscn) ---
## Ancho total (a ratio 1.0) del relleno de las barras -- coincide con el
## offset_left/right de HealthBarFill/ChakraBarFill en player.tscn (32px).
const STATUS_BAR_WIDTH := 32.0

# --- Screen shake (solo camara local, is_multiplayer_authority) ---
const SCREEN_SHAKE_DECAY_PER_SECOND := 26.0
const SCREEN_SHAKE_HIT_STRENGTH := 4.5
const SCREEN_SHAKE_ATTACK_STRENGTH := 2.5
var _screen_shake_strength: float = 0.0

# --- Flash de golpe recibido (TorsoRect/LegsRect) ---
var _torso_flash_tween: Tween = null
var _legs_flash_tween: Tween = null

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

# --- Cadaveres (H2): cargar cuerpos y venderlos ---------------------------
## Cuantos cadaveres como maximo se pueden cargar a la vez. Tope simple para
## que el "peso del botin" tenga un limite claro, no hace falta que sea
## configurable por Resource todavia (a diferencia de los estilos).
const MAX_CADAVERES_CARGADOS := 3
const CADAVER_PICKUP_RANGE := 60.0
## Los cadaveres cargados se apilan detras del jugador (no delante, para no
## estorbar la vista de apuntado) -- offset del primero y separacion entre
## cada uno siguiente, asi se nota a simple vista cuantos llevas.
const CADAVER_CARRY_OFFSET := 34.0
const CADAVER_CARRY_SPACING := 18.0
const CADAVER_DROP_OFFSET := 30.0
const VENTA_RANGE := 80.0
## Rango de interaccion con los puntos del casino (H3). Mismo valor que
## VENTA_RANGE de arriba a proposito -- es el mismo tipo de "punto estatico,
## te acercas y pulsas una tecla" que Comprador, solo que con otro nombre
## para que quede claro que es un concepto distinto (casino, no venta).
const CASINO_RANGE := 80.0
## Rango de interaccion con los puntos del Hub (H5): Forja, Herboristeria,
## Taberna. Mismo criterio que CASINO_RANGE de arriba -- punto estatico,
## deteccion por distancia simple, solo con otro nombre para dejar claro que
## es la tanda del Hub y no la del casino.
const HUB_RANGE := 80.0
## Con que moneda se apuesta en la mesa de dados ahora mismo: "limpio" o
## "manchado". El brief define la manchada como "solo cambiable en el
## casino" (2.3), pero el usuario quiere ademas la via tematica de blanquear
## dinero JUGANDO en vez de solo pagando la comision del 15% del cambista:
## apostar manchado directo salta el cambista -- si ganas, blanqueas el
## doble sin comision; si pierdes, lo pierdes igual que si lo hubieras
## cambiado y apostado el limpio resultante. Se alterna con la tecla M
## (toggle_moneda_apuesta), por defecto limpio (el camino "seguro" que
## sigue el brief al pie de la letra).
var _apuesta_moneda: String = "limpio"
## Peso del botin (brief H2 tarea 4): cada cadaver cargado resta velocidad.
## MIN_CARGA_SPEED_RATIO evita que cargar el maximo te deje casi inmovil --
## seria un castigo, no una decision interesante.
const CARGA_SPEED_PENALTY_PER_CADAVER := 0.15
const MIN_CARGA_SPEED_RATIO := 0.4

## NodePaths absolutos a los cadaveres que este jugador esta cargando ahora
## mismo. Mismo truco que grabbed_enemy_path: los cadaveres son nodos de red
## deterministas (mismo nombre en todos los peers, ver Cadaver/EnemigoSimple
## ._spawn_cadaver), asi que un NodePath resuelve al mismo nodo en cada peer.
var carried_cadaver_paths: Array[NodePath] = []

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
## Rayo: mientras > 0, aplica style_data.impulse_speed_boost_multiplier tras
## el Impulso (el "salir disparado" que distingue a Rayo de un simple dash).
var _impulse_speed_boost_remaining: float = 0.0

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
## Agua (H6): "sana" -- goteo de curacion mientras el buff este activo.
## Mismo mecanismo que _unguento_heal_per_second de Herboristeria, pero
## repartido en la duracion del Potenciador (no en UNGUENTO_DURATION).
var _potenciador_heal_per_second: float = 0.0
## Rayo (H6): "da velocidad" -- multiplicador leido por _current_speed_multiplier
## mientras _potenciador_active_element == "rayo".
var _potenciador_speed_multiplier: float = 1.0
## Tierra (H6): "da armadura" -- multiplicador de daño RECIBIDO mientras
## _potenciador_active_element == "tierra" (opuesto a _vulnerabilidad_multiplicador
## de las Puertas: aqui reduce en vez de aumentar). Ver confirm_damage_taken.
var _potenciador_damage_reduction: float = 1.0
var _potenciador_dash_active_time: float = 0.0
var _potenciador_dash_total_time: float = 0.0
var _potenciador_dash_from: Vector2
var _potenciador_dash_to: Vector2

# --- Forja (H5 tarea 2) ---------------------------------------------------
## +7% / +14% / +20% de daño segun NetworkManager.forja_nivel[peer_id]
## (indice = nivel, 0 = sin mejorar). Regla invariante del brief (seccion 4):
## "ninguna mejora permanente supera el +20% sobre la base" -- el nivel 3 se
## queda justo en el techo, no lo supera.
const FORJA_BONUS_POR_NIVEL: Array[float] = [0.0, 0.07, 0.14, 0.20]

# --- Herboristeria (H5 tarea 3): inventario de consumibles ----------------
## Adaptacion del brief 2.4 ("maximo 3 por jugador Y MISION" -> sin concepto
## de mision real todavia, ver comentario de cabecera de herboristeria.gd):
## "3 cargados a la vez, se recargan comprando mas". Mismo patron que
## carried_cadaver_paths -- array simple con un tope, mutado solo via
## confirm_*() del host.
const MAX_CONSUMIBLES_CARGADOS := 3
var consumibles: Array[String] = []

## Pildora de soldado: recupera chakra al instante. Cantidad razonable frente
## a chakra_max=100 tipico -- no rellena la barra entera, pero saca de un
## apuro real.
const PILDORA_CHAKRA_AMOUNT := 40.0
## Unguento: cura por goteo 20s (brief 2.4 literal). Total curado repartido
## a lo largo de la duracion.
const UNGUENTO_DURATION := 20.0
const UNGUENTO_TOTAL_HEAL := 40.0
var _unguento_time_remaining: float = 0.0
var _unguento_heal_per_second: float = 0.0
## Bomba de humo: "escape garantizado" (brief 2.4) -- adaptado a
## invulnerabilidad + velocidad brevemente, en vez de un teletransporte real
## (mas simple de implementar y de leer en pantalla sin arte/VFX, y cumple
## igual "te saca de una situacion mala" sin arriesgar teletransportarte
## dentro de una pared).
const BOMBA_HUMO_DURATION := 2.5
const BOMBA_HUMO_SPEED_MULTIPLIER := 1.6
var _bomba_humo_time_remaining: float = 0.0
## Sales: reducen el desgaste (drenaje de vida) de las Puertas durante un
## tiempo -- ver _handle_puertas() y style_data.puertas_life_drain_per_second_per_level.
const SALES_DURATION := 15.0
const SALES_DRAIN_REDUCTION := 0.5
var _sales_time_remaining: float = 0.0

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
	else:
		# El HUD de dinero es solo del propio jugador -- ocultarlo en los
		# personajes de otros peers para no acumular Labels invisibles
		# encima unos de otros en pantalla.
		_money_label.get_parent().visible = false

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
	_potenciador_heal_per_second = 0.0
	_potenciador_speed_multiplier = 1.0
	_potenciador_damage_reduction = 1.0
	_potenciador_dash_active_time = 0.0
	_impulse_speed_boost_remaining = 0.0
	set_collision_mask_value(1, true)
	if _zone_preview != null:
		_zone_preview.queue_free()
		_zone_preview = null
	_zone_charging = false
	grabbed_enemy_path = NodePath("")
	# Color base de torso/piernas segun el estilo actual -- recalculado aqui
	# (arranque y cada cambio de estilo del debug 1/2/3) para que las Puertas
	# sigan interpolando desde el color correcto (ver _update_puertas_visual).
	var base_colors := _style_base_colors()
	_torso_color_base = base_colors[0]
	_legs_color_base = base_colors[1]
	_update_puertas_visual()
	_update_vulnerability_visual()
	_update_potenciador_visual()
	_update_status_bars()

## Color base de TorsoRect/LegsRect segun style_data.element_name. Fuego en
## tonos rojo/naranja, Viento en cian/blanco verdoso, Fisico en gris/marron
## (sin elemento chakra); el resto (placeholder, y Agua/Rayo/Tierra que
## todavia no existen como estilos jugables) se queda con el azul/verde
## original de player.tscn. Devuelve [color_torso, color_piernas].
func _style_base_colors() -> Array:
	match style_data.element_name:
		"fuego":
			return [Color(0.75, 0.18, 0.08, 1.0), Color(0.5, 0.22, 0.08, 1.0)]
		"viento":
			return [Color(0.55, 0.85, 0.8, 1.0), Color(0.78, 0.95, 0.88, 1.0)]
		"fisico":
			return [Color(0.42, 0.42, 0.44, 1.0), Color(0.36, 0.28, 0.2, 1.0)]
		_:
			return [Color(0.24, 0.36, 0.62, 1.0), Color(0.28, 0.55, 0.28, 1.0)]

## Ancho del relleno de vida/chakra segun vida_actual/chakra_current -- se
## llama cada fotograma para TODOS los peers (no solo la autoridad), asi se
## ven las barras de todos los jugadores conectados, no solo la propia.
## Fisico tiene chakra_max = 0 (no usa Proyectil/Zona): en ese caso se oculta
## la barra de chakra en vez de dejarla vacia y "rota" a la vista.
func _update_status_bars() -> void:
	var vida_ratio: float = clamp(vida_actual / max(style_data.vida_maxima, 0.001), 0.0, 1.0)
	_health_bar_fill.size.x = STATUS_BAR_WIDTH * vida_ratio
	if style_data.chakra_max <= 0.0:
		_chakra_bar_bg.visible = false
		_chakra_bar_fill.visible = false
	else:
		_chakra_bar_bg.visible = true
		_chakra_bar_fill.visible = true
		var chakra_ratio: float = clamp(chakra_current / style_data.chakra_max, 0.0, 1.0)
		_chakra_bar_fill.size.x = STATUS_BAR_WIDTH * chakra_ratio

## Screen shake breve y sutil, solo visible en la camara del jugador LOCAL
## (is_multiplayer_authority): al conectar un golpe (Basico/Proyectil/Impulso)
## o al recibir daño real. strength en pixeles, decae rapido via
## _process_screen_shake().
func trigger_hit_shake(strength: float = SCREEN_SHAKE_ATTACK_STRENGTH) -> void:
	if not is_multiplayer_authority():
		return
	_screen_shake_strength = max(_screen_shake_strength, strength)

func _process_screen_shake(delta: float) -> void:
	if _screen_shake_strength <= 0.05:
		if _screen_shake_strength != 0.0:
			_screen_shake_strength = 0.0
			_camera.offset = Vector2.ZERO
		return
	_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _screen_shake_strength
	_screen_shake_strength = max(_screen_shake_strength - SCREEN_SHAKE_DECAY_PER_SECOND * delta, 0.0)

## Flash breve de modulate blanco y vuelta al normal (~0.15s) en TorsoRect y
## LegsRect -- feedback de "acabo de recibir un golpe real". Tween de
## Godot 4 (create_tween), sin AnimationPlayer. confirm_damage_taken ya corre
## igual en todos los peers (rpc call_local), asi que llamar esto ahi basta
## para que se vea igual en todos sin logica de red aparte.
func _flash_damage_taken() -> void:
	if _torso_flash_tween != null and _torso_flash_tween.is_valid():
		_torso_flash_tween.kill()
	_torso_rect.modulate = Color(1, 1, 1, 1)
	_torso_flash_tween = create_tween()
	_torso_flash_tween.tween_property(_torso_rect, "modulate", Color(1.8, 1.8, 1.8, 1.0), 0.03)
	_torso_flash_tween.tween_property(_torso_rect, "modulate", Color(1, 1, 1, 1), 0.12)

	if _legs_flash_tween != null and _legs_flash_tween.is_valid():
		_legs_flash_tween.kill()
	_legs_rect.modulate = Color(1, 1, 1, 1)
	_legs_flash_tween = create_tween()
	_legs_flash_tween.tween_property(_legs_rect, "modulate", Color(1.8, 1.8, 1.8, 1.0), 0.03)
	_legs_flash_tween.tween_property(_legs_rect, "modulate", Color(1, 1, 1, 1), 0.12)

func _physics_process(delta: float) -> void:
	_update_status_bars()
	if is_multiplayer_authority():
		_process_screen_shake(delta)
		_handle_debug_style_switch()
		_handle_combo_timer(delta)
		_handle_vulnerability(delta)
		_handle_impulse_cooldown(delta)
		_handle_collision_ignore(delta)
		_handle_impulse_speed_boost(delta)
		_handle_potenciador_timer(delta)
		_handle_unguento(delta)
		_handle_bomba_humo(delta)
		_handle_sales(delta)
		_process_impulse_motion(delta)
		_process_potenciador_dash(delta)
		_handle_movement()
		_handle_aim()
		_update_money_label()
		_update_interaction_hint()
		if style_data.melee_only:
			_handle_puertas(delta)
		_handle_zone_input(delta)
		_process_grab_hold()
		_process_carry_hold()
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
		if Input.is_action_just_pressed("cargar_cadaver"):
			_request_toggle_carry()
		if Input.is_action_just_pressed("vender_cadaver"):
			_request_vender()
		if Input.is_action_just_pressed("cambiar_dinero"):
			_request_cambiar_dinero()
		if Input.is_action_just_pressed("apostar_alto"):
			_request_apostar_dados("alto")
		if Input.is_action_just_pressed("apostar_bajo"):
			_request_apostar_dados("bajo")
		if Input.is_action_just_pressed("toggle_moneda_apuesta"):
			_toggle_apuesta_moneda()
		if Input.is_action_just_pressed("pedir_prestamo"):
			_request_prestamo_usurero()
		if Input.is_action_just_pressed("comprar_forja"):
			_request_mejorar_forja()
		if Input.is_action_just_pressed("comprar_pildora"):
			_request_comprar_consumible(Herboristeria.TIPO_PILDORA)
		if Input.is_action_just_pressed("comprar_unguento"):
			_request_comprar_consumible(Herboristeria.TIPO_UNGUENTO)
		if Input.is_action_just_pressed("comprar_bomba_humo"):
			_request_comprar_consumible(Herboristeria.TIPO_BOMBA_HUMO)
		if Input.is_action_just_pressed("comprar_sales"):
			_request_comprar_consumible(Herboristeria.TIPO_SALES)
		if Input.is_action_just_pressed("usar_consumible"):
			_request_usar_consumible()
		if Input.is_action_just_pressed("brindis_taberna"):
			_request_brindis()
	move_and_slide()

## Solo local (no pasa por red, como el cambio de estilo de debug): elegir
## con que moneda apostar es una preferencia personal antes de apostar, no
## una accion que otros jugadores necesiten ver confirmada.
func _toggle_apuesta_moneda() -> void:
	_apuesta_moneda = "manchado" if _apuesta_moneda == "limpio" else "limpio"
	_status_label.modulate = Color(1, 1, 1)
	if _apuesta_moneda == "manchado":
		_status_label.text = "Apuesta con MANCHADO (blanquea sin comision si ganas)"
	else:
		_status_label.text = "Apuesta con LIMPIO"

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
	velocity = input_dir * SPEED * _current_speed_multiplier() * _carga_speed_multiplier()

func _handle_aim() -> void:
	var to_cursor := get_global_mouse_position() - global_position
	if to_cursor.length() > 0.001:
		_torso.rotation = to_cursor.angle()

## dinero_manchado/dinero_limpio son pools compartidos en NetworkManager
## (ver network_manager.gd) que ya se actualizan via RPC call_local en
## confirm_vender/confirm_cambiar_dinero/confirm_apostar_dados -- este Label
## solo lee su valor actual cada frame, no necesita señal ni RPC propio.
func _update_money_label() -> void:
	var texto := "Manchado: %.0f  |  Limpio: %.0f" % [NetworkManager.dinero_manchado, NetworkManager.dinero_limpio]
	# Aviso visible de deuda con el Usurero: en NEGATIVO (pedido explicito
	# del usuario), mismo Label de dinero -- reutilizado en vez de crear un
	# tercer Label solo para esto.
	if NetworkManager.usurero_deuda_pendiente > 0.0:
		texto += "  |  Deuda Usurero: -%.0f" % NetworkManager.usurero_deuda_pendiente
	_money_label.text = texto

## Que tecla pulsar en el punto de interaccion mas cercano, o "" si no hay
## ninguno en rango. Comprueba cada tipo con su propio _find_nearest_*_in_range
## ya existente (mismo radio que usa el submit_ real de cada uno, para que
## el aviso aparezca exactamente cuando la accion de verdad funcionaria) --
## se para en el primero que encuentre, de mas a menos "de paso" segun el
## orden en que sueles cruzarte con ellos (cadaver suelto primero, luego los
## puntos estaticos).
func _update_interaction_hint() -> void:
	var texto := ""
	if _find_nearest_free_cadaver(CADAVER_PICKUP_RANGE) != null:
		texto = "Pulsa G para recoger el cadaver"
	elif _find_nearest_comprador_in_range(VENTA_RANGE) != null:
		texto = "Pulsa V para vender" if not carried_cadaver_paths.is_empty() else "Pulsa V para vender (no llevas ningun cadaver)"
	elif _find_nearest_cambista_in_range(CASINO_RANGE) != null:
		texto = "Pulsa C para cambiar dinero manchado a limpio"
	elif _find_nearest_mesa_dados_in_range(CASINO_RANGE) != null:
		texto = "Pulsa T para apostar alto, B para apostar bajo (M para cambiar de moneda)"
	elif _find_nearest_usurero_in_range(CASINO_RANGE) != null:
		texto = "Pulsa U para pedir un prestamo"
	elif _find_nearest_forja_in_range(HUB_RANGE) != null:
		texto = "Pulsa Y para mejorar la forja"
	elif _find_nearest_herboristeria_in_range(HUB_RANGE) != null:
		texto = "P pildora, H unguento, J bomba de humo, L sales -- I para usar"
	elif _find_nearest_taberna_in_range(HUB_RANGE) != null:
		texto = "Pulsa X para el brindis"
	_interaction_label.text = texto

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
			_update_vulnerability_visual()

func _handle_impulse_cooldown(delta: float) -> void:
	if _impulse_cooldown_remaining > 0.0:
		_impulse_cooldown_remaining -= delta

func _handle_collision_ignore(delta: float) -> void:
	if _collision_ignore_remaining > 0.0:
		_collision_ignore_remaining -= delta
		if _collision_ignore_remaining <= 0.0:
			set_collision_mask_value(1, true)

func _handle_impulse_speed_boost(delta: float) -> void:
	if _impulse_speed_boost_remaining > 0.0:
		_impulse_speed_boost_remaining = max(_impulse_speed_boost_remaining - delta, 0.0)

## Prediccion local (igual que el resto de timers de estado): cuenta atras
## del buff recibido. No hace falta ir al host, solo apaga el flag local.
func _handle_potenciador_timer(delta: float) -> void:
	if _potenciador_time_remaining > 0.0:
		# Agua: goteo de curacion mientras dure el buff -- misma prediccion
		# local que el resto de este timer (no depende del host cada frame).
		if _potenciador_heal_per_second > 0.0:
			vida_actual = min(vida_actual + _potenciador_heal_per_second * delta, style_data.vida_maxima)
		_potenciador_time_remaining -= delta
		if _potenciador_time_remaining <= 0.0:
			_potenciador_active_element = ""
			_potenciador_caster_id = 0
			_potenciador_damage_bonus = 0.0
			_potenciador_heal_per_second = 0.0
			_potenciador_speed_multiplier = 1.0
			_potenciador_damage_reduction = 1.0
			_update_potenciador_visual()

## Ungüento (H5, Herboristeria): cura por goteo mientras dure. Prediccion
## local igual que el drenaje de vida de las Puertas (_handle_puertas) --
## vida_actual es un coste/beneficio propio, no hace falta ir al host cada
## fotograma para curarse un poco.
func _handle_unguento(delta: float) -> void:
	if _unguento_time_remaining > 0.0:
		_unguento_time_remaining -= delta
		vida_actual = min(vida_actual + _unguento_heal_per_second * delta, style_data.vida_maxima)
		if _unguento_time_remaining <= 0.0:
			_unguento_time_remaining = 0.0
			_unguento_heal_per_second = 0.0

## Bomba de humo (H5, Herboristeria): solo cuenta atras el timer -- la
## invulnerabilidad la mira confirm_damage_taken() y el boost de velocidad
## lo mira _current_speed_multiplier(), ambos consultando
## _bomba_humo_time_remaining > 0.0 directamente.
func _handle_bomba_humo(delta: float) -> void:
	if _bomba_humo_time_remaining > 0.0:
		_bomba_humo_time_remaining = max(_bomba_humo_time_remaining - delta, 0.0)

## Sales (H5, Herboristeria): solo cuenta atras el timer -- la reduccion del
## desgaste de las Puertas la mira _handle_puertas() directamente.
func _handle_sales(delta: float) -> void:
	if _sales_time_remaining > 0.0:
		_sales_time_remaining = max(_sales_time_remaining - delta, 0.0)

## Avanza por un tramo de un lerp(from, to) usando move_and_collide() en vez
## de teletransportar global_position directamente -- BUG real reportado:
## dashear (Impulso, Espacio) hacia una pared la atravesaba y sacaba al
## jugador del mapa, porque el codigo anterior asignaba global_position sin
## pasar nunca por colision. Se usan dos ratios (antes/despues de este
## fotograma) para poder pedir solo el DESPLAZAMIENTO de este frame -- si
## move_and_collide choca con algo, el jugador se para ahi en vez de
## atravesarlo, sea Impulso o el dash del Potenciador de Viento (mismo bug,
## mismo arreglo). El collision_mask de Viento se sigue desactivando aparte
## (ver _handle_collision_ignore) para que SU Impulso si pueda saltar
## desniveles a proposito -- move_and_collide respeta ese mask igual que
## cualquier otro movimiento, asi que no hace falta tratar Viento distinto
## aqui.
func _move_lerp_step(from: Vector2, to: Vector2, ratio_antes: float, ratio_despues: float) -> void:
	var punto_antes: Vector2 = from.lerp(to, clamp(ratio_antes, 0.0, 1.0))
	var punto_despues: Vector2 = from.lerp(to, clamp(ratio_despues, 0.0, 1.0))
	move_and_collide(punto_despues - punto_antes)

func _process_potenciador_dash(delta: float) -> void:
	if _potenciador_dash_active_time <= 0.0:
		return
	var t_antes: float = 1.0 - clamp(_potenciador_dash_active_time / max(_potenciador_dash_total_time, 0.001), 0.0, 1.0)
	_potenciador_dash_active_time -= delta
	var t_despues: float = 1.0 - clamp(_potenciador_dash_active_time / max(_potenciador_dash_total_time, 0.001), 0.0, 1.0)
	_move_lerp_step(_potenciador_dash_from, _potenciador_dash_to, t_antes, t_despues)

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
	elif Input.is_action_just_pressed("debug_style_agua"):
		new_path = "res://resources/styles/agua.tres"
	elif Input.is_action_just_pressed("debug_style_rayo"):
		new_path = "res://resources/styles/rayo.tres"
	elif Input.is_action_just_pressed("debug_style_tierra"):
		new_path = "res://resources/styles/tierra.tres"
	if new_path != "":
		style_data = load(new_path)
		_apply_style_reset()

func _current_speed_multiplier() -> float:
	var mult := 1.0
	if style_data.melee_only and puertas_nivel > 0:
		mult *= 1.0 + puertas_nivel * style_data.puertas_speed_multiplier_per_level
	# Bomba de humo (H5, Herboristeria): escape garantizado -- velocidad
	# breve ademas de la invulnerabilidad (ver confirm_damage_taken).
	if _bomba_humo_time_remaining > 0.0:
		mult *= BOMBA_HUMO_SPEED_MULTIPLIER
	# Rayo: empuje de velocidad propio tras el Impulso.
	if _impulse_speed_boost_remaining > 0.0:
		mult *= style_data.impulse_speed_boost_multiplier
	# Rayo (Potenciador recibido, H6): "da velocidad" -- ver
	# confirm_potenciador_received.
	if _potenciador_active_element == "rayo":
		mult *= _potenciador_speed_multiplier
	return mult

## H5 tarea 2: se extiende para multiplicar tambien por el nivel de Forja
## del jugador (NetworkManager.forja_nivel, persistente por peer_id) y por el
## brindis de grupo de la Taberna (NetworkManager.brindis_damage_multiplier,
## activo para todos mientras dure) -- antes solo consideraba las Puertas
## del Fisico. Se usa en TODOS los sitios que ya usaban esta funcion
## (Basico de los 3 estilos, Lanzamiento y embestida del Fisico), asi que la
## Forja y el brindis suben el daño de cualquier estilo, no solo Fisico.
func _current_damage_multiplier() -> float:
	var mult := 1.0
	if style_data.melee_only and puertas_nivel > 0:
		mult *= 1.0 + puertas_nivel * style_data.puertas_damage_multiplier_per_level
	mult *= _forja_damage_multiplier()
	mult *= NetworkManager.brindis_damage_multiplier
	return mult

## Nivel de Forja de ESTE jugador (por peer_id, ver NetworkManager.forja_nivel)
## traducido a multiplicador de daño. clampi() cubre tanto "sin entrada en
## el Dictionary" (Dictionary.get devuelve el default 0) como un nivel fuera
## de rango por seguridad.
func _forja_damage_multiplier() -> float:
	var nivel: int = clampi(NetworkManager.forja_nivel.get(get_multiplayer_authority(), 0), 0, FORJA_BONUS_POR_NIVEL.size() - 1)
	return 1.0 + FORJA_BONUS_POR_NIVEL[nivel]

## Peso del botin (H2 tarea 4): cuantos mas cadaveres cargues, mas lento
## vuelves. Lineal con un suelo minimo, no depende del estilo (a diferencia
## de _current_speed_multiplier, que si es cosa de las Puertas del Fisico).
func _carga_speed_multiplier() -> float:
	if carried_cadaver_paths.is_empty():
		return 1.0
	return max(MIN_CARGA_SPEED_RATIO, 1.0 - carried_cadaver_paths.size() * CARGA_SPEED_PENALTY_PER_CADAVER)

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
		"rayo":
			return "electrico"
		"agua":
			return "veneno"
		"tierra":
			return "aplastamiento"
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

## Cadaver mas cercano dentro de range_max que nadie este cargando ya.
## Proximidad simple, sin cono: recoger no necesita apuntar, solo estar
## cerca (a diferencia del Agarre, que si apunta a un enemigo vivo).
func _find_nearest_free_cadaver(range_max: float) -> Cadaver:
	var nearest: Cadaver = null
	var best_dist: float = INF
	for c in get_tree().get_nodes_in_group(Cadaver.GRUPO_CADAVERES):
		if not (c is Cadaver) or c.cargado_por_peer_id != 0:
			continue
		var dist: float = global_position.distance_to(c.global_position)
		if dist <= range_max and dist < best_dist:
			best_dist = dist
			nearest = c
	return nearest

## Comprador mas cercano dentro de range_max. Mismo criterio de proximidad
## simple que _find_nearest_free_cadaver -- los compradores son estaticos,
## no hace falta cono ni deteccion fisica.
func _find_nearest_comprador_in_range(range_max: float) -> Comprador:
	var nearest: Comprador = null
	var best_dist: float = INF
	for c in get_tree().get_nodes_in_group(Comprador.GRUPO_COMPRADORES):
		if not (c is Comprador):
			continue
		var dist: float = global_position.distance_to(c.global_position)
		if dist <= range_max and dist < best_dist:
			best_dist = dist
			nearest = c
	return nearest

## Cambista mas cercano dentro de range_max. Misma proximidad simple que
## _find_nearest_comprador_in_range -- el cambista tambien es estatico.
func _find_nearest_cambista_in_range(range_max: float) -> Cambista:
	var nearest: Cambista = null
	var best_dist: float = INF
	for c in get_tree().get_nodes_in_group(Cambista.GRUPO_CAMBISTAS):
		if not (c is Cambista):
			continue
		var dist: float = global_position.distance_to(c.global_position)
		if dist <= range_max and dist < best_dist:
			best_dist = dist
			nearest = c
	return nearest

## Mesa de dados mas cercana dentro de range_max. Misma proximidad simple
## que las funciones de arriba.
func _find_nearest_mesa_dados_in_range(range_max: float) -> MesaDados:
	var nearest: MesaDados = null
	var best_dist: float = INF
	for m in get_tree().get_nodes_in_group(MesaDados.GRUPO_MESAS_DADOS):
		if not (m is MesaDados):
			continue
		var dist: float = global_position.distance_to(m.global_position)
		if dist <= range_max and dist < best_dist:
			best_dist = dist
			nearest = m
	return nearest

## Usurero mas cercano dentro de range_max. Misma proximidad simple que las
## funciones de arriba -- el Usurero tambien es estatico.
func _find_nearest_usurero_in_range(range_max: float) -> Usurero:
	var nearest: Usurero = null
	var best_dist: float = INF
	for u in get_tree().get_nodes_in_group(Usurero.GRUPO_USUREROS):
		if not (u is Usurero):
			continue
		var dist: float = global_position.distance_to(u.global_position)
		if dist <= range_max and dist < best_dist:
			best_dist = dist
			nearest = u
	return nearest

## Forja mas cercana dentro de range_max. Misma proximidad simple que las
## funciones de arriba -- la Forja tambien es estatica.
func _find_nearest_forja_in_range(range_max: float) -> Forja:
	var nearest: Forja = null
	var best_dist: float = INF
	for f in get_tree().get_nodes_in_group(Forja.GRUPO_FORJAS):
		if not (f is Forja):
			continue
		var dist: float = global_position.distance_to(f.global_position)
		if dist <= range_max and dist < best_dist:
			best_dist = dist
			nearest = f
	return nearest

## Herboristeria mas cercana dentro de range_max. Misma proximidad simple.
func _find_nearest_herboristeria_in_range(range_max: float) -> Herboristeria:
	var nearest: Herboristeria = null
	var best_dist: float = INF
	for h in get_tree().get_nodes_in_group(Herboristeria.GRUPO_HERBORISTERIAS):
		if not (h is Herboristeria):
			continue
		var dist: float = global_position.distance_to(h.global_position)
		if dist <= range_max and dist < best_dist:
			best_dist = dist
			nearest = h
	return nearest

## Taberna mas cercana dentro de range_max. Misma proximidad simple.
func _find_nearest_taberna_in_range(range_max: float) -> Taberna:
	var nearest: Taberna = null
	var best_dist: float = INF
	for t in get_tree().get_nodes_in_group(Taberna.GRUPO_TABERNAS):
		if not (t is Taberna):
			continue
		var dist: float = global_position.distance_to(t.global_position)
		if dist <= range_max and dist < best_dist:
			best_dist = dist
			nearest = t
	return nearest

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

	confirm_basic_attack.rpc(next_combo, new_chakra, spawn_tag, aim_point, not targets.is_empty())

## Resultado confirmado por el host. Se aplica en todos los peers por igual.
## hit_occurred (nuevo, solo para el screen shake) es simplemente si el
## cono encontro algun enemigo -- no cambia ningun calculo de daño/chakra,
## solo se lee para disparar la sacudida de camara del propio atacante.
@rpc("any_peer", "call_local", "reliable")
func confirm_basic_attack(combo_index: int, new_chakra: float, spawn_tag: bool, aim_point: Vector2, hit_occurred: bool) -> void:
	combo_count = combo_index
	chakra_current = new_chakra
	_combo_window_timer = style_data.basic_combo_window
	if spawn_tag:
		_spawn_status_tag(aim_point)
	if hit_occurred:
		trigger_hit_shake()

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
	# Solo para el screen shake local del propio tirador al conectar (ver
	# projectile.gd _on_body_entered) -- no cambia el calculo de daño, que
	# sigue siendo exclusivo del host.
	proj.shooter_peer_id = get_multiplayer_authority()
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
		_update_potenciador_visual()
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

## Mientras se carguen cadaveres, se apilan detras del jugador siguiendo su
## posicion cada frame -- mismo mecanismo que _process_grab_hold (solo la
## autoridad del personaje mueve, nunca por RPC), pero en fila para varios a
## la vez en vez de uno solo delante.
func _process_carry_hold() -> void:
	for i in range(carried_cadaver_paths.size()):
		var cad := get_node_or_null(carried_cadaver_paths[i]) as Cadaver
		if cad == null or not is_instance_valid(cad):
			continue
		var offset: Vector2 = Vector2.LEFT.rotated(_torso.rotation) * (CADAVER_CARRY_OFFSET + i * CADAVER_CARRY_SPACING)
		cad.global_position = global_position + offset

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
	zone.damage_type = _basic_damage_type()
	if style_data.element_name == "fuego":
		zone.damage_per_second = style_data.zone_damage_per_second
	elif style_data.element_name == "viento":
		zone.pull_force = style_data.zone_pull_force
	elif style_data.element_name == "rayo":
		zone.damage_per_second = style_data.zone_damage_per_second
	elif style_data.element_name == "agua" or style_data.element_name == "tierra":
		zone.slow_factor = style_data.zone_slow_factor
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
		# La deteccion (geometria contra la posicion ya sincronizada de cada
		# enemigo) se calcula igual en todos los peers; solo la APLICACION
		# del daño sigue reservada al host dentro de la funcion. Se necesita
		# el resultado aqui, fuera del guard is_server(), para poder disparar
		# el screen shake en la camara del propio jugador local aunque no
		# sea el host.
		if _apply_impulse_pierce_damage(from_pos, to_pos) and is_multiplayer_authority():
			trigger_hit_shake()
	elif style_data.element_name == "fuego":
		_spawn_impulse_trail(from_pos, to_pos)
	elif style_data.element_name == "rayo":
		_impulse_speed_boost_remaining = style_data.impulse_speed_boost_duration
	elif style_data.element_name == "agua":
		# Prediccion local igual que el Ungüento -- es un coste/beneficio
		# propio, no hace falta ir al host para curarse de golpe.
		vida_actual = min(vida_actual + style_data.impulse_self_heal, style_data.vida_maxima)
	elif style_data.element_name == "tierra":
		if multiplayer.is_server():
			_apply_impulse_shockwave(from_pos)

func _process_impulse_motion(delta: float) -> void:
	if _impulse_active_time <= 0.0:
		return
	var t_antes: float = 1.0 - clamp(_impulse_active_time / max(style_data.impulse_travel_time, 0.001), 0.0, 1.0)
	_impulse_active_time -= delta
	var t_despues: float = 1.0 - clamp(_impulse_active_time / max(style_data.impulse_travel_time, 0.001), 0.0, 1.0)
	_move_lerp_step(_impulse_from, _impulse_to, t_antes, t_despues)

## Fisico: embestida, atraviesa enemigos en el camino. La APLICACION del
## daño solo ocurre cuando multiplayer.is_server() es true, asi el danio
## siempre lo decide el host -- pero la deteccion (y el bool que devuelve)
## corre igual en cualquier peer, para que el screen shake local del
## jugador (ver confirm_impulse) funcione aunque no sea el host.
func _apply_impulse_pierce_damage(from_pos: Vector2, to_pos: Vector2) -> bool:
	var damage: float = style_data.impulse_pierce_damage * _current_damage_multiplier()
	var hit_occurred := false
	for enemigo in get_tree().get_nodes_in_group(GRUPO_ENEMIGOS):
		if not (enemigo is Node2D):
			continue
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemigo.global_position, from_pos, to_pos)
		if enemigo.global_position.distance_to(closest) <= style_data.impulse_pierce_width:
			hit_occurred = true
			if multiplayer.is_server() and enemigo.has_method("recibir_daño"):
				enemigo.recibir_daño("contundente", damage)
	return hit_occurred

## Tierra: onda de choque en el punto de partida del Impulso (antes de
## desplazarse), daña a los enemigos cercanos. Solo se llama cuando
## multiplayer.is_server() es true, mismo criterio que _apply_impulse_pierce_damage.
func _apply_impulse_shockwave(from_pos: Vector2) -> void:
	var damage: float = style_data.impulse_shockwave_damage * _current_damage_multiplier()
	for enemigo in get_tree().get_nodes_in_group(GRUPO_ENEMIGOS):
		if enemigo is Node2D and enemigo.global_position.distance_to(from_pos) <= style_data.impulse_shockwave_radius:
			if enemigo.has_method("recibir_daño"):
				enemigo.recibir_daño("aplastamiento", damage)

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
		# Sales (H5, Herboristeria): reducen este desgaste mientras dure el
		# efecto -- ver _handle_sales() y SALES_DRAIN_REDUCTION.
		var drain_mult := SALES_DRAIN_REDUCTION if _sales_time_remaining > 0.0 else 1.0
		vida_actual = max(vida_actual - style_data.puertas_life_drain_per_second_per_level * puertas_nivel * drain_mult * delta, 1.0)
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
	_update_puertas_visual()

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
	_update_puertas_visual()
	_update_vulnerability_visual()

## Escala y tine TorsoRect/LegsRect segun puertas_nivel (mas rojo/mas grande
## por nivel); en nivel 0 vuelve a los colores/escala base de player.tscn.
func _update_puertas_visual() -> void:
	var max_nivel: float = float(max(style_data.puertas_niveles_max, 1))
	var ratio: float = clamp(float(puertas_nivel) / max_nivel, 0.0, 1.0)
	var target_scale := Vector2.ONE * (1.0 + ratio * PUERTAS_SCALE_PER_LEVEL)
	_torso_rect.scale = target_scale
	_legs_rect.scale = target_scale
	_torso_rect.color = _torso_color_base.lerp(PUERTAS_COLOR_MAX, ratio)
	_legs_rect.color = _legs_color_base.lerp(PUERTAS_COLOR_MAX, ratio)

## Indicador de vulnerabilidad tras cerrar las Puertas -- distinto del tinte
## de nivel de arriba, para no confundir "Puertas abiertas" con "acabo de
## cerrarlas y ahora recibo mas daño".
func _update_vulnerability_visual() -> void:
	_vulnerability_indicator.visible = _vulnerabilidad_restante > 0.0

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
		# Mismo problema que el cono vacio de abajo: sin aviso, un E sin
		# chakra suficiente es indistinguible de "esta roto".
		confirm_potenciador_failed.rpc("chakra insuficiente")
		return
	var facing_dir: Vector2 = Vector2.RIGHT.rotated(_torso.rotation)
	var candidates := _find_allies_in_cone(style_data.potenciador_range, style_data.potenciador_cone_degrees, facing_dir)
	if candidates.is_empty():
		# Sin esto, un E que no encuentra a nadie en el cono no da ninguna
		# señal -- indistinguible de "esta roto" para quien lo pulsa.
		confirm_potenciador_failed.rpc("no hay ningun aliado en rango")
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
	var heal_per_second := 0.0
	var speed_multiplier := 1.0
	var damage_reduction := 1.0
	if style_data.element_name == "fuego":
		damage_bonus = style_data.potenciador_fuego_damage_bonus
	elif style_data.element_name == "viento":
		dash_distance = style_data.potenciador_viento_dash_distance
		dash_travel_time = style_data.potenciador_viento_dash_travel_time
	elif style_data.element_name == "agua":
		heal_per_second = style_data.potenciador_agua_heal_total / max(duration, 0.001)
	elif style_data.element_name == "rayo":
		speed_multiplier = style_data.potenciador_rayo_speed_multiplier
	elif style_data.element_name == "tierra":
		damage_reduction = style_data.potenciador_tierra_damage_reduction
	confirm_potenciador_cast.rpc(new_chakra)
	# RPC sobre OTRO nodo replicado (el objetivo, no self) -- mismo truco que
	# ya usa el Agarre/Lanzamiento para aplicar el resultado donde toca.
	target.confirm_potenciador_received.rpc(style_data.element_name, duration, get_multiplayer_authority(), damage_bonus, dash_distance, dash_travel_time, global_position, heal_per_second, speed_multiplier, damage_reduction)

@rpc("any_peer", "call_local", "reliable")
func confirm_potenciador_cast(new_chakra: float) -> void:
	chakra_current = new_chakra

## Aviso de fallo al que pidio el Potenciador: sin chakra suficiente o sin
## ningun aliado en el cono. Se manda desde el host sobre el propio nodo del
## que lo lanzo (misma instancia que corre en todos los peers); solo el peer
## dueno actua para no llenar la consola del resto. Placeholder de sonido: no
## hay audio en el proyecto todavia, se deja el log como feedback minimo.
@rpc("any_peer", "call_local", "reliable")
func confirm_potenciador_failed(motivo: String) -> void:
	if not is_multiplayer_authority():
		return
	print("Potenciador fallido: ", motivo)

## Se ejecuta en el jugador OBJETIVO (no en quien lo lanzo). caster_pos es
## la posicion del que lo lanzo en el momento del cast, usada solo por el
## dash de Viento.
@rpc("any_peer", "call_local", "reliable")
func confirm_potenciador_received(element: String, duration: float, caster_id: int, damage_bonus: float, dash_distance: float, dash_travel_time: float, caster_pos: Vector2, heal_per_second: float, speed_multiplier: float, damage_reduction: float) -> void:
	_potenciador_active_element = element
	_potenciador_time_remaining = duration
	_potenciador_caster_id = caster_id
	_potenciador_damage_bonus = damage_bonus
	_potenciador_heal_per_second = heal_per_second
	_potenciador_speed_multiplier = speed_multiplier
	_potenciador_damage_reduction = damage_reduction
	_update_potenciador_visual()
	if element == "viento" and dash_distance > 0.0:
		_start_potenciador_dash(caster_pos, dash_distance, dash_travel_time)

## Glow naranja (Fuego) / estela verde (Viento) mientras el Potenciador
## recibido siga activo; se apaga solo cuando expira (_handle_potenciador_timer)
## o se consume de golpe (bonus de Agarre del Fisico, ver confirm_grab).
func _update_potenciador_visual() -> void:
	match _potenciador_active_element:
		"fuego":
			_potenciador_indicator.color = POTENCIADOR_COLOR_FUEGO
			_potenciador_indicator.visible = true
		"viento":
			_potenciador_indicator.color = POTENCIADOR_COLOR_VIENTO
			_potenciador_indicator.visible = true
		"agua":
			_potenciador_indicator.color = POTENCIADOR_COLOR_AGUA
			_potenciador_indicator.visible = true
		"rayo":
			_potenciador_indicator.color = POTENCIADOR_COLOR_RAYO
			_potenciador_indicator.visible = true
		"tierra":
			_potenciador_indicator.color = POTENCIADOR_COLOR_TIERRA
			_potenciador_indicator.visible = true
		_:
			_potenciador_indicator.visible = false

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

## Llamado por enemy_simple.gd cuando ataca cuerpo a cuerpo. Los enemigos ya
## estan en red (host-autoritativo, ver enemy_simple.gd): _atacar() solo
## corre en el host, asi que el guard de abajo siempre deja pasar la llamada
## real y solo retransmite -- pero se deja explicito por si en el futuro
## algun peer local llega a llamar esto por error (amistoso-fuego, etc.).
func recibir_daño(tipo_daño: String, cantidad: float) -> void:
	if not multiplayer.is_server():
		return
	confirm_damage_taken.rpc(tipo_daño, cantidad)

## Aplica el daño igual en todos los peers (incluido el host, call_local).
## Sin esto, recibir_daño() solo mutaba la copia local del host y nunca
## llegaba al peer dueño del personaje -- vida_actual se desincronizaba.
@rpc("any_peer", "call_local", "reliable")
func confirm_damage_taken(_tipo_daño: String, cantidad: float) -> void:
	# Bomba de humo (H5, Herboristeria): invulnerabilidad breve mientras se
	# escapa -- se ignora el daño entero, no solo se reduce. Corre igual en
	# todos los peers porque _bomba_humo_time_remaining ya esta sincronizado
	# via confirm_usar_consumible (call_local reliable), asi que el
	# resultado es el mismo en todas las copias de este nodo.
	if _bomba_humo_time_remaining > 0.0:
		return
	vida_actual = max(vida_actual - cantidad * _vulnerabilidad_multiplicador * _potenciador_damage_reduction, 0.0)
	# Feedback de golpe: flash breve en todos los peers (este RPC ya es
	# call_local) y sacudida de camara solo en la del propio jugador local.
	_flash_damage_taken()
	trigger_hit_shake(SCREEN_SHAKE_HIT_STRENGTH)

# =========================================================================
# Cadaveres (H2) -- recoger/soltar con G, vender con V. Mismo patron
# submit_/confirm_ que el resto del kit: el cliente pide, el host decide
# (a que cadaver/comprador te refieres, cuanto vale) y confirma con un RPC
# call_local que aplica el resultado igual en todos los peers.
# =========================================================================

func _request_toggle_carry() -> void:
	submit_toggle_carry.rpc_id(1)

## "Toggle" en el sentido de que una sola tecla sirve para las dos acciones:
## si hay un cadaver libre cerca y queda hueco, se recoge; si no, se suelta
## el ultimo que se cogio. Evita necesitar una tecla separada para soltar
## en un vertical slice que todavia no tiene UI para explicarla.
@rpc("any_peer", "call_local", "reliable")
func submit_toggle_carry() -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	if carried_cadaver_paths.size() < MAX_CADAVERES_CARGADOS:
		var candidate := _find_nearest_free_cadaver(CADAVER_PICKUP_RANGE)
		if candidate != null:
			confirm_pickup_cadaver.rpc(candidate.get_path())
			return
	if not carried_cadaver_paths.is_empty():
		confirm_drop_cadaver.rpc(carried_cadaver_paths[-1])

@rpc("any_peer", "call_local", "reliable")
func confirm_pickup_cadaver(path: NodePath) -> void:
	var cad := get_node_or_null(path) as Cadaver
	if cad == null or not is_instance_valid(cad) or cad.cargado_por_peer_id != 0:
		return # otro jugador se lo llevo entre que el host decidio y esto llega
	cad.cargado_por_peer_id = get_multiplayer_authority()
	carried_cadaver_paths.append(path)

@rpc("any_peer", "call_local", "reliable")
func confirm_drop_cadaver(path: NodePath) -> void:
	carried_cadaver_paths.erase(path)
	var cad := get_node_or_null(path) as Cadaver
	if cad == null or not is_instance_valid(cad):
		return
	cad.cargado_por_peer_id = 0
	cad.global_position = global_position + Vector2.RIGHT.rotated(_torso.rotation) * CADAVER_DROP_OFFSET

func _request_vender() -> void:
	submit_vender.rpc_id(1)

## Vende de golpe TODOS los cadaveres que se esten cargando al comprador mas
## cercano en rango -- mas simple de probar en un vertical slice que vender
## de uno en uno, y demuestra igual de bien el flujo completo (brief H2
## tarea 5: matar -> recoger -> volver -> vender).
@rpc("any_peer", "call_local", "reliable")
func submit_vender() -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	if carried_cadaver_paths.is_empty():
		# Sin aviso, pulsar V sin cargar nada se ve igual que un boton roto
		# (mismo motivo que confirm_casino_mensaje en el cambista/dados).
		confirm_casino_mensaje.rpc("No llevas ningun cadaver que vender (recogelo con G)")
		return
	var comprador := _find_nearest_comprador_in_range(VENTA_RANGE)
	if comprador == null:
		confirm_casino_mensaje.rpc("No hay ningun comprador cerca")
		return
	var total_precio := 0.0
	var vendidos: Array[NodePath] = []
	for path in carried_cadaver_paths:
		var cad := get_node_or_null(path) as Cadaver
		if cad == null or not is_instance_valid(cad):
			continue
		total_precio += comprador.calcular_precio(cad.estado_conservacion, cad.valor_base)
		vendidos.append(path)
	if vendidos.is_empty():
		return
	# Usurero: mientras quede deuda pendiente (importe real, no un contador
	# de transacciones -- ver NetworkManager.usurero_deuda_pendiente), esta
	# venta se recorta un usurero_deuda_recorte_porcentaje antes de sumarse
	# al pool, y ese recorte paga deuda directamente. min() evita recortar
	# de mas si lo que queda por pagar es menor que el recorte calculado
	# (asi la deuda no se va a negativo al saldarse con la ultima venta).
	var recorte_usurero := 0.0
	var nueva_deuda: float = NetworkManager.usurero_deuda_pendiente
	if nueva_deuda > 0.0:
		recorte_usurero = min(total_precio * NetworkManager.usurero_deuda_recorte_porcentaje, nueva_deuda)
		total_precio -= recorte_usurero
		nueva_deuda -= recorte_usurero
	var nuevo_total: float = NetworkManager.dinero_manchado + total_precio
	confirm_vender.rpc(vendidos, nuevo_total, total_precio, recorte_usurero, nueva_deuda)

## Aplica la venta igual en todos los peers: borra los cadaveres vendidos,
## los quita de la lista de carga y actualiza el pool compartido de dinero
## manchado (NetworkManager.dinero_manchado -- mutarlo aqui directamente
## vale porque este RPC ya es call_local reliable en si mismo, no hace
## falta un RPC aparte solo para el dinero). Tambien aplica la deuda del
## Usurero ya decidida por el host en submit_vender().
@rpc("any_peer", "call_local", "reliable")
func confirm_vender(vendidos: Array[NodePath], nuevo_total: float, precio_ganado: float, recorte_usurero: float, nueva_deuda: float) -> void:
	for path in vendidos:
		carried_cadaver_paths.erase(path)
		var cad := get_node_or_null(path) as Cadaver
		if cad != null and is_instance_valid(cad):
			cad.queue_free()
	NetworkManager.dinero_manchado = nuevo_total
	NetworkManager.usurero_deuda_pendiente = nueva_deuda
	print("[Venta] +%.1f dinero manchado (total compartido: %.1f)" % [precio_ganado, nuevo_total])
	_status_label.modulate = Color(1, 1, 1)
	if recorte_usurero > 0.0:
		_status_label.text = "Vendiste %d cadaver(es): +%.0f manchado (recorte Usurero -%.0f, deuda restante: -%.0f)" % [vendidos.size(), precio_ganado, recorte_usurero, nueva_deuda]
	else:
		_status_label.text = "Vendiste %d cadaver(es): +%.0f manchado" % [vendidos.size(), precio_ganado]

# =========================================================================
# Casino (H3) -- cambista (C) y mesa de dados (T=alto, B=bajo). Mismo patron
# submit_/confirm_ que el resto del kit: el cliente pide, el host decide
# (que punto esta en rango, cuanto se gana o se pierde) y confirma con un
# RPC call_local que aplica el resultado igual en todos los peers.
# =========================================================================

func _request_cambiar_dinero() -> void:
	submit_cambiar_dinero.rpc_id(1)

## Cambia TODO el dinero manchado disponible en el pool compartido de una
## vez (brief H3 tarea 1: "mas simple es cambiar todo el manchado
## disponible de una vez") -- mismo criterio que "vender todos los
## cadaveres cargados de golpe" en submit_vender() de arriba.
@rpc("any_peer", "call_local", "reliable")
func submit_cambiar_dinero() -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	var cambista := _find_nearest_cambista_in_range(CASINO_RANGE)
	if cambista == null:
		confirm_casino_mensaje.rpc("No hay ningun cambista cerca")
		return
	var manchado_disponible: float = NetworkManager.dinero_manchado
	if manchado_disponible <= 0.0:
		# Se ignora sin penalizar, pero SI hay que avisar -- si no, pulsar la
		# tecla sin dinero manchado se ve exactamente igual que un boton
		# roto (brief: "los dos cuadrados de abajo no hacen nada").
		confirm_casino_mensaje.rpc("No tienes dinero manchado que cambiar")
		return
	var limpio_ganado: float = cambista.calcular_cambio(manchado_disponible)
	var nuevo_manchado: float = NetworkManager.dinero_manchado - manchado_disponible
	var nuevo_limpio: float = NetworkManager.dinero_limpio + limpio_ganado
	confirm_cambiar_dinero.rpc(nuevo_manchado, nuevo_limpio, limpio_ganado)

@rpc("any_peer", "call_local", "reliable")
func confirm_cambiar_dinero(nuevo_manchado: float, nuevo_limpio: float, limpio_ganado: float) -> void:
	NetworkManager.dinero_manchado = nuevo_manchado
	NetworkManager.dinero_limpio = nuevo_limpio
	var mensaje: String = "Cambiaste: +%.0f limpio (comision 15%%)" % limpio_ganado
	print("[Cambista] +%.1f dinero limpio (comision 15%% aplicada, limpio compartido: %.1f, manchado restante: %.1f)" % [limpio_ganado, nuevo_limpio, nuevo_manchado])
	_status_label.modulate = Color(1, 1, 1)
	_status_label.text = mensaje

func _request_apostar_dados(eleccion: String) -> void:
	submit_apostar_dados.rpc_id(1, eleccion, _apuesta_moneda)

## Apuesta la cantidad fija de la mesa (MesaDados.apuesta_fija) a "alto" o
## "bajo", con la moneda que el jugador tenga seleccionada (tecla M) --
## "limpio" (el camino que sigue el brief al pie de la letra) o "manchado"
## (via de blanquear jugando en vez de pagando la comision del Cambista,
## decision de diseno del usuario, ver _apuesta_moneda arriba). `moneda`
## solo elige DE QUE POOL sale/entra el dinero -- el host sigue siendo quien
## calcula el resultado real, asi que el cliente no puede inventarse ni la
## cantidad ni el resultado, solo pedir con cual de sus dos monederos jugar.
## Ver mesa_dados.gd para las reglas de las tres caras y el payout. El RNG
## del resultado corre entero en el host dentro de mesa.resolver_tirada().
@rpc("any_peer", "call_local", "reliable")
func submit_apostar_dados(eleccion: String, moneda: String) -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	if eleccion != "alto" and eleccion != "bajo":
		return
	if moneda != "limpio" and moneda != "manchado":
		return
	var mesa := _find_nearest_mesa_dados_in_range(CASINO_RANGE)
	if mesa == null:
		confirm_casino_mensaje.rpc("No hay ninguna mesa de dados cerca")
		return
	var disponible: float = NetworkManager.dinero_limpio if moneda == "limpio" else NetworkManager.dinero_manchado
	if disponible < mesa.apuesta_fija:
		# Igual que en el Cambista: sin aviso esto se ve identico a un boton
		# que no responde.
		confirm_casino_mensaje.rpc("Necesitas al menos %.0f de dinero %s para apostar" % [mesa.apuesta_fija, moneda])
		return
	var resultado := mesa.resolver_tirada(eleccion)
	var gano: bool = resultado["gano"]
	var cara: int = resultado["cara"]
	# Usurero: una apuesta GANADA paga deuda pendiente (importe real, no un
	# contador -- ver comentario de submit_vender) -- perder no cuenta, no
	# genera nada que recortar.
	var recorte_usurero := 0.0
	var nueva_deuda: float = NetworkManager.usurero_deuda_pendiente
	var ganancia: float = mesa.apuesta_fija
	if gano and nueva_deuda > 0.0:
		recorte_usurero = min(mesa.apuesta_fija * NetworkManager.usurero_deuda_recorte_porcentaje, nueva_deuda)
		ganancia -= recorte_usurero
		nueva_deuda -= recorte_usurero
	var delta: float = ganancia if gano else -mesa.apuesta_fija
	var nuevo_limpio: float = NetworkManager.dinero_limpio
	var nuevo_manchado: float = NetworkManager.dinero_manchado
	if moneda == "limpio":
		nuevo_limpio += delta
	else:
		nuevo_manchado += delta
	confirm_apostar_dados.rpc(nuevo_limpio, nuevo_manchado, moneda, eleccion, cara, gano, mesa.apuesta_fija, recorte_usurero, nueva_deuda)

@rpc("any_peer", "call_local", "reliable")
func confirm_apostar_dados(nuevo_limpio: float, nuevo_manchado: float, moneda: String, eleccion: String, cara: int, gano: bool, apuesta: float, recorte_usurero: float, nueva_deuda: float) -> void:
	NetworkManager.dinero_limpio = nuevo_limpio
	NetworkManager.dinero_manchado = nuevo_manchado
	NetworkManager.usurero_deuda_pendiente = nueva_deuda
	var resultado_texto: String
	if gano:
		resultado_texto = "GANASTE +%.1f" % (apuesta - recorte_usurero)
		if recorte_usurero > 0.0:
			resultado_texto += " (recorte Usurero -%.1f, deuda restante: -%.0f)" % [recorte_usurero, nueva_deuda]
	else:
		resultado_texto = "perdiste -%.1f" % apuesta
	print("[Dados] Apostaste %s a %s, salio cara %d -> %s (limpio: %.1f, manchado: %.1f)" % [moneda, eleccion, cara, resultado_texto, nuevo_limpio, nuevo_manchado])
	_status_label.text = "Dados %s (%s, cara %d): %s" % [moneda, eleccion, cara, resultado_texto]
	_status_label.modulate = Color(0.4, 1, 0.4) if gano else Color(1, 0.4, 0.4)

## Mensaje generico de casino para casos que se ignoran sin penalizar pero
## que SI hay que comunicar (sin objetivo en rango, fondos insuficientes) --
## si no, la tecla se ve exactamente igual que un boton roto.
@rpc("any_peer", "call_local", "reliable")
func confirm_casino_mensaje(mensaje: String) -> void:
	_status_label.modulate = Color(1, 1, 1)
	_status_label.text = mensaje

# =========================================================================
# Usurero (H4 recortado a solo esto -- decision explicita del usuario: sin
# boveda con votacion, revelacion ni Modo Mesa Alta, ver comentario de
# cabecera de usurero.gd). Mismo patron submit_/confirm_ que el resto del
# casino: el cliente pide, el host decide (trigger, cuanto presta, si ya hay
# deuda activa) y confirma con un RPC call_local que aplica el resultado
# igual en todos los peers.
# =========================================================================

func _request_prestamo_usurero() -> void:
	submit_pedir_prestamo_usurero.rpc_id(1)

## Concede el prestamo del Usurero SOLO si ambos pools compartidos estan
## exactamente a cero (decision de diseno explicita del usuario -- de verdad
## no queda nada de ningun tipo) y no hay ya una deuda activa. No permitir
## un segundo prestamo mientras se sigue pagando el primero es una decision
## de diseno (la tarea deja el criterio abierto): mantiene un unico contador
## entero en NetworkManager en vez de una pila de prestamos independientes,
## y evita que la deuda crezca sin limite. Si te vuelves a quedar a cero con
## deuda activa, la unica salida es seguir generando dinero (aunque sea
## recortado) hasta saldarla -- no hay forma de "quedarse atascado del todo"
## porque los enemigos de la sala de pruebas siguen ahi para pelear y vender.
@rpc("any_peer", "call_local", "reliable")
func submit_pedir_prestamo_usurero() -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	var usurero := _find_nearest_usurero_in_range(CASINO_RANGE)
	if usurero == null:
		confirm_casino_mensaje.rpc("No hay ningun usurero cerca")
		return
	if NetworkManager.dinero_manchado > 0.0 or NetworkManager.dinero_limpio > 0.0:
		confirm_casino_mensaje.rpc("El Usurero solo presta cuando te has quedado sin nada de nada")
		return
	if NetworkManager.usurero_deuda_pendiente > 0.0:
		confirm_casino_mensaje.rpc("Ya le debes al Usurero -- salda la deuda antes de pedir mas")
		return
	var nuevo_limpio: float = NetworkManager.dinero_limpio + usurero.monto_prestamo
	# La deuda total incluye el interes (brief 2.3: "20%"): pides 50, debes
	# 60 -- ver comentario de recorte_porcentaje en usurero.gd.
	var deuda_total: float = usurero.monto_prestamo * (1.0 + usurero.recorte_porcentaje)
	confirm_pedir_prestamo_usurero.rpc(nuevo_limpio, usurero.monto_prestamo, deuda_total, usurero.recorte_porcentaje)

@rpc("any_peer", "call_local", "reliable")
func confirm_pedir_prestamo_usurero(nuevo_limpio: float, monto: float, deuda_total: float, recorte_porcentaje: float) -> void:
	NetworkManager.dinero_limpio = nuevo_limpio
	NetworkManager.usurero_deuda_pendiente = deuda_total
	NetworkManager.usurero_deuda_recorte_porcentaje = recorte_porcentaje
	print("[Usurero] Prestamo de %.1f limpio -- deuda: -%.0f (se paga al %.0f%% de cada venta/apuesta ganada)" % [monto, deuda_total, recorte_porcentaje * 100.0])
	_status_label.modulate = Color(1, 0.6, 0.6)
	_status_label.text = "Usurero: +%.0f limpio -- deuda: -%.0f" % [monto, deuda_total]

# =========================================================================
# Forja (H5 tarea 2, Calle de los Faroles) -- tecla Y. Mismo patron
# submit_/confirm_ que el resto: el cliente pide, el host decide (que Forja
# esta en rango, el precio del siguiente nivel, si hay dinero limpio
# suficiente en el pool compartido) y confirma con un RPC call_local que
# aplica el resultado igual en todos los peers.
# =========================================================================

func _request_mejorar_forja() -> void:
	submit_mejorar_forja.rpc_id(1)

## Mejora SIEMPRE al siguiente nivel (no se puede saltar ni elegir uno
## menor) -- mismo criterio de "una sola accion obvia por tecla" que el
## resto del casino/economia en este vertical slice sin UI real.
@rpc("any_peer", "call_local", "reliable")
func submit_mejorar_forja() -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	var forja := _find_nearest_forja_in_range(HUB_RANGE)
	if forja == null:
		confirm_casino_mensaje.rpc("No hay ninguna forja cerca")
		return
	var peer_id := get_multiplayer_authority()
	var nivel_actual: int = NetworkManager.forja_nivel.get(peer_id, 0)
	if nivel_actual >= FORJA_BONUS_POR_NIVEL.size() - 1:
		confirm_casino_mensaje.rpc("Tu arma ya esta al maximo nivel de forja")
		return
	var nivel_objetivo := nivel_actual + 1
	var precio: float = forja.precio_para_nivel(nivel_objetivo)
	if NetworkManager.dinero_limpio < precio:
		confirm_casino_mensaje.rpc("Necesitas %.0f de dinero limpio para mejorar la forja (nivel %d)" % [precio, nivel_objetivo])
		return
	var nuevo_limpio: float = NetworkManager.dinero_limpio - precio
	confirm_mejorar_forja.rpc(peer_id, nivel_objetivo, nuevo_limpio)

@rpc("any_peer", "call_local", "reliable")
func confirm_mejorar_forja(peer_id: int, nivel: int, nuevo_limpio: float) -> void:
	NetworkManager.forja_nivel[peer_id] = nivel
	NetworkManager.dinero_limpio = nuevo_limpio
	_status_label.modulate = Color(1, 1, 1)
	_status_label.text = "Forja mejorada a nivel %d (+%.0f%% daño)" % [nivel, FORJA_BONUS_POR_NIVEL[nivel] * 100.0]

# =========================================================================
# Herboristeria (H5 tarea 3, Calle de los Faroles) -- comprar con P/H/J/L,
# usar el mas reciente con I. Mismo patron submit_/confirm_ que el resto.
# =========================================================================

func _request_comprar_consumible(tipo: String) -> void:
	submit_comprar_consumible.rpc_id(1, tipo)

@rpc("any_peer", "call_local", "reliable")
func submit_comprar_consumible(tipo: String) -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	var herb := _find_nearest_herboristeria_in_range(HUB_RANGE)
	if herb == null:
		confirm_casino_mensaje.rpc("No hay ninguna herboristeria cerca")
		return
	if consumibles.size() >= MAX_CONSUMIBLES_CARGADOS:
		confirm_casino_mensaje.rpc("Ya llevas el maximo de consumibles cargados (%d)" % MAX_CONSUMIBLES_CARGADOS)
		return
	var precio: float = herb.precio_de(tipo)
	if precio < 0.0:
		return # tipo invalido, no deberia pasar nunca desde los botones del jugador
	if NetworkManager.dinero_limpio < precio:
		confirm_casino_mensaje.rpc("Necesitas %.0f de dinero limpio para comprar eso" % precio)
		return
	var nuevo_limpio: float = NetworkManager.dinero_limpio - precio
	confirm_comprar_consumible.rpc(tipo, nuevo_limpio)

@rpc("any_peer", "call_local", "reliable")
func confirm_comprar_consumible(tipo: String, nuevo_limpio: float) -> void:
	consumibles.append(tipo)
	NetworkManager.dinero_limpio = nuevo_limpio
	_status_label.modulate = Color(1, 1, 1)
	_status_label.text = "Comprado: %s (%d/%d cargados)" % [tipo, consumibles.size(), MAX_CONSUMIBLES_CARGADOS]

func _request_usar_consumible() -> void:
	submit_usar_consumible.rpc_id(1)

## Usa siempre el ULTIMO comprado (mas reciente, LIFO) -- brief: "una tecla
## para usar el consumible seleccionado/mas reciente". Sin UI de inventario
## en este vertical slice, "el mas reciente" es la unica seleccion posible
## sin anadir una pantalla propia solo para esto.
@rpc("any_peer", "call_local", "reliable")
func submit_usar_consumible() -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	if consumibles.is_empty():
		confirm_casino_mensaje.rpc("No tienes ningun consumible cargado")
		return
	var tipo: String = consumibles[-1]
	confirm_usar_consumible.rpc(tipo)

## Aplica el efecto real de `tipo` (ver comentario de cabecera de
## herboristeria.gd) y descarta el consumible usado. Todos los efectos son
## deterministas (sin RNG), asi que aplicarlos igual en todos los peers
## dentro de este RPC call_local basta -- no hace falta que el host calcule
## nada aparte y lo mande como parametro, a diferencia de p.ej. los dados.
@rpc("any_peer", "call_local", "reliable")
func confirm_usar_consumible(tipo: String) -> void:
	if consumibles.is_empty():
		return
	consumibles.remove_at(consumibles.size() - 1)
	match tipo:
		Herboristeria.TIPO_PILDORA:
			chakra_current = min(chakra_current + PILDORA_CHAKRA_AMOUNT, style_data.chakra_max)
		Herboristeria.TIPO_UNGUENTO:
			_unguento_time_remaining = UNGUENTO_DURATION
			_unguento_heal_per_second = UNGUENTO_TOTAL_HEAL / UNGUENTO_DURATION
		Herboristeria.TIPO_BOMBA_HUMO:
			_bomba_humo_time_remaining = BOMBA_HUMO_DURATION
		Herboristeria.TIPO_SALES:
			_sales_time_remaining = SALES_DURATION
	_status_label.modulate = Color(0.6, 1, 0.8)
	_status_label.text = "Usaste: %s (%d restantes)" % [tipo, consumibles.size()]

# =========================================================================
# Taberna "El Ancla Rota" (H5 tarea 4, Muelle) -- tecla X. A diferencia del
# resto de esta tanda, el resultado NO es individual: afecta a TODOS los
# jugadores conectados, asi que el estado del buff vive en NetworkManager
# (ver confirm_brindis alli) en vez de en este nodo -- mismo patron
# submit_/confirm_ en cuanto a validacion (cliente pide, host decide), pero
# la confirmacion apunta a un nodo distinto de self.
# =========================================================================

func _request_brindis() -> void:
	submit_brindis.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func submit_brindis() -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	var taberna := _find_nearest_taberna_in_range(HUB_RANGE)
	if taberna == null:
		confirm_casino_mensaje.rpc("No hay ninguna taberna cerca")
		return
	if NetworkManager.dinero_limpio < taberna.costo_brindis:
		confirm_casino_mensaje.rpc("Necesitas %.0f de dinero limpio para el brindis" % taberna.costo_brindis)
		return
	var nuevo_limpio: float = NetworkManager.dinero_limpio - taberna.costo_brindis
	var multiplicador: float = 1.0 + taberna.brindis_bonus_daño
	NetworkManager.confirm_brindis.rpc(nuevo_limpio, taberna.brindis_duracion, multiplicador)
	confirm_casino_mensaje.rpc("Brindis en El Ancla Rota: +%.0f%% de daño para todo el grupo durante %.0f s" % [taberna.brindis_bonus_daño * 100.0, taberna.brindis_duracion])
