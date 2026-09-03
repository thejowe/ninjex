extends Node2D
class_name MeleeTechniqueFx
## Feedback visual de las tecnicas de loadout Q/E (T2, rework de combate
## 2026-09-03) y del pool de tecnicas de pergamino equipadas en esos mismos
## huecos (T4) -- comparten esta escena porque comparten
## submit_loadout_technique()/confirm_loadout_technique() en player.gd.
##
## Bug de playtest (2026-09-03): la unica senal de que la tecnica se habia
## usado era el screen shake, y SOLO si conectaba (trigger_hit_shake) -- a
## diferencia de un Proyectil, que se ve aunque no impacte a nadie. Esta
## escena cubre ese hueco: se instancia SIEMPRE que se usa la tecnica
## (golpee o no), igual de presente que el resto del kit.
##
## Dos formas, igual que StyleData/PergaminoTechnique.shape: "cone" (Q de
## fabrica, y cualquier tecnica del pool con shape="cone") se dibuja como un
## arco relleno hacia facing_dir; "area" (E de fabrica / shape="area") como
## un circulo relleno alrededor del origen. NO es una Zona (esa es la ranura
## Mayus/GroundZone con la regla de "siempre plano en pantalla" -- ver
## diseno-juego-ninja.md) -- esto es un golpe puntual de melee, se dibuja en
## espacio de mundo normal como cualquier otro FX de ataque (igual que
## Projectile/StatusTag) y se autodestruye enseguida.

@export var shape: String = "cone" # "cone" o "area"
@export var element: String = "placeholder"
@export var facing_dir: Vector2 = Vector2.RIGHT
@export var range_or_radius: float = 80.0
@export var cone_degrees: float = 70.0
@export var lifetime: float = 0.22

var _age: float = 0.0

func _ready() -> void:
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)

func _process(delta: float) -> void:
	_age += delta
	queue_redraw()

## Mismos colores provisionales por elemento que status_tag.gd/zone_preview.gd
## -- solo para distinguir a simple vista durante el playtest, sin arte final.
func _base_color() -> Color:
	match element:
		"fuego":
			return Color(1.0, 0.42, 0.1)
		"viento":
			return Color(0.65, 0.9, 0.65)
		"fisico":
			return Color(0.85, 0.85, 0.85)
		"agua":
			return Color(0.3, 0.65, 0.95)
		"rayo":
			return Color(0.95, 0.9, 0.3)
		"tierra":
			return Color(0.55, 0.4, 0.2)
		_:
			return Color(1.0, 1.0, 1.0)

func _draw() -> void:
	var base := _base_color()
	var fade: float = clamp(1.0 - (_age / max(lifetime, 0.001)), 0.0, 1.0)
	var fill := Color(base.r, base.g, base.b, 0.55 * fade)
	var edge := Color(base.r, base.g, base.b, min(1.0, 0.9 * fade))
	if shape == "cone":
		var half_angle: float = deg_to_rad(cone_degrees * 0.5)
		var base_angle: float = facing_dir.angle()
		var steps := 16
		var points := PackedVector2Array([Vector2.ZERO])
		for i in range(steps + 1):
			var a: float = base_angle - half_angle + (deg_to_rad(cone_degrees) * i / float(steps))
			points.append(Vector2(cos(a), sin(a)) * range_or_radius)
		draw_colored_polygon(points, fill)
	else:
		draw_circle(Vector2.ZERO, range_or_radius, fill)
		draw_arc(Vector2.ZERO, range_or_radius, 0.0, TAU, 48, edge, 3.0)
