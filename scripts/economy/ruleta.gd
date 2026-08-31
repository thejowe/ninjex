class_name Ruleta
extends Node2D
## Rueda del Clan (H6 casino, brief 2.3 y diseno-juego-ninja.md "El casino"):
## ruleta con sectores, apuesta unica por ronda, pagos altos. SIN trampa
## posible -- es el juego limpio a proposito (a diferencia de Dados/Cartas,
## ningun estilo ni tecla oculta puede alterar el sector que sale). Mismo
## patron estatico que Cambista/MesaDados/Usurero: colocada a mano en
## test_room.tscn, el HOST decide "en rango" por distancia simple al validar
## el RPC en player.gd, sin Area2D ni estado de red propio -- el nodo en si
## nunca cambia de estado. RNG solo en el host, mismo motivo que
## MesaDados.resolver_tirada.

const GRUPO_RULETAS := "ruletas"

## 8 sectores: 3 rojo, 3 azul (las apuestas "seguras", 3/8 de probabilidad
## cada una) y 1 oro + 1 clan (jackpots, 1/8 cada uno).
const SECTORES: Array[String] = ["rojo", "azul", "rojo", "azul", "rojo", "azul", "oro", "clan"]

## Multiplicador de PAGO TOTAL (incluye la apuesta devuelta, no solo el
## neto) por categoria si el sector que sale coincide con tu eleccion --
## mismo criterio de "la casa gana a la larga por diseno" que mesa_dados.gd:
## EV(rojo) = EV(azul) = 3/8 * 1.8 = 0.675 (devuelve el 67.5% de media, un
## margen parecido al -1/3 neto de los Dados); EV(oro) = 1/8 * 5.0 = 0.625;
## EV(clan) = 1/8 * 7.0 = 0.875 -- el jackpot es el que mas cerca esta de
## ser "justo" (pagos altos, lo que pide la tarea), pero sigue sin llegar a
## 1.0 para que nadie tenga incentivo a apostar siempre ahi.
const PAGOS := {"rojo": 1.8, "azul": 1.8, "oro": 5.0, "clan": 7.0}

@export var radio_apuesta: float = 70.0
@export var apuesta_minima: float = 1.0

@onready var _visual: ColorRect = $Visual

func _ready() -> void:
	add_to_group(GRUPO_RULETAS)

## Categorias validas para elegir con la tecla (ver player.gd
## submit_girar_ruleta).
static func categorias() -> Array[String]:
	return ["rojo", "azul", "oro", "clan"]

## Gira la ruleta y resuelve el resultado para una `eleccion` (una de
## categorias()). Lo llama el host desde player.gd submit_girar_ruleta() --
## el RNG solo corre en el host para que el resultado sea autoritativo,
## mismo motivo que MesaDados.resolver_tirada().
func girar(eleccion: String) -> Dictionary:
	var sector: String = SECTORES[randi() % SECTORES.size()]
	var gano: bool = sector == eleccion
	var pago: float = PAGOS.get(eleccion, 0.0) if gano else 0.0
	return {"sector": sector, "gano": gano, "pago": pago}
