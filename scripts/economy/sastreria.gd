class_name Sastreria
extends Node2D
## Sastreria (H5 cierre, Calle de los Faroles, junto a Forja/Herboristeria).
## Cosmetico puro (brief 2.4 / diseno "Tiendas y dinero limpio": "no afecta
## al equilibrio"): SIN bonus de ningun tipo, solo apariencia. Mismo patron
## de interaccion estatica que Forja/Herboristeria: deteccion por distancia
## simple desde player.gd, sin Area2D ni estado de red propio.
##
## Es POR JUGADOR (cada uno elige su propio tinte) pagado del pool
## COMPARTIDO de dinero limpio -- mismo criterio que Forja/Herboristeria: el
## gasto es compartido, el resultado es individual. Estado persistente en
## NetworkManager.sastreria_tinte_indice (Dictionary peer_id -> indice de
## PALETA_TINTES), mismo patron que NetworkManager.forja_nivel.
##
## Decision de alcance (vertical slice, sin arte final todavia): en vez de
## variantes de sprite reales (ropa/mascaras/bandas distintas como pide el
## brief), se usa un tinte de color simple sobre el sprite placeholder del
## jugador -- Player aplica PALETA_TINTES[indice] como modulate del nodo
## Visuals completo (torso+piernas a la vez), sin tocar los colores base por
## estilo (_torso_color_base/_legs_color_base siguen dependiendo solo del
## elemento, ver _style_base_colors) ni la interpolacion de las Puertas. Es
## el mismo tipo de recorte que taberna.gd documenta para el brindis: cambiar
## esto a variantes de sprite reales es tarea de arte futura, no de esta
## tanda.

const GRUPO_SASTRERIAS := "sastrerias"

@export var radio_tinte: float = 80.0

## Precio fijo por cada cambio de tinte (no crece como los niveles de Forja
## -- es cosmetico, no hay "nivel" que perseguir, solo elegir cual te gusta).
@export var precio_tinte: float = 20.0

## Paleta de tintes disponibles, en el orden en que los cicla una sola tecla
## (R, ver player.gd submit_sastreria_siguiente_tinte). Sin variantes de
## sprite reales todavia (ver comentario de cabecera), asi que cada entrada
## es solo un color que se aplica como modulate.
const PALETA_TINTES: Array[Color] = [
	Color(1.0, 1.0, 1.0, 1.0), # sin tinte (blanco = identidad, no altera el color base)
	Color(0.85, 0.2, 0.2, 1.0), # banda roja
	Color(0.2, 0.35, 0.9, 1.0), # banda azul
	Color(0.85, 0.75, 0.15, 1.0), # dorado
	Color(0.55, 0.15, 0.65, 1.0), # purpura/mascara
	Color(0.12, 0.12, 0.12, 1.0), # negro sigiloso
]

@onready var _visual: ColorRect = $Visual

func _ready() -> void:
	add_to_group(GRUPO_SASTRERIAS)
