class_name Taberna
extends Node2D
## "El Ancla Rota" (H5 tarea 4, Muelle). Brindis simple: un jugador
## interactua, se paga un coste fijo de dinero LIMPIO del pool compartido, y
## se activa un buff de daño de GRUPO temporal para TODOS los jugadores
## conectados (NetworkManager.brindis_time_remaining/brindis_damage_multiplier,
## ver network_manager.gd). Mismo patron de interaccion estatica que
## Comprador/Cambista/Forja/Herboristeria: deteccion por distancia simple
## desde player.gd, sin Area2D ni estado de red propio.
##
## Recorte deliberado de alcance (decision explicita del usuario, ver tarea):
## sin "que bebida pidio cada uno" (eso es la parte cosmetica/social
## descartada). La pizarra de deudas (fiar el brindis sin fondos, ver
## NetworkManager.taberna_deuda_pendiente), la pizarra de records
## (NetworkManager.record_casino_perdidas/record_cuerpos_destrozados, ver
## player.gd submit_taberna_ver_records) y el desglose de contribucion
## (NetworkManager.taberna_aportado_manchado + misiones_completadas del
## grupo, ver player.gd submit_taberna_ver_desglose, tecla F10) SI estan
## implementados -- ya no son un recorte.
##
## Respeta la misma regla invariante que la Forja (brief seccion 4: "ninguna
## mejora permanente supera el +20%"): aunque este buff es TEMPORAL, no
## permanente, se mantiene bajo el mismo techo de +20% por decision del
## usuario en la tarea.

const GRUPO_TABERNAS := "tabernas"

@export var radio_brindis: float = 80.0

## Coste fijo en dinero limpio, sale del pool COMPARTIDO (no de quien lo
## paga en particular) -- mismo criterio que el resto de compras de esta
## tanda.
@export var costo_brindis: float = 150.0

## +15% de daño durante 3 minutos: por debajo del techo de +20% de la Forja,
## y con duracion corta a proposito -- es un empujon puntual tras volver de
## pelear, no una mejora permanente.
@export var brindis_duracion: float = 180.0
@export var brindis_bonus_daño: float = 0.15

## Musica diegetica (H6 extra): lista FIJA comprable en cualquier orden --
## recorte deliberado de "se desbloquean segun avanzas" (brief), porque el
## vertical slice todavia no tiene progresion de mision real dentro de una
## misma partida. Cada cancion es una compra UNICA y
## PERMANENTE de GRUPO (no por jugador -- suena igual para todos, mismo
## criterio que casa_equipo_almacen_comprado), pagada del pool compartido de
## dinero limpio igual que el brindis.
@export var canciones_disponibles: PackedStringArray = [
	"Balada del Muelle",
	"Vals del Contrabandista",
	"Tambor de Ronda",
]
@export var costo_cancion: float = 40.0

@onready var _visual: ColorRect = $Visual

func _ready() -> void:
	add_to_group(GRUPO_TABERNAS)
