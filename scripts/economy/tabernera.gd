class_name Tabernera
extends Node2D
## NPC fijo de la Taberna "El Ancla Rota" (H6 narrativa, brief 2.4 "Funcion
## acogedora": "cada NPC fijo tiene una linea nueva por mision completada").
## Mismo patron de interaccion estatica que Comprador/Cambista/Taberna:
## deteccion por distancia simple desde player.gd, sin Area2D ni estado de
## red propio -- el nodo en si nunca cambia de estado. La linea que muestra
## SI cambia, pero se calcula localmente a partir de
## NetworkManager.misiones_completadas (ya identico en todos los peers via
## RPC call_local de confirm_volver_hub), asi que no hace falta ningun RPC
## propio para mostrarla -- ver player.gd _request_hablar_tabernera(), mismo
## criterio de "solo local" que _toggle_apuesta_moneda().
##
## Historia pequeña de fondo (brief): la tabernera conoce a todo el que pasa
## por el Muelle. Sus lineas van de la cautela inicial a la calidez de quien
## ya reconoce caras.

const GRUPO_TABERNERAS := "taberneras"

@export var radio_dialogo: float = 70.0

## Array de {umbral, texto} ordenado por umbral ascendente -- se muestra el
## ultimo cuyo umbral sea <= misiones_completadas (agrupado por rangos, no
## una linea por cada mision exacta, tal y como pide la tarea).
const LINEAS := [
	{"umbral": 0, "texto": "Primera vez que te veo por El Ancla Rota. Bebe si quieres, pero no me debas nada que no puedas pagar."},
	{"umbral": 1, "texto": "Vaya, sigues de una pieza. Por aqui no todos vuelven a contarlo."},
	{"umbral": 3, "texto": "Ya casi eres de la casa. Guardo la silla del rincon para los que no se rinden."},
	{"umbral": 6, "texto": "Contigo el Muelle respira distinto. Ojala mi padre hubiera visto a alguien como tu antes de la guerra."},
	{"umbral": 10, "texto": "Cuando cierre esto, algun dia, quiero que se cuente que aqui bebio gente que no dejo caer a nadie."},
]

@onready var _visual: ColorRect = $Visual

func _ready() -> void:
	add_to_group(GRUPO_TABERNERAS)

## Ultima linea cuyo umbral no supera misiones_completadas. LINEAS siempre
## tiene un umbral 0, asi que esto nunca devuelve "".
func linea_para(misiones_completadas: int) -> String:
	var texto := ""
	for entrada in LINEAS:
		if entrada["umbral"] <= misiones_completadas:
			texto = entrada["texto"]
		else:
			break
	return texto
