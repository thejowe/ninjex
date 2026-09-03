class_name TiendaPergaminos
extends Node2D
## Tienda de Pergaminos (H6 casino, Muelle Alto -- brief 2.3: "dentro: mesas,
## cambista, tienda de pergaminos, sala privada"). Vende, con FICHAS (no con
## dinero limpio/manchado -- ver regla invariante del brief seccion 4, nunca
## se convierten entre si), tecnicas del pool de pergaminos del estilo
## equipado (T4/T5, rework de combate 2026-09-03 -- ver style_data.gd
## StyleData.pergaminos_pool y player.gd submit_comprar_pergamino) para los
## huecos de loadout Q/E: cada compra aprende la siguiente tecnica del pool y
## el jugador elige a que hueco va, sustituyendo lo que hubiera antes (la
## sustituida queda aprendida-pero-no-equipada, reequipable gratis). Mismo
## patron de interaccion estatica que Forja/Sastreria: deteccion por
## distancia simple desde player.gd (_find_nearest_tienda_pergaminos_in_range),
## sin Area2D ni estado de red propio -- este nodo nunca cambia, solo expone
## el precio.
##
## A DIFERENCIA de Forja/Sastreria/Herboristeria (donde el gasto es del pool
## COMPARTIDO de dinero limpio y el resultado es individual), aqui el gasto
## TAMBIEN es individual: las fichas son de definicion del brief "se ganan
## jugando" -- cada jugador compra con SUS PROPIAS fichas, nunca con las del
## grupo. Ver NetworkManager.fichas y NetworkManager.pergaminos_aprendidos
## para el estado por jugador, y player.gd submit_comprar_pergamino para la
## validacion.
##
## Precio FIJO (no crece como los niveles de Forja) por tecnica comprada,
## igual de barato o caro para cualquier estilo o tecnica del pool -- mismo
## criterio de simplicidad que el precio fijo de Sastreria.precio_tinte. T5
## no toca este precio ni el mecanismo de fichas.

const GRUPO_TIENDAS_PERGAMINOS := "tiendas_pergaminos"

@export var radio_compra: float = 80.0
@export var precio_pergamino: float = 150.0

@onready var _visual: ColorRect = $Visual

func _ready() -> void:
	add_to_group(GRUPO_TIENDAS_PERGAMINOS)
