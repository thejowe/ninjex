class_name MesaDados
extends Node2D
## Mesa de dados de tres caras (H3 tarea 2, plan-desarrollo.md linea 125 y
## brief 2.3). Mismo patron de punto de interaccion estatico que Comprador/
## Cambista: el HOST decide "en rango" por distancia simple al validar el
## RPC en player.gd, y aqui solo vive la logica de resultado -- sin Area2D
## ni estado de red propio porque la mesa nunca cambia de estado.
##
## Regla de las tres caras (decision de diseno: el brief no da mas detalle
## que "define tu la probabilidad/payout de forma simple y jugable"):
##   cara 1 (1/3) = BAJO gana
##   cara 2 (1/3) = NEUTRO -- pierdes la apuesta elijas lo que elijas
##   cara 3 (1/3) = ALTO gana
## Si tu eleccion coincide con la cara ganadora, te devuelven el DOBLE de la
## apuesta (+100% neto). Si no coincide, o sale la cara neutra, pierdes la
## apuesta entera. Valor esperado = 1/3*(+apuesta) + 1/3*(-apuesta) +
## 1/3*(-apuesta) = -apuesta/3: la casa gana a la larga por diseno -- es lo
## que hace que recuperar la comision del 15% del Cambista jugando "pique"
## de verdad (brief H3 "hecho cuando").
##
## Moneda de la apuesta (decision de diseno del usuario, fuera del texto
## literal del brief): player.gd deja elegir con la tecla M entre apostar
## "limpio" (seguro, ya paso por el Cambista) o "manchado" directo (salta
## el Cambista -- si ganas, blanqueas el doble sin pagar el 15%; si
## pierdes, lo pierdes igual). resolver_tirada() no sabe de monedas, solo
## calcula la cara y si acertaste -- quien paga o cobra y de que pool es
## decision de player.gd (submit_apostar_dados).

const GRUPO_MESAS_DADOS := "mesas_dados"
const CARA_BAJO := 1
const CARA_NEUTRO := 2
const CARA_ALTO := 3

@export var radio_apuesta: float = 70.0
## Apuesta ajustable (pedido del usuario: "que se pueda apostar todo lo que
## quieras, no un minimo de 20"). Ya no es un monto fijo -- solo el suelo
## para no poder apostar 0 ni negativo. El jugador ajusta cuanto apostar con
## +/- (ver player.gd _apuesta_monto/APUESTA_STEP) y esa cantidad viaja en
## el RPC submit_apostar_dados(); el host solo comprueba que sea >= esto y
## que haya fondos suficientes.
@export var apuesta_minima: float = 1.0

@onready var _visual: ColorRect = $Visual

func _ready() -> void:
	add_to_group(GRUPO_MESAS_DADOS)

## Tira los dados y resuelve el resultado para una eleccion "alto"/"bajo".
## Lo llama el host desde player.gd submit_apostar_dados() -- el RNG solo
## corre en el host para que el resultado sea autoritativo y no se pueda
## falsear ni predecir desde el cliente.
func resolver_tirada(eleccion: String) -> Dictionary:
	var cara := randi_range(CARA_BAJO, CARA_ALTO)
	var gano := (cara == CARA_BAJO and eleccion == "bajo") or (cara == CARA_ALTO and eleccion == "alto")
	return {"cara": cara, "gano": gano}

## Trampa retroactiva de Viento (H6, brief 2.3/diseno "El casino"): mantener
## una tecla usa Viento para "empujar" un dado justo antes de que pare. Ya
## no hay azar que resolver -- el resultado se fuerza a la cara que coincide
## con tu eleccion. Sigue viviendo aqui (no en player.gd) por el mismo
## motivo que resolver_tirada() de arriba: la logica de resultado de la mesa
## vive en el nodo de la mesa; player.gd (submit_apostar_dados) solo decide
## SI se puede usar (estilo Viento equipado, chakra suficiente) y llama a
## esta version en vez de la normal.
func resolver_tirada_forzada(eleccion: String) -> Dictionary:
	var cara := CARA_BAJO if eleccion == "bajo" else CARA_ALTO
	return {"cara": cara, "gano": true}
