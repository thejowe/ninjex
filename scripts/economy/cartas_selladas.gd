class_name CartasSelladas
extends Node2D
## Cartas Selladas (H6 casino, brief 2.3 / diseno-juego-ninja.md "El
## casino"): poker simplificado a "carta mas alta" contra 3 NPC -- sin motor
## de poker real (manos, rondas de apuesta, mazo compartido, etc.), cada
## jugada reparte una carta (1-13) al jugador y a cada NPC y gana quien
## saque la mas alta. Deliberadamente simple (alcance de la tarea: "no hace
## falta IA de combate nueva compleja... el foco es el estilo, no un motor
## de poker"). Mismo patron estatico que el resto del casino: colocada a
## mano, el HOST decide "en rango" al validar el RPC en player.gd, sin
## Area2D ni estado de red propio, RNG solo en el host.
##
## Dos trampas posibles segun el brief:
##
## - Con RAYO (jugar_mano(con_rayo), ver player.gd submit_jugar_cartas):
##   "acelerar tu turno y decidir con mas tiempo" se adapta, al no haber
##   timer de decision real en este vertical slice, a "reparte dos cartas y
##   quedate con la mejor" -- mecanicamente es lo mismo que pide el brief
##   (una ventaja de informacion/eleccion), solo que sin necesitar una UI de
##   cuenta atras que hoy no existe. Sube sospecha igual que la trampa de
##   Viento en la Mesa de Dados.
##
## - Con SELLOS (jugar_mano(con_sellos), H6 casino-agent): brief
##   diseno-juego-ninja.md linea 179, "con Sellos puedes ver una carta rival
##   durante medio segundo". Misma adaptacion de "informacion sin timer de
##   decision real" que Rayo de arriba: en vez de solo mostrar la carta sin
##   poder actuar sobre ella (lo que seria una trampa sin ningun efecto de
##   juego, y por tanto sin motivo para arriesgarse a subir sospecha por
##   ella), "conocer" la carta de un NPC concreto se traduce en
##   revelar_carta_npc(indice) tirando esa carta DOS veces y quedandose con
##   la MAS BAJA de las dos -- lo opuesto de con_rayo (que se queda con la
##   MEJOR de dos tiradas propias): aqui "sabes lo que va a salir" se
##   convierte en que esa carta concreta nunca puede ser la version mas alta
##   posible de si misma. Requiere tener el pergamino de Sellos comprado
##   para el estilo equipado (ver NetworkManager.pergaminos_sellos_comprados,
##   player.gd submit_jugar_cartas) -- la trampa usa la MISMA tecnica de
##   Sellos que el combate, ahora ya no gratis, ver H6 casino-agent.

const GRUPO_CARTAS_SELLADAS := "cartas_selladas"
const NUM_NPC := 3
const CARTA_MIN := 1
const CARTA_MAX := 13

@export var radio_apuesta: float = 70.0
@export var apuesta_minima: float = 1.0
## Pago total (incluye la apuesta) al ganar. Probabilidad base de ganar
## (jugador vs 3 NPC, cartas uniformes e independientes, sin empates
## especiales -- ver jugar_mano) es 1/4; pago justo seria 4.0x, 3.5x deja el
## mismo tipo de margen que el resto del casino (EV = 0.25 * 3.5 = 0.875,
## parecido al jackpot "clan" de la Ruleta).
@export var pago_ganador: float = 3.5

@onready var _visual: ColorRect = $Visual

func _ready() -> void:
	add_to_group(GRUPO_CARTAS_SELLADAS)

## Reparte una mano y resuelve el resultado. `con_rayo` llega ya validado
## por player.gd (estilo Rayo equipado + chakra suficiente) -- reparte DOS
## cartas al jugador y se queda con la mejor en vez de una sola, ver
## comentario de cabecera. Un empate entre el jugador y el mejor NPC se
## resuelve a favor de la casa (gano = false) para no complicar el reparto
## con un "push" que devuelva la apuesta.
func jugar_mano(con_rayo: bool, con_sellos: bool = false) -> Dictionary:
	var carta_jugador := randi_range(CARTA_MIN, CARTA_MAX)
	if con_rayo:
		carta_jugador = max(carta_jugador, randi_range(CARTA_MIN, CARTA_MAX))
	var mejor_npc := 0
	for i in range(NUM_NPC):
		var carta_npc: int = revelar_carta_npc(i) if (con_sellos and i == 0) else randi_range(CARTA_MIN, CARTA_MAX)
		mejor_npc = max(mejor_npc, carta_npc)
	var gano: bool = carta_jugador > mejor_npc
	return {"carta_jugador": carta_jugador, "mejor_npc": mejor_npc, "gano": gano, "pago": pago_ganador if gano else 0.0}

## Trampa de Sellos (ver comentario de cabecera): "conoce" -- y por tanto
## rebaja -- la carta de un NPC concreto tirandola DOS veces y quedandose
## con la mas baja, en vez de una tirada normal. Publico porque
## representa el gancho que la cabecera de este archivo pedia para
## desbloquear la trampa; jugar_mano() lo llama internamente para el NPC 0
## cuando con_sellos es true.
func revelar_carta_npc(indice: int) -> int:
	return min(randi_range(CARTA_MIN, CARTA_MAX), randi_range(CARTA_MIN, CARTA_MAX))
