class_name Prisionero
extends Node2D
## Entidad "prisionero vivo" de H6 (brief-traspaso-claude-code.md 2.2 y
## diseno-juego-ninja.md "Mercado negro": "capturas del estilo Sellos").
##
## DECISION DE DISEÑO explicita (documentada porque el brief dice "del
## estilo Sellos" y esto NO nace de ahi): las 6 tecnicas Sellos ya estan
## asignadas 1 a 1 por estilo -- nova (fuego), corte/arrastre (viento),
## curacion (agua), descarga (rayo), puño sismico (tierra), golpe fantasma
## (fisico) -- ver style_data.gd grupo "Sellos". No queda hueco libre para
## una septima tecnica de captura sin pisar una ya construida y jugada. En
## su lugar, la captura reutiliza el Agarre del Fisico ya existente: sujetar
## hasta el final de grab_hold_duration SIN lanzar ya no libera al enemigo,
## lo somete y genera este Prisionero (ver player.gd
## _schedule_grab_someter/confirm_someter_prisionero). Es el candidato que
## el propio brief señala como mas probable para "capturar vivo".
##
## Igual que Cadaver: entidad host-autoritativa que nace dentro de un RPC
## call_local (confirm_someter_prisionero en player.gd) con nombre de nodo
## determinista ("prisionero_<id>", mismo contador que Cadaver via
## NetworkManager.next_cadaver_id -- ambos son "cosas que nacen en un RPC
## call_local y necesitan nombre unico", no hace falta un segundo contador
## solo para esto). Se recoge/carga/vende reutilizando EXACTAMENTE el mismo
## sistema que Cadaver en player.gd (carried_cadaver_paths,
## MAX_CADAVERES_CARGADOS, cargado_por_peer_id): no hay un sistema de carga
## paralelo, solo ramas "is Cadaver / is Prisionero" en los puntos donde
## player.gd ya distinguia el tipo concreto.
##
## A diferencia de Cadaver, SIGUE VIVO: esta en GRUPO_ENEMIGOS ademas de en
## su propio grupo, para que cualquier tecnica de area (Basico/Zona/Sellos/
## Impulso) pueda alcanzarlo por error -- el diseño pide explicitamente "no
## atacar por error" (diseno-juego-ninja.md linea 228), lo que solo tiene
## sentido si de verdad puede morir por fuego amigo mientras se transporta.

const GRUPO_PRISIONEROS := "prisioneros"
const GRUPO_ENEMIGOS := "enemigos"

## Vida con la que nace un prisionero recien sometido. Numero bajo a
## proposito: ya esta inmovilizado, no en pelea, pero un par de golpes reales
## siguen pudiendo matarlo -- el riesgo real que pide el brief, no un simple
## adorno de UI.
@export var vida_actual: float = 20.0
## Valor base copiado de EnemigoSimple.valor_cadaver_base al capturar (ver
## player.gd confirm_someter_prisionero). Se multiplica por
## EconomiaCadaveres.MULTIPLICADOR_PRISIONERO al vender -- ver el comentario
## de esa constante para por que NO pasa por Comprador.calcular_precio como
## un Cadaver normal.
@export var valor_base: float = 20.0

## Peer id de quien lo esta cargando. 0 = tirado en el suelo, libre para que
## cualquiera lo recoja. Identico significado y ciclo de vida que
## Cadaver.cargado_por_peer_id -- lo cambia unicamente el host, dentro de los
## mismos RPC confirm_pickup_cadaver/confirm_drop_cadaver/confirm_vender de
## player.gd (ahora con una rama "is Prisionero" junto a la de Cadaver).
var cargado_por_peer_id: int = 0

@onready var _visual: ColorRect = $Visual

func _ready() -> void:
	add_to_group(GRUPO_PRISIONEROS)
	add_to_group(GRUPO_ENEMIGOS)
	# Color de debug (piel/atado, sin arte todavia) distinto de cualquier
	# estado_conservacion de Cadaver para que se distinga a simple vista.
	_visual.color = Color(0.85, 0.75, 0.55, 1.0)

## Interfaz identica a EnemigoSimple.recibir_daño (mismo nombre: el resto del
## kit de combate lo llama por duck-typing via has_method(), ver
## _find_enemies_in_cone/_apply_impulse_* en player.gd -- no hace falta que
## Prisionero herede de nada para ser atacable por error).
func recibir_daño(tipo_daño: String, cantidad: float) -> void:
	if not multiplayer.is_server():
		return
	if vida_actual <= 0.0:
		return
	vida_actual -= cantidad
	if vida_actual <= 0.0:
		# Igual que EnemigoSimple.recibir_daño con el id de cadaver: se pide
		# UNA vez aqui (esta linea solo la ejecuta el host, ver el guard de
		# arriba) y viaja como argumento del RPC -- si cada peer lo pidiera
		# por su cuenta dentro de morir(), cada uno tiraria de SU PROPIO
		# contador local (nunca avanzado en clientes) y colisionaria con ids
		# de cadaveres ya usados por el host.
		morir.rpc(NetworkManager.next_cadaver_id(), tipo_daño)

## DECISION DE DISEÑO explicita (brief: "si muere mientras se carga, decide
## tu si se convierte en cadaver normal o se pierde el valor entero"): se
## convierte en un Cadaver normal con el tipo de daño que lo mato. Perder el
## valor ENTERO de golpe castigaria un descuido de fuego amigo mas de lo que
## vale la pena en un vertical slice; perder solo el "premium" de ir vivo
## (MULTIPLICADOR_PRISIONERO) comunica igual el riesgo sin ser punitivo, y
## reutiliza el flujo de venta de Cadaver ya existente sin codigo nuevo.
@rpc("any_peer", "call_local", "reliable")
func morir(cadaver_id: int, tipo_dano_final: String) -> void:
	var root: Node = NetworkManager.cadavers_root
	var nuevo_cadaver_path := NodePath("")
	if root != null:
		var scene: PackedScene = preload("res://scenes/cadavers/cadaver.tscn")
		var cadaver: Cadaver = scene.instantiate()
		cadaver.estado_conservacion = tipo_dano_final
		cadaver.valor_base = valor_base
		cadaver.name = "cadaver_%d" % cadaver_id
		root.add_child(cadaver)
		cadaver.global_position = global_position
		nuevo_cadaver_path = cadaver.get_path()
	# Si alguien lo estaba cargando, que su lista de carga pase a apuntar al
	# Cadaver nuevo en vez de quedarse con un NodePath muerto (contaria para
	# siempre contra MAX_CADAVERES_CARGADOS sin que hubiera nada que vender).
	if cargado_por_peer_id != 0 and NetworkManager.players_root != null:
		var jugador: Node = NetworkManager.players_root.get_node_or_null(str(cargado_por_peer_id))
		if jugador != null and jugador.has_method("reemplazar_prisionero_por_cadaver"):
			jugador.reemplazar_prisionero_por_cadaver(get_path(), nuevo_cadaver_path)
	queue_free()
