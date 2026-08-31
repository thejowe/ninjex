class_name Pescador
extends Node2D
## NPC fijo del Muelle (puestos de pescado), mismo patron y mismo criterio
## "solo local" que Tabernera (ver ese fichero para el porque no hace falta
## RPC propio para mostrar la linea).
##
## Historia pequeña de fondo (brief): vive del pescado y de lo que el
## contrabando deja caer al agua. Sus lineas son las mas terrenales de los
## tres -- lo que se cuece en el puerto, sin metersen en la guerra del clan.

const GRUPO_PESCADORES := "pescadores"

@export var radio_dialogo: float = 70.0

const LINEAS := [
	{"umbral": 0, "texto": "Pescado del dia, si es que hoy hay dia. El agua del Muelle ya sabe a otra cosa desde que subio el contrabando."},
	{"umbral": 1, "texto": "Anoche saque una red rara del fondo. No pregunto de donde sale lo que pasa por aqui de noche -- me va mejor asi."},
	{"umbral": 3, "texto": "La gente empieza a hablar de vosotros en los puestos. Buena señal o mala, segun a quien le preguntes."},
	{"umbral": 6, "texto": "Desde que andais por aqui vendo mas pescado que nunca -- la gente sale de casa con menos miedo."},
	{"umbral": 10, "texto": "Cuando mis hijos pregunten por que el Muelle sigue en pie, les voy a hablar de vosotros."},
]

@onready var _visual: ColorRect = $Visual

func _ready() -> void:
	add_to_group(GRUPO_PESCADORES)

func linea_para(misiones_completadas: int) -> String:
	var texto := ""
	for entrada in LINEAS:
		if entrada["umbral"] <= misiones_completadas:
			texto = entrada["texto"]
		else:
			break
	return texto
