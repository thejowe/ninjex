extends CanvasLayer
## Prologo textual antes de la primera partida (H6, brief seccion 5 y diseno
## seccion 2 "Puerto Bajo"). Paneles de texto secuenciales -- no hace falta
## un sistema de dialogo con arbol de opciones para este vertical slice
## (sobreconstruir para esta tanda). Cada peer lo ve solo en su propia
## pantalla: es ambientacion, no viaja por red ni bloquea a nadie mas.

signal finished

const LINEAS := [
	"Puerto Bajo, veinte años despues de la guerra.",
	"El clan perdio. Los que quedan sobreviven del contrabando: carne, secretos, lo que pese.",
	"Aqui nadie os apura. La aldea se sube despacio, de terraza en terraza, entre farolillos y madera humeda.",
	"Pero el dinero manchado no vale nada en la calle. Hay que subir al Muelle Alto y cambiarlo -- si el casino no se queda con demasiado.",
	"Antes de bajar al muelle, elegid como peleais.",
]

@onready var _label: Label = $Panel/Label

var _index := 0

func _ready() -> void:
	_show_line()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_advance()
		get_viewport().set_input_as_handled()

func _advance() -> void:
	_index += 1
	if _index >= LINEAS.size():
		finished.emit()
		return
	_show_line()

func _show_line() -> void:
	_label.text = LINEAS[_index]
