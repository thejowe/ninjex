class_name SalidaTienda
extends Node2D
## Punto de salida dentro de una escena de interior de tienda (scope nuevo
## H5+, ver plan-assets.md seccion 8 / plan-desarrollo.md seccion 2): vuelve
## al grupo entero al Hub (tecla "salir_tienda", F12). Mismo patron estatico
## que ExtraccionMision -- la validacion de rango vive en player.gd
## (submit_salir_tienda), aqui solo se registra el grupo para encontrarla.

const GRUPO_SALIDAS_TIENDA := "salidas_tienda"

func _ready() -> void:
	add_to_group(GRUPO_SALIDAS_TIENDA)
