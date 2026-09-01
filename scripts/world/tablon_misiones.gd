class_name TablonMisiones
extends Node2D
## Tablon de misiones del Muelle (H6): punto de interaccion estatico donde el
## jugador elige uno de los cinco biomas. Mismo patron que Cambista/Comprador
## -- colocado a mano en la escena, deteccion por distancia simple resuelta
## en player.gd (_find_nearest_tablon_in_range), sin Area2D ni estado de red
## propio porque el tablon es estatico. La eleccion en si la resuelve
## NetworkManager.confirm_iniciar_mision (ver player.gd submit_elegir_mision).

const GRUPO_TABLONES := "tablones_mision"

## H6 (tarea pendiente de baja prioridad de plan-desarrollo.md): hasta ahora
## Comprador.Tipo.FALSIFICADOR/CLAN_RIVAL y Prisionero eran mecanismo puro --
## existian en codigo (ver comprador.gd, SOLO LECTURA desde aqui, y
## prisionero.gd) pero ninguna mision real los pedia como objetivo. Este
## diccionario engancha tres de los cinco biomas a un objetivo explicito que
## SI cambia como conviene pelear (mismo criterio de "hecho" que H2): Costa
## castiga quemar/aplastar porque el Falsificador de esa mision paga mal por
## cuerpos desfigurados, Peaje castiga rematar con contundente porque el Clan
## Rival de esa mision paga mal por un cuerpo "anonimo", y Cantera premia
## aguantar el Agarre del Taijutsu sin lanzar para someter en vez de matar.
## Bambu y Ruinas quedan sin entrada a proposito: siguen siendo la mision
## generica "mata al jefe y extrae", no hace falta forzar un objetivo especial
## en las 5 para que el enganche sea real -- solo en las que de verdad lo
## llevan colocado en su propia escena (ver mision_costa.tscn/
## mision_peaje.tscn/mision_cantera.tscn, nodo "Compradores").
const OBJETIVOS: Dictionary = {
	"costa": "Vende cadaveres al Falsificador de la zona: paga bien por cuerpos con la cara intacta, mal por cuerpos desfigurados (quemadura o aplastamiento) -- no rematas con Fuego si quieres cobrar aqui.",
	"peaje": "Vende cadaveres al Clan Rival del peaje: paga bien por una muerte con firma de tecnica (arma, elemento), mal por un cuerpo \"anonimo\" (contundente) -- evita rematar a puñetazo limpio si quieres cobrar aqui.",
	"cantera": "La Cantera Vieja es campo de trabajo forzado: aguanta el Agarre del Taijutsu SIN lanzar para someter en vez de matar y capturar un prisionero vivo (vale 2.5x un cadaver normal al venderlo).",
}

## Version corta del objetivo de arriba, solo para el aviso de interaccion del
## tablon (player.gd) -- el texto largo queda aqui como fuente de verdad de
## "por que", el corto es solo el "que" para no saturar el HUD de una linea.
const OBJETIVOS_CORTOS: Dictionary = {
	"costa": "vende al Falsificador",
	"peaje": "vende al Clan Rival",
	"cantera": "captura prisioneros",
}

## Orden y tecla fija de cada bioma -- mismo orden que NetworkManager.MISIONES
## y que el aviso original de player.gd (F1 Costa ... F5 Ruinas), solo que
## ahora la lista vive aqui para poder anotar el objetivo de cada uno sin
## tocar comprador.gd ni duplicar la lista de biomas en dos sitios.
const ORDEN_BIOMAS: Array[String] = ["costa", "bambu", "peaje", "cantera", "ruinas"]
const TECLAS_BIOMAS: Dictionary = {"costa": "F1", "bambu": "F2", "peaje": "F3", "cantera": "F4", "ruinas": "F5"}
const NOMBRES_BIOMAS: Dictionary = {"costa": "Costa", "bambu": "Bambu", "peaje": "Peaje", "cantera": "Cantera", "ruinas": "Ruinas"}

func _ready() -> void:
	add_to_group(GRUPO_TABLONES)

## Texto del objetivo explicito y largo de un bioma, o "" si es la mision
## generica sin objetivo especial (bambu/ruinas). Publico para que cualquier
## otra pantalla futura (p.ej. una UI de mision en curso) lo consulte sin
## duplicar el diccionario.
func objetivo_para(bioma_id: String) -> String:
	return OBJETIVOS.get(bioma_id, "")

## Linea completa que muestra player.gd al interactuar con el tablon --
## "Tablon de misiones -- F1 Costa (vende al Falsificador), F2 Bambu, ...".
## Antes era un string fijo en player.gd; ahora se construye aqui para que el
## objetivo explicito de cada mision quede al lado de su tecla, en el mismo
## sitio donde el jugador ya lee "F1 Costa, F2 Bambu...".
func texto_tablon() -> String:
	var partes: Array[String] = []
	for bioma_id in ORDEN_BIOMAS:
		var tecla: String = TECLAS_BIOMAS[bioma_id]
		var nombre: String = NOMBRES_BIOMAS[bioma_id]
		var tag: String = OBJETIVOS_CORTOS.get(bioma_id, "")
		if tag != "":
			partes.append("%s %s (%s)" % [tecla, nombre, tag])
		else:
			partes.append("%s %s" % [tecla, nombre])
	return "Tablon de misiones -- " + ", ".join(partes)
