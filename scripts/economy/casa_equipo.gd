class_name CasaEquipo
extends Node2D
## Casa del equipo (H5 cierre, Terrazas). Mejoras de calidad de vida
## compradas ENTRE TODOS con la boveda (brief 2.4 / diseno "Tiendas y dinero
## limpio"): a diferencia de Forja/Herboristeria/Sastreria (gasto compartido,
## resultado individual), aqui tanto el gasto COMO el resultado son de
## grupo -- mismo criterio que la Taberna. Mismo patron de interaccion
## estatica que el resto de esta tanda: un solo nodo, varias teclas segun la
## mejora (igual que Herboristeria con P/H/J/L), sin Area2D ni estado de red
## propio.
##
## Las cuatro mejoras del brief y como se adaptan a este vertical slice:
##
## - Cocina: brief dice "comidas que dan bonus de grupo antes de salir a
##   mision". Sin flujo de "salir a mision" real todavia (mismo hueco que ya
##   resolvio Taberna para su brindis), se adapta al MISMO patron temporal
##   que el brindis: buff de grupo con duracion (ver
##   NetworkManager.cocina_time_remaining/cocina_damage_reduction_multiplier).
##   POR ESO, a diferencia de Almacen/Jardin de abajo, la Cocina NO se compra
##   "una vez para siempre" -- es una accion repetible (como pedir de comer),
##   igual que el brindis de la Taberna es repetible. Documentado aqui
##   porque es la excepcion a "cada mejora se compra una vez" del resto de
##   esta tienda.
##
## - Almacen: "aumenta cuantos cuerpos podeis cargar". Compra UNICA y
##   permanente (sin niveles): suma ALMACEN_BONUS_CADAVERES al
##   Player.MAX_CADAVERES_CARGADOS de TODOS los jugadores del grupo (brief
##   seccion 4: "los bonus de comida y casa se aplican a todo el grupo, no
##   solo a quien pago"). Estado en NetworkManager.casa_equipo_almacen_comprado
##   (bool compartido, no Dictionary por peer -- es del grupo entero).
##
## - Palomar: "permite rechazar una mision sin penalizacion". BLOQUEADA: el
##   vertical slice no tiene sistema de misiones/tablon todavia (confirmado,
##   ningun archivo lo menciona), asi que "rechazar una mision" no tiene nada
##   que hacer de verdad. Mismo criterio de documentar un bloqueo que usa
##   cartas_selladas.gd para la trampa de Sellos: no se anade tecla ni
##   estado para esto, se deja explicito aqui para cuando exista el tablon
##   de misiones real.
##
## - Jardin: "cultiva reactivos para la herboristeria". Un sistema de cultivo
##   con tiempo real (plantar, esperar, cosechar) es sobreconstruir para este
##   alcance -- se adapta a un efecto simple y verificable: compra UNICA y
##   permanente que aplica un descuento fijo (JARDIN_DESCUENTO_HERBORISTERIA)
##   sobre el precio de los 4 consumibles de Herboristeria (ver
##   player.gd submit_comprar_consumible). Descuento, no bonus, pero se
##   mantiene igualmente por debajo del techo del +20% de la regla invariante
##   (brief seccion 4) por el mismo criterio de margen que ya usa Taberna.
##   Estado en NetworkManager.casa_equipo_jardin_comprado (bool compartido,
##   mismo patron que Almacen).

const GRUPO_CASAS_EQUIPO := "casas_equipo"

@export var radio_interaccion: float = 80.0

## Cocina: coste fijo por cada ronda (repetible, ver comentario de cabecera),
## sale del pool COMPARTIDO -- mismos valores que el brindis de la Taberna
## por ser el mismo tipo de accion (comida/bebida -> buff de grupo temporal).
@export var precio_cocina: float = 150.0
const COCINA_DURACION := 180.0
## Reduce el daño RECIBIDO por todo el grupo un 15% mientras dure -- por
## debajo del techo de +20% (regla invariante, brief seccion 4), con el
## mismo margen que deja el +15% de daño del brindis de la Taberna. Efecto
## distinto al del brindis (reduccion de daño recibido, no bonus al propio
## daño) para que Cocina y Taberna no sean el mismo buff con otro nombre.
const COCINA_REDUCCION_DAÑO := 0.15

## Almacen: compra unica, permanente, sale del pool COMPARTIDO. Precio mas
## alto que el resto de esta tienda porque es un beneficio para siempre, no
## una ronda puntual.
@export var precio_almacen: float = 200.0
const ALMACEN_BONUS_CADAVERES := 2

## Jardin: compra unica, permanente, sale del pool COMPARTIDO.
@export var precio_jardin: float = 180.0
const JARDIN_DESCUENTO_HERBORISTERIA := 0.15

@onready var _visual: ColorRect = $Visual

func _ready() -> void:
	add_to_group(GRUPO_CASAS_EQUIPO)
