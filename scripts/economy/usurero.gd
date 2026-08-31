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
## brief-traspaso-claude-code.md 2.5), asi que en vez de "5 misiones" la
## deuda es un IMPORTE REAL (monto_prestamo + interes) que se paga con un
## recorte del mismo porcentaje sobre cada TRANSACCION QUE GENERA DINERO --
## una venta de cadaveres exitosa o una apuesta de dados ganada en la Mesa
## de Dados (ver player.gd confirm_vender/confirm_apostar_dados) -- hasta
## saldar el importe entero. Revisar esta adaptacion cuando exista el
## concepto real de mision.

const GRUPO_USUREROS := "usureros"

@export var radio_prestamo: float = 70.0

## Fondo minimo (decision de diseno: te saca del apuro -- alcanza para
## varias apuestas del monto por defecto en la Mesa de Dados (ver
## player.gd _apuesta_monto, 20.0 de partida, ajustable) -- pero no es gratis ni te deja
## comodo).
@export var monto_prestamo: float = 50.0

## Interes del prestamo (brief 2.3: "20%"): la deuda total a devolver es
## monto_prestamo * (1 + recorte_porcentaje) -- ver player.gd
## confirm_pedir_prestamo_usurero(). Se paga con un recorte de este mismo
## porcentaje sobre cada transaccion que genera dinero (venta exitosa o
## apuesta ganada) hasta saldar el importe entero, en vez de un numero fijo
## de transacciones -- si ganas poco cada vez tardas mas en pagar, si ganas
## mucho lo saldas antes. Adaptacion de "20% de las 5 misiones siguientes"
## del brief (el concepto real de mision no existe hasta H5+).
@export var recorte_porcentaje: float = 0.20

@onready var _visual: ColorRect = $Visual

func _ready() -> void:
	add_to_group(GRUPO_USUREROS)
