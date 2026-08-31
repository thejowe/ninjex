class_name ExtraccionMision
extends Node2D
## Punto de extraccion al final de una mision (H6): vuelve al jugador al Hub
## cargando lo que lleve encima. Mismo patron estatico que TablonMisiones --
## la validacion de "en rango" y de "el jefe de la zona sigue vivo" vive en
## player.gd (submit_volver_hub), aqui solo se registra el grupo para que lo
## encuentre _find_nearest_extraccion_in_range.

const GRUPO_EXTRACCIONES := "extracciones_mision"

func _ready() -> void:
	add_to_group(GRUPO_EXTRACCIONES)
