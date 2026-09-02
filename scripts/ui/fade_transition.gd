extends CanvasLayer
## Fundido a negro reusable (scope nuevo H5+: transicion Hub<->interior de
## tienda "estilo Pokemon", ver plan-assets.md seccion 8 "Interiores de
## tienda" y plan-desarrollo.md seccion 2). Autoload global ("FadeTransition")
## para que cualquier punto del codigo (hoy: NetworkManager.confirm_entrar_tienda/
## confirm_salir_tienda) pueda pedir un fundido sin depender de que exista un
## Player concreto en la escena en ese instante -- mismo criterio que
## NetworkManager, que tambien es autoload.
##
## Puramente VISUAL y LOCAL a cada peer: no es un RPC ni necesita estado de
## red propio. Cada peer que recibe el confirm_* correspondiente (via
## call_local, igual que el resto del patron RPC del proyecto) dispara su
## propio fundido de forma independiente -- no hace falta que el frame exacto
## coincida entre peers, mismo razonamiento que brindis_time_remaining en
## network_manager.gd ("no hace falta que el segundo exacto coincida entre
## peers").
##
## CanvasLayer con layer alto (100) para quedar por encima de la camara del
## jugador y de su HUD (que vive en su propio CanvasLayer dentro de
## player.tscn, sin layer explicito == layer 1 por defecto).

const FADE_DURATION := 0.35

@onready var _rect: ColorRect = $ColorRect

func _ready() -> void:
	layer = 100
	_rect.color = Color(0, 0, 0, 0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

## Funde a negro, ejecuta `en_negro` (el swap de escena real: instanciar/
## liberar el interior y reposicionar jugadores), y funde de vuelta.
## `en_negro` es sincrona a proposito -- todo el trabajo real de
## confirm_entrar_tienda/confirm_salir_tienda (instantiate/add_child/
## queue_free) no necesita esperar nada, asi que no hace falta que este
## metodo acepte una version async de `en_negro`. Reentrante de forma segura:
## si se llama dos veces seguidas antes de terminar, create_tween() de la
## segunda llamada simplemente continua desde el color actual del ColorRect.
func play_transition(en_negro: Callable) -> void:
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var fade_out := create_tween()
	fade_out.tween_property(_rect, "color:a", 1.0, FADE_DURATION)
	await fade_out.finished
	if en_negro.is_valid():
		en_negro.call()
	var fade_in := create_tween()
	fade_in.tween_property(_rect, "color:a", 0.0, FADE_DURATION)
	await fade_in.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
