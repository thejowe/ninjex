class_name Herboristeria
extends Node2D
## Punto de venta de consumibles (H5 tarea 3, Calle de los Faroles). Mismo
## patron de interaccion estatica que Comprador/Cambista/Forja: deteccion por
## distancia simple desde player.gd, sin Area2D ni estado de red propio.
##
## Adaptacion del brief (2.4: "maximo tres consumibles por jugador Y MISION"):
## este vertical slice no tiene el concepto de mision real (ver comentario de
## cabecera de usurero.gd para la misma adaptacion en H4), asi que se usa "3
## cargados a la vez, se recargan comprando mas" -- el limite vive en
## player.gd (MAX_CONSUMIBLES_CARGADOS) sobre el array Player.consumibles,
## igual que MAX_CADAVERES_CARGADOS limita los cadaveres.
##
## Los 4 tipos y su efecto real estan documentados en player.gd
## (confirm_usar_consumible): pildora (chakra instantanea), unguento (cura
## por goteo 20s), bomba_humo (escape: invulnerabilidad + velocidad breve),
## sales (reduce el desgaste de las Puertas un tiempo).

const GRUPO_HERBORISTERIAS := "herboristerias"

## Tipos validos, en el mismo orden que aparecen en el brief 2.4.
const TIPO_PILDORA := "pildora"
const TIPO_UNGUENTO := "unguento"
const TIPO_BOMBA_HUMO := "bomba_humo"
const TIPO_SALES := "sales"

@export var radio_compra: float = 80.0

## Precios en dinero limpio, cada uno se compra de uno en uno (una tecla por
## tipo en player.gd, ver comentario de cabecera del apartado Herboristeria).
@export var precio_pildora: float = 30.0
@export var precio_unguento: float = 40.0
@export var precio_bomba_humo: float = 35.0
@export var precio_sales: float = 25.0

@onready var _visual: ColorRect = $Visual

func _ready() -> void:
	add_to_group(GRUPO_HERBORISTERIAS)

## Precio de `tipo`, o -1.0 si no es un tipo valido. Lo llama el host desde
## player.gd submit_comprar_consumible() -- nunca el cliente, mismo motivo
## que Forja.precio_para_nivel().
func precio_de(tipo: String) -> float:
	match tipo:
		TIPO_PILDORA:
			return precio_pildora
		TIPO_UNGUENTO:
			return precio_unguento
		TIPO_BOMBA_HUMO:
			return precio_bomba_humo
		TIPO_SALES:
			return precio_sales
		_:
			return -1.0
