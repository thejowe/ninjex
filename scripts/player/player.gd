extends CharacterBody2D
## Jugador. H1 tareas 3-6: movimiento WASD, apuntado con cursor, Basico
## encadenable de 3 golpes (sin coste) y chakra que solo se recupera
## golpeando.
##
## Red: la posicion/orientacion se replica con un MultiplayerSynchronizer
## (autoridad = el peer dueno del personaje, movimiento con prediccion
## local de siempre). El Basico y el chakra pasan por RPC hacia el host
## (peer 1), que es quien decide el resultado y lo retransmite a todos --
## eso es lo "host-autoritativo" para acciones, tal como pide el plan.
## No hay reconciliacion/rollback todavia: para 1 solo peer (este playtest)
## es un no-op porque el host y el unico jugador son el mismo peer; con un
## segundo jugador real (tarea futura) el flujo ya esta en el sitio
## correcto para anadir esa validacion sin reescribir el input.

const SPEED := 220.0
const DEFAULT_STYLE_PATH := "res://resources/styles/estilo_base.tres"

@export var style_data: StyleData

@onready var _legs: Node2D = $Visuals/Legs
@onready var _torso: Node2D = $Visuals/Torso
@onready var _camera: Camera2D = $Camera2D

## Chakra actual. Lo fija el host via confirm_basic_attack(); nunca sube
## solo con el tiempo (no hay _process que lo regenere).
var chakra_current: float = 0.0
## Golpe actual dentro de la cadena del Basico (0 = sin combo activo).
var combo_count: int = 0

var _combo_window_timer: float = 0.0

func _ready() -> void:
	if style_data == null:
		style_data = load(DEFAULT_STYLE_PATH)
	chakra_current = 0.0
	if is_multiplayer_authority():
		_camera.enabled = true
		_camera.make_current()

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		_handle_movement()
		_handle_aim()
		_handle_combo_timer(delta)
		if Input.is_action_just_pressed("attack_basic"):
			_request_basic_attack()
	move_and_slide()

func _handle_movement() -> void:
	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if input_dir.length() > 0.0:
		input_dir = input_dir.normalized()
		_legs.rotation = input_dir.angle()
	velocity = input_dir * SPEED

func _handle_aim() -> void:
	var to_cursor := get_global_mouse_position() - global_position
	if to_cursor.length() > 0.001:
		_torso.rotation = to_cursor.angle()

func _handle_combo_timer(delta: float) -> void:
	if combo_count > 0:
		_combo_window_timer -= delta
		if _combo_window_timer <= 0.0:
			combo_count = 0

## Pedido del cliente que controla este personaje. Se manda siempre al host
## (peer 1); si el peer local YA es el host, Godot resuelve la llamada en
## local sin red de por medio.
func _request_basic_attack() -> void:
	var aim_point := get_global_mouse_position()
	submit_basic_attack.rpc_id(1, aim_point)

## Se ejecuta SOLO en el host (autoridad de la accion). Valida que quien
## pide el golpe es el dueno de este personaje, calcula el resultado
## (combo + chakra recuperada + si toca soltar etiqueta) y lo retransmite
## a todos los peers, incluido el que lo pidio.
@rpc("any_peer", "call_local", "reliable")
func submit_basic_attack(aim_point: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id() # llamada local del propio host
	if sender_id != get_multiplayer_authority():
		return # alguien pidiendo un golpe con un personaje que no controla

	var next_combo := (combo_count % 3) + 1
	var recovered: float = style_data.chakra_recovered_per_hit
	var new_chakra: float = min(chakra_current + recovered, style_data.chakra_max)
	var spawn_tag := next_combo == 3

	confirm_basic_attack.rpc(next_combo, new_chakra, spawn_tag, aim_point)

## Resultado confirmado por el host. Se aplica en todos los peers por igual.
@rpc("any_peer", "call_local", "reliable")
func confirm_basic_attack(combo_index: int, new_chakra: float, spawn_tag: bool, aim_point: Vector2) -> void:
	combo_count = combo_index
	chakra_current = new_chakra
	_combo_window_timer = style_data.basic_combo_window
	if spawn_tag:
		_spawn_status_tag(aim_point)

func _spawn_status_tag(pos: Vector2) -> void:
	var effects_root: Node = NetworkManager.effects_root
	if effects_root == null:
		return
	var tag_scene: PackedScene = preload("res://scenes/combat/status_tag.tscn")
	var tag := tag_scene.instantiate()
	effects_root.add_child(tag)
	tag.global_position = pos
	tag.element = style_data.element_name
	tag.lifetime = style_data.basic_tag_duration
