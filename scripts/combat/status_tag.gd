extends Node2D
## Etiqueta elemental flotante que deja el tercer golpe del Basico.
##
## Placeholder de esta tanda: existe, se instancia en el punto de impacto y
## se autodestruye pasado su tiempo de vida. La logica de "otro jugador la
## activa para formar una combinacion" es una tarea futura (paso 11 del
## plan, combinaciones de suelo) y NO esta implementada aqui a proposito.

## Nombre del elemento que dejo la etiqueta (coincide con StyleData.element_name).
@export var element: String = "placeholder"
## Cuanto dura flotando antes de desaparecer sola. Lo fija quien la crea
## (normalmente StyleData.basic_tag_duration); 1.5 s es el valor por defecto.
@export var lifetime: float = 1.5

@onready var _visual: ColorRect = $Visual

func _ready() -> void:
	_apply_color()
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)

func _apply_color() -> void:
	# Colores provisionales solo para distinguir el elemento a simple vista
	# durante el playtest; no hay arte final todavia.
	match element:
		"fuego":
			_visual.color = Color(1.0, 0.42, 0.1, 0.9)
		"viento":
			_visual.color = Color(0.65, 0.9, 0.65, 0.9)
		"fisico":
			_visual.color = Color(0.85, 0.85, 0.85, 0.9)
		"agua":
			_visual.color = Color(0.3, 0.65, 0.95, 0.9)
		"rayo":
			_visual.color = Color(0.95, 0.9, 0.3, 0.9)
		"tierra":
			_visual.color = Color(0.55, 0.4, 0.2, 0.9)
		_:
			_visual.color = Color(1.0, 1.0, 1.0, 0.9)
