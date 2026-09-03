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
## Ayuda de playtest, NO es una mecanica real del juego: las teclas 1-6
## (debug_style_* en project.godot) cambian el estilo del propio jugador en
## caliente. Sirve para probar combinaciones de estilos con un solo teclado
## conectado. La eleccion de estilo REAL ya existe (H6): pantalla previa al
## spawn (ver scripts/ui/seleccion_estilo.gd + NetworkManager.submit_style_choice/
## _spawn_player) -- estas teclas quedan solo como atajo de debug, no hace
## falta tocarlas para jugar.
##
## Rework de combate 2026-09-03 (plan-desarrollo.md seccion 2.1, T1-T3,
## pedido explicito del usuario -- ver diagnostico de choque con reglas
## invariantes de pilar-agent citado alli antes de tocar nada mas): el
## chakra dejo de recuperarse golpeando con el Basico y pasa a regenerarse
## solo por tiempo (ver chakra_current, _advance_chakra_regen); a cambio,
## cada ranura que no sea el Basico gano su propio cooldown (ver
## _slot_cooldowns) -- es lo que ahora obliga a volver al Basico entre usos.
## Zona y Potenciador se reasignaron de Q/E a Mayus/Ctrl; Q y E pasaron a
## ser 2 huecos de tecnica de loadout por estilo (ver seccion "Loadout Q/E"
## mas abajo). Ranura nueva de Soporte en F15 (ver seccion "Soporte"),
## unica que puede afectar a quien la lanza.

const SPEED := 220.0
const DEFAULT_STYLE_PATH := "res://resources/styles/fuego.tres"
const GRUPO_JUGADORES := "jugadores"
const GRUPO_ENEMIGOS := "enemigos"

@export var style_data: StyleData

## Sastreria (H5 cierre): el tinte se aplica como modulate de TODO este nodo
## (torso+piernas a la vez), separado de _torso_color_base/_legs_color_base
## (que siguen dependiendo solo del elemento) -- ver comentario de cabecera
## de sastreria.gd.
@onready var _visuals: Node2D = $Visuals
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
## Panel de vida/chakra propio en pantalla, arriba a la derecha (scope nuevo
## 2026-09-02 -- ver plan-desarrollo.md). Las barras de StatusBars sobre la
## cabeza (arriba) NO se quitan: se mantienen para todos (propio incluido)
## porque en combate cuerpo a cuerpo son la lectura mas rapida (no hay que
## desviar la vista a una esquina de la pantalla). Este panel es el
## complemento fijo -- grande, siempre visible, sin depender de la camara.
@onready var _own_health_fill: ColorRect = $HUD/OwnStatsPanel/OwnHealthFill
@onready var _own_health_label: Label = $HUD/OwnStatsPanel/OwnHealthLabel
@onready var _own_chakra_bg: ColorRect = $HUD/OwnStatsPanel/OwnChakraBg
@onready var _own_chakra_fill: ColorRect = $HUD/OwnStatsPanel/OwnChakraFill
@onready var _own_chakra_label: Label = $HUD/OwnStatsPanel/OwnChakraLabel
## Hasta 3 companeros (partida de 2-4 jugadores) debajo del panel propio, en
## pequeño. Mismo dato ya sincronizado que las barras sobre la cabeza
## (vida_actual/chakra_current via confirm_damage_taken y el resto de
## confirm_* de esta clase, todos call_local reliable) -- no se inventa
## sincronizacion nueva, solo se espeja en pantalla. Las de los companeros
## sobre SU cabeza si se mantienen (mismo motivo: combate cercano rapido).
@onready var _companion_rows: Array[Control] = [
	$HUD/CompanionsPanel/Row1, $HUD/CompanionsPanel/Row2, $HUD/CompanionsPanel/Row3,
]
@onready var _companion_name_labels: Array[Label] = [
	$HUD/CompanionsPanel/Row1/NameLabel, $HUD/CompanionsPanel/Row2/NameLabel, $HUD/CompanionsPanel/Row3/NameLabel,
]
@onready var _companion_health_fills: Array[ColorRect] = [
	$HUD/CompanionsPanel/Row1/HealthFill, $HUD/CompanionsPanel/Row2/HealthFill, $HUD/CompanionsPanel/Row3/HealthFill,
]
@onready var _companion_chakra_bgs: Array[ColorRect] = [
	$HUD/CompanionsPanel/Row1/ChakraBg, $HUD/CompanionsPanel/Row2/ChakraBg, $HUD/CompanionsPanel/Row3/ChakraBg,
]
@onready var _companion_chakra_fills: Array[ColorRect] = [
	$HUD/CompanionsPanel/Row1/ChakraFill, $HUD/CompanionsPanel/Row2/ChakraFill, $HUD/CompanionsPanel/Row3/ChakraFill,
]
## Minimapa arriba a la izquierda -- radar abstracto, ver cabecera de
## minimap_radar.gd para por que (en vez de SubViewport con mapa real).
@onready var _minimap: MinimapRadar = $HUD/MinimapRadar

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
## Ancho a ratio 1.0 de las barras del panel fijo de pantalla (OwnStatsPanel/
## CompanionsPanel) -- coincide con el offset_right de sus *Bg/*Fill en
## player.tscn (240px). Escala independiente de STATUS_BAR_WIDTH porque unas
## son ColorRect en espacio de mundo (mundo -> pixeles de camara) y estas
## viven en el CanvasLayer del HUD (pixeles de pantalla fijos).
const SCREEN_BAR_WIDTH := 240.0

# --- Screen shake (solo camara local, is_multiplayer_authority) ---
const SCREEN_SHAKE_DECAY_PER_SECOND := 26.0
const SCREEN_SHAKE_HIT_STRENGTH := 4.5
const SCREEN_SHAKE_ATTACK_STRENGTH := 2.5
var _screen_shake_strength: float = 0.0

# --- Flash de golpe recibido (TorsoRect/LegsRect) ---
var _torso_flash_tween: Tween = null
var _legs_flash_tween: Tween = null

## Chakra actual. En Fisico se queda siempre a 0 (chakra_max = 0 en su
## StyleData): no tiene Proyectil/Zona/Potenciador/Loadout/Soporte que
## gastarlo.
##
## Rework de combate 2026-09-03 (plan-desarrollo.md seccion 2.1, T1): hasta
## esta tanda SOLO subia golpeando con el Basico ("el chakra se recupera
## golpeando, nunca con el tiempo" era la regla mas repetida del diseno
## original). El usuario pidio explicitamente sustituirla por regeneracion
## PASIVA por tiempo -- ver _advance_chakra_regen()/_server_regen_chakra()/
## _predict_chakra_regen() mas abajo. Con eso, lo que obliga a volver al
## Basico entre usos de una ranura ya no es "sin chakra", es el cooldown
## propio de cada ranura (ver _slot_cooldowns) -- el Basico sigue siendo la
## UNICA ranura sin cooldown.
##
## El host es la unica fuente autoritativa: su copia local de CADA nodo
## Player (incluidos los de peers remotos, que tambien existen en el arbol
## del host aunque is_multiplayer_authority() de alli sea false) es la que
## de verdad valida el gasto en submit_*(); por eso la regeneracion
## autoritativa corre con multiplayer.is_server() como guarda, NO con
## is_multiplayer_authority() (que en el host solo seria true para SU PROPIO
## personaje) -- de lo contrario el chakra de cualquier peer que no fuera el
## host nunca se regeneraria en la copia que de verdad importa. El resto de
## peers solo PREDICEN la misma formula en su pantalla (cosmetica, para que
## la barra no se vea congelada entre sincronizaciones) y el host corrige
## cada CHAKRA_REGEN_SYNC_INTERVAL segundos via confirm_chakra_sync -- ver
## T6 en plan-desarrollo.md (auditoria de red, netcode-agent) para el
## seguimiento de este mecanismo.
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

# --- Cooldowns por ranura (T1, rework de combate 2026-09-03) --------------
## Dictionary generico slot_id (String) -> segundos restantes, en vez de una
## variable suelta por ranura (a diferencia de _impulse_cooldown_remaining,
## que ya existia de antes y se deja intacto). Slot ids en uso: "proyectil"
## (Proyectil/Agarre comparten cooldown -- son la MISMA ranura, un estilo
## solo tiene uno de los dos), "zona" (Zona/Lanzamiento, mismo criterio),
## "potenciador", "sellos", y desde T2/T3 mas abajo "loadout_q", "loadout_e",
## "soporte". Es tambien el punto de extension para T4 (pool de tecnicas de
## pergamino equipables en Q/E): una tecnica nueva en el mismo hueco
## reutiliza el slot_id ya existente, no hace falta un timer por tecnica.
var _slot_cooldowns: Dictionary = {}

func _tick_cooldowns(delta: float) -> void:
	for slot_id in _slot_cooldowns.keys():
		_slot_cooldowns[slot_id] = max(_slot_cooldowns[slot_id] - delta, 0.0)

func _cooldown_remaining(slot_id: String) -> float:
	return _slot_cooldowns.get(slot_id, 0.0)

func _start_cooldown(slot_id: String, duration: float) -> void:
	_slot_cooldowns[slot_id] = duration

# --- Chakra pasivo (T1) ----------------------------------------------------
## Cada cuantos segundos el host retransmite el chakra ya regenerado a todos
## los peers (ver comentario de chakra_current). No hace falta que sea muy
## frecuente: entre sincronizaciones cada peer ya predice la misma formula
## localmente (_predict_chakra_regen), esto solo corrige la deriva y
## mantiene al dia el HUD de companeros de quien no es el host.
const CHAKRA_REGEN_SYNC_INTERVAL := 0.5
var _chakra_regen_sync_accum: float = 0.0

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
## Rango de interaccion con las sillas de la Taberna (H6 extra): mas
## ajustado que HUB_RANGE a proposito -- sentarse es una pose puntual junto
## a una silla concreta, no "en cualquier parte de la Taberna" (eso es el
## emote general, que si usa HUB_RANGE).
const SILLA_RANGE := 40.0
## Grupo compartido por TODAS las escenas de mision (H6) para marcar al jefe
## de zona -- ver mision_*.tscn. Central aqui (no en NetworkManager) porque
## solo lo consulta la comprobacion de extraccion de _update_interaction_hint
## y submit_volver_hub, ambas en este fichero.
const GRUPO_JEFE_MISION := "mision_jefe"
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
## Cuanto se apuesta en la mesa de dados (pedido del usuario: "que se pueda
## apostar todo lo que quieras, no un minimo de 20"). Antes era un monto fijo
## (MesaDados.apuesta_fija = 20.0) sin forma de cambiarlo -- ahora se ajusta
## con +/- (apuesta_subir/apuesta_bajar) de APUESTA_STEP en APUESTA_STEP, sin
## techo (el host igual rechaza si no hay fondos, ver submit_apostar_dados),
## con suelo en APUESTA_MONTO_MINIMO para no poder apostar 0 ni negativo. Es
## puramente local (como _apuesta_moneda) -- no hace falta red hasta que de
## verdad se aposte.
const APUESTA_STEP := 10.0
const APUESTA_MONTO_MINIMO := 1.0
var _apuesta_monto: float = 20.0
## Costes de chakra de las trampas de casino (H6). Doblados si
## NetworkManager.sospecha_tramo(peer_id) == "ambar" -- brief 2.3: "las
## trampas cuestan el doble de chakra". Valores en la misma escala que
## style_data.projectile_chakra_cost (15-20 tipico).
const TRAMPA_DADOS_CHAKRA_COST := 15.0
const CARTAS_RAYO_CHAKRA_COST := 20.0
const CARTAS_SELLOS_CHAKRA_COST := 20.0
## Sospecha ganada por cada uso de trampa (H6) -- ver NetworkManager
## SOSPECHA_AMBAR_UMBRAL/SOSPECHA_ROJO_UMBRAL para los tramos. La de Cartas
## es menor porque su ventaja (elegir entre dos cartas) es mas modesta que
## forzar un dado ganador siempre.
const SOSPECHA_POR_TRAMPA_DADOS := 15.0
const SOSPECHA_POR_TRAMPA_CARTAS := 10.0
## Fichas ganadas por partida de casino (H6, brief "Tres monedas": "solo se
## ganan jugando", sin mas detalle). Decision propia: se reparte SIEMPRE algo,
## menos al perder que al ganar -- si solo se repartiera al ganar, comprar
## pergaminos dependeria enteramente de rachas de suerte en las apuestas, y
## las fichas dejarian de sentirse como recompensa por "jugar" (texto del
## brief) para sentirse como recompensa por "ganar" (mas estricto de lo que
## pide). Mismos 4 juegos que ya reparten dinero limpio/manchado: Mesa de
## Dados, Rueda del Clan, Cartas Selladas, Peleas del Sotano -- no crea
## ningun juego nuevo, solo engancha su resultado ya calculado.
const FICHAS_POR_GANAR := 5.0
const FICHAS_POR_PERDER := 1.0
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

# --- Sellos (R mantenido, secuencia de 3 direccionales) -------------------
## Tecnica oculta de pergamino (H6): mantener R inmoviliza al jugador (ver
## _handle_movement) y captura hasta 3 pulsaciones direccionales. Soltar R
## antes de completar 3 cancela sin efecto. A diferencia de la Zona (que deja
## moverse mientras se carga con Mayus/Shift), este es el "momento de
## riesgo" del brief -- por eso bloquea movimiento, cosa que Zona no hace.
var _sellos_charging: bool = false
var _sellos_directions: Array[String] = []
const SELLOS_SECUENCIA_LONGITUD := 3

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

# --- Potenciador (Ctrl, ver T2) -- recibido de un aliado, nunca de uno mismo ---
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

# --- Casa del equipo (H5 cierre, Terrazas): reduccion de daño recibido -----
## Cocina (ver casa_equipo.gd): igual que _potenciador_damage_reduction pero
## de grupo en vez de recibido de un aliado -- se lee directamente de
## NetworkManager.cocina_damage_reduction_multiplier en confirm_damage_taken,
## no hace falta variable local propia (a diferencia del brindis, que si usa
## NetworkManager.brindis_damage_multiplier directamente en
## _current_damage_multiplier tambien sin variable local).

## Bug real de red (confirmado con dos cuentas de Steam en vivo, ver
## historial de este archivo): NetworkManager._spawn_player() (host) pone
## set_multiplayer_authority(id) DESPUES de players_root.add_child(), pero el
## MultiplayerSpawner (auto-spawn, ver main.tscn) solo replica la
## instanciacion/nombre del nodo a los demas peers, NO llamadas de script
## posteriores como set_multiplayer_authority -- eso es puramente local a la
## instancia del host. Resultado: en la copia replicada de cada cliente, el
## nodo Player quedaba con la autoridad por defecto de Godot (peer id 1, el
## servidor) porque nadie mas la fijaba ahi. Para el nodo del propio host
## (id 1) esto coincidia por pura casualidad; para el nodo de CUALQUIER OTRO
## peer (id != 1), is_multiplayer_authority() daba false en la pantalla de
## ESE MISMO jugador -- rompiendo la camara (ver _ready() mas abajo) Y todo
## el gateo de _physics_process() (linea ~458: movimiento/ataques/input
## entero detras de is_multiplayer_authority()), asi que ese jugador nunca
## veia su propia camara seguirlo ni podia moverse en su propia pantalla,
## aunque su nodo SI aparecia bien en la pantalla de los demas.
##
## Fix estandar de los demos oficiales de multiplayer de Godot: derivar la
## autoridad del NOMBRE del nodo (que si viaja con la replicacion del spawn,
## ya que network_manager.gd pone player.name = str(id) ANTES de add_child)
## en _enter_tree(), que corre en CADA peer (host y todos los clientes) para
## CADA instancia replicada, sin depender de que nadie mas la replique. Se
## deja intacto el set_multiplayer_authority(id) de _spawn_player en el host
## (no estorba, y es el primero en ejecutarse alli) -- este _enter_tree() es
## el que faltaba para que los CLIENTES tambien la fijen en su propia copia.
##
## Bug de seguimiento al de arriba (mismo patron, confirmado con dos cuentas
## de Steam en vivo): NetworkManager._spawn_player() tambien hace
## `player.global_position = _spawn_position_for(id)` DESPUES de add_child --
## exactamente igual que set_multiplayer_authority(), esa asignacion es una
## mutacion de script local a la instancia del HOST, no algo que el
## MultiplayerSpawner replique. Antes del fix de autoridad de arriba esto
## coincidia por casualidad: el host era la autoridad de TODOS los nodos en
## TODAS las pantallas, asi que el MultiplayerSynchronizer (properties/0 de
## player.tscn, replica ".:position") difundia la posicion que el host habia
## puesto en su copia. Al arreglar la autoridad, cada peer paso a ser la
## fuente de verdad SOLO de su propio nodo -- pero la copia local de ESE peer
## de su propio nodo nunca recibio la posicion de spawn (esa linea solo corrio
## en la copia del host, sobre un nodo que ya no es el que se replica), asi
## que se quedaba en el Vector2.ZERO por defecto de player.tscn y ESO era lo
## que se difundia a todo el mundo. Mismo arreglo: derivarla localmente en
## cada peer, aqui mismo, con el mismo id que ya usamos para la autoridad.
## NetworkManager.spawn_points ya esta poblado en este punto en todo peer:
## main.gd._ready() lo rellena desde $TestRoom/PlayerSpawns (parte de la
## escena estatica que cada peer carga localmente, sin red) ANTES de que el
## MultiplayerSpawner (tambien hijo de main.tscn) pueda spawnear ningun
## Player -- ver comentario de cabecera de network_manager.gd _spawn_player.
##
## Esto NO se re-dispara durante cambios de mision/Hub: confirm_iniciar_mision/
## confirm_volver_hub NO reparentan los nodos Player (se quedan fijos bajo
## Players todo el rato); lo que entra/sale del arbol es la escena del bioma
## bajo mission_root. El reposicionamiento de jugadores en esos cambios lo
## hace NetworkManager._reposicionar_jugadores(), que es distinto: corre via
## RPC call_local en TODOS los peers por igual (no solo el host), asi que no
## sufre este problema -- cada peer fija bien la posicion de su propio nodo
## autoritativo ahi. Por eso este _enter_tree() solo necesita cubrir el spawn
## inicial, no hace falta ningun flag de "ya posicionado".
## Tercer bug de la misma familia que autoridad/posicion de arriba (mismo
## patron confirmado con dos cuentas de Steam en vivo), esta vez con
## style_data (el estilo elegido en la pantalla previa al spawn: Fuego/
## Viento/Fisico/Agua/Rayo/Tierra) -- ver NetworkManager._spawn_player(),
## que solo lo deja bien puesto en la copia LOCAL del host, y
## NetworkManager.confirm_style_choice(), el RPC que lo arregla.
##
## A diferencia de autoridad/posicion, el estilo NO se puede derivar
## localmente aqui (no es un dato ya sincronizado como el nombre del nodo o
## spawn_points, es una eleccion privada de cada jugador) -- por eso hace
## falta leerlo de NetworkManager.style_choice, el Dictionary que
## confirm_style_choice ya sincroniza en TODOS los peers (no solo en el
## host). Esto cubre la rama "el RPC de confirmacion llego ANTES de que este
## nodo entrara al arbol" del riesgo de orden documentado alli: si ya esta
## disponible, se aplica aqui, ANTES de _ready() (que si no, cargaria el
## estilo por defecto). Si todavia no esta disponible (llegara despues),
## style_data se queda null aqui y confirm_style_choice lo aplicara el mismo
## cuando llegue el RPC, encontrando el nodo ya en el arbol.
func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())
	global_position = NetworkManager._spawn_position_for(str(name).to_int())
	var synced_style_path: String = NetworkManager.style_choice.get(str(name).to_int(), "")
	if synced_style_path != "":
		style_data = load(synced_style_path)

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
		# Mismo motivo: panel de vida/chakra propio, panel de companeros y
		# minimapa son solo del jugador local -- en la copia de cada OTRO
		# peer se ocultan para no acumular una segunda copia superpuesta.
		$HUD/OwnStatsPanel.visible = false
		$HUD/CompanionsPanel.visible = false
		_minimap.visible = false

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
	_sellos_charging = false
	_sellos_directions.clear()
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

## Panel fijo de pantalla (propio + companeros) y minimapa -- solo tiene
## sentido calcularlo para el jugador local, se llama unicamente desde el
## bloque is_multiplayer_authority() de _physics_process. Reutiliza
## vida_actual/chakra_current de este nodo y de los otros nodos Player en
## GRUPO_JUGADORES: son el mismo dato ya sincronizado que usan las barras
## sobre la cabeza (_update_status_bars), no un canal nuevo.
func _update_screen_hud() -> void:
	_update_own_stats_panel()
	var companions := _nearby_companions()
	_update_companions_panel(companions)
	_update_minimap(companions)

func _update_own_stats_panel() -> void:
	var vida_ratio: float = clamp(vida_actual / max(style_data.vida_maxima, 0.001), 0.0, 1.0)
	_own_health_fill.size.x = SCREEN_BAR_WIDTH * vida_ratio
	_own_health_label.text = "Vida %d/%d" % [ceili(vida_actual), int(style_data.vida_maxima)]
	if style_data.chakra_max <= 0.0:
		_own_chakra_bg.visible = false
		_own_chakra_fill.visible = false
		_own_chakra_label.visible = false
	else:
		_own_chakra_bg.visible = true
		_own_chakra_fill.visible = true
		_own_chakra_label.visible = true
		var chakra_ratio: float = clamp(chakra_current / style_data.chakra_max, 0.0, 1.0)
		_own_chakra_fill.size.x = SCREEN_BAR_WIDTH * chakra_ratio
		_own_chakra_label.text = "Chakra %d/%d" % [ceili(chakra_current), int(style_data.chakra_max)]

## Hasta _companion_rows.size() (3) jugadores de GRUPO_JUGADORES que no sean
## este (orden estable por peer_id -- nombre del nodo, ver
## NetworkManager._spawn_player -- para que cada companero no salte de fila
## entre fotogramas).
func _nearby_companions() -> Array:
	var others: Array = []
	for jugador in get_tree().get_nodes_in_group(GRUPO_JUGADORES):
		if jugador != self:
			others.append(jugador)
	others.sort_custom(func(a, b): return str(a.name).to_int() < str(b.name).to_int())
	if others.size() > _companion_rows.size():
		others.resize(_companion_rows.size())
	return others

func _update_companions_panel(companions: Array) -> void:
	for i in range(_companion_rows.size()):
		if i >= companions.size():
			_companion_rows[i].visible = false
			continue
		_companion_rows[i].visible = true
		var companero: CharacterBody2D = companions[i]
		_companion_name_labels[i].text = "Aliado %s" % companero.name
		var vida_ratio: float = clamp(companero.vida_actual / max(companero.style_data.vida_maxima, 0.001), 0.0, 1.0)
		_companion_health_fills[i].size.x = SCREEN_BAR_WIDTH * vida_ratio
		if companero.style_data.chakra_max <= 0.0:
			_companion_chakra_bgs[i].visible = false
			_companion_chakra_fills[i].visible = false
		else:
			_companion_chakra_bgs[i].visible = true
			_companion_chakra_fills[i].visible = true
			var chakra_ratio: float = clamp(companero.chakra_current / companero.style_data.chakra_max, 0.0, 1.0)
			_companion_chakra_fills[i].size.x = SCREEN_BAR_WIDTH * chakra_ratio

func _update_minimap(companions: Array) -> void:
	var offsets: Array[Vector2] = []
	for companero in companions:
		offsets.append(companero.global_position - global_position)
	_minimap.set_companions(offsets)

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
	# Cooldowns de ranura y regeneracion pasiva de chakra (T1): a proposito
	# FUERA del bloque is_multiplayer_authority() de abajo -- corren para
	# TODAS las copias de TODOS los Player en TODOS los peers (igual que
	# _update_status_bars encima), porque el host necesita decaer/regenerar
	# tambien su copia de los personajes de peers remotos (no solo la suya
	# propia) para que submit_*() valide contra un estado al dia. Ver
	# comentario de chakra_current y _slot_cooldowns.
	_tick_cooldowns(delta)
	if multiplayer.is_server():
		_server_regen_chakra(delta)
	else:
		_predict_chakra_regen(delta)
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
		_update_screen_hud()
		if style_data.melee_only:
			_handle_puertas(delta)
		_handle_zone_input(delta)
		_handle_sellos_input()
		_process_grab_hold()
		_process_carry_hold()
		if Input.is_action_just_pressed("attack_basic"):
			_request_basic_attack()
		if Input.is_action_just_pressed("attack_projectile") and _cooldown_remaining("proyectil") <= 0.0:
			if style_data.melee_only:
				_request_grab()
			else:
				_request_projectile_attack()
		if Input.is_action_just_pressed("impulse") and _impulse_cooldown_remaining <= 0.0 and _impulse_active_time <= 0.0:
			_request_impulse()
		if Input.is_action_just_pressed("potenciador") and not style_data.melee_only and _cooldown_remaining("potenciador") <= 0.0:
			_request_potenciador()
		if Input.is_action_just_pressed("loadout_q") and _cooldown_remaining("loadout_q") <= 0.0:
			_request_loadout_technique("Q")
		if Input.is_action_just_pressed("loadout_e") and _cooldown_remaining("loadout_e") <= 0.0:
			_request_loadout_technique("E")
		if Input.is_action_just_pressed("soporte") and _cooldown_remaining("soporte") <= 0.0:
			_request_soporte()
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
		if Input.is_action_just_pressed("ruleta_rojo"):
			_request_girar_ruleta("rojo")
		if Input.is_action_just_pressed("ruleta_azul"):
			_request_girar_ruleta("azul")
		if Input.is_action_just_pressed("ruleta_oro"):
			_request_girar_ruleta("oro")
		if Input.is_action_just_pressed("ruleta_clan"):
			_request_girar_ruleta("clan")
		if Input.is_action_just_pressed("jugar_cartas"):
			_request_jugar_cartas()
		if Input.is_action_just_pressed("pelea_izquierda"):
			_request_apostar_pelea("izquierda")
		if Input.is_action_just_pressed("pelea_derecha"):
			_request_apostar_pelea("derecha")
		if Input.is_action_just_pressed("toggle_moneda_apuesta"):
			_toggle_apuesta_moneda()
		if Input.is_action_just_pressed("apuesta_subir"):
			_ajustar_apuesta_monto(APUESTA_STEP)
		if Input.is_action_just_pressed("apuesta_bajar"):
			_ajustar_apuesta_monto(-APUESTA_STEP)
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
		if Input.is_action_just_pressed("taberna_ver_records"):
			_request_taberna_ver_records()
		if Input.is_action_just_pressed("taberna_comprar_cancion"):
			_request_taberna_musica()
		if Input.is_action_just_pressed("taberna_sentarse"):
			_request_taberna_sentarse()
		if Input.is_action_just_pressed("taberna_emote"):
			_request_taberna_emote()
		if Input.is_action_just_pressed("taberna_ver_desglose"):
			_request_taberna_ver_desglose()
		if Input.is_action_just_pressed("sastreria_siguiente_tinte"):
			_request_sastreria_tinte()
		if Input.is_action_just_pressed("casa_comprar_cocina"):
			_request_comprar_cocina()
		if Input.is_action_just_pressed("casa_comprar_almacen"):
			_request_comprar_almacen()
		if Input.is_action_just_pressed("casa_comprar_jardin"):
			_request_comprar_jardin()
		if Input.is_action_just_pressed("casa_comprar_palomar"):
			_request_comprar_palomar()
		if Input.is_action_just_pressed("abandonar_mision"):
			_request_abandonar_mision()
		if Input.is_action_just_pressed("comprar_pergamino"):
			_request_comprar_pergamino()
		if Input.is_action_just_pressed("elegir_mision_costa"):
			_request_elegir_mision("costa")
		if Input.is_action_just_pressed("elegir_mision_bambu"):
			_request_elegir_mision("bambu")
		if Input.is_action_just_pressed("elegir_mision_peaje"):
			_request_elegir_mision("peaje")
		if Input.is_action_just_pressed("elegir_mision_cantera"):
			_request_elegir_mision("cantera")
		if Input.is_action_just_pressed("elegir_mision_ruinas"):
			_request_elegir_mision("ruinas")
		if Input.is_action_just_pressed("volver_hub"):
			_request_volver_hub()
		if Input.is_action_just_pressed("hablar_tabernera"):
			_request_hablar_tabernera()
		if Input.is_action_just_pressed("hablar_viejo_maestro"):
			_request_hablar_viejo_maestro()
		if Input.is_action_just_pressed("hablar_pescador"):
			_request_hablar_pescador()
		if Input.is_action_just_pressed("entrar_tienda"):
			_request_entrar_tienda()
		if Input.is_action_just_pressed("salir_tienda"):
			_request_salir_tienda()
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

## Solo local, igual que _toggle_apuesta_moneda -- ajustar cuanto vas a
## apostar es una preferencia previa, no una accion de red hasta que de
## verdad pulses T/B. Sin techo (el host valida fondos al apostar de
## verdad), suelo en APUESTA_MONTO_MINIMO para no poder dejarlo en 0.
func _ajustar_apuesta_monto(delta: float) -> void:
	_apuesta_monto = max(APUESTA_MONTO_MINIMO, _apuesta_monto + delta)
	_status_label.modulate = Color(1, 1, 1)
	_status_label.text = "Apuesta actual: %.0f (+/- para ajustar)" % _apuesta_monto

## Solo local (H6 narrativa, mismo criterio que _toggle_apuesta_moneda): la
## linea del NPC se calcula a partir de NetworkManager.misiones_completadas,
## que ya es identico en todos los peers (mutado por confirm_volver_hub via
## RPC call_local) -- no hay estado que mutar ni nada que un cliente pueda
## mentir para conseguir, asi que un RPC propio solo añadiria una vuelta
## host de mas para mostrar texto de ambientacion. Igual que prologo.gd, es
## ambientacion que cada peer ve en su propia pantalla.
func _request_hablar_tabernera() -> void:
	var tabernera := _find_nearest_tabernera_in_range(HUB_RANGE)
	if tabernera == null:
		return
	_status_label.modulate = Color(1, 0.9, 0.7)
	_status_label.text = tabernera.linea_para(NetworkManager.misiones_completadas)

func _request_hablar_viejo_maestro() -> void:
	var maestro := _find_nearest_viejo_maestro_in_range(HUB_RANGE)
	if maestro == null:
		return
	_status_label.modulate = Color(1, 0.9, 0.7)
	_status_label.text = maestro.linea_para(NetworkManager.misiones_completadas)

func _request_hablar_pescador() -> void:
	var pescador := _find_nearest_pescador_in_range(HUB_RANGE)
	if pescador == null:
		return
	_status_label.modulate = Color(1, 0.9, 0.7)
	_status_label.text = pescador.linea_para(NetworkManager.misiones_completadas)

func _handle_movement() -> void:
	if _impulse_active_time > 0.0 or _potenciador_dash_active_time > 0.0:
		# El Impulso (y el dash del Potenciador de Viento) mueven al jugador
		# directamente por posicion; el WASD no debe pelearse con el dash.
		velocity = Vector2.ZERO
		return
	if _sellos_charging:
		# Brief: "inmovil mientras las haces" -- las direccionales que se
		# pulsan aqui alimentan la secuencia (ver _handle_sellos_input), no
		# mueven al jugador.
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
	var peer_id_hud := get_multiplayer_authority()
	var texto := "Manchado: %.0f  |  Limpio: %.0f  |  Fichas: %.0f" % [NetworkManager.dinero_manchado, NetworkManager.dinero_limpio, NetworkManager.fichas.get(peer_id_hud, 0.0)]
	# Aviso visible de deuda con el Usurero: en NEGATIVO (pedido explicito
	# del usuario), mismo Label de dinero -- reutilizado en vez de crear un
	# tercer Label solo para esto.
	if NetworkManager.usurero_deuda_pendiente > 0.0:
		texto += "  |  Deuda Usurero: -%.0f" % NetworkManager.usurero_deuda_pendiente
	# Deuda de la Taberna (H6 extra): distinta de la del Usurero de arriba --
	# ver NetworkManager.taberna_deuda_pendiente. Mismo criterio de "en
	# negativo" que el resto del HUD de deuda.
	if NetworkManager.taberna_deuda_pendiente > 0.0:
		texto += "  |  Deuda Taberna: -%.0f" % NetworkManager.taberna_deuda_pendiente
	# Aviso de sospecha (H6): solo el propio tramo, igual que el resto de
	# este Label es informacion del propio jugador, no del grupo.
	var peer_id := get_multiplayer_authority()
	var tramo := NetworkManager.sospecha_tramo(peer_id)
	if tramo == "ambar":
		texto += "  |  Sospecha: AMBAR (trampas al doble de chakra)"
	elif tramo == "rojo":
		var restante: float = NetworkManager.sospecha_expulsado_restante.get(peer_id, 0.0)
		texto += "  |  Sospecha: ROJO -- expulsado %.0fs (sin cambista)" % restante
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
	var cargable := _find_nearest_free_cadaver(CADAVER_PICKUP_RANGE)
	if cargable != null:
		texto = "Pulsa G para recoger el prisionero" if cargable is Prisionero else "Pulsa G para recoger el cadaver"
	elif _find_nearest_comprador_in_range(VENTA_RANGE) != null:
		texto = "Pulsa V para vender" if not carried_cadaver_paths.is_empty() else "Pulsa V para vender (no llevas ningun cadaver)"
	elif _find_nearest_cambista_in_range(CASINO_RANGE) != null:
		texto = "Pulsa C para cambiar dinero manchado a limpio"
	elif _find_nearest_mesa_dados_in_range(CASINO_RANGE) != null:
		texto = "Apuesta %.0f %s -- T alto, B bajo (mantén 9 con Viento para trampa, +/- ajusta, M cambia moneda)" % [_apuesta_monto, _apuesta_moneda]
	elif _find_nearest_ruleta_in_range(CASINO_RANGE) != null:
		texto = "Apuesta %.0f %s a la Rueda del Clan -- Z rojo, K azul, O oro, N clan (+/- ajusta, M cambia moneda)" % [_apuesta_monto, _apuesta_moneda]
	elif _find_nearest_cartas_selladas_in_range(CASINO_RANGE) != null:
		texto = "Apuesta %.0f %s en Cartas Selladas -- 7 juega (mantén 8 con Rayo o / con Sellos para trampa)" % [_apuesta_monto, _apuesta_moneda]
	elif _find_nearest_peleas_sotano_in_range(CASINO_RANGE) != null:
		texto = "Apuesta %.0f %s en las Peleas del Sotano -- , izquierda, . derecha" % [_apuesta_monto, _apuesta_moneda]
	elif _find_nearest_usurero_in_range(CASINO_RANGE) != null:
		# H6 narrativa: la linea del Usurero se decidio SIN tecla propia (a
		# diferencia de tabernera/viejo maestro/pescador) -- aparece sola en
		# el mismo aviso de "pulsa U", delante del menu de prestamo, porque
		# el Usurero ya tiene su propia tecla ocupada y anadir una segunda
		# solo para hablar es mas friccion de la que pide una linea de
		# ambientacion (decision de diseno, ver cabecera de esta funcion).
		var usurero_hint := _find_nearest_usurero_in_range(CASINO_RANGE)
		texto = "\"%s\" -- Pulsa U para pedir un prestamo" % usurero_hint.linea_para(NetworkManager.misiones_completadas)
	elif _find_nearest_tabernera_in_range(HUB_RANGE) != null:
		texto = "Pulsa F7 para hablar con la tabernera"
	elif _find_nearest_pescador_in_range(HUB_RANGE) != null:
		texto = "Pulsa F9 para hablar con el pescador"
	elif _find_nearest_viejo_maestro_in_range(HUB_RANGE) != null:
		texto = "Pulsa F8 para hablar con el viejo maestro"
	elif _find_nearest_forja_in_range(HUB_RANGE) != null:
		texto = "Pulsa Y para mejorar la forja"
	elif _find_nearest_herboristeria_in_range(HUB_RANGE) != null:
		texto = "P pildora, H unguento, J bomba de humo, L sales -- I para usar"
	elif _find_nearest_silla_taberna_in_range(SILLA_RANGE) != null:
		texto = "Pulsa ` para sentarte"
	elif _find_nearest_taberna_in_range(HUB_RANGE) != null:
		texto = "Pulsa X para el brindis, \\ para la pizarra de records, ' para comprar/cambiar musica, F10 para el desglose de contribucion, Flecha derecha para un gesto"
	elif _find_nearest_sastreria_in_range(HUB_RANGE) != null:
		texto = "Pulsa R para cambiar tu tinte"
	elif _find_nearest_casa_equipo_in_range(HUB_RANGE) != null:
		texto = "Casa del equipo -- ; Cocina, [ Almacen, ] Jardin, F13 Palomar"
	elif _find_nearest_tienda_pergaminos_in_range(CASINO_RANGE) != null:
		var tienda_hint := _find_nearest_tienda_pergaminos_in_range(CASINO_RANGE)
		texto = "Pulsa 0 para comprar el pergamino de %s (%.0f fichas)" % [style_data.style_name, tienda_hint.precio_pergamino]
	elif _find_nearest_puerta_tienda_in_range(HUB_RANGE) != null:
		var puerta_hint := _find_nearest_puerta_tienda_in_range(HUB_RANGE)
		texto = "Pulsa F11 para entrar (%s)" % (puerta_hint.nombre_visible if puerta_hint.nombre_visible != "" else "tienda")
	elif _find_nearest_salida_tienda_in_range(HUB_RANGE) != null:
		texto = "Pulsa F12 para salir"
	elif _find_nearest_tablon_in_range(HUB_RANGE) != null:
		# H6: el texto (incluido el objetivo explicito de Costa/Peaje/Cantera)
		# vive ahora en TablonMisiones.texto_tablon() -- ver ese script.
		texto = _find_nearest_tablon_in_range(HUB_RANGE).texto_tablon()
	elif _find_nearest_extraccion_in_range(HUB_RANGE) != null:
		if get_tree().get_nodes_in_group(GRUPO_JEFE_MISION).is_empty():
			texto = "Pulsa F6 para volver a la Aldea con el botin"
		else:
			texto = "Aun queda el jefe de la zona -- no puedes extraer todavia"
	elif NetworkManager.mision_actual != "" and NetworkManager.casa_equipo_palomar_comprado:
		# Palomar (Casa del equipo): a diferencia del resto de esta funcion,
		# este aviso NO depende de la proximidad a ningun punto -- el Palomar
		# deja rechazar la mision desde cualquier sitio, por eso el hint
		# tambien aparece en cualquier sitio (solo si nada mas prioritario ya
		# ocupo el aviso este frame, ver orden del elif de arriba).
		texto = "Pulsa F14 para rechazar la mision y volver a la Aldea (Palomar)"
	_interaction_label.text = texto

func _handle_combo_timer(delta: float) -> void:
	if combo_count > 0:
		_combo_window_timer -= delta
		if _combo_window_timer <= 0.0:
			combo_count = 0

## Formula compartida por la prediccion cosmetica (_predict_chakra_regen,
## corre en TODOS los peers que no son el host para esta copia del nodo) y
## el tick autoritativo (_server_regen_chakra, solo en el host) -- ver
## comentario de chakra_current para el porque de la separacion.
func _advance_chakra_regen(delta: float) -> float:
	if style_data.chakra_max <= 0.0 or chakra_current >= style_data.chakra_max:
		return chakra_current
	return min(chakra_current + style_data.chakra_regen_per_second * delta, style_data.chakra_max)

func _predict_chakra_regen(delta: float) -> void:
	chakra_current = _advance_chakra_regen(delta)

## Solo corre cuando multiplayer.is_server() es true, para la copia de CADA
## Player del arbol del host (propio y de cualquier otro peer) -- a
## proposito NO usa is_multiplayer_authority(), que en la maquina del host
## solo seria true para su propio personaje. Ver comentario de chakra_current.
func _server_regen_chakra(delta: float) -> void:
	if style_data.chakra_max <= 0.0:
		return # Fisico: sin chakra que regenerar ni que sincronizar
	chakra_current = _advance_chakra_regen(delta)
	_chakra_regen_sync_accum += delta
	if _chakra_regen_sync_accum >= CHAKRA_REGEN_SYNC_INTERVAL:
		_chakra_regen_sync_accum = 0.0
		confirm_chakra_sync.rpc(chakra_current)

## Correccion periodica del host -- aplica igual en todos los peers
## (call_local), incluida la copia del propio host (no-op ahi, ya tenia ese
## valor). Idempotente aunque llegue tarde o desordenado respecto a un
## confirm_* de una accion de combate: siempre gana el ULTIMO valor recibido,
## igual que el resto de confirm_* de este fichero.
@rpc("any_peer", "call_local", "reliable")
func confirm_chakra_sync(new_chakra: float) -> void:
	chakra_current = new_chakra

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

## Punto de entrada publico para NetworkManager.confirm_style_choice (ver su
## comentario de cabecera para el detalle completo del bug/fix): aplica un
## estilo llegado por RPC directamente sobre este nodo ya spawneado, para la
## rama "el RPC de confirmacion llego DESPUES de que el nodo ya existiera y
## ya hubiera arrancado con el estilo por defecto". Reutiliza
## _apply_style_reset(), la misma funcion que ya usa el hot-swap de debug de
## abajo, para reiniciar el estado dependiente de estilo (chakra/vida/combo/
## etc.) -- expuesta sin guion bajo (a diferencia de _apply_style_reset) a
## proposito: es la unica funcion de este bloque pensada para llamarse desde
## fuera del nodo (NetworkManager), el resto son puramente internas.
func apply_synced_style(new_style_data: StyleData) -> void:
	style_data = new_style_data
	_apply_style_reset()

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

## Cadaver o Prisionero mas cercano dentro de range_max que nadie este
## cargando ya. Proximidad simple, sin cono: recoger no necesita apuntar,
## solo estar cerca (a diferencia del Agarre, que si apunta a un enemigo
## vivo). H6: mismo criterio para ambos tipos -- reutiliza el sistema de
## carga de Cadaver tal cual (ver cabecera de Prisionero.gd), asi que "lo
## mas cercano cargable" tiene que mirar los dos grupos.
func _find_nearest_free_cadaver(range_max: float) -> Node2D:
	var nearest: Node2D = null
	var best_dist: float = INF
	for c in get_tree().get_nodes_in_group(Cadaver.GRUPO_CADAVERES):
		if not (c is Cadaver) or c.cargado_por_peer_id != 0:
			continue
		var dist: float = global_position.distance_to(c.global_position)
		if dist <= range_max and dist < best_dist:
			best_dist = dist
			nearest = c
	for p in get_tree().get_nodes_in_group(Prisionero.GRUPO_PRISIONEROS):
		if not (p is Prisionero) or p.cargado_por_peer_id != 0:
			continue
		var dist: float = global_position.distance_to(p.global_position)
		if dist <= range_max and dist < best_dist:
			best_dist = dist
			nearest = p
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

## Silla de la Taberna mas cercana dentro de range_max (H6 extra). Misma
## proximidad simple que el resto de puntos.
func _find_nearest_silla_taberna_in_range(range_max: float) -> SillaTaberna:
	var nearest: SillaTaberna = null
	var best_dist: float = INF
	for s in get_tree().get_nodes_in_group(SillaTaberna.GRUPO_SILLAS_TABERNA):
		if not (s is SillaTaberna):
			continue
		var dist: float = global_position.distance_to(s.global_position)
		if dist <= range_max and dist < best_dist:
			best_dist = dist
			nearest = s
	return nearest

## Sastreria mas cercana dentro de range_max. Misma proximidad simple.
func _find_nearest_sastreria_in_range(range_max: float) -> Sastreria:
	var nearest: Sastreria = null
	var best_dist: float = INF
	for s in get_tree().get_nodes_in_group(Sastreria.GRUPO_SASTRERIAS):
		if not (s is Sastreria):
			continue
		var dist: float = global_position.distance_to(s.global_position)
		if dist <= range_max and dist < best_dist:
			best_dist = dist
			nearest = s
	return nearest

## Tabernera mas cercana dentro de range_max (H6 narrativa). Misma
## proximidad simple que el resto de puntos estaticos.
func _find_nearest_tabernera_in_range(range_max: float) -> Tabernera:
	var nearest: Tabernera = null
	var best_dist: float = INF
	for t in get_tree().get_nodes_in_group(Tabernera.GRUPO_TABERNERAS):
		if not (t is Tabernera):
			continue
		var dist: float = global_position.distance_to(t.global_position)
		if dist <= range_max and dist < best_dist:
			best_dist = dist
			nearest = t
	return nearest

## Viejo maestro mas cercano dentro de range_max (H6 narrativa). Misma
## proximidad simple.
func _find_nearest_viejo_maestro_in_range(range_max: float) -> ViejoMaestro:
	var nearest: ViejoMaestro = null
	var best_dist: float = INF
	for v in get_tree().get_nodes_in_group(ViejoMaestro.GRUPO_VIEJOS_MAESTROS):
		if not (v is ViejoMaestro):
			continue
		var dist: float = global_position.distance_to(v.global_position)
		if dist <= range_max and dist < best_dist:
			best_dist = dist
			nearest = v
	return nearest

## Pescador mas cercano dentro de range_max (H6 narrativa). Misma proximidad
## simple.
func _find_nearest_pescador_in_range(range_max: float) -> Pescador:
	var nearest: Pescador = null
	var best_dist: float = INF
	for p in get_tree().get_nodes_in_group(Pescador.GRUPO_PESCADORES):
		if not (p is Pescador):
			continue
		var dist: float = global_position.distance_to(p.global_position)
		if dist <= range_max and dist < best_dist:
			best_dist = dist
			nearest = p
	return nearest

## Casa del equipo mas cercana dentro de range_max. Misma proximidad simple.
func _find_nearest_casa_equipo_in_range(range_max: float) -> CasaEquipo:
	var nearest: CasaEquipo = null
	var best_dist: float = INF
	for c in get_tree().get_nodes_in_group(CasaEquipo.GRUPO_CASAS_EQUIPO):
		if not (c is CasaEquipo):
			continue
		var dist: float = global_position.distance_to(c.global_position)
		if dist <= range_max and dist < best_dist:
			best_dist = dist
			nearest = c
	return nearest

## Rueda del Clan mas cercana dentro de range_max. Misma proximidad simple
## que las funciones de arriba.
func _find_nearest_ruleta_in_range(range_max: float) -> Ruleta:
	var nearest: Ruleta = null
	var best_dist: float = INF
	for r in get_tree().get_nodes_in_group(Ruleta.GRUPO_RULETAS):
		if not (r is Ruleta):
			continue
		var dist: float = global_position.distance_to(r.global_position)
		if dist <= range_max and dist < best_dist:
			best_dist = dist
			nearest = r
	return nearest

## Mesa de Cartas Selladas mas cercana dentro de range_max. Misma proximidad
## simple que las funciones de arriba.
func _find_nearest_cartas_selladas_in_range(range_max: float) -> CartasSelladas:
	var nearest: CartasSelladas = null
	var best_dist: float = INF
	for c in get_tree().get_nodes_in_group(CartasSelladas.GRUPO_CARTAS_SELLADAS):
		if not (c is CartasSelladas):
			continue
		var dist: float = global_position.distance_to(c.global_position)
		if dist <= range_max and dist < best_dist:
			best_dist = dist
			nearest = c
	return nearest

## Peleas del Sotano mas cercanas dentro de range_max. Misma proximidad
## simple que las funciones de arriba.
func _find_nearest_peleas_sotano_in_range(range_max: float) -> PeleasSotano:
	var nearest: PeleasSotano = null
	var best_dist: float = INF
	for p in get_tree().get_nodes_in_group(PeleasSotano.GRUPO_PELEAS_SOTANO):
		if not (p is PeleasSotano):
			continue
		var dist: float = global_position.distance_to(p.global_position)
		if dist <= range_max and dist < best_dist:
			best_dist = dist
			nearest = p
	return nearest

## Tienda de Pergaminos mas cercana dentro de range_max. Misma proximidad
## simple que las funciones de arriba.
func _find_nearest_tienda_pergaminos_in_range(range_max: float) -> TiendaPergaminos:
	var nearest: TiendaPergaminos = null
	var best_dist: float = INF
	for t in get_tree().get_nodes_in_group(TiendaPergaminos.GRUPO_TIENDAS_PERGAMINOS):
		if not (t is TiendaPergaminos):
			continue
		var dist: float = global_position.distance_to(t.global_position)
		if dist <= range_max and dist < best_dist:
			best_dist = dist
			nearest = t
	return nearest

## Tablon de misiones mas cercano dentro de range_max (H6). Misma proximidad
## simple que las funciones de arriba.
func _find_nearest_tablon_in_range(range_max: float) -> TablonMisiones:
	var nearest: TablonMisiones = null
	var best_dist: float = INF
	for t in get_tree().get_nodes_in_group(TablonMisiones.GRUPO_TABLONES):
		if not (t is TablonMisiones):
			continue
		var dist: float = global_position.distance_to(t.global_position)
		if dist <= range_max and dist < best_dist:
			best_dist = dist
			nearest = t
	return nearest

## Punto de extraccion mas cercano dentro de range_max (H6). Misma proximidad
## simple que las funciones de arriba.
func _find_nearest_extraccion_in_range(range_max: float) -> ExtraccionMision:
	var nearest: ExtraccionMision = null
	var best_dist: float = INF
	for e in get_tree().get_nodes_in_group(ExtraccionMision.GRUPO_EXTRACCIONES):
		if not (e is ExtraccionMision):
			continue
		var dist: float = global_position.distance_to(e.global_position)
		if dist <= range_max and dist < best_dist:
			best_dist = dist
			nearest = e
	return nearest

## Puerta de tienda mas cercana dentro de range_max (scope nuevo H5+, ver
## plan-desarrollo.md seccion 2 "Interiores de tienda con fundido a negro").
## Misma proximidad simple que las funciones de arriba.
func _find_nearest_puerta_tienda_in_range(range_max: float) -> PuertaTienda:
	var nearest: PuertaTienda = null
	var best_dist: float = INF
	for p in get_tree().get_nodes_in_group(PuertaTienda.GRUPO_PUERTAS_TIENDA):
		if not (p is PuertaTienda):
			continue
		var dist: float = global_position.distance_to(p.global_position)
		if dist <= range_max and dist < best_dist:
			best_dist = dist
			nearest = p
	return nearest

## Salida de tienda mas cercana dentro de range_max (scope nuevo H5+). Misma
## proximidad simple que _find_nearest_extraccion_in_range.
func _find_nearest_salida_tienda_in_range(range_max: float) -> SalidaTienda:
	var nearest: SalidaTienda = null
	var best_dist: float = INF
	for s in get_tree().get_nodes_in_group(SalidaTienda.GRUPO_SALIDAS_TIENDA):
		if not (s is SalidaTienda):
			continue
		var dist: float = global_position.distance_to(s.global_position)
		if dist <= range_max and dist < best_dist:
			best_dist = dist
			nearest = s
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
## (combo + si toca soltar etiqueta + danio real a los enemigos en el arco)
## y lo retransmite a todos los peers, incluido el que lo pidio.
##
## T1 (rework de combate 2026-09-03): el Basico YA NO recupera chakra --
## chakra_current se regenera solo con el tiempo ahora (ver
## _server_regen_chakra/_advance_chakra_regen), asi que este RPC dejo de
## mandar un new_chakra. El Basico sigue siendo la UNICA ranura sin
## cooldown propio -- a proposito, es lo que lo mantiene siempre disponible
## mientras el resto de ranuras estan de cooldown (ver _slot_cooldowns).
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

	confirm_basic_attack.rpc(next_combo, spawn_tag, aim_point, not targets.is_empty())

## Resultado confirmado por el host. Se aplica en todos los peers por igual.
## hit_occurred (nuevo, solo para el screen shake) es simplemente si el
## cono encontro algun enemigo -- no cambia ningun calculo de daño, solo se
## lee para disparar la sacudida de camara del propio atacante.
@rpc("any_peer", "call_local", "reliable")
func confirm_basic_attack(combo_index: int, spawn_tag: bool, aim_point: Vector2, hit_occurred: bool) -> void:
	combo_count = combo_index
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
	# T1: cooldown propio de la ranura, ademas del coste de chakra que ya
	# tenia -- ver comentario de _slot_cooldowns. El slot_id "proyectil" es
	# compartido con el Agarre del Fisico (misma ranura, un estilo solo usa
	# uno de los dos).
	if _cooldown_remaining("proyectil") > 0.0:
		return
	if chakra_current < style_data.projectile_chakra_cost:
		return # sin chakra suficiente, se ignora la peticion (sin penalizar)
	var new_chakra: float = chakra_current - style_data.projectile_chakra_cost
	confirm_projectile_attack.rpc(new_chakra, aim_point)

@rpc("any_peer", "call_local", "reliable")
func confirm_projectile_attack(new_chakra: float, aim_point: Vector2) -> void:
	chakra_current = new_chakra
	_start_cooldown("proyectil", style_data.projectile_cooldown)
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
	# T1: mismo slot_id "proyectil" que usa el Proyectil de los demas
	# estilos -- es la misma ranura, solo que Fisico no paga chakra por ella.
	if _cooldown_remaining("proyectil") > 0.0:
		return
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
	_start_cooldown("proyectil", style_data.grab_cooldown)
	if consume_potenciador:
		_potenciador_active_element = ""
		_potenciador_caster_id = 0
		_potenciador_damage_bonus = 0.0
		_update_potenciador_visual()
	if multiplayer.is_server():
		_schedule_grab_someter(target, style_data.grab_hold_duration)

## H6: aguantar el Agarre hasta el final de grab_hold_duration sin lanzar ya
## NO libera al enemigo -- lo somete y genera un Prisionero cargable (ver
## Prisionero.gd, cabecera, para el porque de esta decision en vez de una
## septima tecnica en la ranura Sellos). Lanzar (confirm_throw) sigue siendo
## la unica forma de evitarlo dentro de la ventana. Solo lo programa el host
## (que es quien decide cuando confirmar cosas); el resultado se retransmite
## igual que cualquier otra confirmacion.
func _schedule_grab_someter(target: EnemigoSimple, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(target) and target.agarrado_por == self:
		# next_cadaver_id() se pide UNA vez aqui (esto solo corre en el host,
		# ver el guard en confirm_grab) y viaja como argumento del RPC --
		# mismo criterio que EnemigoSimple.recibir_daño con el id de cadaver,
		# evita que cada peer tire de su propio contador local dentro de la
		# RPC call_local y colisione nombres de nodo.
		confirm_someter_prisionero.rpc(target.get_path(), NetworkManager.next_cadaver_id(), target.valor_cadaver_base)

## Convierte al enemigo agarrado en un Prisionero vivo. Nace LIBRE en el
## suelo (cargado_por_peer_id = 0), igual que un Cadaver recien spawneado --
## hay que recogerlo aparte con G, no se auto-carga en quien lo sometio.
@rpc("any_peer", "call_local", "reliable")
func confirm_someter_prisionero(path: NodePath, prisionero_id: int, valor_base: float) -> void:
	var target := get_node_or_null(path) as EnemigoSimple
	grabbed_enemy_path = NodePath("")
	if target == null or not is_instance_valid(target):
		return
	target.agarrado_por = null
	var root: Node = NetworkManager.cadavers_root
	if root != null:
		var scene: PackedScene = preload("res://scenes/cadavers/prisionero.tscn")
		var prisionero: Prisionero = scene.instantiate()
		prisionero.valor_base = valor_base
		prisionero.name = "prisionero_%d" % prisionero_id
		root.add_child(prisionero)
		prisionero.global_position = target.global_position
	target.queue_free()

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
		# Cadaver o Prisionero (H6, ver cabecera de Prisionero.gd) -- ambos
		# son Node2D con global_position, no hace falta el tipo concreto
		# para seguir al jugador.
		var node := get_node_or_null(carried_cadaver_paths[i])
		if node == null or not is_instance_valid(node) or not (node is Cadaver or node is Prisionero):
			continue
		var offset: Vector2 = Vector2.LEFT.rotated(_torso.rotation) * (CADAVER_CARRY_OFFSET + i * CADAVER_CARRY_SPACING)
		(node as Node2D).global_position = global_position + offset

# =========================================================================
# Zona (Fuego/Viento) -- mantener Mayus/Shift carga, soltar coloca.
# T2 (rework de combate 2026-09-03): esto vivia en Q -- Q paso a ser un
# hueco de tecnica de loadout (ver mas abajo), la Zona/Lanzamiento se
# reasigno a Mayus (accion "zone_cast", mismo nombre de accion de siempre,
# solo cambia la tecla fisica -- ver project.godot).
# =========================================================================

func _handle_zone_input(delta: float) -> void:
	if style_data.melee_only:
		if Input.is_action_just_pressed("zone_cast") and _get_grabbed_enemy() != null and _cooldown_remaining("zona") <= 0.0:
			_request_throw(get_global_mouse_position())
		return
	if Input.is_action_just_pressed("zone_cast") and _cooldown_remaining("zona") <= 0.0:
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
	# T1: cooldown propio de la ranura, ademas del coste de chakra que ya
	# tenia. Slot_id "zona" compartido con el Lanzamiento del Fisico.
	if _cooldown_remaining("zona") > 0.0:
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
	_start_cooldown("zona", style_data.zone_cooldown)
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
# Lanzamiento (solo Fisico, sustituye a la Zona) -- misma tecla que Zona
# (Mayus/Shift), ver comentario de la seccion Zona arriba.
# =========================================================================

func _request_throw(cursor_pos: Vector2) -> void:
	submit_throw.rpc_id(1, cursor_pos)

@rpc("any_peer", "call_local", "reliable")
func submit_throw(cursor_pos: Vector2) -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	# T1: mismo slot_id "zona" que usa la Zona de los demas estilos -- misma
	# ranura, el Fisico no paga chakra por ella.
	if _cooldown_remaining("zona") > 0.0:
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
	_start_cooldown("zona", style_data.throw_cooldown)
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
# Sellos -- mantener R, secuencia de 3 direccionales, tecnica oculta.
# =========================================================================

## Corre cada fotograma para la autoridad del personaje (ver _physics_process,
## igual que _handle_zone_input). Mantener R inmoviliza (ver _handle_movement)
## y captura hasta 3 pulsaciones direccionales; soltar R antes de completar 3
## cancela sin efecto.
func _handle_sellos_input() -> void:
	if Input.is_action_just_pressed("sellos") and not _zone_charging and _get_grabbed_enemy() == null and _cooldown_remaining("sellos") <= 0.0:
		_sellos_charging = true
		_sellos_directions.clear()
	if not _sellos_charging:
		return
	if Input.is_action_just_released("sellos"):
		_sellos_charging = false
		_sellos_directions.clear()
		return
	var dir := ""
	if Input.is_action_just_pressed("move_left"):
		dir = "left"
	elif Input.is_action_just_pressed("move_right"):
		dir = "right"
	elif Input.is_action_just_pressed("move_up"):
		dir = "up"
	elif Input.is_action_just_pressed("move_down"):
		dir = "down"
	if dir == "":
		return
	_sellos_directions.append(dir)
	if _sellos_directions.size() >= SELLOS_SECUENCIA_LONGITUD:
		_sellos_charging = false
		var secuencia := _sellos_directions.duplicate()
		_sellos_directions.clear()
		submit_sellos_technique.rpc_id(1, secuencia, get_global_mouse_position())

## secuencia va sin usar por ahora (el host solo comprueba que este completa):
## se manda igual porque el sistema de pergaminos futuro (casino-agent) la
## necesitara para decidir QUE tecnica sale de cada combinacion direccional;
## hasta que exista, cada estilo tiene una unica tecnica fija en su
## StyleData (ver comentario de cabecera de style_data.gd, grupo "Sellos").
@rpc("any_peer", "call_local", "reliable")
func submit_sellos_technique(secuencia: Array, aim_point: Vector2) -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	if secuencia.size() < SELLOS_SECUENCIA_LONGITUD:
		return # secuencia incompleta o manipulada -- se ignora sin penalizar
	# T1: cooldown propio de la ranura -- se aplica incluso en Fisico, que no
	# paga chakra por su Sello (ver usa_chakra mas abajo).
	if _cooldown_remaining("sellos") > 0.0:
		return
	# H6: la tecnica de Sellos ya no es gratis por tener el estilo equipado --
	# hace falta haberla comprado en la Tienda de Pergaminos (ver
	# NetworkManager.pergaminos_sellos_comprados, player.gd
	# submit_comprar_pergamino). Las tecnicas de Sellos son las "ocultas" del
	# brief, no necesarias para avanzar en la historia -- no rompe la regla
	# invariante de la seccion 4 ("ninguna tecnica necesaria para avanzar esta
	# detras del casino"). Sin mensaje via confirm_casino_mensaje: a
	# diferencia de una compra explicita que falla, este es un intento de
	# usar una tecnica de combate en pleno combate -- igual que la secuencia
	# incompleta de arriba, se ignora sin penalizar y sin interrumpir el flujo
	# con un aviso de texto.
	var peer_id_sellos := get_multiplayer_authority()
	var comprados_sellos: Dictionary = NetworkManager.pergaminos_sellos_comprados.get(peer_id_sellos, {})
	if not comprados_sellos.get(style_data.element_name, false):
		return
	var usa_chakra: bool = style_data.chakra_max > 0.0
	if usa_chakra and chakra_current < style_data.sellos_chakra_cost:
		return
	var new_chakra: float = chakra_current - style_data.sellos_chakra_cost if usa_chakra else chakra_current
	var damage_type := _basic_damage_type()
	var mult: float = _current_damage_multiplier()

	if style_data.melee_only:
		# Fisico: cono como el Basico/Agarre (sin chakra que gastar), golpe
		# unico mucho mas fuerte que el Basico.
		var facing_dir: Vector2 = aim_point - global_position
		if facing_dir.length() < 0.001:
			facing_dir = Vector2.RIGHT.rotated(_torso.rotation)
		facing_dir = facing_dir.normalized()
		var damage: float = style_data.sellos_fisico_damage * mult
		for enemigo in _find_enemies_in_cone(style_data.sellos_fisico_range, style_data.sellos_fisico_cone_degrees, facing_dir):
			if enemigo.has_method("recibir_daño"):
				enemigo.recibir_daño(damage_type, damage)
	elif style_data.element_name == "agua":
		# Agua: sin daño de area -- cura de golpe, aplicada en
		# confirm_sellos_technique (mismo patron que el resto de curas, que
		# corren en todos los peers via RPC en vez de solo en el host).
		pass
	else:
		# Fuego (nova), Rayo (descarga), Tierra (puño sismico): area simple
		# alrededor del jugador, solo cambia el damage_type. Viento ademas
		# arrastra de golpe a quien alcance hacia el punto de origen.
		var damage: float = style_data.sellos_damage * mult
		var pull_distance: float = 0.0
		if style_data.element_name == "viento":
			pull_distance = style_data.sellos_viento_pull_distance
		for enemigo in get_tree().get_nodes_in_group(GRUPO_ENEMIGOS):
			if not (enemigo is Node2D):
				continue
			var dist: float = global_position.distance_to(enemigo.global_position)
			if dist > style_data.sellos_radius:
				continue
			if pull_distance > 0.0:
				enemigo.global_position = enemigo.global_position.move_toward(global_position, min(pull_distance, dist))
			if enemigo.has_method("recibir_daño"):
				enemigo.recibir_daño(damage_type, damage)

	confirm_sellos_technique.rpc(new_chakra)

@rpc("any_peer", "call_local", "reliable")
func confirm_sellos_technique(new_chakra: float) -> void:
	chakra_current = new_chakra
	_start_cooldown("sellos", style_data.sellos_cooldown)
	if style_data.element_name == "agua":
		vida_actual = min(vida_actual + style_data.sellos_agua_self_heal, style_data.vida_maxima)
	trigger_hit_shake(SCREEN_SHAKE_ATTACK_STRENGTH * 1.5)

# =========================================================================
# Loadout Q/E -- T2 (rework de combate 2026-09-03). Dos huecos de tecnica
# equipable por estilo (sustituyen a Zona/Potenciador en estas dos teclas,
# reasignadas a Mayus/Ctrl, ver las secciones de arriba). Cada estilo trae
# de fabrica UNA tecnica por hueco ("factory"): Q es un golpe unico en cono
# (como el Basico, mas fuerte); E es un estallido de area alrededor del
# propio jugador. Todos los estilos, incluido Fisico, tienen las dos (Fisico
# sin coste de chakra, igual que el Agarre/Lanzamiento/Sellos-fisico).
#
# T4 (pool de tecnicas de pergamino) ya esta hecho: _equipped_loadout_technique()
# resuelve "factory" o cualquier id del pool de StyleData.pergaminos_pool
# (ver PergaminoTechnique) leyendo NetworkManager.loadout_equipped.
# submit_equipar_tecnica_loadout()/confirm_equipar_tecnica_loadout() (mas
# abajo) son el punto de entrada que T5 (Tienda de Pergaminos, casino-agent)
# llama para cambiar que tecnica ya aprendida ocupa Q o E -- T4 no
# implementa la compra en si (eso gasta fichas y anade a
# NetworkManager.pergaminos_aprendidos, ver tienda_pergaminos.gd de T5).
# =========================================================================

## Devuelve el id equipado en `slot` ("factory" por defecto -- ver
## NetworkManager.loadout_equipped).
func _equipped_loadout_technique(slot: String) -> String:
	var peer_id := get_multiplayer_authority()
	var equipped: Dictionary = NetworkManager.loadout_equipped.get(peer_id, {})
	return equipped.get(slot, "factory")

func _request_loadout_technique(slot: String) -> void:
	var aim_point := get_global_mouse_position()
	submit_loadout_technique.rpc_id(1, slot, aim_point)

@rpc("any_peer", "call_local", "reliable")
func submit_loadout_technique(slot: String, aim_point: Vector2) -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	if slot != "Q" and slot != "E":
		return # peticion manipulada -- solo existen estos dos huecos
	var slot_id := "loadout_q" if slot == "Q" else "loadout_e"
	if _cooldown_remaining(slot_id) > 0.0:
		return
	# T4: la tecnica equipada decide coste/cooldown/daño/forma -- "factory"
	# usa los campos fijos de siempre (Q = cono, E = area), cualquier otro id
	# viene del pool de StyleData (PergaminoTechnique lleva su propio shape,
	# por eso una tecnica del pool funciona igual de bien en Q que en E).
	var technique_id := _equipped_loadout_technique(slot)
	var cost: float
	var cooldown: float
	var damage: float
	var shape: String
	var hit_range: float
	var cone_degrees: float
	var radius: float
	if technique_id == "factory":
		cost = style_data.loadout_q_chakra_cost if slot == "Q" else style_data.loadout_e_chakra_cost
		cooldown = style_data.loadout_q_cooldown if slot == "Q" else style_data.loadout_e_cooldown
		damage = style_data.loadout_q_damage if slot == "Q" else style_data.loadout_e_damage
		shape = "cone" if slot == "Q" else "area"
		hit_range = style_data.loadout_q_range
		cone_degrees = style_data.loadout_q_cone_degrees
		radius = style_data.loadout_e_radius
	else:
		var tech := style_data.find_pergamino_technique(technique_id)
		if tech == null:
			return # id desconocido/manipulado -- no deberia pasar (solo se equipan ids aprendidos)
		cost = tech.chakra_cost
		cooldown = tech.cooldown
		damage = tech.damage
		shape = tech.shape
		hit_range = tech.hit_range
		cone_degrees = tech.cone_degrees
		radius = tech.radius
	var usa_chakra: bool = style_data.chakra_max > 0.0
	if usa_chakra and chakra_current < cost:
		return
	var new_chakra: float = chakra_current - cost if usa_chakra else chakra_current
	var damage_type := _basic_damage_type()
	var final_damage: float = damage * _current_damage_multiplier()
	var hit_occurred := false
	if shape == "cone":
		var facing_dir: Vector2 = aim_point - global_position
		if facing_dir.length() < 0.001:
			facing_dir = Vector2.RIGHT.rotated(_torso.rotation)
		facing_dir = facing_dir.normalized()
		for enemigo in _find_enemies_in_cone(hit_range, cone_degrees, facing_dir):
			hit_occurred = true
			if enemigo.has_method("recibir_daño"):
				enemigo.recibir_daño(damage_type, final_damage)
	else:
		for enemigo in get_tree().get_nodes_in_group(GRUPO_ENEMIGOS):
			if not (enemigo is Node2D):
				continue
			if global_position.distance_to(enemigo.global_position) <= radius:
				hit_occurred = true
				if enemigo.has_method("recibir_daño"):
					enemigo.recibir_daño(damage_type, final_damage)
	confirm_loadout_technique.rpc(slot_id, new_chakra, cooldown, hit_occurred)

@rpc("any_peer", "call_local", "reliable")
func confirm_loadout_technique(slot_id: String, new_chakra: float, cooldown: float, hit_occurred: bool) -> void:
	chakra_current = new_chakra
	_start_cooldown(slot_id, cooldown)
	if hit_occurred:
		trigger_hit_shake()

## T4: punto de entrada para que la Tienda de Pergaminos (T5, casino-agent)
## cambie que tecnica ocupa Q o E. Host-autoritativo: "factory" siempre vale
## (T2, gratis); cualquier otro id debe existir en style_data.pergaminos_pool
## Y estar en NetworkManager.pergaminos_aprendidos para ESTE peer y estilo
## (comprada) -- si no, la peticion se descarta en silencio, igual que el
## resto de submit_* ante datos manipulados. Esta funcion NO gasta fichas ni
## toca pergaminos_aprendidos: eso es la compra (T5); esto es solo "poner en
## Q/E algo que ya tienes", que tambien hace falta para volver a la de
## fabrica o cambiar entre dos tecnicas ya compradas sin pagar de nuevo.
@rpc("any_peer", "call_local", "reliable")
func submit_equipar_tecnica_loadout(slot: String, technique_id: String) -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	if slot != "Q" and slot != "E":
		return # peticion manipulada -- solo existen estos dos huecos
	if technique_id != "factory":
		if style_data.find_pergamino_technique(technique_id) == null:
			return # id no existe en el pool de este estilo -- manipulado
		var peer_id := get_multiplayer_authority()
		var aprendidas: Array = NetworkManager.pergaminos_aprendidos.get(peer_id, {}).get(style_data.element_name, [])
		if not aprendidas.has(technique_id):
			return # no comprada para este estilo todavia -- ver T5
	confirm_equipar_tecnica_loadout.rpc(get_multiplayer_authority(), slot, technique_id)

@rpc("any_peer", "call_local", "reliable")
func confirm_equipar_tecnica_loadout(peer_id: int, slot: String, technique_id: String) -> void:
	var equipped: Dictionary = NetworkManager.loadout_equipped.get(peer_id, {})
	equipped[slot] = technique_id
	NetworkManager.loadout_equipped[peer_id] = equipped

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
# Potenciador -- Ctrl (T2, rework de combate 2026-09-03: vivia en E, que
# paso a ser un hueco de tecnica de loadout, ver mas abajo). Se lanza sobre
# un aliado, NUNCA sobre uno mismo -- regla invariante de esta ranura en
# concreto (no la comparte la ranura de Soporte nueva de T3). Solo Fuego/
# Viento/Agua/Rayo/Tierra tienen chakra para lanzarlo (Fisico no tiene
# Potenciador propio, brief 2.1); Fisico si puede RECIBIRLO -- ver bonus en
# Agarre.
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
	# T1: cooldown propio de la ranura. Sin mensaje de fallo especifico (a
	# diferencia de chakra/cono vacios de abajo) -- un intento en cooldown ya
	# tiene su propia señal clara en pantalla (el hueco no responde), igual
	# que el resto de ranuras de esta tanda.
	if _cooldown_remaining("potenciador") > 0.0:
		return
	if chakra_current < style_data.potenciador_chakra_cost:
		# Mismo problema que el cono vacio de abajo: sin aviso, un intento sin
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
	_start_cooldown("potenciador", style_data.potenciador_cooldown)

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
# Soporte -- F15 (T3, ranura nueva del rework de combate 2026-09-03: F1-F14
# ya estaban ocupadas, ver project.godot). Cura/escudo/efecto NO ofensivo --
# a diferencia del Potenciador de arriba, esta ranura SI puede afectar a
# quien la lanza: si hay un aliado en el cono de apuntado se aplica a el, si
# no hay nadie se aplica a uno mismo. Gasta el mismo chakra pasivo de
# siempre, no crea un recurso nuevo. Solo una tecnica de fabrica por estilo
# (cura); dar a elegir entre varias es el mismo T4 de Loadout Q/E.
# =========================================================================

func _request_soporte() -> void:
	var facing_dir: Vector2 = Vector2.RIGHT.rotated(_torso.rotation)
	submit_soporte.rpc_id(1, facing_dir)

## El host busca el aliado mas cercano en el cono de apuntado, igual que el
## Potenciador/Agarre; si no hay ninguno, el objetivo pasa a ser uno mismo
## -- unica ranura del kit que puede hacer esto (ver cabecera de esta
## seccion).
@rpc("any_peer", "call_local", "reliable")
func submit_soporte(facing_dir: Vector2) -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	if _cooldown_remaining("soporte") > 0.0:
		return
	var usa_chakra: bool = style_data.chakra_max > 0.0
	if usa_chakra and chakra_current < style_data.soporte_chakra_cost:
		return
	var new_chakra: float = chakra_current - style_data.soporte_chakra_cost if usa_chakra else chakra_current
	var candidates := _find_allies_in_cone(style_data.soporte_range, style_data.soporte_cone_degrees, facing_dir)
	var target: Node = self
	if not candidates.is_empty():
		var best: Node2D = candidates[0]
		var best_dist: float = global_position.distance_to(best.global_position)
		for c in candidates:
			var d: float = global_position.distance_to(c.global_position)
			if d < best_dist:
				best_dist = d
				best = c
		target = best
	confirm_soporte_cast.rpc(new_chakra)
	# RPC sobre el nodo objetivo (self o un aliado) -- mismo truco que ya usa
	# el Potenciador para aplicar el resultado donde toca, aunque aqui el
	# objetivo pueda ser el propio nodo que emite el RPC.
	target.confirm_soporte_received.rpc(style_data.soporte_heal_amount)

@rpc("any_peer", "call_local", "reliable")
func confirm_soporte_cast(new_chakra: float) -> void:
	chakra_current = new_chakra
	_start_cooldown("soporte", style_data.soporte_cooldown)

## Se ejecuta en el jugador OBJETIVO (self o un aliado, ver submit_soporte).
@rpc("any_peer", "call_local", "reliable")
func confirm_soporte_received(heal_amount: float) -> void:
	vida_actual = min(vida_actual + heal_amount, style_data.vida_maxima)

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
	vida_actual = max(vida_actual - cantidad * _vulnerabilidad_multiplicador * _potenciador_damage_reduction * NetworkManager.cocina_damage_reduction_multiplier, 0.0)
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

## Tope real de cadaveres cargados: MAX_CADAVERES_CARGADOS mas
## CasaEquipo.ALMACEN_BONUS_CADAVERES si el grupo ya compro el Almacen (H5
## cierre, Terrazas) -- ver NetworkManager.casa_equipo_almacen_comprado. Sin
## niveles (brief: compra unica), asi que no hace falta mas que un bool.
func _max_cadaveres_cargados() -> int:
	if NetworkManager.casa_equipo_almacen_comprado:
		return MAX_CADAVERES_CARGADOS + CasaEquipo.ALMACEN_BONUS_CADAVERES
	return MAX_CADAVERES_CARGADOS

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
	if carried_cadaver_paths.size() < _max_cadaveres_cargados():
		var candidate := _find_nearest_free_cadaver(CADAVER_PICKUP_RANGE)
		if candidate != null:
			confirm_pickup_cadaver.rpc(candidate.get_path())
			return
	if not carried_cadaver_paths.is_empty():
		confirm_drop_cadaver.rpc(carried_cadaver_paths[-1])

## H6: Cadaver y Prisionero comparten cargado_por_peer_id/carried_cadaver_paths
## (ver cabecera de Prisionero.gd) -- una rama por tipo en vez de un sistema
## de carga paralelo.
@rpc("any_peer", "call_local", "reliable")
func confirm_pickup_cadaver(path: NodePath) -> void:
	var cad := get_node_or_null(path) as Cadaver
	if cad != null and is_instance_valid(cad) and cad.cargado_por_peer_id == 0:
		cad.cargado_por_peer_id = get_multiplayer_authority()
		carried_cadaver_paths.append(path)
		return
	var pris := get_node_or_null(path) as Prisionero
	if pris != null and is_instance_valid(pris) and pris.cargado_por_peer_id == 0:
		pris.cargado_por_peer_id = get_multiplayer_authority()
		carried_cadaver_paths.append(path)
	# Si ninguno de los dos aplica (nulo, invalido o ya cargado por otro):
	# otro jugador se lo llevo entre que el host decidio y esto llega.

@rpc("any_peer", "call_local", "reliable")
func confirm_drop_cadaver(path: NodePath) -> void:
	carried_cadaver_paths.erase(path)
	var cad := get_node_or_null(path) as Cadaver
	if cad != null and is_instance_valid(cad):
		cad.cargado_por_peer_id = 0
		cad.global_position = global_position + Vector2.RIGHT.rotated(_torso.rotation) * CADAVER_DROP_OFFSET
		return
	var pris := get_node_or_null(path) as Prisionero
	if pris != null and is_instance_valid(pris):
		pris.cargado_por_peer_id = 0
		pris.global_position = global_position + Vector2.RIGHT.rotated(_torso.rotation) * CADAVER_DROP_OFFSET

## Cuando un Prisionero cargado muere de verdad (dano real, no la captura
## inicial) se convierte en un Cadaver normal -- ver Prisionero.morir() y su
## comentario de cabecera para la decision de diseño. Aqui solo se actualiza
## la lista de carga de quien lo llevaba para que el Cadaver nuevo ocupe su
## sitio, igual que si lo hubiera recogido el mismo (si no, el NodePath
## muerto del prisionero se quedaria para siempre contando contra
## MAX_CADAVERES_CARGADOS sin nada que vender).
func reemplazar_prisionero_por_cadaver(prisionero_path: NodePath, cadaver_path: NodePath) -> void:
	var idx := carried_cadaver_paths.find(prisionero_path)
	if idx == -1:
		return
	carried_cadaver_paths[idx] = cadaver_path

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
	# Maquina expendedora de cadaveres (quinto comprador): usos COMPARTIDOS
	# de grupo, no por jugador -- ver NetworkManager.usos_maquina_restantes.
	# Se comprueba ANTES de calcular ningun precio: sin usos, la venta ni
	# siquiera se intenta (mismo criterio que el resto de los avisos de esta
	# funcion via confirm_casino_mensaje).
	var es_maquina: bool = comprador.tipo == Comprador.Tipo.MAQUINA_EXPENDEDORA
	if es_maquina and NetworkManager.usos_maquina_restantes <= 0:
		confirm_casino_mensaje.rpc("La máquina expendedora no tiene usos, recarga en curso")
		return
	var total_precio := 0.0
	var vendidos: Array[NodePath] = []
	for path in carried_cadaver_paths:
		var cad := get_node_or_null(path) as Cadaver
		if cad != null and is_instance_valid(cad):
			total_precio += comprador.calcular_precio(cad.estado_conservacion, cad.valor_base)
			vendidos.append(path)
			continue
		var pris := get_node_or_null(path) as Prisionero
		if pris != null and is_instance_valid(pris):
			# H6: sin pasar por Comprador.calcular_precio -- ver comentario de
			# EconomiaCadaveres.MULTIPLICADOR_PRISIONERO.
			total_precio += pris.valor_base * EconomiaCadaveres.MULTIPLICADOR_PRISIONERO
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
	# Pizarra de records de la Taberna (H6 extra, ver NetworkManager.
	# record_cuerpos_destrozados y su comentario de cabecera para la
	# definicion elegida de "destrozado"): venderle al Carnicero cuenta,
	# sea cual sea el estado_conservacion de cada cadaver.
	var es_carnicero: bool = comprador.tipo == Comprador.Tipo.CARNICERO
	confirm_vender.rpc(vendidos, nuevo_total, total_precio, recorte_usurero, nueva_deuda, es_carnicero, es_maquina)

## Aplica la venta igual en todos los peers: borra los cadaveres vendidos,
## los quita de la lista de carga y actualiza el pool compartido de dinero
## manchado (NetworkManager.dinero_manchado -- mutarlo aqui directamente
## vale porque este RPC ya es call_local reliable en si mismo, no hace
## falta un RPC aparte solo para el dinero). Tambien aplica la deuda del
## Usurero ya decidida por el host en submit_vender().
@rpc("any_peer", "call_local", "reliable")
func confirm_vender(vendidos: Array[NodePath], nuevo_total: float, precio_ganado: float, recorte_usurero: float, nueva_deuda: float, es_carnicero: bool, es_maquina: bool = false) -> void:
	# H6: se cuentan los Cadaver reales por separado de los Prisionero -- ver
	# el uso de esta cuenta mas abajo con record_cuerpos_destrozados (un
	# prisionero vendido vivo no es un "cadaver destrozado").
	var cadaveres_vendidos := 0
	for path in vendidos:
		carried_cadaver_paths.erase(path)
		var cad := get_node_or_null(path) as Cadaver
		if cad != null and is_instance_valid(cad):
			cadaveres_vendidos += 1
			cad.queue_free()
			continue
		var pris := get_node_or_null(path) as Prisionero
		if pris != null and is_instance_valid(pris):
			pris.queue_free()
	NetworkManager.dinero_manchado = nuevo_total
	NetworkManager.usurero_deuda_pendiente = nueva_deuda
	# Desglose de contribucion de la Taberna (plan-desarrollo.md, tarea
	# reenganchada): precio_ganado es el importe que de verdad entra en
	# dinero_manchado en esta venta (ya con el recorte del Usurero aplicado
	# si tocaba), asi que sumarlo aqui es "cuanto ha metido este jugador al
	# bote comun" sin inventar tracking nuevo -- reutiliza el mismo
	# get_multiplayer_authority() que ya se calculaba para
	# record_cuerpos_destrozados de abajo.
	var peer_id_vendedor := get_multiplayer_authority()
	if precio_ganado > 0.0:
		NetworkManager.taberna_aportado_manchado[peer_id_vendedor] = NetworkManager.taberna_aportado_manchado.get(peer_id_vendedor, 0.0) + precio_ganado
	if es_carnicero and cadaveres_vendidos > 0:
		NetworkManager.record_cuerpos_destrozados[peer_id_vendedor] = NetworkManager.record_cuerpos_destrozados.get(peer_id_vendedor, 0) + cadaveres_vendidos
	# Maquina expendedora: un uso compartido de grupo por esta interaccion
	# con V (venderla de golpe cuenta 1, no por cadaver -- ver submit_vender).
	# Mutarlo aqui directamente vale por el mismo motivo que dinero_manchado
	# arriba: este RPC ya es call_local reliable, llega igual a todos los
	# peers. Solo el HOST arranca el timer de recarga (mismo guard que
	# _schedule_grab_someter usa para el suyo).
	if es_maquina:
		NetworkManager.usos_maquina_restantes = max(0, NetworkManager.usos_maquina_restantes - 1)
		if NetworkManager.usos_maquina_restantes == 0 and multiplayer.is_server():
			NetworkManager.schedule_recarga_maquina()
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
	# Tramo ROJO de sospecha (H6, brief 2.3): "expulsion tres dias de juego,
	# sin cambista ni pergaminos" -- los pergaminos no existen todavia (fuera
	# de alcance), asi que lo unico que hay que bloquear de verdad es esto.
	if NetworkManager.sospecha_tramo(get_multiplayer_authority()) == "rojo":
		confirm_casino_mensaje.rpc("Estas expulsado del casino por sospecha -- vuelve mas tarde")
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
	# Trampa retroactiva de Viento (H6): mantener la tecla justo al apostar
	# es la adaptacion de "empujar el dado justo antes de que pare" -- no
	# hay animacion de tirada real en este vertical slice (resolver_tirada
	# es instantaneo), asi que el momento equivalente es el instante en que
	# se pide la apuesta. Ver mesa_dados.gd resolver_tirada_forzada().
	var trampa_pedida := Input.is_action_pressed("trampa_dados")
	submit_apostar_dados.rpc_id(1, eleccion, _apuesta_moneda, _apuesta_monto, trampa_pedida)

## Apuesta `monto` (ajustable con +/-, ver _apuesta_monto arriba -- ya no es
## un monto fijo de mesa) a "alto" o "bajo", con la moneda que el jugador
## tenga seleccionada (tecla M) -- "limpio" (el camino que sigue el brief al
## pie de la letra) o "manchado" (via de blanquear jugando en vez de pagando
## la comision del Cambista, decision de diseno del usuario, ver
## _apuesta_moneda arriba). `moneda` y `monto` solo dicen DE QUE POOL y
## CUANTO se pide jugarse -- el host sigue siendo quien valida fondos y
## calcula el resultado real, asi que el cliente no puede inventarse ni la
## cantidad ni el resultado, solo pedir con que monedero y cuanto.
## Ver mesa_dados.gd para las reglas de las tres caras y el payout. El RNG
## del resultado corre entero en el host dentro de mesa.resolver_tirada().
@rpc("any_peer", "call_local", "reliable")
func submit_apostar_dados(eleccion: String, moneda: String, monto: float, trampa_pedida: bool) -> void:
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
	if monto < mesa.apuesta_minima:
		confirm_casino_mensaje.rpc("La apuesta minima es %.0f" % mesa.apuesta_minima)
		return
	var disponible: float = NetworkManager.dinero_limpio if moneda == "limpio" else NetworkManager.dinero_manchado
	if disponible < monto:
		# Igual que en el Cambista: sin aviso esto se ve identico a un boton
		# que no responde.
		confirm_casino_mensaje.rpc("Necesitas al menos %.0f de dinero %s para esa apuesta" % [monto, moneda])
		return
	# Trampa de Viento (H6, brief 2.3): si se pidio, hace falta el estilo
	# Viento equipado y chakra suficiente (doblada si estas en tramo AMBAR de
	# sospecha). Si no hay Viento equipado, mismo confirm_casino_mensaje que
	# usa el resto del casino para "no puedes" -- pedido explicito de la
	# tarea, en vez de dejar la tecla sin hacer nada.
	var peer_id := get_multiplayer_authority()
	var nuevo_chakra: float = chakra_current
	var hizo_trampa := false
	var nueva_sospecha: float = NetworkManager.sospecha_nivel.get(peer_id, 0.0)
	var nueva_expulsion: float = NetworkManager.sospecha_expulsado_restante.get(peer_id, 0.0)
	if trampa_pedida:
		if style_data.element_name != "viento":
			confirm_casino_mensaje.rpc("Necesitas el estilo Viento equipado para esa trampa")
		else:
			var costo: float = TRAMPA_DADOS_CHAKRA_COST * (2.0 if NetworkManager.sospecha_tramo(peer_id) == "ambar" else 1.0)
			if chakra_current < costo:
				confirm_casino_mensaje.rpc("No tienes suficiente chakra para empujar el dado")
			else:
				hizo_trampa = true
				nuevo_chakra = chakra_current - costo
				nueva_sospecha = min(NetworkManager.SOSPECHA_MAX, nueva_sospecha + SOSPECHA_POR_TRAMPA_DADOS)
				if nueva_sospecha >= NetworkManager.SOSPECHA_ROJO_UMBRAL:
					nueva_expulsion = NetworkManager.SOSPECHA_DIAS_EXPULSION * NetworkManager.SOSPECHA_SEGUNDOS_POR_DIA
					nueva_sospecha = 0.0
	var resultado: Dictionary = mesa.resolver_tirada_forzada(eleccion) if hizo_trampa else mesa.resolver_tirada(eleccion)
	var gano: bool = resultado["gano"]
	var cara: int = resultado["cara"]
	# Usurero: una apuesta GANADA paga deuda pendiente (importe real, no un
	# contador -- ver comentario de submit_vender) -- perder no cuenta, no
	# genera nada que recortar.
	var recorte_usurero := 0.0
	var nueva_deuda: float = NetworkManager.usurero_deuda_pendiente
	var ganancia: float = monto
	if gano and nueva_deuda > 0.0:
		recorte_usurero = min(monto * NetworkManager.usurero_deuda_recorte_porcentaje, nueva_deuda)
		ganancia -= recorte_usurero
		nueva_deuda -= recorte_usurero
	var delta: float = ganancia if gano else -monto
	var nuevo_limpio: float = NetworkManager.dinero_limpio
	var nuevo_manchado: float = NetworkManager.dinero_manchado
	if moneda == "limpio":
		nuevo_limpio += delta
	else:
		nuevo_manchado += delta
	var fichas_ganadas: float = FICHAS_POR_GANAR if gano else FICHAS_POR_PERDER
	var nuevas_fichas: float = NetworkManager.fichas.get(peer_id, 0.0) + fichas_ganadas
	confirm_apostar_dados.rpc(nuevo_limpio, nuevo_manchado, moneda, eleccion, cara, gano, monto, recorte_usurero, nueva_deuda, nuevo_chakra, nueva_sospecha, nueva_expulsion, hizo_trampa, fichas_ganadas, nuevas_fichas)

@rpc("any_peer", "call_local", "reliable")
func confirm_apostar_dados(nuevo_limpio: float, nuevo_manchado: float, moneda: String, eleccion: String, cara: int, gano: bool, apuesta: float, recorte_usurero: float, nueva_deuda: float, nuevo_chakra: float, nueva_sospecha: float, nueva_expulsion: float, hizo_trampa: bool, fichas_ganadas: float, nuevas_fichas: float) -> void:
	NetworkManager.dinero_limpio = nuevo_limpio
	NetworkManager.dinero_manchado = nuevo_manchado
	NetworkManager.usurero_deuda_pendiente = nueva_deuda
	chakra_current = nuevo_chakra
	var peer_id := get_multiplayer_authority()
	NetworkManager.sospecha_nivel[peer_id] = nueva_sospecha
	NetworkManager.sospecha_expulsado_restante[peer_id] = nueva_expulsion
	NetworkManager.fichas[peer_id] = nuevas_fichas
	var resultado_texto: String
	if gano:
		resultado_texto = "GANASTE +%.1f" % (apuesta - recorte_usurero)
		if recorte_usurero > 0.0:
			resultado_texto += " (recorte Usurero -%.1f, deuda restante: -%.0f)" % [recorte_usurero, nueva_deuda]
	else:
		resultado_texto = "perdiste -%.1f" % apuesta
		# Pizarra de records de la Taberna (H6 extra, ver NetworkManager.
		# record_casino_perdidas): cuenta cada vez que gano == false.
		NetworkManager.record_casino_perdidas[peer_id] = NetworkManager.record_casino_perdidas.get(peer_id, 0) + 1
	var texto := "Dados %s (%s, cara %d): %s (+%.0f fichas)" % [moneda, eleccion, cara, resultado_texto, fichas_ganadas]
	if hizo_trampa:
		texto += " [Viento: dado forzado]"
	print("[Dados] Apostaste %s a %s, salio cara %d -> %s (limpio: %.1f, manchado: %.1f)" % [moneda, eleccion, cara, resultado_texto, nuevo_limpio, nuevo_manchado])
	_status_label.text = texto
	_status_label.modulate = Color(0.4, 1, 0.4) if gano else Color(1, 0.4, 0.4)

## Mensaje generico de casino para casos que se ignoran sin penalizar pero
## que SI hay que comunicar (sin objetivo en rango, fondos insuficientes) --
## si no, la tecla se ve exactamente igual que un boton roto.
@rpc("any_peer", "call_local", "reliable")
func confirm_casino_mensaje(mensaje: String) -> void:
	_status_label.modulate = Color(1, 1, 1)
	_status_label.text = mensaje

# =========================================================================
# Rueda del Clan (H6, tecla Z/K/O/N segun categoria) -- mismo patron
# submit_/confirm_ que el resto del casino. Sin trampa (ver ruleta.gd).
# =========================================================================

func _request_girar_ruleta(categoria: String) -> void:
	submit_girar_ruleta.rpc_id(1, categoria, _apuesta_moneda, _apuesta_monto)

## Apuesta unica por ronda a una categoria de sector (Ruleta.categorias()).
## El host decide "en rango" y calcula el resultado; RNG autoritativo dentro
## de ruleta.girar(). Sin Usurero: a diferencia de Vender/Dados, esta tanda
## no extiende el recorte de deuda a los juegos nuevos (fuera de alcance,
## ver instrucciones de la tarea -- el Usurero es un sistema ya cerrado).
@rpc("any_peer", "call_local", "reliable")
func submit_girar_ruleta(categoria: String, moneda: String, monto: float) -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	if not Ruleta.categorias().has(categoria):
		return
	if moneda != "limpio" and moneda != "manchado":
		return
	var ruleta := _find_nearest_ruleta_in_range(CASINO_RANGE)
	if ruleta == null:
		confirm_casino_mensaje.rpc("No hay ninguna Rueda del Clan cerca")
		return
	if monto < ruleta.apuesta_minima:
		confirm_casino_mensaje.rpc("La apuesta minima es %.0f" % ruleta.apuesta_minima)
		return
	var disponible: float = NetworkManager.dinero_limpio if moneda == "limpio" else NetworkManager.dinero_manchado
	if disponible < monto:
		confirm_casino_mensaje.rpc("Necesitas al menos %.0f de dinero %s para esa apuesta" % [monto, moneda])
		return
	var resultado := ruleta.girar(categoria)
	var gano: bool = resultado["gano"]
	var sector: String = resultado["sector"]
	var pago: float = resultado["pago"]
	var delta: float = (monto * pago) - monto if gano else -monto
	var nuevo_limpio: float = NetworkManager.dinero_limpio
	var nuevo_manchado: float = NetworkManager.dinero_manchado
	if moneda == "limpio":
		nuevo_limpio += delta
	else:
		nuevo_manchado += delta
	var peer_id := get_multiplayer_authority()
	var fichas_ganadas: float = FICHAS_POR_GANAR if gano else FICHAS_POR_PERDER
	var nuevas_fichas: float = NetworkManager.fichas.get(peer_id, 0.0) + fichas_ganadas
	confirm_girar_ruleta.rpc(nuevo_limpio, nuevo_manchado, moneda, categoria, sector, gano, monto, pago, fichas_ganadas, nuevas_fichas)

@rpc("any_peer", "call_local", "reliable")
func confirm_girar_ruleta(nuevo_limpio: float, nuevo_manchado: float, moneda: String, categoria: String, sector: String, gano: bool, apuesta: float, pago: float, fichas_ganadas: float, nuevas_fichas: float) -> void:
	NetworkManager.dinero_limpio = nuevo_limpio
	NetworkManager.dinero_manchado = nuevo_manchado
	var peer_id := get_multiplayer_authority()
	NetworkManager.fichas[peer_id] = nuevas_fichas
	var resultado_texto: String
	if gano:
		resultado_texto = "GANASTE +%.1f (x%.1f)" % [(apuesta * pago) - apuesta, pago]
	else:
		resultado_texto = "perdiste -%.1f" % apuesta
		NetworkManager.record_casino_perdidas[peer_id] = NetworkManager.record_casino_perdidas.get(peer_id, 0) + 1
	_status_label.text = "Ruleta %s (elegiste %s, salio %s): %s (+%.0f fichas)" % [moneda, categoria, sector, resultado_texto, fichas_ganadas]
	_status_label.modulate = Color(0.4, 1, 0.4) if gano else Color(1, 0.4, 0.4)

# =========================================================================
# Cartas Selladas (H6, tecla 7 juega, mantener 8 usa la trampa de Rayo,
# mantener / usa la trampa de Sellos) -- mismo patron submit_/confirm_ que
# el resto del casino. Ver cartas_selladas.gd para el detalle de las dos
# trampas.
# =========================================================================

func _request_jugar_cartas() -> void:
	var usar_rayo := Input.is_action_pressed("trampa_rayo_cartas")
	var usar_sellos := Input.is_action_pressed("trampa_sellos_cartas")
	submit_jugar_cartas.rpc_id(1, _apuesta_moneda, _apuesta_monto, usar_rayo, usar_sellos)

## Poker simplificado a carta mas alta contra 3 NPC (ver
## cartas_selladas.gd). `usar_rayo` pide la trampa de Rayo -- adaptacion de
## "acelerar tu turno y decidir con mas tiempo" a "reparte dos cartas y
## quedate con la mejor" (sin timer de decision real en este vertical
## slice, ver comentario de cabecera de cartas_selladas.gd). Sube sospecha
## igual que la trampa de Viento en la Mesa de Dados.
@rpc("any_peer", "call_local", "reliable")
func submit_jugar_cartas(moneda: String, monto: float, usar_rayo: bool, usar_sellos: bool) -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	if moneda != "limpio" and moneda != "manchado":
		return
	var mesa := _find_nearest_cartas_selladas_in_range(CASINO_RANGE)
	if mesa == null:
		confirm_casino_mensaje.rpc("No hay ninguna mesa de Cartas Selladas cerca")
		return
	if monto < mesa.apuesta_minima:
		confirm_casino_mensaje.rpc("La apuesta minima es %.0f" % mesa.apuesta_minima)
		return
	var disponible: float = NetworkManager.dinero_limpio if moneda == "limpio" else NetworkManager.dinero_manchado
	if disponible < monto:
		confirm_casino_mensaje.rpc("Necesitas al menos %.0f de dinero %s para esa apuesta" % [monto, moneda])
		return
	var peer_id := get_multiplayer_authority()
	var nuevo_chakra: float = chakra_current
	var hizo_trampa := false
	var nueva_sospecha: float = NetworkManager.sospecha_nivel.get(peer_id, 0.0)
	var nueva_expulsion: float = NetworkManager.sospecha_expulsado_restante.get(peer_id, 0.0)
	if usar_rayo:
		if style_data.element_name != "rayo":
			confirm_casino_mensaje.rpc("Necesitas el estilo Rayo equipado para esa trampa")
		else:
			var costo: float = CARTAS_RAYO_CHAKRA_COST * (2.0 if NetworkManager.sospecha_tramo(peer_id) == "ambar" else 1.0)
			if chakra_current < costo:
				confirm_casino_mensaje.rpc("No tienes suficiente chakra para acelerar tu turno")
			else:
				hizo_trampa = true
				nuevo_chakra = chakra_current - costo
				nueva_sospecha = min(NetworkManager.SOSPECHA_MAX, nueva_sospecha + SOSPECHA_POR_TRAMPA_CARTAS)
				if nueva_sospecha >= NetworkManager.SOSPECHA_ROJO_UMBRAL:
					nueva_expulsion = NetworkManager.SOSPECHA_DIAS_EXPULSION * NetworkManager.SOSPECHA_SEGUNDOS_POR_DIA
					nueva_sospecha = 0.0
	# Trampa de Sellos (H6, brief "con Sellos puedes ver una carta rival"):
	# a diferencia de Rayo (atada al estilo Rayo), esta usa la MISMA tecnica
	# de Sellos que el combate -- cualquier estilo sirve, siempre que su
	# pergamino ya este comprado (ver NetworkManager.pergaminos_sellos_comprados,
	# gateado igual que submit_sellos_technique en Task 6). Fisico no paga
	# chakra (chakra_max = 0), igual que el resto de costes de chakra de este
	# archivo comprueban usa_chakra en otros sitios.
	var hizo_trampa_sellos := false
	if usar_sellos:
		var comprados_cartas: Dictionary = NetworkManager.pergaminos_sellos_comprados.get(peer_id, {})
		if not comprados_cartas.get(style_data.element_name, false):
			confirm_casino_mensaje.rpc("Necesitas el pergamino de Sellos de tu estilo para esa trampa")
		else:
			var usa_chakra_sellos: bool = style_data.chakra_max > 0.0
			var costo_sellos: float = CARTAS_SELLOS_CHAKRA_COST * (2.0 if NetworkManager.sospecha_tramo(peer_id) == "ambar" else 1.0)
			if usa_chakra_sellos and chakra_current < costo_sellos:
				confirm_casino_mensaje.rpc("No tienes suficiente chakra para ver la carta rival")
			else:
				hizo_trampa_sellos = true
				hizo_trampa = true
				if usa_chakra_sellos:
					nuevo_chakra -= costo_sellos
				nueva_sospecha = min(NetworkManager.SOSPECHA_MAX, nueva_sospecha + SOSPECHA_POR_TRAMPA_CARTAS)
				if nueva_sospecha >= NetworkManager.SOSPECHA_ROJO_UMBRAL:
					nueva_expulsion = NetworkManager.SOSPECHA_DIAS_EXPULSION * NetworkManager.SOSPECHA_SEGUNDOS_POR_DIA
					nueva_sospecha = 0.0
	var resultado := mesa.jugar_mano(hizo_trampa, hizo_trampa_sellos)
	var gano: bool = resultado["gano"]
	var carta_jugador: int = resultado["carta_jugador"]
	var mejor_npc: int = resultado["mejor_npc"]
	var pago: float = resultado["pago"]
	var delta: float = (monto * pago) - monto if gano else -monto
	var nuevo_limpio: float = NetworkManager.dinero_limpio
	var nuevo_manchado: float = NetworkManager.dinero_manchado
	if moneda == "limpio":
		nuevo_limpio += delta
	else:
		nuevo_manchado += delta
	var fichas_ganadas: float = FICHAS_POR_GANAR if gano else FICHAS_POR_PERDER
	var nuevas_fichas: float = NetworkManager.fichas.get(peer_id, 0.0) + fichas_ganadas
	confirm_jugar_cartas.rpc(nuevo_limpio, nuevo_manchado, moneda, gano, carta_jugador, mejor_npc, monto, pago, nuevo_chakra, nueva_sospecha, nueva_expulsion, hizo_trampa, fichas_ganadas, nuevas_fichas)

@rpc("any_peer", "call_local", "reliable")
func confirm_jugar_cartas(nuevo_limpio: float, nuevo_manchado: float, moneda: String, gano: bool, carta_jugador: int, mejor_npc: int, apuesta: float, pago: float, nuevo_chakra: float, nueva_sospecha: float, nueva_expulsion: float, hizo_trampa: bool, fichas_ganadas: float, nuevas_fichas: float) -> void:
	NetworkManager.dinero_limpio = nuevo_limpio
	NetworkManager.dinero_manchado = nuevo_manchado
	chakra_current = nuevo_chakra
	var peer_id := get_multiplayer_authority()
	NetworkManager.sospecha_nivel[peer_id] = nueva_sospecha
	NetworkManager.sospecha_expulsado_restante[peer_id] = nueva_expulsion
	NetworkManager.fichas[peer_id] = nuevas_fichas
	var resultado_texto: String
	if gano:
		resultado_texto = "GANASTE +%.1f" % [(apuesta * pago) - apuesta]
	else:
		resultado_texto = "perdiste -%.1f" % apuesta
		NetworkManager.record_casino_perdidas[peer_id] = NetworkManager.record_casino_perdidas.get(peer_id, 0) + 1
	var texto := "Cartas %s (tu %d vs mejor NPC %d): %s (+%.0f fichas)" % [moneda, carta_jugador, mejor_npc, resultado_texto, fichas_ganadas]
	if hizo_trampa:
		texto += " [trampa]"
	_status_label.text = texto
	_status_label.modulate = Color(0.4, 1, 0.4) if gano else Color(1, 0.4, 0.4)

# =========================================================================
# Peleas del Sotano (H6, tecla , izquierda / . derecha) -- mismo pool libre
# que la Mesa de Dados: cualquiera cerca apuesta directo, sin votar. Sin
# trampa (el brief no menciona ninguna para este juego).
# =========================================================================

func _request_apostar_pelea(eleccion: String) -> void:
	submit_apostar_pelea.rpc_id(1, eleccion, _apuesta_moneda, _apuesta_monto)

@rpc("any_peer", "call_local", "reliable")
func submit_apostar_pelea(eleccion: String, moneda: String, monto: float) -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	if eleccion != "izquierda" and eleccion != "derecha":
		return
	if moneda != "limpio" and moneda != "manchado":
		return
	var pelea := _find_nearest_peleas_sotano_in_range(CASINO_RANGE)
	if pelea == null:
		confirm_casino_mensaje.rpc("No hay ninguna pelea del Sotano cerca")
		return
	if monto < pelea.apuesta_minima:
		confirm_casino_mensaje.rpc("La apuesta minima es %.0f" % pelea.apuesta_minima)
		return
	var disponible: float = NetworkManager.dinero_limpio if moneda == "limpio" else NetworkManager.dinero_manchado
	if disponible < monto:
		confirm_casino_mensaje.rpc("Necesitas al menos %.0f de dinero %s para esa apuesta" % [monto, moneda])
		return
	var resultado := pelea.resolver_apuesta(eleccion)
	var gano: bool = resultado["gano"]
	var ganador: String = resultado["ganador"]
	var pago: float = resultado["pago"]
	var delta: float = (monto * pago) - monto if gano else -monto
	var nuevo_limpio: float = NetworkManager.dinero_limpio
	var nuevo_manchado: float = NetworkManager.dinero_manchado
	if moneda == "limpio":
		nuevo_limpio += delta
	else:
		nuevo_manchado += delta
	var peer_id := get_multiplayer_authority()
	var fichas_ganadas: float = FICHAS_POR_GANAR if gano else FICHAS_POR_PERDER
	var nuevas_fichas: float = NetworkManager.fichas.get(peer_id, 0.0) + fichas_ganadas
	confirm_apostar_pelea.rpc(nuevo_limpio, nuevo_manchado, moneda, eleccion, ganador, gano, monto, pago, pelea.nombre_izquierda, pelea.nombre_derecha, fichas_ganadas, nuevas_fichas)

@rpc("any_peer", "call_local", "reliable")
func confirm_apostar_pelea(nuevo_limpio: float, nuevo_manchado: float, moneda: String, eleccion: String, ganador: String, gano: bool, apuesta: float, pago: float, nombre_izq: String, nombre_der: String, fichas_ganadas: float, nuevas_fichas: float) -> void:
	NetworkManager.dinero_limpio = nuevo_limpio
	NetworkManager.dinero_manchado = nuevo_manchado
	var peer_id := get_multiplayer_authority()
	NetworkManager.fichas[peer_id] = nuevas_fichas
	var nombre_ganador := nombre_izq if ganador == "izquierda" else nombre_der
	var resultado_texto: String
	if gano:
		resultado_texto = "GANASTE +%.1f" % [(apuesta * pago) - apuesta]
	else:
		resultado_texto = "perdiste -%.1f" % apuesta
		NetworkManager.record_casino_perdidas[peer_id] = NetworkManager.record_casino_perdidas.get(peer_id, 0) + 1
	_status_label.text = "Pelea %s (apostaste %s, gano %s): %s (+%.0f fichas)" % [moneda, eleccion, nombre_ganador, resultado_texto, fichas_ganadas]
	_status_label.modulate = Color(0.4, 1, 0.4) if gano else Color(1, 0.4, 0.4)

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
	# Jardin de la Casa del equipo (H5 cierre): descuento fijo sobre el precio
	# de cualquier consumible, ver comentario de cabecera de casa_equipo.gd.
	if NetworkManager.casa_equipo_jardin_comprado:
		precio *= 1.0 - CasaEquipo.JARDIN_DESCUENTO_HERBORISTERIA
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
	var multiplicador: float = 1.0 + taberna.brindis_bonus_daño
	if NetworkManager.dinero_limpio < taberna.costo_brindis:
		# Pizarra de deudas (H6 extra): en vez de bloquear como el resto del
		# casino, la Taberna fia -- el brindis se activa igual y el costo
		# entero se apunta a NetworkManager.taberna_deuda_pendiente (deuda de
		# GRUPO, no del Usurero -- ver su comentario de cabecera).
		var nueva_deuda: float = NetworkManager.taberna_deuda_pendiente + taberna.costo_brindis
		NetworkManager.confirm_taberna_fiar.rpc(taberna.brindis_duracion, multiplicador, nueva_deuda)
		confirm_casino_mensaje.rpc("La Taberna fia esta ronda: +%.0f%% de daño para todo el grupo durante %.0f s (deuda del grupo: -%.0f)" % [taberna.brindis_bonus_daño * 100.0, taberna.brindis_duracion, nueva_deuda])
		return
	var nuevo_limpio: float = NetworkManager.dinero_limpio - taberna.costo_brindis
	NetworkManager.confirm_brindis.rpc(nuevo_limpio, taberna.brindis_duracion, multiplicador)
	confirm_casino_mensaje.rpc("Brindis en El Ancla Rota: +%.0f%% de daño para todo el grupo durante %.0f s" % [taberna.brindis_bonus_daño * 100.0, taberna.brindis_duracion])

func _request_taberna_ver_records() -> void:
	submit_taberna_ver_records.rpc_id(1)

## Lee la pizarra de records de la Taberna (H6 extra): solo texto, no muta
## ningun estado -- reutiliza confirm_casino_mensaje en vez de un confirm_
## propio (mismo criterio que el resto de mensajes informativos del casino).
## Calcula "quien va primero" en cada categoria sobre NetworkManager.
## record_casino_perdidas/record_cuerpos_destrozados (ver su comentario de
## cabecera para las definiciones elegidas y el hueco bloqueado de caidas).
@rpc("any_peer", "call_local", "reliable")
func submit_taberna_ver_records() -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	var taberna := _find_nearest_taberna_in_range(HUB_RANGE)
	if taberna == null:
		confirm_casino_mensaje.rpc("No hay ninguna taberna cerca")
		return
	var texto := "Pizarra de la Taberna -- "
	texto += "Mas perdidas en el casino: %s  |  " % _texto_lider_record(NetworkManager.record_casino_perdidas)
	texto += "Mas cuerpos destrozados: %s  |  " % _texto_lider_record(NetworkManager.record_cuerpos_destrozados)
	texto += "Mas caidas: (sin sistema de muerte/respawn todavia)"
	confirm_casino_mensaje.rpc(texto)

## Formatea "jugador <peer_id> (<n>)" para quien tenga el contador mas alto
## de un Dictionary peer_id -> int de la pizarra de records. "sin datos" si
## esta vacio (nadie ha hecho nada que cuente todavia).
func _texto_lider_record(record: Dictionary) -> String:
	if record.is_empty():
		return "sin datos"
	var lider_id: int = -1
	var lider_valor: int = -1
	for peer_id in record.keys():
		var valor: int = record[peer_id]
		if valor > lider_valor:
			lider_valor = valor
			lider_id = peer_id
	return "jugador %d (%d)" % [lider_id, lider_valor]

func _request_taberna_ver_desglose() -> void:
	submit_taberna_ver_desglose.rpc_id(1)

## Desglose de contribucion de la Taberna (plan-desarrollo.md, tarea
## reenganchada tras H6: dependia del concepto de mision completada, que ya
## existe desde el propio H5 en NetworkManager.misiones_completadas). Mismo
## patron que submit_taberna_ver_records de arriba (solo lectura, reutiliza
## confirm_casino_mensaje en vez de un confirm_ propio), pero en vez de
## enseñar solo "quien va primero" en una categoria, lista a CADA jugador
## con lo que ha metido al bote comun de dinero manchado
## (NetworkManager.taberna_aportado_manchado, ver su comentario de cabecera)
## y anade el contador de misiones del GRUPO entero -- las misiones no
## tienen "quien la completo" de forma individual, las trae todo el grupo
## junto al volver a extraccion (ver confirm_volver_hub), asi que ese dato
## se muestra compartido en vez de forzar una atribucion que no existe.
@rpc("any_peer", "call_local", "reliable")
func submit_taberna_ver_desglose() -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	var taberna := _find_nearest_taberna_in_range(HUB_RANGE)
	if taberna == null:
		confirm_casino_mensaje.rpc("No hay ninguna taberna cerca")
		return
	var texto := "Desglose de la Taberna -- "
	texto += "Aportado al bote (manchado) por jugador: %s  |  " % _texto_desglose_contribucion(NetworkManager.taberna_aportado_manchado)
	texto += "Misiones completadas por el grupo: %d" % NetworkManager.misiones_completadas
	confirm_casino_mensaje.rpc(texto)

## Formatea "jugador <peer_id> (<valor>)" para TODOS los peer_id de un
## Dictionary peer_id -> float, de mayor a menor aporte y separados por
## comas -- a diferencia de _texto_lider_record de arriba (que solo enseña
## al que va primero), esto es el desglose completo pedido en la tarea, uno
## por cada jugador que haya aportado algo. "sin datos" si esta vacio.
func _texto_desglose_contribucion(record: Dictionary) -> String:
	if record.is_empty():
		return "sin datos"
	var peer_ids: Array = record.keys()
	peer_ids.sort_custom(func(a, b): return record[a] > record[b])
	var partes: Array[String] = []
	for peer_id in peer_ids:
		partes.append("jugador %d (%.0f)" % [peer_id, record[peer_id]])
	return ", ".join(partes)

func _request_taberna_musica() -> void:
	submit_taberna_musica.rpc_id(1)

## Una sola tecla, una sola accion obvia (mismo criterio que
## submit_sastreria_tinte/submit_comprar_pergamino): si queda alguna
## cancion de taberna.canciones_disponibles sin comprar, compra la primera
## que encuentre (lista fija, cualquier orden sirve, ver comentario de
## cabecera de taberna.gd) y la deja sonando. Si ya estan todas compradas,
## cicla a la siguiente de la lista (con vuelta al principio) sin coste.
@rpc("any_peer", "call_local", "reliable")
func submit_taberna_musica() -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	var taberna := _find_nearest_taberna_in_range(HUB_RANGE)
	if taberna == null:
		confirm_casino_mensaje.rpc("No hay ninguna taberna cerca")
		return
	for cancion in taberna.canciones_disponibles:
		if not NetworkManager.taberna_canciones_compradas.get(cancion, false):
			if NetworkManager.dinero_limpio < taberna.costo_cancion:
				confirm_casino_mensaje.rpc("Necesitas %.0f de dinero limpio para comprar '%s'" % [taberna.costo_cancion, cancion])
				return
			var nuevo_limpio: float = NetworkManager.dinero_limpio - taberna.costo_cancion
			NetworkManager.confirm_taberna_musica.rpc(nuevo_limpio, cancion, true)
			confirm_casino_mensaje.rpc("Cancion comprada para la Taberna: '%s' (sonando ahora)" % cancion)
			return
	if taberna.canciones_disponibles.is_empty():
		return
	var indice_actual: int = taberna.canciones_disponibles.find(NetworkManager.taberna_cancion_actual)
	var siguiente: String = taberna.canciones_disponibles[(indice_actual + 1) % taberna.canciones_disponibles.size()]
	NetworkManager.confirm_taberna_musica.rpc(NetworkManager.dinero_limpio, siguiente, false)
	confirm_casino_mensaje.rpc("Ahora suena en la Taberna: '%s'" % siguiente)

## Sillas y emote (H6 extra): puramente cosmetico, sin impacto economico ni
## de combate -- por eso NO sigue el patron submit_/confirm_ mediado por el
## host del resto del kit (nada que validar, ni fondos que proteger de un
## cliente mentiroso). Broadcast directo call_local en vez: quien pulsa la
## tecla dispara el RPC en su propio nodo y todos los peers ven la misma
## pose (mismo NodePath -- ver confirm_someter_prisionero.rpc() para el mismo
## patron de broadcast directo sin pasar por el host). Sin estado
## persistente en NetworkManager (pedido explicito de la tarea):
## _sentado_taberna es una var local de ESTE nodo, se pierde si el jugador
## se desconecta/reconecta, no se guarda en ningun sitio.
var _sentado_taberna: bool = false

func _request_taberna_sentarse() -> void:
	if _find_nearest_silla_taberna_in_range(SILLA_RANGE) == null:
		return
	rpc_taberna_toggle_sentado.rpc()

## Pose simple sin arte (mismo criterio placeholder que el resto del
## vertical slice, ver CLAUDE.md "no producir arte final antes de cerrar
## H1"): encoge el sprite en vertical mientras esta sentado, recupera su
## tamaño normal al levantarse. Toggle: pulsar de nuevo junto a una silla
## se levanta.
@rpc("any_peer", "call_local", "reliable")
func rpc_taberna_toggle_sentado() -> void:
	_sentado_taberna = not _sentado_taberna
	var target_scale := Vector2(1.0, 0.7) if _sentado_taberna else Vector2(1.0, 1.0)
	var tween := create_tween()
	tween.tween_property(_visuals, "scale", target_scale, 0.15)

func _request_taberna_emote() -> void:
	if _find_nearest_taberna_in_range(HUB_RANGE) == null:
		return
	rpc_taberna_emote.rpc()

## Gesto generico momentaneo (no toggle, a diferencia de sentarse): un
## bamboleo simple de rotacion, mismo criterio de pose placeholder de arriba.
@rpc("any_peer", "call_local", "reliable")
func rpc_taberna_emote() -> void:
	var tween := create_tween()
	tween.tween_property(_visuals, "rotation", 0.3, 0.1)
	tween.tween_property(_visuals, "rotation", -0.3, 0.2)
	tween.tween_property(_visuals, "rotation", 0.0, 0.1)

# =========================================================================
# Sastreria (H5 cierre, Calle de los Faroles) -- tecla R. Cosmetico puro, sin
# bonus de ningun tipo (ver comentario de cabecera de sastreria.gd). Mismo
# patron submit_/confirm_ que Forja: individual por peer_id, pagado del pool
# compartido de dinero limpio.
# =========================================================================

func _request_sastreria_tinte() -> void:
	submit_sastreria_tinte.rpc_id(1)

## Cicla SIEMPRE al siguiente tinte de la paleta (con vuelta al principio) --
## mismo criterio de "una sola accion obvia por tecla" que el resto de la
## economia en este vertical slice sin UI real.
@rpc("any_peer", "call_local", "reliable")
func submit_sastreria_tinte() -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	var sastreria := _find_nearest_sastreria_in_range(HUB_RANGE)
	if sastreria == null:
		confirm_casino_mensaje.rpc("No hay ninguna sastreria cerca")
		return
	if NetworkManager.dinero_limpio < sastreria.precio_tinte:
		confirm_casino_mensaje.rpc("Necesitas %.0f de dinero limpio para cambiar de tinte" % sastreria.precio_tinte)
		return
	var peer_id := get_multiplayer_authority()
	var indice_actual: int = NetworkManager.sastreria_tinte_indice.get(peer_id, -1)
	var indice_nuevo := (indice_actual + 1) % Sastreria.PALETA_TINTES.size()
	var nuevo_limpio: float = NetworkManager.dinero_limpio - sastreria.precio_tinte
	confirm_sastreria_tinte.rpc(peer_id, indice_nuevo, nuevo_limpio)

@rpc("any_peer", "call_local", "reliable")
func confirm_sastreria_tinte(peer_id: int, indice: int, nuevo_limpio: float) -> void:
	NetworkManager.sastreria_tinte_indice[peer_id] = indice
	NetworkManager.dinero_limpio = nuevo_limpio
	_visuals.modulate = Sastreria.PALETA_TINTES[indice]
	_status_label.modulate = Color(1, 1, 1)
	_status_label.text = "Tinte cambiado"

# =========================================================================
# Tienda de Pergaminos (H6, Muelle Alto) -- tecla 0. Vende el desbloqueo
# permanente de la tecnica de Sellos de CADA estilo, una compra por estilo y
# por jugador. A diferencia de Forja/Sastreria (pool compartido de dinero
# limpio), aqui el gasto tambien es individual: paga con las FICHAS del
# propio jugador (NetworkManager.fichas), nunca del grupo -- ver comentario
# de cabecera de NetworkManager.fichas y tienda_pergaminos.gd.
# =========================================================================

func _request_comprar_pergamino() -> void:
	submit_comprar_pergamino.rpc_id(1)

## Compra SIEMPRE el pergamino del estilo actualmente equipado (style_data) --
## mismo criterio de "una sola accion obvia por tecla" que el resto de la
## economia en este vertical slice sin UI real. Si ya esta comprado para ese
## estilo, no hace nada (mensaje informativo, no penaliza).
@rpc("any_peer", "call_local", "reliable")
func submit_comprar_pergamino() -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	var tienda := _find_nearest_tienda_pergaminos_in_range(CASINO_RANGE)
	if tienda == null:
		confirm_casino_mensaje.rpc("No hay ninguna Tienda de Pergaminos cerca")
		return
	var peer_id := get_multiplayer_authority()
	var estilo_key: String = style_data.element_name
	var comprados: Dictionary = NetworkManager.pergaminos_sellos_comprados.get(peer_id, {})
	if comprados.get(estilo_key, false):
		confirm_casino_mensaje.rpc("Ya tienes el pergamino de %s" % style_data.style_name)
		return
	var fichas_actuales: float = NetworkManager.fichas.get(peer_id, 0.0)
	if fichas_actuales < tienda.precio_pergamino:
		confirm_casino_mensaje.rpc("Necesitas %.0f fichas para el pergamino de %s" % [tienda.precio_pergamino, style_data.style_name])
		return
	var nuevas_fichas: float = fichas_actuales - tienda.precio_pergamino
	confirm_comprar_pergamino.rpc(estilo_key, nuevas_fichas)

@rpc("any_peer", "call_local", "reliable")
func confirm_comprar_pergamino(estilo_key: String, nuevas_fichas: float) -> void:
	var peer_id := get_multiplayer_authority()
	var comprados: Dictionary = NetworkManager.pergaminos_sellos_comprados.get(peer_id, {})
	comprados[estilo_key] = true
	NetworkManager.pergaminos_sellos_comprados[peer_id] = comprados
	NetworkManager.fichas[peer_id] = nuevas_fichas
	_status_label.modulate = Color(1, 1, 1)
	_status_label.text = "Pergamino comprado: %s (%s)" % [style_data.style_name, style_data.sellos_technique_name]

# =========================================================================
# Misiones (H6) -- Tablon del Muelle (F1-F5 elige bioma) y extraccion al
# final de la mision (F6 vuelve al Hub). Mismo patron submit_/confirm_ que
# el resto del kit: el cliente pide, el host valida rango y estado, y la
# aplicacion real (instanciar/liberar la escena de mision) vive en
# NetworkManager porque afecta a TODOS los peers a la vez, no a un unico
# personaje -- mismo criterio que confirm_brindis/confirm_cocina de arriba.
# F14 (submit_abandonar_mision, mas abajo) es la salida de emergencia del
# Palomar (Casa del equipo): a diferencia de F6, no exige rango de
# extraccion ni jefe muerto -- ver casa_equipo.gd para el porque.
# =========================================================================

func _request_elegir_mision(bioma_id: String) -> void:
	submit_elegir_mision.rpc_id(1, bioma_id)

@rpc("any_peer", "call_local", "reliable")
func submit_elegir_mision(bioma_id: String) -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	if NetworkManager.mision_actual != "":
		return # ya hay una mision en marcha, ignorar
	if NetworkManager.interior_actual != "":
		return # dentro de un interior de tienda (scope nuevo H5+), no se puede iniciar mision -- en la practica ya es imposible por distancia (el Tablon solo existe en el Hub), guard explicito de todas formas por simetria con confirm_entrar_tienda
	if _find_nearest_tablon_in_range(HUB_RANGE) == null:
		return
	NetworkManager.confirm_iniciar_mision.rpc(bioma_id)

func _request_volver_hub() -> void:
	submit_volver_hub.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func submit_volver_hub() -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	if NetworkManager.mision_actual == "":
		return # no hay mision activa de la que volver
	if _find_nearest_extraccion_in_range(HUB_RANGE) == null:
		return
	if not get_tree().get_nodes_in_group(GRUPO_JEFE_MISION).is_empty():
		return # el jefe de la zona sigue vivo, no se puede extraer todavia
	NetworkManager.confirm_volver_hub.rpc()

func _request_abandonar_mision() -> void:
	submit_abandonar_mision.rpc_id(1)

## Palomar (Casa del equipo, brief 2.4): a diferencia de submit_volver_hub de
## arriba, esto NO exige estar en el rango de ExtraccionMision ni que el jefe
## de zona este muerto -- es justo lo que el Palomar habilita (ver comentario
## de cabecera de casa_equipo.gd para el punto de diseno verificado). Solo
## exige que el grupo ya haya comprado el Palomar y que haya una mision
## activa de la que salir.
@rpc("any_peer", "call_local", "reliable")
func submit_abandonar_mision() -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	if NetworkManager.mision_actual == "":
		return # no hay mision activa que rechazar
	if not NetworkManager.casa_equipo_palomar_comprado:
		return # sin Palomar, no existe la accion de rechazar una mision
	NetworkManager.confirm_abandonar_mision.rpc()
	confirm_casino_mensaje.rpc("Palomar: mision rechazada, todo el grupo vuelve a la Aldea")

# =========================================================================
# Interiores de tienda del Hub (scope nuevo H5+, ver plan-desarrollo.md
# seccion 2 "Interiores de tienda con fundido a negro" -- pedido explicito
# del usuario, no parte del diseno original): F11 entra por la puerta mas
# cercana (PuertaTienda), F12 sale por la salida del interior activo
# (SalidaTienda). Mismo patron submit_/confirm_ que Misiones justo arriba --
# el cliente pide, el host valida rango, y la aplicacion real (fundido a
# negro + instanciar/liberar la escena de interior) vive en NetworkManager
# porque afecta a TODOS los peers a la vez, no a un unico personaje.
# =========================================================================

func _request_entrar_tienda() -> void:
	var puerta := _find_nearest_puerta_tienda_in_range(HUB_RANGE)
	if puerta == null:
		return
	submit_entrar_tienda.rpc_id(1, puerta.tienda_id)

@rpc("any_peer", "call_local", "reliable")
func submit_entrar_tienda(tienda_id: String) -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	if NetworkManager.mision_actual != "" or NetworkManager.interior_actual != "":
		return
	var puerta := _find_nearest_puerta_tienda_in_range(HUB_RANGE)
	if puerta == null or puerta.tienda_id != tienda_id:
		return # el cliente no esta de verdad junto a esa puerta -- no confiar en el parametro a ciegas
	NetworkManager.confirm_entrar_tienda.rpc(tienda_id)

func _request_salir_tienda() -> void:
	submit_salir_tienda.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func submit_salir_tienda() -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	if NetworkManager.interior_actual == "":
		return
	if _find_nearest_salida_tienda_in_range(HUB_RANGE) == null:
		return
	NetworkManager.confirm_salir_tienda.rpc()

# =========================================================================
# Casa del equipo (H5 cierre, Terrazas) -- ; Cocina, [ Almacen, ] Jardin,
# F13 Palomar. A diferencia de Forja/Herboristeria/Sastreria (gasto
# compartido, resultado individual), aqui el resultado TAMBIEN es de grupo --
# mismo criterio que la Taberna. Ver comentario de cabecera de casa_equipo.gd
# para el porque de cada adaptacion (Cocina repetible vs. Almacen/Jardin/
# Palomar compra unica). La accion que el Palomar habilita de verdad
# (rechazar una mision en marcha) vive en submit_abandonar_mision, en la
# seccion de Misiones de mas arriba -- aqui solo esta la compra.
# =========================================================================

func _request_comprar_cocina() -> void:
	submit_comprar_cocina.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func submit_comprar_cocina() -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	var casa := _find_nearest_casa_equipo_in_range(HUB_RANGE)
	if casa == null:
		confirm_casino_mensaje.rpc("No hay ninguna casa del equipo cerca")
		return
	if NetworkManager.dinero_limpio < casa.precio_cocina:
		confirm_casino_mensaje.rpc("Necesitas %.0f de dinero limpio para la cocina" % casa.precio_cocina)
		return
	var nuevo_limpio: float = NetworkManager.dinero_limpio - casa.precio_cocina
	var reduccion: float = 1.0 - CasaEquipo.COCINA_REDUCCION_DAÑO
	NetworkManager.confirm_cocina.rpc(nuevo_limpio, CasaEquipo.COCINA_DURACION, reduccion)
	confirm_casino_mensaje.rpc("Cocina: -%.0f%% de daño recibido para todo el grupo durante %.0f s" % [CasaEquipo.COCINA_REDUCCION_DAÑO * 100.0, CasaEquipo.COCINA_DURACION])

func _request_comprar_almacen() -> void:
	submit_comprar_almacen.rpc_id(1)

## Compra unica y permanente (brief: "sin niveles") -- si el grupo ya lo
## compro, no se puede volver a pagar por lo mismo.
@rpc("any_peer", "call_local", "reliable")
func submit_comprar_almacen() -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	var casa := _find_nearest_casa_equipo_in_range(HUB_RANGE)
	if casa == null:
		confirm_casino_mensaje.rpc("No hay ninguna casa del equipo cerca")
		return
	if NetworkManager.casa_equipo_almacen_comprado:
		confirm_casino_mensaje.rpc("El Almacen ya esta comprado")
		return
	if NetworkManager.dinero_limpio < casa.precio_almacen:
		confirm_casino_mensaje.rpc("Necesitas %.0f de dinero limpio para el Almacen" % casa.precio_almacen)
		return
	var nuevo_limpio: float = NetworkManager.dinero_limpio - casa.precio_almacen
	NetworkManager.confirm_comprar_almacen.rpc(nuevo_limpio)
	confirm_casino_mensaje.rpc("Almacen comprado: +%d cadaveres cargados para todo el grupo" % CasaEquipo.ALMACEN_BONUS_CADAVERES)

func _request_comprar_jardin() -> void:
	submit_comprar_jardin.rpc_id(1)

## Compra unica y permanente, mismo criterio que el Almacen de arriba.
@rpc("any_peer", "call_local", "reliable")
func submit_comprar_jardin() -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	var casa := _find_nearest_casa_equipo_in_range(HUB_RANGE)
	if casa == null:
		confirm_casino_mensaje.rpc("No hay ninguna casa del equipo cerca")
		return
	if NetworkManager.casa_equipo_jardin_comprado:
		confirm_casino_mensaje.rpc("El Jardin ya esta comprado")
		return
	if NetworkManager.dinero_limpio < casa.precio_jardin:
		confirm_casino_mensaje.rpc("Necesitas %.0f de dinero limpio para el Jardin" % casa.precio_jardin)
		return
	var nuevo_limpio: float = NetworkManager.dinero_limpio - casa.precio_jardin
	NetworkManager.confirm_comprar_jardin.rpc(nuevo_limpio)
	confirm_casino_mensaje.rpc("Jardin comprado: -%.0f%% en los precios de la Herboristeria" % [CasaEquipo.JARDIN_DESCUENTO_HERBORISTERIA * 100.0])

func _request_comprar_palomar() -> void:
	submit_comprar_palomar.rpc_id(1)

## Palomar (brief 2.4: "permite rechazar una mision sin penalizacion").
## Compra unica y permanente, mismo criterio que Almacen/Jardin de arriba --
## ver comentario de cabecera de casa_equipo.gd para el punto de diseno
## verificado (hoy no hay penalizacion que quitar porque no hay forma de
## rechazar una mision en absoluto; el Palomar es lo que habilita esa accion,
## ver submit_abandonar_mision en la seccion de Misiones, mas arriba).
@rpc("any_peer", "call_local", "reliable")
func submit_comprar_palomar() -> void:
	if not multiplayer.is_server():
		return
	if not _validate_sender():
		return
	var casa := _find_nearest_casa_equipo_in_range(HUB_RANGE)
	if casa == null:
		confirm_casino_mensaje.rpc("No hay ninguna casa del equipo cerca")
		return
	if NetworkManager.casa_equipo_palomar_comprado:
		confirm_casino_mensaje.rpc("El Palomar ya esta comprado")
		return
	if NetworkManager.dinero_limpio < casa.precio_palomar:
		confirm_casino_mensaje.rpc("Necesitas %.0f de dinero limpio para el Palomar" % casa.precio_palomar)
		return
	var nuevo_limpio: float = NetworkManager.dinero_limpio - casa.precio_palomar
	NetworkManager.confirm_comprar_palomar.rpc(nuevo_limpio)
	confirm_casino_mensaje.rpc("Palomar comprado: el grupo ya puede rechazar una mision en marcha con F14")
