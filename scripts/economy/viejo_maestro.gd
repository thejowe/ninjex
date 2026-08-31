class_name ViejoMaestro
extends Node2D
## NPC fijo de las Terrazas (ruinas del clan), mismo patron y mismo criterio
## "solo local" que Tabernera (ver ese fichero para el porque no hace falta
## RPC propio para mostrar la linea).
##
## Historia pequeña de fondo (brief): el unico que queda del clan que perdio
## la guerra, vive entre las ruinas de las Terrazas. Sus lineas van del duelo
## por lo perdido a una esperanza cautelosa en quien sigue peleando.

const GRUPO_VIEJOS_MAESTROS := "viejos_maestros"

@export var radio_dialogo: float = 70.0

const LINEAS := [
	{"umbral": 0, "texto": "Estas ruinas eran el dojo. Ahora solo quedan las piedras y un viejo que no supo morir con los demas."},
	{"umbral": 1, "texto": "Te moviste como alguien de nuestro estilo, alla afuera. O quizas solo quiero verlo."},
	{"umbral": 3, "texto": "El clan no volvera. Pero lo que ensenamos, parece que todavia sirve para algo -- para ti, al menos."},
	{"umbral": 6, "texto": "Ya no sueño con la guerra. Sueño con que alguien recuerde la tecnica sin recordar la derrota."},
	{"umbral": 10, "texto": "Si algun dia me falta el aliento entre estas piedras, que sea sabiendo que el clan sigue vivo en alguien."},
]

@onready var _visual: ColorRect = $Visual

func _ready() -> void:
	add_to_group(GRUPO_VIEJOS_MAESTROS)

func linea_para(misiones_completadas: int) -> String:
	var texto := ""
	for entrada in LINEAS:
		if entrada["umbral"] <= misiones_completadas:
			texto = entrada["texto"]
		else:
			break
	return texto
