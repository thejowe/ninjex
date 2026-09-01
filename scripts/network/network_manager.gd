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
## Raiz donde EnemigoSimple instancia los cadaveres al morir (H2). Ver
## EnemigoSimple._spawn_cadaver().
var cadavers_root: Node = null
## Puntos de spawn de jugadores del mapa actual (Marker2D). Si esta vacio,
## los jugadores caen en (0,0) -- eso es lo que pasaba antes de fijar esto:
## (0,0) es la esquina de la sala de pruebas, la camara se centraba ahi y
## la mayor parte de la pantalla quedaba fuera de la sala (se veia vacio).
var spawn_points: Array[Node2D] = []

## H6: id del bioma activo ("costa"/"bambu"/"peaje"/"cantera"/"ruinas") o ""
## si estamos en el Hub. Solo lo muta el host, siempre dentro de
## confirm_iniciar_mision/confirm_volver_hub (mismo patron que el resto del
## autoload). player.gd lo consulta para no dejar abrir dos misiones a la vez
## ni volver al hub si no hay ninguna activa.
var mision_actual: String = ""
## H6 (narrativa de NPCs, brief 2.4 "Funcion acogedora"): cuantas misiones ha
## completado el grupo en total. Solo lo muta el host, incrementado dentro de
## confirm_volver_hub() -- mismo patron host-autoritativo que mision_actual.
## confirm_volver_hub() solo se llama tras matar al jefe de zona y llegar al
## punto de extraccion (ver player.gd submit_volver_hub), asi que cada
## llamada es una vuelta CON EXITO -- no hace falta distinguir derrota, el
## juego todavia no tiene ese concepto. Los NPCs fijos de la Taberna,
## Terrazas y Muelle (tabernera.gd/viejo_maestro.gd/pescador.gd) lo leen para
## elegir su linea de dialogo.
var misiones_completadas: int = 0
## Contenedor donde se instancia la escena de mision activa -- asignado por
## main.gd en _ready() (nodo "Misiones", hermano de Hub/TestRoom, colocado
## lejos en el mundo para que sus paredes nunca se solapen con las del Hub).
var mission_root: Node = null
## Puntos de spawn del Hub (Muelle) -- asignados por main.gd en _ready().
## Se usan para reponer spawn_points al volver de una mision cuando no habia
## spawn_points previos guardados (primera vez que se entra a una mision).
var hub_spawn_points: Array[Node2D] = []
## spawn_points de antes de entrar en la mision activa, para restaurarlos tal
## cual al volver (evita asumir que siempre se vuelve al Hub -- si en el
## futuro hay misiones encadenadas, esto ya lo contempla).
var _spawn_points_previos: Array[Node2D] = []

## H6: escena de cada bioma, instanciada bajo mission_root al elegir en el
## Tablon de misiones (ver TablonMisiones / player.gd submit_elegir_mision).
## Todas comparten estructura (3 areas + PuertaMision + ExtraccionMision),
## solo cambian ambientacion y estadisticas de EnemigoSimple -- ver cada
## escena para el detalle.
const MISIONES: Dictionary = {
	"costa": preload("res://scenes/world/mision_costa/mision_costa.tscn"),
	"bambu": preload("res://scenes/world/mision_bambu/mision_bambu.tscn"),
	"peaje": preload("res://scenes/world/mision_peaje/mision_peaje.tscn"),
	"cantera": preload("res://scenes/world/mision_cantera/mision_cantera.tscn"),
	"ruinas": preload("res://scenes/world/mision_ruinas/mision_ruinas.tscn"),
}

## Dinero "manchado" (H2): pool compartido entre todos los jugadores desde
## ya -- la votacion de boveda es H4, no esta implementada, pero no pasa
## nada por que el pool ya sea unico ahora mismo. Solo lo muta el host,
## siempre desde dentro de un RPC call_local (player.gd confirm_vender),
## asi que el valor llega igual a todos los peers sin necesitar su propio
## RPC de replicacion.
var dinero_manchado: float = 0.0

## Dinero "limpio" (H3): mismo patron de pool compartido que dinero_manchado
## de arriba -- se llena cambiando manchado en el Cambista (comision 15%,
## ver cambista.gd) y se apuesta en la Mesa de Dados (ver mesa_dados.gd).
## Solo lo muta el host, siempre desde dentro de un RPC call_local
## (player.gd confirm_cambiar_dinero / confirm_apostar_dados).
var dinero_limpio: float = 0.0

## Deuda con el Usurero (H4 recortado a solo el Usurero -- decision del
## usuario, sin votacion ni Modo Mesa Alta; ver usurero.gd para el trigger).
## Importe REAL pendiente de pagar (monto del prestamo + interes), no un
## contador de transacciones -- se muestra en negativo en el HUD (pedido
## explicito del usuario: "que salga el dinero en negativo") y baja con
## cada transaccion que genera dinero (venta exitosa o apuesta ganada)
## hasta llegar a 0. Solo lo muta el host, siempre desde dentro de un RPC
## call_local (player.gd confirm_pedir_prestamo_usurero/confirm_vender/
## confirm_apostar_dados), mismo patron que dinero_manchado/dinero_limpio.
var usurero_deuda_pendiente: float = 0.0

## Porcentaje de recorte vigente para la deuda activa de arriba, copiado del
## Usurero.recorte_porcentaje del nodo con el que se pidio el prestamo en el
## momento de pedirlo -- asi las transacciones que lo pagan despues no
## necesitan estar cerca de ningun Usurero ni volver a consultar el nodo.
var usurero_deuda_recorte_porcentaje: float = 0.0

## Contador de ids de cadaver, solo lo incrementa el host (siempre desde
## EnemigoSimple.recibir_daño(), que ya esta filtrado por
## is_multiplayer_authority()). El id resultante viaja como argumento del
## RPC morir() para que todos los peers instancien el cadaver con el mismo
## nombre de nodo -- sin esto no seria direccionable por NodePath despues.
var _next_cadaver_id: int = 1

func next_cadaver_id() -> int:
	_next_cadaver_id += 1
	return _next_cadaver_id - 1

## Nivel de Forja (H5 tarea 2) de CADA jugador -- peer_id -> nivel (0-3).
## A diferencia de dinero_manchado/dinero_limpio (pools compartidos), esto es
## POR JUGADOR: cada peer_id mejora su propia arma con dinero limpio del pool
## compartido. Sin entrada en el Dictionary == nivel 0 (sin mejorar). Solo lo
## muta el host, siempre desde dentro de un RPC call_local
## (player.gd confirm_mejorar_forja), mismo patron que el resto de estado
## compartido. Player._current_damage_multiplier() lo lee cada vez que
## calcula daño real.
var forja_nivel: Dictionary = {}

## Tinte de Sastreria (H5 cierre) de CADA jugador -- peer_id -> indice sobre
## Sastreria.PALETA_TINTES. Mismo patron POR JUGADOR que forja_nivel de
## arriba: cada peer_id elige su propio tinte con dinero limpio del pool
## compartido. Sin entrada == sin tinte (color base normal del estilo). Solo
## lo muta el host, siempre desde dentro de un RPC call_local (player.gd
## confirm_sastreria_tinte).
var sastreria_tinte_indice: Dictionary = {}

## Fichas (H6 casino, brief "Tres monedas": "solo se ganan jugando, compran
## pergaminos") de CADA jugador -- peer_id -> cantidad. A DIFERENCIA de
## dinero_manchado/dinero_limpio (pools COMPARTIDOS) y aunque el patron
## Dictionary peer_id->valor es el mismo que forja_nivel/sastreria_tinte_indice
## de arriba, las fichas son individuales POR DEFINICION DEL BRIEF: cada
## jugador gasta las suyas propias en la Tienda de Pergaminos, no un pool de
## grupo. Sin entrada == 0.0 (nadie empieza con fichas). Solo lo mutan los
## confirm_* de player.gd que resuelven un juego de casino (ver
## confirm_apostar_dados/confirm_girar_ruleta/confirm_jugar_cartas/
## confirm_apostar_pelea) y confirm_comprar_pergamino (que las resta), mismo
## criterio del resto de este autoload: el host calcula, el RPC call_local
## aplica el mismo valor en todos los peers.
##
## Regla invariante critica (brief seccion 4): las fichas NUNCA se convierten
## desde/hacia dinero_limpio/dinero_manchado, ni directa ni indirectamente.
## Ningun submit_*/confirm_* debe leer fichas y escribir dinero_limpio o
## dinero_manchado (o viceversa) en la misma operacion.
var fichas: Dictionary = {}

## Pergaminos de Sellos comprados (H6 casino) -- peer_id -> Dictionary
## {element_name: String -> bool}. Cada estilo (StyleData.element_name:
## "fuego"/"viento"/"agua"/"tierra"/"rayo"/"fisico") tiene su propia tecnica
## de Sellos (ver style_data.gd grupo "Sellos") y su propio desbloqueo
## independiente -- comprar el pergamino de Fuego no desbloquea el de Rayo.
## Compra UNICA y PERMANENTE por jugador y por estilo (igual que
## casa_equipo_almacen_comprado es unica y permanente para el grupo, pero
## aqui es por peer_id, no de grupo). Sin entrada para un estilo == no
## comprado. Solo lo muta el host, siempre desde dentro de
## player.gd confirm_comprar_pergamino. player.gd submit_sellos_technique lo
## consulta para decidir si la tecnica de Sellos in-combate se ejecuta o no.
var pergaminos_sellos_comprados: Dictionary = {}

## Medidor de sospecha (H6 casino, brief 2.3 / diseno "El casino") -- POR
## JUGADOR, no compartido como los pools de dinero: "te vigilan a ti", no al
## grupo. Mismo patron que forja_nivel de arriba: Dictionary peer_id ->
## nivel (0-100), sin entrada == 0 (nadie mira). Solo lo mutan los confirm_*
## de player.gd que resuelven una trampa (ver submit_apostar_dados /
## submit_jugar_cartas), siempre con el valor ya calculado por el host,
## mismo criterio que el resto del estado compartido de este autoload.
var sospecha_nivel: Dictionary = {}
const SOSPECHA_MAX := 100.0
## Tramo AMBAR (brief: "un vigilante te sigue, las trampas cuestan el doble
## de chakra" -- ver el *2.0 en los costes de trampa de player.gd).
const SOSPECHA_AMBAR_UMBRAL := 40.0
## Tramo ROJO (brief: "expulsion tres dias de juego, sin cambista ni
## pergaminos"). Al cruzar este umbral se dispara la expulsion de abajo y el
## nivel se resetea a 0 -- el castigo ya se ha "cobrado", no hace falta
## seguir acumulando encima mientras se cumple la expulsion.
const SOSPECHA_ROJO_UMBRAL := 100.0
## Baja lentamente con el tiempo jugando limpio (brief) -- decae en
## _process de este autoload igual que brindis_time_remaining de abajo: no
## hace falta que el segundo exacto coincida entre peers (mismo motivo que
## el comentario de brindis_time_remaining), la autoridad real es el valor
## que lee el HOST dentro de cada submit_ que valida una trampa.
const SOSPECHA_DECAY_POR_SEGUNDO := 1.5

## Segundos restantes de expulsion (tramo rojo) por peer_id -- 0/sin entrada
## = no expulsado. Mientras > 0, player.gd submit_cambiar_dinero rechaza la
## peticion (brief: "sin cambista"; los pergaminos no existen todavia, ver
## alcance de la tarea, asi que no hay nada mas que bloquear).
var sospecha_expulsado_restante: Dictionary = {}
## Adaptacion de "expulsion tres dias de juego" (brief 2.3): el vertical
## slice no tiene el concepto de "dia de juego" todavia -- misma situacion
## que resolvio usurero.gd adaptando "5 misiones" a un importe real (ver su
## comentario de cabecera), aqui se adapta a un temporizador de sesion real,
## reutilizando el mismo mecanismo que ya existe para el brindis de Taberna
## (brindis_time_remaining), solo que penaliza en vez de bufar. 1 "dia" = 60s
## de sesion real; revisar esta adaptacion si el juego llega a tener un
## ciclo dia/noche real.
const SOSPECHA_SEGUNDOS_POR_DIA := 60.0
const SOSPECHA_DIAS_EXPULSION := 3.0

## Tramo actual de sospecha de un jugador ("verde"/"ambar"/"rojo"). Lo
## consulta player.gd tanto para decidir si duplicar el coste de chakra de
## una trampa (ambar) como para bloquear el cambista (rojo).
func sospecha_tramo(peer_id: int) -> String:
	if sospecha_expulsado_restante.get(peer_id, 0.0) > 0.0:
		return "rojo"
	if sospecha_nivel.get(peer_id, 0.0) >= SOSPECHA_AMBAR_UMBRAL:
		return "ambar"
	return "verde"

## Brindis de la Taberna (H5 tarea 4): buff de GRUPO temporal, activo para
## TODOS los jugadores conectados mientras dure -- Player._current_damage_multiplier()
## multiplica por brindis_damage_multiplier sin importar quien pago la ronda
## (brief seccion 4: "los bonus de comida y casa se aplican a todo el grupo,
## no solo a quien pago"). Arranca via el RPC call_local de Taberna (ver
## player.gd submit_brindis/confirm_brindis mas abajo); el contador en si se
## decrementa localmente en cada peer via _process() de este autoload -- no
## hace falta que el segundo exacto en que expira coincida entre peers, es
## un buff temporal de sabor, no un recurso compartido que se pueda gastar
## mal si diverge un frame.
var brindis_time_remaining: float = 0.0
var brindis_damage_multiplier: float = 1.0

## Pizarra de deudas de la Taberna (H6 extra, ver comentario de cabecera de
## taberna.gd): a diferencia de usurero_deuda_pendiente (prestamo pedido a
## proposito en el Usurero), esta deuda nace de FIAR una ronda -- el grupo
## pide un brindis sin dinero limpio suficiente y la Taberna lo sirve igual,
## apuntando costo_brindis entero a esta cuenta compartida en vez de
## bloquear la accion (mismo patron confirm_casino_mensaje que usa el resto
## del casino). Deliberadamente SIN mecanismo de pago automatico (a
## diferencia del recorte del Usurero sobre ventas/apuestas): la tarea solo
## pide fiar + mostrar la deuda en el HUD, no un sistema de cobro -- pagar
## esta cuenta queda fuera de alcance hasta que se pida explicitamente. Solo
## lo muta el host, siempre desde dentro de confirm_taberna_fiar (ver
## player.gd submit_brindis), mismo patron que usurero_deuda_pendiente.
var taberna_deuda_pendiente: float = 0.0

## Pizarra de records de la Taberna (H6 extra) -- POR JUGADOR, mismo patron
## Dictionary peer_id -> int que forja_nivel/sastreria_tinte_indice. Sin
## entrada == 0. Solo los mutan los confirm_* que ya existian para cada
## juego (ver player.gd confirm_apostar_dados/confirm_girar_ruleta/
## confirm_jugar_cartas/confirm_apostar_pelea cuando gano == false); esta
## pizarra no añade ningun submit_/confirm_ propio para incrementarse, solo
## lee/engancha en los que ya estan.
##
## "Quien ha caido mas veces" (brief H5 taberna, pizarra de records) queda
## BLOQUEADO igual que otros huecos ya documentados (ver Palomar/Sellos-en-
## Cartas): no existe sistema de muerte/respawn de jugador todavia (ver
## comentario de cabecera de player.gd sobre vida_actual, "no incluye muerte
## ni respawn de jugador"). No hay contador para esto.
var record_casino_perdidas: Dictionary = {}

## "Quien ha destrozado mas cuerpos" (pizarra de records). Definicion
## elegida para esta tarea (el brief deja el criterio abierto): un cadaver
## vendido al Carnicero (ver comprador.gd Tipo.CARNICERO) cuenta como
## "destrozado" -- el Carnicero es el "suelo garantizado" que paga precio
## fijo IGNORANDO el tipo de daño con el que murio el enemigo (a diferencia
## del Boticario, que paga mas por cuerpos frescos/cortante-veneno), asi que
## venderle ahi es tratar el cuerpo sin ningun cuidado por como quedo. Mismo
## patron Dictionary peer_id -> int que record_casino_perdidas de arriba.
## Solo lo muta player.gd confirm_vender.
var record_cuerpos_destrozados: Dictionary = {}

## Desglose de contribucion de la Taberna (plan-desarrollo.md: "quedo
## bloqueado en H5 por falta del concepto de mision -- ya existe, se puede
## reenganchar"). Cuanto dinero MANCHADO ha metido cada jugador al bote
## comun vendiendo cadaveres/prisioneros -- mismo patron Dictionary
## peer_id -> valor que record_casino_perdidas/record_cuerpos_destrozados de
## arriba (float en vez de int porque esto es dinero, no un contador de
## sucesos). Sin entrada == 0. Solo lo muta player.gd confirm_vender,
## sumando precio_ganado (el importe que de verdad entra en dinero_manchado
## en esa venta, ya con el recorte del Usurero aplicado si tocaba) al mismo
## peer_id que ese metodo ya calculaba para record_cuerpos_destrozados -- no
## es tracking nuevo de "quien vendio", es el mismo dato reutilizado.
##
## No incluye dinero_limpio (Cambista/premios de casino): esos ingresos no
## tienen un "vendedor" analogo de forma natural en el codigo actual, y las
## misiones tampoco tienen atribucion individual (las completa el grupo
## entero al volver a extraccion, ver confirm_volver_hub) -- por eso el
## desglose de la Taberna (player.gd submit_taberna_ver_desglose) muestra
## misiones_completadas como dato COMPARTIDO del grupo en vez de forzar una
## atribucion por jugador que no existe.
var taberna_aportado_manchado: Dictionary = {}

## Musica diegetica de la Taberna (H6 extra, ver comentario de cabecera de
## taberna.gd) -- lista FIJA comprable en cualquier orden, compra UNICA y
## PERMANENTE de GRUPO (no por jugador, mismo criterio que
## casa_equipo_almacen_comprado): song name -> bool. Sin entrada == no
## comprada. Solo lo muta el host, siempre desde confirm_taberna_musica.
var taberna_canciones_compradas: Dictionary = {}
## Cancion sonando ahora mismo, o "" si no suena ninguna. Solo puede ser una
## ya comprada (ver taberna_canciones_compradas de arriba) -- puramente de
## sabor, no hay reproduccion de audio real todavia (sin arte/assets antes
## de cerrar H1, ver CLAUDE.md), asi que esto es el "que cancion esta
## activa" que se muestra en el HUD/mensajes, no un AudioStreamPlayer.
var taberna_cancion_actual: String = ""

## Cocina de la Casa del equipo (H5 cierre, Terrazas): mismo patron que
## brindis_time_remaining/brindis_damage_multiplier de arriba -- buff de
## GRUPO temporal, activo para TODOS los jugadores conectados, decae
## localmente en cada peer via _process() de este autoload (mismo criterio:
## no hace falta que el segundo exacto de expiracion coincida entre peers).
## A diferencia del brindis (multiplica el daño que HACES), este reduce el
## daño que RECIBES -- ver player.gd confirm_damage_taken.
var cocina_time_remaining: float = 0.0
var cocina_damage_reduction_multiplier: float = 1.0

## Almacen y Jardin de la Casa del equipo (H5 cierre): compras UNICAS y
## PERMANENTES del grupo entero (a diferencia de forja_nivel/sastreria_tinte_indice
## de arriba, que son Dictionary por peer_id, esto es un bool compartido --
## no hay "quien lo compro", beneficia a todo el grupo por igual, ver
## comentario de cabecera de casa_equipo.gd). Solo los muta el host, siempre
## desde dentro de un RPC call_local (player.gd confirm_comprar_almacen /
## confirm_comprar_jardin).
var casa_equipo_almacen_comprado: bool = false
var casa_equipo_jardin_comprado: bool = false

func _process(delta: float) -> void:
	if brindis_time_remaining > 0.0:
		brindis_time_remaining -= delta
		if brindis_time_remaining <= 0.0:
			brindis_time_remaining = 0.0
			brindis_damage_multiplier = 1.0
	if cocina_time_remaining > 0.0:
		cocina_time_remaining -= delta
		if cocina_time_remaining <= 0.0:
			cocina_time_remaining = 0.0
			cocina_damage_reduction_multiplier = 1.0
	# Decae la sospecha de cada jugador -- mismo criterio de "no hace falta
	# que coincida al frame exacto entre peers" que el brindis de arriba.
	for peer_id in sospecha_expulsado_restante.keys():
		var restante: float = sospecha_expulsado_restante[peer_id]
		if restante > 0.0:
			sospecha_expulsado_restante[peer_id] = max(0.0, restante - delta)
	for peer_id in sospecha_nivel.keys():
		if sospecha_expulsado_restante.get(peer_id, 0.0) > 0.0:
			continue # en tramo rojo el nivel ya esta a 0, nada que decaer
		var nivel: float = sospecha_nivel[peer_id]
		if nivel > 0.0:
			sospecha_nivel[peer_id] = max(0.0, nivel - SOSPECHA_DECAY_POR_SEGUNDO * delta)

## Confirma el brindis igual en todos los peers: descuenta el coste del pool
## compartido de dinero limpio y activa el buff de grupo. Vive aqui (en el
## autoload, no en player.gd) porque afecta a TODOS los jugadores conectados
## a la vez, no a un unico personaje -- a diferencia del resto de
## confirm_*() de esta tanda (Forja/Herboristeria), que son mejoras
## individuales y por eso viven en player.gd. Lo llama el host desde
## player.gd submit_brindis(), nunca el cliente directamente (mismo patron
## de confianza que el resto de confirm_* del proyecto: solo el submit_ que
## lo precede esta filtrado por multiplayer.is_server()+_validate_sender()).
@rpc("any_peer", "call_local", "reliable")
func confirm_brindis(nuevo_limpio: float, duracion: float, multiplicador: float) -> void:
	dinero_limpio = nuevo_limpio
	brindis_time_remaining = duracion
	brindis_damage_multiplier = multiplicador

## Confirma el brindis FIADO igual en todos los peers -- rama nueva de
## submit_brindis para cuando no hay dinero limpio suficiente (ver
## taberna_deuda_pendiente arriba). A diferencia de confirm_brindis, NO
## toca dinero_limpio: el costo entero se apunta a la deuda compartida en
## vez de salir del pool.
@rpc("any_peer", "call_local", "reliable")
func confirm_taberna_fiar(duracion: float, multiplicador: float, nueva_deuda: float) -> void:
	brindis_time_remaining = duracion
	brindis_damage_multiplier = multiplicador
	taberna_deuda_pendiente = nueva_deuda

## Confirma la musica de la Taberna igual en todos los peers -- una sola
## tecla, una sola accion obvia (mismo criterio que sastreria_tinte/
## comprar_pergamino): si `comprada` es true, esta es una compra nueva
## (nuevo_limpio ya viene descontado); si es false, solo se esta ciclando a
## una cancion ya comprada (nuevo_limpio llega sin cambios). Ver
## player.gd submit_taberna_musica.
@rpc("any_peer", "call_local", "reliable")
func confirm_taberna_musica(nuevo_limpio: float, cancion: String, comprada: bool) -> void:
	dinero_limpio = nuevo_limpio
	if comprada:
		taberna_canciones_compradas[cancion] = true
	taberna_cancion_actual = cancion

## Confirma la Cocina de la Casa del equipo igual en todos los peers. Vive
## aqui por el mismo motivo que confirm_brindis de arriba: afecta a TODOS
## los jugadores conectados, no a un unico personaje. Lo llama el host desde
## player.gd submit_comprar_cocina().
@rpc("any_peer", "call_local", "reliable")
func confirm_cocina(nuevo_limpio: float, duracion: float, reduccion_multiplicador: float) -> void:
	dinero_limpio = nuevo_limpio
	cocina_time_remaining = duracion
	cocina_damage_reduction_multiplier = reduccion_multiplicador

## Confirma la compra unica y permanente de Almacen/Jardin igual en todos los
## peers. Separados de confirm_cocina porque no llevan duracion ni pool de
## dinero variable en el momento del disparo -- solo activan el flag una vez.
@rpc("any_peer", "call_local", "reliable")
func confirm_comprar_almacen(nuevo_limpio: float) -> void:
	dinero_limpio = nuevo_limpio
	casa_equipo_almacen_comprado = true

@rpc("any_peer", "call_local", "reliable")
func confirm_comprar_jardin(nuevo_limpio: float) -> void:
	dinero_limpio = nuevo_limpio
	casa_equipo_jardin_comprado = true

## Estilo elegido por cada peer en la pantalla de eleccion previa al spawn
## (H6, ver scripts/ui/seleccion_estilo.gd) -- guardado como el path del
## recurso .tres. Sin entrada == ese peer aun no ha elegido, todavia no se
## spawnea (ver submit_style_choice). Solo lo muta el host.
var style_choice: Dictionary = {}

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
	# El spawn del host (peer 1) ya NO ocurre aqui (H6): espera a que main.gd
	# termine el prologo + pantalla de eleccion de estilo y mande
	# submit_style_choice, igual que cualquier otro peer.

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
	# No se spawnea aqui: el spawn real lo dispara submit_style_choice en
	# cuanto este cliente elige estilo y confirma la conexion (ver main.gd).

func _on_peer_connected(_id: int) -> void:
	pass # el spawn ya no depende de la conexion, ver submit_style_choice.

func _on_peer_disconnected(id: int) -> void:
	style_choice.erase(id)
	if players_root == null:
		return
	var node := players_root.get_node_or_null(str(id))
	if node != null:
		node.queue_free()

## Pedido por cada peer (host incluido) en cuanto termina la pantalla de
## eleccion de estilo y la conexion esta lista (ver main.gd _run_intro_flow).
## Mismo patron any_peer+call_local+validacion por sender_id que el resto de
## submit_* de player.gd, pero vive aqui porque este RPC ocurre ANTES de que
## exista ningun nodo Player al que atar la autoridad.
@rpc("any_peer", "call_local", "reliable")
func submit_style_choice(style_path: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id() # llamada local del propio host
	if style_choice.has(sender_id):
		return # ya eligio antes (RPC duplicado o reconexion), no re-spawnear
	style_choice[sender_id] = style_path
	_spawn_player(sender_id, style_path)

func _spawn_player(id: int, style_path: String = "") -> void:
	if players_root == null:
		push_warning("NetworkManager: players_root no asignado todavia, no se puede spawnear peer %d" % id)
		return
	if players_root.has_node(str(id)):
		return
	var player_scene: PackedScene = preload("res://scenes/player/player.tscn")
	var player := player_scene.instantiate()
	player.name = str(id)
	# Se asigna ANTES de add_child: el _ready() del jugador (que decide el
	# estilo por defecto si style_data es null) se dispara en cuanto entra al
	# arbol, asi que tiene que estar puesto antes.
	if style_path != "":
		player.style_data = load(style_path)
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

# =========================================================================
# Misiones (H6) -- cambio de escena Hub <-> bioma. Decision de arquitectura:
# la escena de mision se instancia/desinstancia como hijo de mission_root
# (un Node2D vacio, hermano de Hub/TestRoom en main.tscn, colocado lejos en
# el mundo) en vez de SceneTree.change_scene_to_packed. Motivo: Hub/TestRoom
# ya conviven siempre como hijos permanentes de Main (ver main.gd), y todo el
# estado de red (players_root, cadavers_root, NetworkManager entero) vive en
# ese mismo arbol -- cambiar de escena de verdad obligaria a reconectar todo
# eso. Instanciar/desinstanciar es el equivalente minimo que ya encaja con
# esa arquitectura. El host decide cuando se cambia (submit_elegir_mision/
# submit_volver_hub en player.gd, filtrados por multiplayer.is_server()) y lo
# replica a todos los peers con un RPC call_local reliable, igual que el
# resto del autoload.
# =========================================================================

## Confirma el inicio de mision igual en todos los peers: instancia la
## escena del bioma, reasigna spawn_points a sus marcadores y reposiciona a
## los jugadores ya conectados. Lo llama el host desde
## player.gd submit_elegir_mision(); nunca el cliente directamente.
@rpc("any_peer", "call_local", "reliable")
func confirm_iniciar_mision(bioma_id: String) -> void:
	if mision_actual != "":
		return # ya hay una mision activa, ignorar peticion duplicada
	if not MISIONES.has(bioma_id):
		return
	if mission_root == null:
		push_warning("NetworkManager: mission_root no asignado, no se puede iniciar la mision")
		return
	_spawn_points_previos = spawn_points.duplicate()
	var instancia: Node = MISIONES[bioma_id].instantiate()
	mission_root.add_child(instancia)
	var nuevos: Array[Node2D] = []
	nuevos.assign(instancia.get_node("PlayerSpawns").get_children())
	spawn_points = nuevos
	mision_actual = bioma_id
	_reposicionar_jugadores()

## Confirma la vuelta al Hub igual en todos los peers: libera la escena de
## mision activa y restaura los spawn_points de antes de entrar (los del Hub
## la primera vez). Lo llama el host desde player.gd submit_volver_hub().
@rpc("any_peer", "call_local", "reliable")
func confirm_volver_hub() -> void:
	if mision_actual == "":
		return # no hay mision activa de la que volver
	if mission_root != null:
		for hijo in mission_root.get_children():
			hijo.queue_free()
	spawn_points = _spawn_points_previos if not _spawn_points_previos.is_empty() else hub_spawn_points.duplicate()
	mision_actual = ""
	misiones_completadas += 1
	_reposicionar_jugadores()

## Manda a cada jugador ya conectado al spawn_point que le toca segun su
## peer_id, mismo calculo que _spawn_position_for usa para jugadores nuevos
## -- asi entrar/salir de una mision reposiciona a todo el grupo de golpe en
## vez de dejarlos flotando en las coordenadas de la escena anterior.
func _reposicionar_jugadores() -> void:
	if players_root == null:
		return
	for jugador in players_root.get_children():
		var id := int(jugador.name)
		jugador.global_position = _spawn_position_for(id)
