class_name SillaTaberna
extends Marker2D
## Silla de la Taberna "El Ancla Rota" (H6 extra, ver comentario de cabecera
## de taberna.gd). Punto puramente cosmetico: marca donde un jugador puede
## sentarse (ver player.gd _request_taberna_sentarse/rpc_taberna_toggle_sentado).
## Sin script propio de comportamiento, solo un Marker2D con grupo -- mismo
## patron liviano de deteccion por distancia que el resto de puntos
## estaticos del hub (Comprador/Cambista/Taberna...), pero sin ningun
## export ni estado: una silla no tiene coste ni configuracion.

const GRUPO_SILLAS_TABERNA := "sillas_taberna"

func _ready() -> void:
	add_to_group(GRUPO_SILLAS_TABERNA)
