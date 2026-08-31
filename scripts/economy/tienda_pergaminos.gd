class_name TiendaPergaminos
extends Node2D
## Tienda de Pergaminos (H6 casino, Muelle Alto -- brief 2.3: "dentro: mesas,
## cambista, tienda de pergaminos, sala privada"). Vende, con FICHAS (no con
## dinero limpio/manchado -- ver regla invariante del brief seccion 4, nunca
## se convierten entre si), el desbloqueo permanente de la tecnica de Sellos
## de un estilo (ver style_data.gd grupo "Sellos" y player.gd
## submit_sellos_technique). Mismo patron de interaccion estatica que
## Forja/Sastreria: deteccion por distancia simple desde player.gd
## (_find_nearest_tienda_pergaminos_in_range), sin Area2D ni estado de red
## propio -- este nodo nunca cambia, solo expone el precio.
##
## A DIFERENCIA de Forja/Sastreria/Herboristeria (donde el gasto es del pool
## COMPARTIDO de dinero limpio y el resultado es individual), aqui el gasto
## TAMBIEN es individual: las fichas son de definicion del brief "se ganan
## jugando" -- cada jugador compra con SUS PROPIAS fichas, nunca con las del
## grupo. Ver NetworkManager.fichas y NetworkManager.pergaminos_sellos_comprados
## para el estado por jugador, y player.gd submit_comprar_pergamino para la
## validacion.
##
## Precio FIJO (no crece como los niveles de Forja): no hay "nivel" de
## pergamino, solo comprado/no comprado por estilo, igual de barato o caro
## para cualquier estilo -- mismo criterio de simplicidad que el precio fijo
## de Sastreria.precio_tinte.

const GRUPO_TIENDAS_PERGAMINOS := "tiendas_pergaminos"

@export var radio_compra: float = 80.0
@export var precio_pergamino: float = 150.0

@onready var _visual: ColorRect = $Visual

func _ready() -> void:
	add_to_group(GRUPO_TIENDAS_PERGAMINOS)
