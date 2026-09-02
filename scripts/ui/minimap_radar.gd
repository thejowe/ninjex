extends Control
class_name MinimapRadar
## Minimapa arriba-izquierda (HUD, scope nuevo 2026-09-02 -- ver plan-desarrollo.md).
## Radar abstracto en vez de mapa real: SubViewport con camara cenital seria
## mas caro y depende de un tileset que todavia no existe (ver CLAUDE.md,
## "no producir arte final antes de H1"). player.gd solo llama a
## set_companions() cada fotograma con la posicion relativa de cada
## companero -- toda la logica de dibujo vive aqui, asi que el dia que haya
## mapa real esto se puede reemplazar sin tocar player.gd.

const RADIUS := 44.0
## Unidades de mundo que caben del centro al borde del radar. Placeholder:
## no hay mapas reales todavia con los que calibrar a ojo (biomas de H6 sin
## terminar) -- ajustar cuando los haya.
const WORLD_RANGE := 900.0
const DOT_RADIUS := 4.0
const COMPANION_COLORS := [Color(1.0, 0.55, 0.1), Color(0.3, 0.8, 1.0), Color(0.85, 0.3, 0.9)]

var _companion_offsets: Array[Vector2] = []

## `offsets[i]` es la posicion del companero i relativa al jugador propio
## (companion.global_position - global_position), en unidades de mundo.
func set_companions(offsets: Array[Vector2]) -> void:
	_companion_offsets = offsets
	queue_redraw()

func _draw() -> void:
	var center := Vector2(RADIUS, RADIUS)
	draw_circle(center, RADIUS, Color(0.05, 0.05, 0.05, 0.6))
	draw_arc(center, RADIUS, 0.0, TAU, 32, Color(1, 1, 1, 0.5), 2.0)
	draw_circle(center, 3.0, Color(1, 1, 1, 0.9)) # jugador propio, siempre en el centro
	for i in range(_companion_offsets.size()):
		var scaled: Vector2 = _companion_offsets[i] / WORLD_RANGE * RADIUS
		if scaled.length() > RADIUS - DOT_RADIUS:
			scaled = scaled.normalized() * (RADIUS - DOT_RADIUS)
		draw_circle(center + scaled, DOT_RADIUS, COMPANION_COLORS[i % COMPANION_COLORS.size()])
