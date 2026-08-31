class_name Cadaver
extends Node2D
## Entidad "cadaver" de H2. Igual que EnemigoSimple, es una entidad de red
## host-autoritativa: el HOST decide spawn/recogida/venta y el resultado se
## retransmite igual a todos los peers.
##
## A diferencia de EnemigoSimple (nodo estatico, ya presente en la escena
## desde el arranque en todos los peers), un cadaver nace en una posicion
## variable cuando muere un enemigo, asi que no puede depender de "todos
## los peers ya tienen el mismo nodo". En su lugar se instancia identico en
## todos los peers dentro de un RPC call_local (EnemigoSimple.morir(), ver
## _spawn_cadaver() ahi) con un nombre de nodo determinista ("cadaver_<id>")
## para que despues sea direccionable por NodePath -- mismo truco que ya usa
## el Agarre del Fisico con los enemigos (grabbed_enemy_path en player.gd).
##
## Mientras se carga, la posicion la fija directamente quien lo lleva
## (player.gd _process_carry_hold, igual que el Agarre) y el
## MultiplayerSynchronizer de aqui abajo la retransmite al resto de peers.

const GRUPO_CADAVERES := "cadaveres"

## Tipo de daño del golpe FINAL que mato al enemigo -- determina el
## multiplicador base de la formula de valor (ver economia_cadaveres.gd).
## Lo fija EnemigoSimple al spawnear, ANTES de add_child (ver _ready()).
@export var estado_conservacion: String = "contundente"
## Valor base del enemigo antes de multiplicadores (viene de
## EnemigoSimple.valor_cadaver_base, copiado al spawnear).
@export var valor_base: float = 20.0

## Peer id de quien lo esta cargando. 0 = tirado en el suelo, libre para que
## cualquiera lo recoja. Lo cambia unicamente el host, dentro de los RPC
## confirm_pickup_cadaver/confirm_drop_cadaver/confirm_vender de player.gd.
var cargado_por_peer_id: int = 0

@onready var _visual: ColorRect = $Visual

func _ready() -> void:
	add_to_group(GRUPO_CADAVERES)
	_visual.color = _color_por_estado(estado_conservacion)

## Color de debug (sin arte todavia) para distinguir a simple vista el
## estado de conservacion mientras se prueba el flujo de venta -- no es una
## mecanica real, solo feedback de playtest.
func _color_por_estado(estado: String) -> Color:
	match estado:
		"cortante":
			return Color(0.75, 0.75, 0.85, 1.0)
		"veneno":
			return Color(0.45, 0.75, 0.25, 1.0)
		"electrico":
			return Color(0.85, 0.85, 0.2, 1.0)
		"aplastamiento":
			return Color(0.5, 0.35, 0.3, 1.0)
		"quemadura":
			return Color(0.15, 0.1, 0.1, 1.0)
		_: # "contundente" y cualquier tipo desconocido
			return Color(0.55, 0.5, 0.45, 1.0)
