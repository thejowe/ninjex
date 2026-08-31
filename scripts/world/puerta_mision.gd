class_name PuertaMision
extends StaticBody2D
## Puerta entre areas de una mision (H6): bloquea el paso hasta que el grupo
## de enemigos indicado esta vacio. Sin RPC ni logica de autoridad propia --
## el estado de "enemigo vivo/muerto" ya llega igual a todos los peers via el
## RPC morir() de EnemigoSimple (queue_free() en todos), asi que cada peer
## puede calcular "puerta abierta" mirando su propio arbol de escena, mismo
## criterio que aplicar_slow()/GroundZone usan para efectos sin RPC propio.

@export var grupo_enemigos_bloqueantes: String = ""

@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _visual: ColorRect = $Visual

func _physics_process(_delta: float) -> void:
	if grupo_enemigos_bloqueantes == "":
		return
	var abierta := get_tree().get_nodes_in_group(grupo_enemigos_bloqueantes).is_empty()
	_collision.set_deferred("disabled", abierta)
	_visual.visible = not abierta
