class_name Cambista
extends Node2D
## Punto de cambio simple (H3 tarea 1, plan-desarrollo.md linea 125): dinero
## manchado -> dinero limpio con comision. Mismo patron que Comprador
## (colocado a mano en test_room.tscn, deteccion por distancia simple, el
## HOST decide "en rango" al validar el RPC en player.gd) -- ver
## comprador.gd para el precedente, no hay Area2D ni estado de red propio
## porque el cambista es estatico.

const GRUPO_CAMBISTAS := "cambistas"

@export var radio_cambio: float = 70.0
## Comision del brief (plan-desarrollo.md linea 118 y brief 2.3): el 15% del
## dinero manchado se pierde al cambiarlo, se queda en el bolsillo del
## cambista. Exportado para poder ajustar sin tocar codigo, igual que los
## factores de ponderacion de Comprador.
@export var comision: float = 0.15

@onready var _visual: ColorRect = $Visual

func _ready() -> void:
	add_to_group(GRUPO_CAMBISTAS)

## Cuanto dinero limpio recibe el jugador por `cantidad` de dinero manchado.
## Lo llama el host desde player.gd submit_cambiar_dinero() -- nunca el
## cliente, mismo motivo que Comprador.calcular_precio(): que nadie pueda
## mentir sobre cuanto recibe.
func calcular_cambio(cantidad: float) -> float:
	return cantidad * (1.0 - comision)
