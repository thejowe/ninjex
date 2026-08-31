class_name Forja
extends Node2D
## Punto de mejora de arma (H5 tarea 2, Calle de los Faroles). Mismo patron de
## interaccion estatica que Comprador/Cambista/Usurero: deteccion por
## distancia simple desde player.gd (_find_nearest_forja_in_range), sin
## Area2D ni estado de red propio -- este nodo nunca cambia, solo expone los
## precios de cada nivel.
##
## Regla invariante del brief (seccion 4): "ninguna mejora permanente supera
## el +20% sobre la base". Los 3 niveles se reparten dentro de ese techo (ver
## Player.FORJA_BONUS_POR_NIVEL: +7% / +14% / +20%), sin aleatoriedad, precio
## creciente en dinero LIMPIO. El nivel conseguido es POR JUGADOR (persiste
## en NetworkManager.forja_nivel, Dictionary peer_id -> nivel) y se paga del
## pool compartido de dinero limpio -- mismo criterio que el resto de compras
## de esta tanda (Herboristeria, Taberna): el gasto es compartido, el
## beneficio es individual.

const GRUPO_FORJAS := "forjas"

@export var radio_mejora: float = 80.0

## Precio en dinero limpio para alcanzar cada nivel (1, 2, 3) desde el
## inmediatamente anterior. Exportado para poder ajustar sin tocar codigo,
## igual que los precios de Comprador/Cambista.
@export var precio_nivel_1: float = 100.0
@export var precio_nivel_2: float = 220.0
@export var precio_nivel_3: float = 380.0

@onready var _visual: ColorRect = $Visual

func _ready() -> void:
	add_to_group(GRUPO_FORJAS)

## Precio para comprar `nivel_objetivo` (1-3). -1 si el nivel no existe.
## Lo llama el host desde player.gd submit_mejorar_forja() -- nunca el
## cliente, para que nadie pueda mentir sobre cuanto cuesta su propia mejora.
func precio_para_nivel(nivel_objetivo: int) -> float:
	match nivel_objetivo:
		1:
			return precio_nivel_1
		2:
			return precio_nivel_2
		3:
			return precio_nivel_3
		_:
			return -1.0
