extends Node2D
class_name ZonePreview
## Indicador de carga de Zona (mantener Q): aparece al pulsar, sigue al
## cursor y crece con el radio mientras se mantiene, se coloca al soltar.
##
## Puramente cosmetico y solo local a quien esta cargando -- no se replica
## a otros peers en esta tanda (mejora futura: replicarlo tambien para que
## el companero vea donde vas a colocar la zona mientras cargas).

@export var element: String = "fuego"
@export var radius: float = 55.0

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var color: Color = Color(0.95, 0.35, 0.05, 0.6) if element == "fuego" else Color(0.55, 0.85, 0.55, 0.55)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, color, 3.0)
	draw_circle(Vector2.ZERO, 4.0, color)
