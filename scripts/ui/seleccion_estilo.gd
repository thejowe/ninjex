extends CanvasLayer
## Pantalla de eleccion de estilo (H6): cada peer elige uno de los 6 estilos
## antes de spawnear. El resultado se manda al host via
## NetworkManager.submit_style_choice (ver main.gd _run_intro_flow), que lo
## usa en _spawn_player en vez del StyleData hardcodeado de antes.
##
## Sustituye a las teclas debug_style_* como mecanica REAL de eleccion --
## esas siguen existiendo solo como atajo de playtest en caliente (ver
## comentario de cabecera de player.gd _handle_debug_style_switch).
##
## Nombres definitivos de los 6 estilos (brief 2.1, pregunta abierta:
## "Fisico" era un marcador de posicion que sonaba a categoria de menu):
## Fuego, Agua, Rayo, Viento, Tierra y Taijutsu (el melee puro, sin chakra).
## Los nombres se leen de StyleData.style_name de cada .tres, no se repiten
## aqui a mano -- element_name/nombre de archivo NO se tocan, otros scripts
## ya los referencian por string.

signal estilo_elegido(path: String)

const RUTAS := [
	"res://resources/styles/fuego.tres",
	"res://resources/styles/agua.tres",
	"res://resources/styles/rayo.tres",
	"res://resources/styles/viento.tres",
	"res://resources/styles/tierra.tres",
	"res://resources/styles/fisico.tres",
]

@onready var _lista: VBoxContainer = $Panel/MarginContainer/VBox/Lista

func _ready() -> void:
	for i in RUTAS.size():
		var estilo: StyleData = load(RUTAS[i])
		var boton := Button.new()
		boton.text = "%d. %s" % [i + 1, estilo.style_name]
		boton.pressed.connect(_elegir.bind(RUTAS[i]))
		_lista.add_child(boton)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var idx: int = event.keycode - KEY_1
		if idx >= 0 and idx < RUTAS.size():
			_elegir(RUTAS[idx])
			get_viewport().set_input_as_handled()

func _elegir(path: String) -> void:
	estilo_elegido.emit(path)
