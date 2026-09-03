extends Node2D
class_name ZonePreview
## Indicador de carga de Zona (mantener Mayus/Shift, reasignada desde Q en
## el rework de combate 2026-09-03): aparece al pulsar, sigue al
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
	var color: Color
	match element:
		"fuego":
			color = Color(0.95, 0.35, 0.05, 0.6)
		"viento":
			color = Color(0.55, 0.85, 0.55, 0.55)
		"agua":
			color = Color(0.25, 0.6, 0.95, 0.6)
		"rayo":
			color = Color(0.95, 0.9, 0.3, 0.6)
		"tierra":
			color = Color(0.55, 0.4, 0.2, 0.6)
		_:
			color = Color(0.8, 0.8, 0.8, 0.5)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, color, 3.0)
	draw_circle(Vector2.ZERO, 4.0, color)
