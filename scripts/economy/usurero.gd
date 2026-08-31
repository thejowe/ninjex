class_name Usurero
extends Node2D
## Punto de interaccion estatico (H4 recortado -- ver comentario de cabecera
## de la tarea del usuario, plan-desarrollo.md lineas 130-141 y brief 2.3
## adaptados: sin boveda con votacion ni Modo Mesa Alta, solo el Usurero).
## Mismo patron que Comprador/Cambista/MesaDados: colocado a mano en
## test_room.tscn, el HOST decide "en rango" por distancia simple al validar
## el RPC en player.gd (ver _find_nearest_usurero_in_range), sin Area2D ni
## estado de red propio -- el nodo en si nunca cambia de estado.
##
## Trigger (decision de diseno explicita del usuario): el Usurero solo
## concede el prestamo si AMBOS pools compartidos
## (NetworkManager.dinero_manchado y NetworkManager.dinero_limpio) estan
## exactamente a cero -- de verdad no queda nada de ningun tipo, no "estamos
## bajos de fondos". El nodo existe siempre en el mapa, visualmente igual
## sin importar el estado de los pools: anadir un estado visual
## activo/inactivo es sobreconstruir para un vertical slice sin arte
## todavia (decision de diseno, usa tu criterio segun pide la tarea). Quien
## de verdad aplica el trigger es player.gd
## submit_pedir_prestamo_usurero(), no este script.
##
## Adaptacion temporal de "20% de las 5 misiones siguientes" (brief 2.3): el
## vertical slice todavia no tiene el concepto de mision (llega en H5, ver
## brief-traspaso-claude-code.md 2.5), asi que el recorte se paga con las
## proximas num_transacciones_recorte TRANSACCIONES QUE GENERAN DINERO --
## una venta de cadaveres exitosa o una apuesta de dados ganada en la Mesa
## de Dados (ver player.gd confirm_vender/confirm_apostar_dados). Revisar
## esta adaptacion cuando exista el concepto real de mision.

const GRUPO_USUREROS := "usureros"

@export var radio_prestamo: float = 70.0

## Fondo minimo (decision de diseno: te saca del apuro -- alcanza para una
## apuesta de sobra en la Mesa de Dados (MesaDados.apuesta_fija = 20.0) con
## margen para intentarlo mas de una vez -- pero no es gratis ni te deja
## comodo).
@export var monto_prestamo: float = 50.0

## Recorte que sufren las proximas num_transacciones_recorte transacciones
## que generan dinero, ANTES de sumarse al pool correspondiente. El recorte
## no va a ningun sitio, simplemente se pierde -- es el pago de la deuda
## (brief 2.3: "20%").
@export var recorte_porcentaje: float = 0.20

## Cuantas transacciones que generan dinero quedan recortadas tras pedir el
## prestamo (adaptacion de "5 misiones", ver comentario de cabecera).
@export var num_transacciones_recorte: int = 5

@onready var _visual: ColorRect = $Visual

func _ready() -> void:
	add_to_group(GRUPO_USUREROS)
