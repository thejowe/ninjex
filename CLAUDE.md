# Ninjex — contexto de proyecto

Juego de acción cooperativa 2–4 jugadores, Godot 4, host-autoritativo desde el primer commit.
Ver `brief-traspaso-claude-code.md`, `diseno-juego-ninja.md` y `plan-desarrollo.md` para el diseño y plan completos.

## Estilo visual

- **Pixel art.** Tamaños de canvas (ver `plan-assets.md` sección 1 para el detalle completo):
  - Tiles de entorno (suelo/pared): 32×32 px
  - Personajes (por capa: legs/torso/fx): 32×48 px
  - Iconos de inventario: 16×16 px
  - Muebles y objetos grandes: 32×64 o 64×64 px
- Cámara en tres cuartos (~60°).
- Sprite de personaje en 3 capas: `legs` (dirección de movimiento), `torso` (rota con el cursor), `fx` (efecto elemental, sprite independiente).
- No producir arte final antes de cerrar el combate (H1) — hasta entonces, placeholder.

## Agentes del proyecto

Cualquier agente que trabaje en este repo (combat-agent, casino-agent, assets-agent, etc.) debe respetar la especificación de arte de arriba.
