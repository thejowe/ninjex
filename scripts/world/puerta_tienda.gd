class_name PuertaTienda
extends Node2D
## Puerta de entrada a una tienda del Hub (scope nuevo H5+, ver
## plan-assets.md seccion 8 "Interiores de tienda" y plan-desarrollo.md
## seccion 2): punto estatico en el Hub que, en rango e interactuando (tecla
## "entrar_tienda", F11), transiciona al grupo entero a la escena de interior
## separada -- mismo patron de deteccion por distancia simple que
## TablonMisiones/ExtraccionMision, y mismo patron RPC host-autoritativo que
## confirm_iniciar_mision/confirm_volver_hub (ver player.gd
## submit_entrar_tienda, NetworkManager.confirm_entrar_tienda).
##
## `tienda_id` tiene que coincidir con una clave de
## NetworkManager.TIENDAS_INTERIOR -- si no coincide con ninguna, la puerta
## no hace nada (ver el guard en confirm_entrar_tienda).

## NOTA arte: `Visual` y `Luz` son placeholder (ColorRect), no arte final --
## ver CLAUDE.md ("No producir arte final antes de cerrar el combate (H1)").
## El pulso de `Luz` en `_ready` es solo para que la puerta se lea como
## interactuable (estilo "casa con ventana iluminada" de Pokemon) sin
## necesitar sprite. Cuando llegue el arte final de interiores (ver
## plan-assets.md seccion 8), este pulso se puede quitar o adaptar a un
## AnimatedSprite2D/Light2D real.

const GRUPO_PUERTAS_TIENDA := "puertas_tienda"

@export var tienda_id: String = ""
@export var nombre_visible: String = ""

@onready var _label: Label = $Label
@onready var _luz: ColorRect = $Luz

func _ready() -> void:
	add_to_group(GRUPO_PUERTAS_TIENDA)
	if _label != null:
		_label.text = nombre_visible
	if _luz != null:
		_iniciar_pulso_luz()

func _iniciar_pulso_luz() -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_luz, "modulate:a", 0.35, 0.9)
	tween.tween_property(_luz, "modulate:a", 1.0, 0.9)
