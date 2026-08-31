class_name Comprador
extends Node2D
## Punto de venta simple (H2 tarea 3): el jugador se acerca cargando
## cadaveres y pulsa "vender_cadaver" (V) para venderlos todos de golpe.
##
## No usa Area2D/deteccion fisica: el HOST decide "en rango" con una simple
## distancia (radio_venta) al validar submit_vender() en player.gd -- mismo
## criterio barato que ya usan los conos de ataque (_find_enemies_in_cone).
## Es estatico (colocado a mano en test_room.tscn, igual en todos los
## peers), asi que no necesita red propia: no cambia de estado en tiempo de
## ejecucion.

const GRUPO_COMPRADORES := "compradores"

enum Tipo { BOTICARIO, CARNICERO }

@export var tipo: Tipo = Tipo.CARNICERO
@export var radio_venta: float = 70.0

## Ponderacion del Boticario (organos frescos): paga extra por cortante/
## veneno, penaliza el resto -- un cuerpo carbonizado o aplastado no le
## sirve para nada.
@export var boticario_factor_fresco: float = 1.6
@export var boticario_factor_penalizado: float = 0.35
## El Carnicero es el "suelo garantizado" del brief: paga poco pero SIEMPRE
## compra. Precio fijo, ignora a proposito MULTIPLICADOR_TIPO_DANO -- le da
## igual como hayas matado al enemigo.
@export var carnicero_factor_fijo: float = 0.5

@onready var _visual: ColorRect = $Visual

func _ready() -> void:
	add_to_group(GRUPO_COMPRADORES)
	# Color de debug para distinguir a simple vista quien es quien mientras
	# no hay arte ni HUD -- no es una mecanica.
	_visual.color = Color(0.55, 0.75, 0.35, 1.0) if tipo == Tipo.BOTICARIO else Color(0.55, 0.4, 0.25, 1.0)

## Precio final que paga ESTE comprador por un cadaver con este estado de
## conservacion. Lo llama el host desde player.gd submit_vender() -- nunca
## el cliente, para que nadie pueda mentir sobre cuanto cobra por su cuerpo.
func calcular_precio(estado_conservacion: String, valor_base: float) -> float:
	match tipo:
		Tipo.CARNICERO:
			return valor_base * carnicero_factor_fijo
		Tipo.BOTICARIO:
			var mult_tipo: float = EconomiaCadaveres.MULTIPLICADOR_TIPO_DANO.get(estado_conservacion, 1.0)
			var fresco: bool = estado_conservacion == "cortante" or estado_conservacion == "veneno"
			var factor_comprador: float = boticario_factor_fresco if fresco else boticario_factor_penalizado
			return valor_base * mult_tipo * factor_comprador
		_:
			return 0.0
