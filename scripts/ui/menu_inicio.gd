extends CanvasLayer
## Pantalla de inicio (primera pantalla del juego, ver main.gd _run_menu_flow).
## Puramente de UI -- no toca red todavia, eso empieza en el lobby (ver
## scripts/ui/lobby.gd). Mismo estilo minimo/funcional que
## seleccion_estilo.gd/prologo.gd: placeholder hasta H1 cierre (CLAUDE.md).

signal jugar_pressed

@onready var _jugar_button: Button = $Panel/MarginContainer/VBox/JugarButton
@onready var _salir_button: Button = $Panel/MarginContainer/VBox/SalirButton

func _ready() -> void:
	_jugar_button.pressed.connect(_on_jugar_pressed)
	_salir_button.pressed.connect(_on_salir_pressed)
	_jugar_button.grab_focus()

func _on_jugar_pressed() -> void:
	jugar_pressed.emit()

func _on_salir_pressed() -> void:
	get_tree().quit()
