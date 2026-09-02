class_name PuertaTienda
extends Node2D
## Puerta de entrada a una tienda del Hub (scope nuevo H5+, ver
## plan-assets.md seccion 8 "Interiores de tienda" y plan-desarrollo.md
## seccion 2): punto estatico en el Hub que, en rango e interactuando (tecla
## "entrar_tienda", F11), transiciona al grupo entero a la escena de interior
## separada -- mismo patron de deteccion por distancia simple que
## TablonMisiones/ExtraccionMision, y mismo patron RPC host-autoritativo que
## confirm_iniciar_mision/confirm_volver_hub (ver player.gd
## submit_entrar_tienda, NetworkManager.confirm_entrar_tienda).
##
## `tienda_id` tiene que coincidir con una clave de
## NetworkManager.TIENDAS_INTERIOR -- si no coincide con ninguna, la puerta
## no hace nada (ver el guard en confirm_entrar_tienda).

const GRUPO_PUERTAS_TIENDA := "puertas_tienda"

@export var tienda_id: String = ""
@export var nombre_visible: String = ""

@onready var _label: Label = $Label

func _ready() -> void:
	add_to_group(GRUPO_PUERTAS_TIENDA)
	if _label != null:
		_label.text = nombre_visible
