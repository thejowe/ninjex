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
## descartada), sin desglose de contribucion, sin pizarra de deudas/records.
## Solo el brindis en si: coste fijo -> buff de grupo temporal simple.
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

@onready var _visual: ColorRect = $Visual

func _ready() -> void:
	add_to_group(GRUPO_TABERNAS)
