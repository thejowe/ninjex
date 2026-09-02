extends Node
## Autoload (singleton "NetworkManager"). Arquitectura de red minima para H1:
## host-autoritativo desde el primer commit.
##
## Esta tanda solo se hace playtest con UN peer conectado como host, pero la
## arquitectura ya contempla un segundo actor: cualquier peer que se conecte
## a este servidor se spawnea automaticamente igual que el host.
##
## TRANSPORTE: Steam P2P via GodotSteam GDExtension (addons/godotsteam/),
## NO ENet/IP directa -- decision del usuario. host_game() crea un lobby de
## Steam (Steam.createLobby) y join_game() se une a uno por su id de lobby
## (Steam.joinLobby), no por IP. El MultiplayerPeer real es SteamMultiplayerPeer
## (ver _on_lobby_created/_on_lobby_joined mas abajo), que Godot trata como
## cualquier otro MultiplayerPeer -- todo el patron host-autoritativo
## submit_/confirm_ del resto de este archivo es AJENO al transporte y no
## cambia. App ID: 480 (Spacewar, de test de Valve) -- ver steam_appid.txt en
## la raiz del repo; no hay App ID propio todavia, se cambiara mas adelante
## tocando solo ese archivo, no este script.
##
## LIMITACION DE TESTEO: Steam P2P requiere el cliente de Steam abierto y
## logueado en cada maquina. Probar con DOS INSTANCIAS EN EL MISMO PC bajo la
## MISMA cuenta de Steam NO simula dos jugadores reales -- Steam identifica al
## peer por SteamID de cuenta, asi que las dos instancias comparten identidad
## (y ademas Steam suele bloquear el overlay/lobby en la segunda instancia).
## Para un playtest de verdad hacen falta dos cuentas de Steam distintas (dos
## PCs, o un familiar/Family Sharing en la misma LAN). Ver resumen final del
## agente de red para alternativas de test recomendadas.

const MAX_PLAYERS := 4 # tope de diseno del juego completo (2-4 jugadores)
## App ID de Steam usado para steamInit/steam_appid.txt -- 480 es Spacewar,
## el juego de pruebas de Valve. Intencional: no hay App ID propio todavia
## (ver comentario de cabecera). NO se referencia desde steam_appid.txt (ese
## archivo lo lee el propio SDK de Steam antes de que corra ningun script),
## pero se pasa tambien aqui a steamInitEx como cinturon y tirantes: si algun
## dia steam_appid.txt se borra sin querer (Valve recomienda no incluirlo en
## el build final), la inicializacion sigue funcionando igual.
const STEAM_APP_ID := 480

## True si Steam.steamInitEx() se completo con exito en _ready(). host_game/
## join_game comprueban esto antes de tocar la API de Steam -- sin esto,
## Steam.createLobby()/joinLobby() explotarian o se quedarian colgados sin
## dar ningun callback si el cliente de Steam no esta corriendo. Tambien deja
## que la verificacion headless del proyecto (sin cliente de Steam abierto)
## cargue el autoload sin crashear.
var steam_initialized: bool = false

## Id del lobby de Steam activo, 0 si no hay ninguno. Puesto por
## _on_lobby_created (host) o _on_lobby_joined (cliente); usado por
## invite_friends() (overlay de invitacion) y disconnect_game() (para salir
## del lobby de Steam, no solo cerrar el MultiplayerPeer).
var steam_lobby_id: int = 0

## Emitida cuando el MultiplayerPeer de Steam ya esta activo y listo (host tras
## _on_lobby_created, cliente tras _on_lobby_joined) -- lobby.gd espera esta
## señal en vez de asumir que host_game()/join_game() conectan de forma
## sincrona como hacia ENet: crear/unirse a un lobby de Steam es asincrono
## (round-trip contra los servidores de Steam), a diferencia de
## ENetMultiplayerPeer.create_server()/create_client(), que devolvian el
## resultado al instante.
signal lobby_ready(is_host: bool)

## Emitida si Steam.createLobby()/joinLobby() fallan (red, lobby llena,
## lobby ya no existe, etc.) -- lobby.gd la escucha para mostrar el motivo y
## dejar reintentar en vez de quedarse colgado en "Conectando...".
signal lobby_join_failed(reason: String)

## Emitida SOLO en un cliente (nunca en el host, ver comentario de
## _on_server_disconnected mas abajo) cuando se pierde la conexion con el
## host a media partida -- pase de dureza (hardening) de netcode-agent:
## hasta ahora NADA en el proyecto escuchaba multiplayer.server_disconnected
## fuera del lobby (lobby.gd solo reacciona a peer_disconnected de OTROS
## peers mientras esta en PanelSala, y deja de escuchar nada en cuanto
## empieza la partida, ver _teardown_lobby_signals). Si el host cerraba el
## juego o perdia la conexion mientras un cliente estaba dentro de una
## mision o un interior de tienda, ese cliente se quedaba congelado sin
## ningun aviso ni forma de volver al menu -- el propio MultiplayerAPI ya no
## tiene servidor al que mandar mas RPCs, asi que cualquier submit_ que
## intentara despues simplemente no iria a ningun sitio. main.gd escucha
## esta señal para desconectar limpio y recargar la escena de vuelta al
## menu de inicio (ver _on_host_disconnected en main.gd).
signal host_disconnected

## Id de lobby recibido via Steam.join_requested (el jugador acepta una
## invitacion de Steam, o pulsa "Unirse a la partida" en la lista de amigos,
## MIENTRAS el juego ya esta corriendo) -- solo se guarda si todavia no
## estamos conectados a nada (ver _on_join_requested). lobby.gd lo consulta
## al entrar en PanelModo para auto-unirse sin que el jugador tenga que picar
## el id de lobby a mano.
var pending_invite_lobby_id: int = 0
## Emitida junto con pending_invite_lobby_id de arriba, para que lobby.gd
## reaccione al momento si ya esta en pantalla (en vez de solo consultar el
## valor en su _ready()).
signal invite_received(lobby_id: int)

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
## Maquina expendedora de cadaveres (idea nueva del usuario, quinto
## comprador -- ver Comprador.Tipo.MAQUINA_EXPENDEDORA): usos COMPARTIDOS
## por todo el grupo, no por jugador, mismo motivo que mision_actual de
## arriba. Se resetea al entrar en mision (ver confirm_iniciar_mision) y se
## decrementa en player.gd confirm_vender cada vez que alguien vende en ella
## (una interaccion con V = un uso, sea 1 o varios cadaveres de golpe).
## Solo lo muta el host: la resta ocurre dentro de confirm_vender, que ya es
## un RPC call_local reliable (mismo criterio que dinero_manchado, no hace
## falta un RPC aparte solo para este contador); la recarga (ver
## schedule_recarga_maquina mas abajo) SI necesita su propio RPC porque no
## esta atada a ninguna accion de un jugador concreto.
var usos_maquina_restantes: int = 0
## Tope de usos_maquina_restantes de la mision activa -- la recarga nunca
## sube por encima de este valor. Guardado aparte (no una constante) porque
## el numero depende del bioma (ver confirm_iniciar_mision): 5 si tiene jefe
## de zona, 3 si no.
var usos_maquina_maximo: int = 0
## Segundos que tarda la maquina en reponer 1 uso tras agotarse. Referencia
## de estilo: mismo patron que Player._schedule_grab_someter (await
## get_tree().create_timer(...).timeout en una funcion que solo arranca el
## host, filtrado por multiplayer.is_server() en el punto de llamada).
const RECARGA_MAQUINA_SEGUNDOS := 60.0
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

## Interiores de tienda del Hub (scope nuevo H5+, ver plan-assets.md seccion
## 8 "Interiores de tienda" y plan-desarrollo.md seccion 2): Dictionary
## tienda_id -> PackedScene, instanciada bajo interior_root al entrar (ver
## confirm_entrar_tienda), liberada al volver (ver confirm_salir_tienda).
## El Casino (casino-agent) ya vive aqui igual que el resto -- se movio
## desde test_room a scenes/world/interiors/casino_interior.tscn, con
## puerta fisica en Muelle Alto (hub.tscn PuertaCasino).
const TIENDAS_INTERIOR: Dictionary = {
	"forja": preload("res://scenes/world/interiors/forja_interior.tscn"),
	"herboristeria": preload("res://scenes/world/interiors/herboristeria_interior.tscn"),
	"mercado_negro": preload("res://scenes/world/interiors/mercado_negro_interior.tscn"),
	"sastreria": preload("res://scenes/world/interiors/sastreria_interior.tscn"),
	"casa_equipo": preload("res://scenes/world/interiors/casa_equipo_interior.tscn"),
	"taberna": preload("res://scenes/world/interiors/taberna_interior.tscn"),
	"casino": preload("res://scenes/world/interiors/casino_interior.tscn"),
}

## Id de la tienda cuyo interior esta activo ahora mismo, o "" si el grupo
## esta en el Hub (fachadas) o en una mision. Mismo patron que mision_actual
## de abajo: solo lo muta el host, siempre dentro de confirm_entrar_tienda/
## confirm_salir_tienda. Los guards de ambas funciones (y de
## submit_elegir_mision en player.gd) usan esta variable Y mision_actual para
## que Hub/mision/interior sean mutuamente excluyentes -- no se puede entrar
## a una tienda en mitad de una mision, ni elegir mision desde dentro de una
## tienda.
var interior_actual: String = ""

## Contenedor donde se instancia el interior de tienda activo -- asignado por
## main.gd en _ready(), hermano de Hub/Misiones (mismo criterio que
## mission_root: colocado lejos en el mundo para que sus paredes nunca se
## solapen con las del Hub ni con las de una mision).
var interior_root: Node = null

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

## Inicializa Steam en cuanto arranca el autoload (antes de que main.gd llegue
## a la pantalla de titulo/lobby, ver comentario de cabecera de main.gd) --
## host_game()/join_game() dependen de steam_initialized para saber si pueden
## usar la API de Steam. No usa Project Settings > Steam > Initialization
## (metodo 1 de la doc de GodotSteam) a proposito: mantener la inicializacion
## explicita en codigo hace mas facil de encontrar/tocar este punto para
## cualquier agente que trabaje despues en la capa de red.
func _ready() -> void:
	var init_result: Dictionary = Steam.steamInitEx(STEAM_APP_ID, false)
	# steamInitEx (a diferencia de steamInit) devuelve un Dictionary con
	# "status"/"verbal" en vez de un simple bool -- lo usamos solo para el
	# push_warning de abajo, mas facil de diagnosticar que un fallo mudo.
	steam_initialized = init_result.get("status", -1) == Steam.STEAM_API_INIT_RESULT_OK
	if not steam_initialized:
		push_warning("NetworkManager: Steam no se pudo inicializar (%s) -- hace falta el cliente de Steam abierto y logueado para jugar en red. host_game()/join_game() no haran nada hasta entonces." % init_result)
		return
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.join_requested.connect(_on_join_requested)

func _process(delta: float) -> void:
	# Imprescindible para que lleguen los callbacks de Steam (lobby_created,
	# lobby_joined, join_requested, etc.) -- sin esto, Steam.createLobby() y
	# companyia se quedan colgados para siempre. Vive en el _process() del
	# autoload (siempre activo, nunca pausado) en vez de en un nodo que podria
	# pausarse -- mismo criterio que recomienda la doc oficial de GodotSteam.
	if steam_initialized:
		Steam.run_callbacks()
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

## Crea un lobby de Steam (asincrono, ver _on_lobby_created mas abajo para la
## parte que de verdad monta el MultiplayerPeer). LOBBY_TYPE_FRIENDS_ONLY:
## visible para amigos del host (para "Invitar amigos", ver invite_friends())
## sin quedar listado publicamente entre el mar de lobbies de Spacewar (app id
## 480 compartido por todo el mundo que usa GodotSteam sin App ID propio, ver
## comentario de cabecera).
func host_game() -> void:
	# multiplayer.multiplayer_peer NUNCA es null por defecto: Godot le pone un
	# OfflineMultiplayerPeer de por si. Comprobar "!= null" no detecta ese caso
	# y por tanto nunca deja pasar la primera llamada real.
	if not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		return
	if not steam_initialized:
		push_error("NetworkManager: Steam no esta inicializado, no se puede crear una sala.")
		lobby_join_failed.emit("Steam no esta disponible. Abre el cliente de Steam e inicia sesion.")
		return
	Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, MAX_PLAYERS)
	# El resto (montar el SteamMultiplayerPeer, emitir lobby_ready) ocurre en
	# _on_lobby_created cuando Steam confirma la creacion -- createLobby() es
	# async, a diferencia de ENetMultiplayerPeer.create_server() de antes, que
	# devolvia el resultado al instante.

## Se une a un lobby de Steam por su id (asincrono, ver _on_lobby_joined mas
## abajo). A diferencia del join_game(ip: String) de antes (ENet), el "sitio"
## al que te unes ahora es un lobby_id de Steam (entero de 64 bits), no una
## direccion IP -- lo normal es llegar aqui via el overlay de invitacion
## (ver invite_friends()/_on_join_requested), pero tambien se acepta pegado a
## mano como atajo de test (ver PanelUnirse en lobby.gd/lobby.tscn).
func join_game(lobby_id: int) -> void:
	if not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		return
	if not steam_initialized:
		push_error("NetworkManager: Steam no esta inicializado, no se puede unir a una sala.")
		lobby_join_failed.emit("Steam no esta disponible. Abre el cliente de Steam e inicia sesion.")
		return
	if lobby_id <= 0:
		lobby_join_failed.emit("Id de sala invalido.")
		return
	Steam.joinLobby(lobby_id)
	# No se spawnea aqui: el spawn real lo dispara submit_style_choice en
	# cuanto este cliente elige estilo y confirma la conexion (ver main.gd),
	# despues de que _on_lobby_joined monte el MultiplayerPeer.

## Callback de Steam.createLobby() (ver host_game() de arriba). Aqui es donde
## de verdad se monta el transporte: SteamMultiplayerPeer.create_host() en vez
## de ENetMultiplayerPeer.create_server(). server_relay = true (recomendado
## por la doc de GodotSteam): los clientes no hablan directamente entre ellos,
## todo pasa por el host -- coincide con el modelo host-autoritativo que ya
## usa el resto de este autoload y simplifica la topologia de red a "todos
## contra el host", igual que tenia ENet.
func _on_lobby_created(connect_status: int, lobby_id: int) -> void:
	if connect_status != Steam.RESULT_OK:
		push_error("NetworkManager: fallo al crear la sala de Steam (codigo %s)" % connect_status)
		lobby_join_failed.emit("No se pudo crear la sala de Steam.")
		return
	steam_lobby_id = lobby_id
	var peer := SteamMultiplayerPeer.new()
	var err := peer.create_host(0)
	if err != OK:
		push_error("NetworkManager: fallo al crear el host de Steam (error %s)" % err)
		lobby_join_failed.emit("No se pudo crear el host de la sala.")
		Steam.leaveLobby(lobby_id)
		steam_lobby_id = 0
		return
	peer.server_relay = true
	multiplayer.multiplayer_peer = peer
	_connect_peer_signals()
	lobby_ready.emit(true)
	# El spawn del host (peer 1) ya NO ocurre aqui (H6): espera a que main.gd
	# termine el prologo + pantalla de eleccion de estilo y mande
	# submit_style_choice, igual que cualquier otro peer.

## Callback de Steam.joinLobby() (ver join_game() de arriba) -- tambien llega
## al HOST (el propio Steam.createLobby() implica entrar a su propio lobby),
## por eso se comprueba getLobbyOwner() == getSteamID() para no montar un
## SteamMultiplayerPeer cliente encima del host que _on_lobby_created ya
## configuro.
func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		push_error("NetworkManager: fallo al unirse a la sala %s (respuesta %s)" % [lobby_id, response])
		lobby_join_failed.emit("No se pudo unir a la sala (puede que ya no exista o este llena).")
		return
	steam_lobby_id = lobby_id
	var owner_id := Steam.getLobbyOwner(lobby_id)
	if owner_id == Steam.getSteamID():
		return # somos el host, _on_lobby_created ya monto el MultiplayerPeer
	var peer := SteamMultiplayerPeer.new()
	var err := peer.create_client(owner_id, 0)
	if err != OK:
		push_error("NetworkManager: fallo al crear el cliente de Steam hacia %s (error %s)" % [owner_id, err])
		lobby_join_failed.emit("No se pudo conectar con el host de la sala.")
		Steam.leaveLobby(lobby_id)
		steam_lobby_id = 0
		return
	peer.server_relay = true
	multiplayer.multiplayer_peer = peer
	_connect_peer_signals()
	lobby_ready.emit(false)

## Callback de Steam.join_requested -- el jugador acepta una invitacion de
## Steam (o pulsa "Unirse a la partida" desde la lista de amigos) MIENTRAS el
## juego ya esta corriendo. Si ya estamos conectados a algo, se ignora (no
## tiene sentido saltar de una sala a otra a media partida); si no, se guarda
## el lobby_id para que lobby.gd se auto-una en cuanto lo consulte (ver
## pending_invite_lobby_id arriba).
func _on_join_requested(lobby_id: int, _friend_id: int) -> void:
	if not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		return
	pending_invite_lobby_id = lobby_id
	invite_received.emit(lobby_id)

## Abre el overlay de invitacion de Steam para el lobby activo -- boton
## "Invitar amigos" del host en PanelSala (ver lobby.gd). Sustituye a mostrar
## la IP local a mano que tenia el flujo de ENet: Steam ya sabe a que lobby
## invitar, no hace falta que el jugador copie/pegue nada.
func invite_friends() -> void:
	if steam_lobby_id == 0:
		return
	Steam.activateGameOverlayInviteDialog(steam_lobby_id)

## Desconecta limpio y vuelve al estado offline (H_lobby: boton "Volver"/
## "Salir de la sala" del lobby, ver scripts/ui/lobby.gd). No hace falta
## desconectar peer_connected/peer_disconnected de aqui: siguen sirviendo
## para la proxima partida (host_game/join_game reusan la misma conexion via
## _connect_peer_signals, que ya evita duplicados).
func disconnect_game() -> void:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	if steam_lobby_id != 0:
		Steam.leaveLobby(steam_lobby_id)
		steam_lobby_id = 0
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	style_choice.clear()

## host_game()/join_game() se pueden llamar mas de una vez a lo largo de la
## vida del proceso ahora que existe un lobby con boton de "Volver" (crear
## sala, cancelar, crear otra vez...) -- is_connected() evita apilar
## conexiones duplicadas a _on_peer_connected/_on_peer_disconnected en cada
## vuelta, cosa que antes no hacia falta porque solo se llamaba una vez por
## partida.
func _connect_peer_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	# Pase de dureza (hardening): ver comentario de host_disconnected arriba.
	# server_disconnected es la señal correcta para detectar "se rompio mi
	# conexion con el host" -- a diferencia de peer_disconnected (que solo
	# esta garantizado cuando un peer normal se va, ver doc de Godot),
	# server_disconnected SIEMPRE dispara en cada cliente cuando el peer 1
	# desaparece, sea porque cerro el juego, crasheo o perdio la red. Nunca
	# dispara en el propio host (un servidor no se desconecta de si mismo),
	# asi que no hace falta filtrar por is_server() en el handler.
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_peer_connected(_id: int) -> void:
	pass # el spawn ya no depende de la conexion, ver submit_style_choice.

## Ver comentario de host_disconnected arriba. disconnect_game() ya deja
## multiplayer_peer en OfflineMultiplayerPeer y limpia steam_lobby_id/
## style_choice -- mismo estado que si el jugador hubiera pulsado "Salir de
## la sala" a mano. main.gd es quien decide que hacer con la señal
## (recargar la escena y volver al menu), este autoload solo detecta la
## caida y deja el estado de red limpio antes de avisar.
func _on_server_disconnected() -> void:
	disconnect_game()
	host_disconnected.emit()

func _on_peer_disconnected(id: int) -> void:
	style_choice.erase(id)
	if players_root == null:
		return
	var node := players_root.get_node_or_null(str(id))
	if node != null:
		node.queue_free()

## Emitida en todos los peers (host incluido, ver confirm_iniciar_partida mas
## abajo) cuando el host pulsa "Iniciar partida" en el lobby. scripts/ui/
## lobby.gd la escucha para dar paso a main.gd._run_intro_flow (prologo ->
## eleccion de estilo -> submit_style_choice), que ya asume que host_game/
## join_game se llamaron antes desde el lobby.
signal game_started

## Pedido por el boton "Iniciar partida" del lobby (ver scripts/ui/lobby.gd),
## visible solo si multiplayer.is_server() -- pero se valida aqui tambien por
## si acaso, mismo criterio de no confiar ciegamente en el cliente que el
## resto de submit_* de player.gd. any_peer+call_local+reliable y validacion
## por sender_id, mismo patron que submit_style_choice de aqui abajo (este
## RPC tambien ocurre antes de que exista ningun nodo Player al que atar la
## autoridad).
@rpc("any_peer", "call_local", "reliable")
func submit_iniciar_partida() -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id != 0 and sender_id != 1:
		return # solo el host (o su propia llamada local, sender_id 0) puede iniciar
	confirm_iniciar_partida.rpc()

## Confirma el inicio de partida igual en todos los peers -- mismo patron
## confirm_* que el resto de este autoload: el host ya valido arriba, aqui
## solo se replica el efecto (emitir game_started) a todo el mundo.
@rpc("any_peer", "call_local", "reliable")
func confirm_iniciar_partida() -> void:
	game_started.emit()

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
	# Bug hermano de autoridad/posicion (commits aa957b1/f224c9a): _spawn_player
	# de arriba solo deja style_data bien puesto en la copia LOCAL del host (el
	# MultiplayerSpawner no replica mutaciones de script, solo reinstancia la
	# escena desde cero en cada otro peer). A diferencia de autoridad/posicion,
	# el estilo no se puede derivar localmente en cada peer (es una eleccion
	# privada, no un dato ya sincronizado) -- hay que difundirlo por RPC
	# explicito. Ver confirm_style_choice mas abajo para el detalle de por que
	# hace falta y como se resuelve el riesgo de orden de llegada.
	confirm_style_choice.rpc(sender_id, style_path)
	# Pase de dureza (hardening) de netcode-agent: sender_id puede ser un peer
	# que se une a una partida YA EN MARCHA (tercer/cuarto jugador entrando
	# tarde) o que se RECONECTA mientras el resto del grupo sigue dentro de
	# una mision o un interior de tienda -- ver _sync_new_peer() mas abajo
	# para el porque hace falta esto ademas del RPC de arriba.
	_sync_new_peer(sender_id)

## Ver comentario de la llamada en submit_style_choice de arriba. Todo el
## estado que mission_root/interior_root llevan puesto (y los estilos de
## los jugadores que ya estaban conectados) viajo en su momento por RPCs
## PUNTUALES (confirm_iniciar_mision/confirm_entrar_tienda/confirm_style_choice),
## que solo alcanzan a los peers conectados EN ESE INSTANTE -- un peer que
## se une despues (o se reconecta tras perder la conexion) nunca los recibe.
## Sin esto, ese peer aparece con el estilo por defecto puesto en los
## jugadores que ya estaban ahi, y si el grupo esta dentro de una mision o
## de un interior de tienda, su copia local de mission_root/interior_root se
## queda vacia -- el host SI lo posiciona bien (_spawn_player usa el
## spawn_points ya vigente), pero ese peer ve un mundo sin paredes ni
## mesas, flotando en el sitio correcto de un escenario que no existe en su
## pantalla. Se manda SOLO al peer nuevo (rpc_id), nunca al grupo entero
## (.rpc()) -- los demas ya estan al dia, repetirselo seria inofensivo pero
## inutil.
func _sync_new_peer(peer_id: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		return # el propio host nunca necesita resincronizarse consigo mismo
	for otro_id in style_choice:
		if otro_id == peer_id:
			continue # su propio estilo ya viaja en el confirm_style_choice.rpc() de submit_style_choice
		confirm_style_choice.rpc_id(peer_id, otro_id, style_choice[otro_id])
	if mision_actual != "":
		confirm_sync_mision_a_peer.rpc_id(peer_id, mision_actual)
	elif interior_actual != "":
		confirm_sync_interior_a_peer.rpc_id(peer_id, interior_actual)

## Aplica el estado de la mision activa SOLO en el peer nuevo (ver
## _sync_new_peer arriba) -- instancia la escena del bioma bajo mission_root
## exactamente igual que confirm_iniciar_mision, pero sin volver a tocar
## mision_actual/usos_maquina_* (ya estan bien en todos los peers que ya
## estaban conectados) ni disparar el reposicionamiento del grupo (el peer
## nuevo todavia no tiene jugador spawneado en su arbol cuando esto llega
## en el peor orden posible, y el que si tiene ya lo coloco _spawn_player).
## Idempotente via el guard de mission_root.get_child_count(): en el HOST
## (que recibe esta misma llamada por call_local al usar rpc_id) la escena
## real ya esta montada, asi que aqui no hace nada.
@rpc("any_peer", "call_local", "reliable")
func confirm_sync_mision_a_peer(bioma_id: String) -> void:
	if mission_root == null or mission_root.get_child_count() > 0:
		return
	if not MISIONES.has(bioma_id):
		return
	var instancia: Node = MISIONES[bioma_id].instantiate()
	mission_root.add_child(instancia)
	var nuevos: Array[Node2D] = []
	nuevos.assign(instancia.get_node("PlayerSpawns").get_children())
	spawn_points = nuevos
	mision_actual = bioma_id

## Aplica el estado del interior de tienda activo SOLO en el peer nuevo --
## mismo criterio que confirm_sync_mision_a_peer de arriba, version interior
## (ver confirm_entrar_tienda mas abajo para el equivalente que SI reposiciona
## al grupo entero, usado cuando alguien entra de verdad, no al sincronizar
## a un recien llegado).
@rpc("any_peer", "call_local", "reliable")
func confirm_sync_interior_a_peer(tienda_id: String) -> void:
	if interior_root == null or interior_root.get_child_count() > 0:
		return
	if not TIENDAS_INTERIOR.has(tienda_id):
		return
	var instancia: Node = TIENDAS_INTERIOR[tienda_id].instantiate()
	interior_root.add_child(instancia)
	var nuevos: Array[Node2D] = []
	nuevos.assign(instancia.get_node("PlayerSpawns").get_children())
	spawn_points = nuevos
	interior_actual = tienda_id

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

## Difunde el estilo elegido por `id` a TODOS los peers (host incluido, via
## call_local) -- tercer bug de la misma familia que autoridad
## (set_multiplayer_authority, commit aa957b1) y posicion (global_position,
## commit f224c9a): _spawn_player() de arriba hace
## `player.style_data = load(style_path)` ANTES de add_child, pero eso es una
## mutacion de script sobre la instancia en memoria del HOST -- el
## MultiplayerSpawner en modo auto-spawn no la replica, en cada OTRO peer
## simplemente reinstancia player.tscn desde cero. Resultado sin este fix: en
## la copia de cualquier peer que no sea el host, style_data nace null y
## player.gd::_ready() cae al estilo por defecto (Fuego) -- ese jugador ve y
## usa el estilo equivocado EN SU PROPIA PANTALLA (el host, que renderiza su
## propia copia autoritativa, lo ve bien; por eso el sintoma es "el host ve
## el estilo correcto pero el propio jugador no").
##
## Diferencia clave con autoridad/posicion: esos dos se resolvieron
## DERIVANDO el valor localmente en cada peer sin tocar la red (el nombre del
## nodo y spawn_points ya viajan/estan sincronizados). El estilo NO se puede
## derivar asi -- es una eleccion privada de cada jugador que ningun otro
## peer puede adivinar -- por eso hace falta este RPC explicito, disparado
## por el host justo despues de _spawn_player (ver submit_style_choice).
##
## Riesgo de orden de llegada: no hay garantia documentada de que la
## replicacion del MultiplayerSpawner (disparada por el add_child dentro de
## _spawn_player) y este RPC manual (lanzado inmediatamente despues, mismo
## frame, mismo canal reliable) lleguen en ese mismo orden en un peer remoto
## -- se cubren las dos posibilidades en vez de asumir una:
## - Si este RPC llega ANTES de que el nodo exista todavia en este peer: el
##   `get_node_or_null` de abajo da null y no hay nada que tocar aqui, pero
##   style_choice[id] ya queda guardado (a diferencia de antes, donde solo el
##   host lo tenia) -- player.gd::_enter_tree() (que Godot garantiza que
##   corre DESPUES, en cuanto el nodo replicado entra al arbol) lo lee de ahi.
## - Si este RPC llega DESPUES (el nodo ya existe, ya paso por _enter_tree()/
##   _ready() con el estilo por defecto): se aplica aqui mismo, directamente
##   sobre el nodo ya existente, via Player.apply_synced_style() (que
##   reutiliza _apply_style_reset(), la misma funcion que ya usa el hot-swap
##   de debug _handle_debug_style_switch, para reiniciar el estado
##   dependiente de estilo: chakra/vida/combo/etc.).
## El guard `node.style_data == style` evita repetir ese reset en el HOST
## (que ya aplico el estilo correcto de forma sincrona en _spawn_player antes
## de este RPC) -- load() de un .tres devuelve la misma instancia cacheada
## para la misma ruta, asi que la comparacion por referencia es valida.
@rpc("any_peer", "call_local", "reliable")
func confirm_style_choice(id: int, style_path: String) -> void:
	style_choice[id] = style_path
	_reaplicar_estilo_si_hace_falta(id, style_path)

## Extraido de confirm_style_choice (arriba) para poder reutilizarlo tambien
## desde _reposicionar_jugadores: busca el nodo del peer `id` y, si su
## style_data no coincide con lo que dice style_choice, lo corrige via
## apply_synced_style(). Callable en cualquier momento (no solo cuando llega
## el RPC de eleccion) sin riesgo: el guard de igualdad por referencia lo hace
## un no-op si ya esta bien.
func _reaplicar_estilo_si_hace_falta(id: int, style_path: String) -> void:
	if players_root == null:
		return
	var node := players_root.get_node_or_null(str(id))
	if node == null:
		return # el nodo aun no ha llegado via MultiplayerSpawner; _enter_tree() lo leera de style_choice cuando llegue
	var style: StyleData = load(style_path)
	if node.style_data == style:
		return # ya tiene el estilo correcto, no repetir el reset
	node.apply_synced_style(style)

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
	if interior_actual != "":
		return # dentro de un interior de tienda -- pase de dureza: submit_elegir_mision
		# ya comprueba esto antes de llamar aqui, pero confirm_entrar_tienda SI
		# re-comprueba las dos condiciones de forma defensiva (ver mas abajo) y
		# esta funcion se habia quedado asimetrica solo comprobando mision_actual;
		# se iguala el criterio por si en el futuro algo mas (aparte de
		# submit_elegir_mision) llega a llamar a este confirm_ directamente.
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
	# Maquina expendedora de cadaveres: 5 usos si el bioma tiene jefe de zona
	# (hoy, los 5 biomas de MISIONES arriba todos lo tienen), 3 si en el
	# futuro existe un bioma sin jefe/mas corto -- condicion dejada explicita
	# a proposito aunque hoy siempre caiga en la rama de 5.
	var tiene_jefe_zona := true # costa/bambu/peaje/cantera/ruinas: los 5 tienen jefe de zona
	usos_maquina_maximo = 5 if tiene_jefe_zona else 3
	usos_maquina_restantes = usos_maquina_maximo
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

## Maquina expendedora de cadaveres: se llama SOLO desde el host (guard en
## el punto de llamada de player.gd confirm_vender, mismo criterio que
## Player._schedule_grab_someter) justo cuando una venta deja el contador
## compartido a 0. Espera RECARGA_MAQUINA_SEGUNDOS y repone 1 uso, sin pasar
## de usos_maquina_maximo. Si para entonces el grupo ya volvio al Hub
## (mision_actual == "") no hace nada -- no hay maquina que recargar.
## Sin underscore a proposito (a diferencia de _reposicionar_jugadores, que
## solo se llama desde dentro de este autoload): player.gd la llama desde
## fuera, como next_cadaver_id()/sospecha_tramo() de arriba.
func schedule_recarga_maquina() -> void:
	await get_tree().create_timer(RECARGA_MAQUINA_SEGUNDOS).timeout
	if mision_actual == "":
		return
	usos_maquina_restantes = min(usos_maquina_restantes + 1, usos_maquina_maximo)
	confirm_recarga_maquina.rpc(usos_maquina_restantes)

## Confirma la recarga igual en todos los peers -- el host ya decidio el
## nuevo valor en _schedule_recarga_maquina de arriba, aqui solo se replica
## (mismo patron call_local reliable que el resto de confirm_* de este
## autoload).
@rpc("any_peer", "call_local", "reliable")
func confirm_recarga_maquina(nuevo_usos: int) -> void:
	usos_maquina_restantes = nuevo_usos

## Manda a cada jugador ya conectado al spawn_point que le toca segun su
## peer_id, mismo calculo que _spawn_position_for usa para jugadores nuevos
## -- asi entrar/salir de una mision reposiciona a todo el grupo de golpe en
## vez de dejarlos flotando en las coordenadas de la escena anterior.
##
## Tambien reaplica el estilo de cada jugador desde style_choice (mismo
## guard idempotente que ya usa confirm_style_choice, ver
## _reaplicar_estilo_si_hace_falta): investigando un reporte en vivo de dos
## cuentas de Steam reales (estilo de un cliente no-host volvia a verse como
## el default de Fuego justo al ENTRAR en una mision, tras funcionar bien en
## el Hub) no se encontro ningun punto del codigo de mision/Hub que mute
## style_data -- ni en lectura estatica ni reproduciendolo con dos procesos
## reales por red (ENet local, RPC real, confirm_iniciar_mision disparado a
## proposito lo antes posible para forzar el peor caso de orden de llegada:
## el estilo sobrevivio siempre en esa prueba). Sin poder reproducirlo con
## Steam real, se añade esta reaplicacion aqui como red de seguridad barata
## (no-op si ya esta bien) para el punto exacto donde el usuario lo vio
## romperse, por si la causa real es algo propio del transporte Steam que
## esta prueba con ENet no cubre.
func _reposicionar_jugadores() -> void:
	if players_root == null:
		return
	for jugador in players_root.get_children():
		var id := int(jugador.name)
		jugador.global_position = _spawn_position_for(id)
		if style_choice.has(id):
			_reaplicar_estilo_si_hace_falta(id, style_choice[id])

# =========================================================================
# Interiores de tienda del Hub (scope nuevo H5+) -- transicion Hub<->interior
# "estilo Pokemon": fundido a negro (ver scripts/ui/fade_transition.gd,
# autoload FadeTransition) + instanciar/desinstanciar la escena de interior
# bajo interior_root, exactamente el mismo patron RPC host-autoritativo y de
# reposicionamiento de spawn_points que confirm_iniciar_mision/
# confirm_volver_hub de arriba -- unica diferencia real: el swap de escena
# ocurre DENTRO del callback que le pasamos a FadeTransition.play_transition,
# para que la carga quede oculta bajo la pantalla en negro en vez de verse a
# medio hacer. El host decide cuando se entra/sale (submit_entrar_tienda/
# submit_salir_tienda en player.gd, filtrados por multiplayer.is_server()) y
# lo replica a todos los peers con un RPC call_local reliable, igual que el
# resto del autoload.
# =========================================================================

## Confirma la entrada a una tienda igual en todos los peers. Lo llama el
## host desde player.gd submit_entrar_tienda(); nunca el cliente
## directamente. Reutiliza _spawn_points_previos/_reposicionar_jugadores, los
## mismos que usa el sistema de misiones -- valido porque Hub/mision/tienda
## son mutuamente excluyentes (ver el guard de abajo), nunca hay dos
## transiciones activas a la vez que puedan pisarse el valor.
@rpc("any_peer", "call_local", "reliable")
func confirm_entrar_tienda(tienda_id: String) -> void:
	if mision_actual != "" or interior_actual != "":
		return # ya hay una mision o un interior activo, ignorar peticion duplicada
	if not TIENDAS_INTERIOR.has(tienda_id):
		return
	if interior_root == null:
		push_warning("NetworkManager: interior_root no asignado, no se puede entrar a la tienda")
		return
	# interior_actual se marca SINCRONO, antes del fundido -- si no, un
	# segundo submit_entrar_tienda que llegue mientras el fundido todavia
	# esta en marcha (jugador machacando F11, o dos jugadores pidiendo dos
	# tiendas distintas casi a la vez) veria el guard de arriba todavia en
	# "" y podria disparar una segunda transicion superpuesta sobre la
	# primera. Mismo motivo en confirm_salir_tienda mas abajo.
	interior_actual = tienda_id
	_spawn_points_previos = spawn_points.duplicate()
	FadeTransition.play_transition(func() -> void:
		var instancia: Node = TIENDAS_INTERIOR[tienda_id].instantiate()
		interior_root.add_child(instancia)
		var nuevos: Array[Node2D] = []
		nuevos.assign(instancia.get_node("PlayerSpawns").get_children())
		spawn_points = nuevos
		_reposicionar_jugadores()
	)

## Confirma la salida de una tienda igual en todos los peers: libera la
## escena de interior activa y restaura los spawn_points del Hub de antes de
## entrar. Lo llama el host desde player.gd submit_salir_tienda().
@rpc("any_peer", "call_local", "reliable")
func confirm_salir_tienda() -> void:
	if interior_actual == "":
		return # no hay interior activo del que salir
	interior_actual = "" # sincrono, antes del fundido -- mismo motivo que confirm_entrar_tienda
	FadeTransition.play_transition(func() -> void:
		if interior_root != null:
			for hijo in interior_root.get_children():
				hijo.queue_free()
		spawn_points = _spawn_points_previos if not _spawn_points_previos.is_empty() else hub_spawn_points.duplicate()
		_reposicionar_jugadores()
	)
