extends Resource
class_name StyleData
## Datos ajustables de UN estilo de combate (daños, costes, tiempos).
##
## Se guardan como .tres en res://resources/styles/ para poder tocar
## numeros en playtesting sin recompilar nada. Esta tanda (H1, tareas 1-6)
## solo necesita los campos para validar Basico + chakra; el resto de
## ranuras (Proyectil, Zona, Impulso, Potenciador) se anaden cuando toque
## esa tarea del plan.

@export var style_name: String = "Estilo base (placeholder)"
@export var element_name: String = "placeholder"

@export_group("Chakra")
## Chakra maximo del estilo. El chakra NUNCA se recupera con el tiempo,
## solo golpeando con el Basico (ver player.gd).
@export var chakra_max: float = 100.0
## Chakra recuperado por cada golpe conectado del Basico.
@export var chakra_recovered_per_hit: float = 12.0

@export_group("Basico")
@export var basic_damage: float = 8.0
## Ventana en segundos para encadenar el siguiente golpe antes de que el
## combo se reinicie a 0.
@export var basic_combo_window: float = 0.6
## Duracion de la etiqueta elemental que deja el tercer golpe.
@export var basic_tag_duration: float = 1.5
