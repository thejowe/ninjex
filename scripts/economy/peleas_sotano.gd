class_name PeleasSotano
extends Node2D
## Peleas del Sotano (H6 casino, brief 2.3 / diseno-juego-ninja.md "El
## casino"): apuestas sobre un combate de NPC que el jugador NO controla --
## "el foco es la apuesta social, no el combate en si" (alcance de la
## tarea), asi que no hay IA de combate nueva: cada apuesta se resuelve al
## instante con una tirada ponderada por el peso de cada contendiente, mismo
## patron autoritativo (RNG solo en el host) que MesaDados.resolver_tirada /
## Ruleta.girar. Varios jugadores pueden apostar sobre el MISMO duelo en
## curso porque, igual que la Mesa de Dados, es un punto estatico compartido
## sin votacion ni estado de ronda propio -- "el duelo" no es una partida
## persistente que haya que esperar a que termine, cada apuesta es su propia
## tirada independiente contra los mismos dos contendientes. Sin trampa: el
## brief no menciona ninguna para este juego.

const GRUPO_PELEAS_SOTANO := "peleas_sotano"

@export var nombre_izquierda: String = "El Carnicero"
@export var nombre_derecha: String = "Mano de Piedra"
## Peso relativo de cada contendiente (no hace falta que sumen 1 -- se
## normalizan en resolver_apuesta()). Ajustable en el editor para dar
## favoritos/infravalorados sin tocar codigo, mismo criterio que
## Comprador.factores.
@export var peso_izquierda: float = 1.0
@export var peso_derecha: float = 1.0

@export var radio_apuesta: float = 70.0
@export var apuesta_minima: float = 1.0
## Pago total (incluye la apuesta) por acertar al ganador. Con pesos
## iguales (50/50) el pago justo seria 2.0x; 1.8x deja un margen parecido al
## resto del casino (EV = 0.5 * 1.8 = 0.9) sin necesitar la logica de "casa
## gana a la larga" mas agresiva de los Dados, porque aqui no hay ninguna
## trampa que compense el margen.
@export var pago_ganador: float = 1.8

@onready var _visual: ColorRect = $Visual

func _ready() -> void:
	add_to_group(GRUPO_PELEAS_SOTANO)

## Resuelve una apuesta a "izquierda" o "derecha". Lo llama el host desde
## player.gd submit_apostar_pelea() -- RNG solo en el host, mismo motivo que
## el resto del casino.
func resolver_apuesta(eleccion: String) -> Dictionary:
	var total_peso: float = peso_izquierda + peso_derecha
	var tirada: float = randf() * total_peso
	var gana_izquierda: bool = tirada < peso_izquierda
	var ganador: String = "izquierda" if gana_izquierda else "derecha"
	var gano: bool = ganador == eleccion
	return {"ganador": ganador, "gano": gano, "pago": pago_ganador if gano else 0.0}
