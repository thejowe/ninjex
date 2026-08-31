class_name TablonMisiones
extends Node2D
## Tablon de misiones del Muelle (H6): punto de interaccion estatico donde el
## jugador elige uno de los cinco biomas. Mismo patron que Cambista/Comprador
## -- colocado a mano en la escena, deteccion por distancia simple resuelta
## en player.gd (_find_nearest_tablon_in_range), sin Area2D ni estado de red
## propio porque el tablon es estatico. La eleccion en si la resuelve
## NetworkManager.confirm_iniciar_mision (ver player.gd submit_elegir_mision).

const GRUPO_TABLONES := "tablones_mision"

func _ready() -> void:
	add_to_group(GRUPO_TABLONES)
