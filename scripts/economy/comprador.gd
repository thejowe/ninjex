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

enum Tipo { BOTICARIO, CARNICERO, FALSIFICADOR, CLAN_RIVAL, MAQUINA_EXPENDEDORA }

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
## Falsificador (H6, Calle de los Faroles): quiere "caras reconocibles,
## documentos, ropa" (brief 2.2 / diseno-juego-ninja.md "Mercado negro") --
## paga mal por "cuerpos desfigurados". Se mapea a estado_conservacion por
## que tipo de daño desfigura la cara: quemadura (la carboniza, ver el
## propio comentario de EconomiaCadaveres.MULTIPLICADOR_TIPO_DANO) y
## aplastamiento (el Lanzamiento del Fisico) son los unicos candidatos que
## de verdad destrozan un rostro; cortante/electrico/veneno/contundente
## dejan la cara intacta (un corte limpio o una quemadura de rayo puntual no
## desfiguran igual que carbonizar o aplastar el cuerpo entero).
@export var falsificador_factor_intacto: float = 1.5
@export var falsificador_factor_desfigurado: float = 0.3
## Clan rival (H6): quiere "bandas de la frente, armas, pruebas" -- paga mal
## por "cuerpos anonimos". Criterio DISTINTO al del Falsificador (a
## proposito, para que ambos compradores premien comportamientos de combate
## distintos en vez de ser el mismo comprador con otro nombre): lo que
## busca el clan no es una cara intacta sino una prueba de que fue un ninja
## rival quien lo mato, no un accidente cualquiera. Cortante/veneno/
## electrico/quemadura/aplastamiento dejan una firma de tecnica reconocible
## (arma blanca, elemento, lanzamiento); "contundente" es la unica categoria
## generica ("un golpe cualquiera") sin firma -- un cuerpo asi es "anonimo"
## para el clan aunque tenga la cara perfectamente reconocible.
@export var clan_factor_firma: float = 1.4
@export var clan_factor_anonimo: float = 0.3
## Maquina expendedora de cadaveres (idea nueva del usuario, quinto
## comprador de las misiones -- ver plan-desarrollo.md seccion 2): a
## diferencia de los otros cuatro, no tiene ningun bias por tipo de daño (no
## premia ni castiga cortante/quemadura/etc. por encima de
## MULTIPLICADOR_TIPO_DANO) -- es puramente "comodidad": comision fija del
## 15% sobre el precio ya ponderado por conservacion, sin favoritismo de
## comprador. Limitada por usos compartidos de grupo (ver
## NetworkManager.usos_maquina_restantes), no por este factor.
@export var maquina_factor_comision: float = 0.85

@onready var _visual: ColorRect = $Visual

func _ready() -> void:
	add_to_group(GRUPO_COMPRADORES)
	# Color de debug para distinguir a simple vista quien es quien mientras
	# no hay arte ni HUD -- no es una mecanica.
	match tipo:
		Tipo.BOTICARIO:
			_visual.color = Color(0.55, 0.75, 0.35, 1.0)
		Tipo.FALSIFICADOR:
			_visual.color = Color(0.75, 0.65, 0.85, 1.0)
		Tipo.CLAN_RIVAL:
			_visual.color = Color(0.75, 0.2, 0.2, 1.0)
		Tipo.MAQUINA_EXPENDEDORA:
			_visual.color = Color(0.5, 0.5, 0.6, 1.0)
		_: # CARNICERO
			_visual.color = Color(0.55, 0.4, 0.25, 1.0)

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
		Tipo.FALSIFICADOR:
			var mult_tipo: float = EconomiaCadaveres.MULTIPLICADOR_TIPO_DANO.get(estado_conservacion, 1.0)
			var desfigurado: bool = estado_conservacion == "quemadura" or estado_conservacion == "aplastamiento"
			var factor_comprador: float = falsificador_factor_desfigurado if desfigurado else falsificador_factor_intacto
			return valor_base * mult_tipo * factor_comprador
		Tipo.CLAN_RIVAL:
			var mult_tipo: float = EconomiaCadaveres.MULTIPLICADOR_TIPO_DANO.get(estado_conservacion, 1.0)
			var anonimo: bool = estado_conservacion == "contundente"
			var factor_comprador: float = clan_factor_anonimo if anonimo else clan_factor_firma
			return valor_base * mult_tipo * factor_comprador
		Tipo.MAQUINA_EXPENDEDORA:
			var mult_tipo: float = EconomiaCadaveres.MULTIPLICADOR_TIPO_DANO.get(estado_conservacion, 1.0)
			return valor_base * mult_tipo * maquina_factor_comision
		_:
			return 0.0
