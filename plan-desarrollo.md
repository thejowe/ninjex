# Plan de desarrollo

**Basado en:** `brief-traspaso-claude-code.md` + `diseno-juego-ninja.md`
**Estado:** plan aprobado para empezar H1. No hay código todavía.

---

## 0. Decisiones confirmadas con el usuario

| Decisión | Respuesta |
|---|---|
| Motor | **Godot 4** |
| Equipo y tiempo | **Un desarrollador en solitario** para código, **+ una persona dedicada a assets** (actualización: ya no es arte 100% comprado/propio del programador — ver `plan-assets.md`) |
| Alcance inmediato | **Vertical slice jugable** (H1→H4 como compromiso firme; H5-H6 planificados pero no prometidos aún) |

Consecuencias directas de estas respuestas:
- Estructura de proyecto en GDScript, escenas `.tscn`, `MultiplayerAPI` de alto nivel de Godot para red.
- Las tareas de código están ordenadas para que **cada hito sea jugable por sí mismo** antes de seguir — no hay margen para trabajar en paralelo en sistemas de código que no se validan.
- **Actualización de equipo:** el brief avisaba que "si hay más gente o un artista, el orden de tareas cambia". Al sumar una persona de assets, el trabajo de arte deja de depender 100% del código: puede avanzar guía de estilo, concept art y placeholders en paralelo a H1, y arte final se sincroniza con `plan-desarrollo.md` fase a fase. El detalle completo del trabajo de assets está en `plan-assets.md`.
- No se produce arte **final** (pulido) hasta que el combate de H1 esté cerrado y validado (regla del brief, sección 6) — pero sí se produce placeholder funcional, guía de estilo y concept art desde el principio, para no dejar a la persona de assets parada.

---

## 1. Qué es el juego (resumen para no perder el rumbo)

Acción cooperativa 2–4 jugadores, pixel art, cámara tres cuartos (~60°), twin-stick con teclado+ratón. Ninjas en una aldea portuaria en decadencia que vive del contrabando.

**Bucle central:**
`Pelea limpia → vendes el cadáver → cambias dinero manchado en el casino → compras técnicas → peleas mejor`

**Los tres sistemas que hacen que esto sea ESTE juego y no otro** (si alguno se pierde en el camino, el juego deja de ser el que describe el diseño):

1. **El valor del cadáver depende de cómo mataste.** El combate se optimiza por valor, no solo por daño. Fuego chamusca y no vale nada; un corte limpio vale caro.
2. **El casino es infraestructura, no minijuego.** Cambiar dinero manchado es obligatorio; apostar nunca lo es.
3. **La bóveda es compartida y se vota.** El botín es de los cuatro enteros. Arriesgarlo exige acuerdo del grupo.

Todo el plan de abajo existe para proteger estos tres sistemas, no para acumular features.

---

## 2. Puntos de diseño ambiguos — supuestos de trabajo

El brief pide señalar esto antes de codificar. Como pedir todo por adelantado frenaría el arranque, tomo un supuesto razonable y ajustable en cada caso, y lo marco con 🔶. Cuando llegue el hito correspondiente, se revisa con el usuario antes de darlo por cerrado.

| Pregunta abierta | Supuesto de trabajo | Se revisa en |
|---|---|---|
| Fórmula de valor del cadáver según daño | Tabla base multiplicador (ver §5, H2) por tipo de daño × comprador. Placeholder numérico, se ajusta jugando. | H2 |
| Sincronización de la ventana de combo (0,5 s) con latencia | El host sella con timestamp de servidor; la ventana efectiva se calcula como `0,5 s + RTT estimado del segundo jugador`, con un tope razonable (p. ej. 150 ms) para no premiar conexiones malas. | H1, paso "combinaciones" |
| ¿Mando entra en el alcance del prototipo? | 🔶 **Fuera de alcance del vertical slice.** Solo teclado+ratón en H1-H4. El input se abstrae desde el principio (capa `InputHandler`) para no reescribir todo cuando se añada mando más adelante. | Antes de H5/H6, si se decide meterlo |
| Nombres definitivos de los seis estilos (`Físico` suena a categoría de menú) | 🔶 Se mantiene `Físico` como nombre de trabajo en código y documentos. Alternativas a valorar más adelante: *Taijutsu*, *Puño de Hierro*, *Marcial*. No bloquea nada técnico — es solo texto/arte. | H6 (o antes, si aparece un nombre mejor) |

Si en algún punto uno de estos supuestos no encaja con lo que el usuario tenía en mente, se corrige ahí mismo sin esperar a terminar el hito.

---

## 3. Reglas invariantes (no se tocan aunque compliquen la implementación)

- Ninguna técnica necesaria para avanzar en la historia está detrás del casino.
- Las técnicas compradas y el progreso de historia nunca entran en la bóveda; solo se arriesga dinero líquido.
- Las fichas no se venden por dinero real, ni directa ni indirectamente.
- Ninguna mejora permanente supera el +20 % sobre la base.
- Los bonus de comida y casa se aplican a todo el grupo, no solo a quien pagó.
- Ningún estilo puede ser puramente de apoyo: todos hacen daño y todos aportan al grupo.
- El cooperativo va desde el primer commit: arquitectura host-autoritativa desde H1, aunque se pruebe en local.

Estas reglas están repetidas en los agentes especializados (sección 6) para que ninguna sesión de trabajo las pise por accidente.

---

## 4. Qué NO hacer (causas típicas de que el proyecto muera)

- Implementar los seis estilos antes de saber si el combate funciona con tres.
- Construir el mundo entero antes de tener una sala divertida.
- Empezar por la historia o el diálogo.
- Saltar directo a cuatro jugadores en red.
- Producir arte final antes de que el combate esté cerrado.

---

## 5. Hitos, dependencias y tareas concretas

### H1 — Prototipo de combate

**Depende de:** nada, es el punto de partida.
**Alcance:** Fuego, Viento y Físico. Una sala. Enemigos de comportamiento simple. Dos jugadores.
**Hecho cuando:** dos personas pelean 20 minutos seguidos sin aburrirse; la combinación Viento+Fuego colocada con el cursor se siente satisfactoria; el Físico llega a la pelea a tiempo sin sentirse excluido.

#### 5.1.0 Estructura de carpetas Godot 4 propuesta

```
res://
├── autoloads/              # Singletons: GameState, EventBus, NetworkManager
├── characters/
│   ├── player/
│   │   ├── player.tscn / player.gd
│   │   └── components/     # movement.gd, aiming.gd, chakra.gd, health.gd, input_handler.gd
│   ├── styles/
│   │   ├── _base/          # style_base.gd (interfaz de las 5 ranuras), slot definitions
│   │   ├── fuego/          # basico.gd, proyectil.gd, zona.gd, impulso.gd, potenciador.gd
│   │   ├── viento/
│   │   └── fisico/         # agarre.gd y lanzamiento.gd en vez de proyectil/zona, puertas.gd
│   └── enemies/
│       ├── enemy_base.tscn/gd
│       └── enemy_grunt.tscn # comportamiento simple para H1
├── combat/
│   ├── hitbox.gd, hurtbox.gd
│   ├── damage_type.gd       # enum: cortante, contundente, quemadura, electrico, aplastamiento, veneno
│   ├── status_zone.gd        # base de las Zonas de suelo, siempre dibujadas planas
│   ├── elemental_tag.gd      # etiqueta flotante de 1,5 s tras el 3er golpe del Básico
│   └── combo_resolver.gd     # detecta combinaciones de suelo y de cuerpo
├── network/
│   ├── network_manager.gd    # host-autoritativo, valida combos cliente vs host
│   └── synced_state.gd
├── levels/
│   └── h1_test_room/          # sala de prueba de H1
├── ui/
│   └── hud.tscn                # chakra, ranuras, salud
└── data/                        # Resources .tres: definición de cada estilo/habilidad
```

#### 5.1.1 Orden de implementación (uno depende del anterior, no saltar)

1. **Movimiento** — `CharacterBody2D`, input map WASD, física básica. Capa de sprite "piernas" sigue la dirección de movimiento (constraint de 3 capas del brief).
2. **Apuntado** — capa de sprite "torso" rota hacia la posición del cursor en el mundo, independiente de las piernas. Aquí se sienta la base del `InputHandler` abstraído (para que añadir mando después no obligue a reescribir combate).
3. **Básico** — melé encadenable de hasta 3 golpes por clics rítmicos, autoapuntado suave por cono, sin coste. El 3er golpe deja la `elemental_tag` flotando 1,5 s.
4. **Chakra** — recurso 0-100 **que solo se recupera golpeando con el Básico**, nunca con el tiempo. Es la regla crítica del brief: sin esto, el twin-stick degenera en acampar a distancia.
5. **Proyectil** — clic derecho, coste bajo, dirección al cursor.
6. **Zona** — mantener Q carga el indicador (radio/coste crecen con el tiempo mantenido), se coloca al soltar. Siempre plana en pantalla aunque el escenario esté en tres cuartos (constraint técnica explícita del brief).
7. **Impulso** — Espacio, movilidad/defensa con recarga corta.
8. **Potenciador** — E, se lanza sobre un aliado, dura 8 s, nunca afecta a quien lo lanza (fuerza a mirar al compañero).
9. **Combinaciones**
   - *De suelo*: Zona sobre Zona ya existente (Viento sobre Fuego = tormenta ígnea, etc.). Requiere solapamiento + chequeo de tipo elemental.
   - *De cuerpo*: Potenciador sobre aliado, ya cubierto en el paso 8; aquí se cierra la tabla completa de combinaciones de Fuego/Viento.
   - Ventana de sincronización ~0,5 s (ver supuesto técnico de la sección 2).
10. **Físico completo** — agarre (sustituye Proyectil), lanzamiento (sustituye Zona), Puertas (mantener F, tres niveles, sube daño/velocidad y drena vida, vulnerabilidad al cerrar proporcional al tiempo abierto; con Puertas abiertas los potenciadores recibidos duran el doble). Es el único estilo que puede meter enemigos dentro de Zonas ajenas — implementar ese caso especial aquí.
11. **Enemigo simple** — `enemy_grunt`: máquina de estados mínima (idle → persigue → ataca), sin pathfinding avanzado. Suficiente para probar el combate, no para IA definitiva.
12. **Segundo jugador (red)** — `NetworkManager` host-autoritativo. Los combos se validan en cliente y el host confirma, aceptando el resultado del cliente salvo que sea imposible. Se prueba primero en local (mismo PC, dos ventanas) antes de red real.

> Nota: los pasos 1-11 se pueden probar con un solo jugador local; el paso 12 es el que convierte el prototipo en cooperativo real. No se retrasa a "después" — es parte de H1 por regla del brief.

---

### H2 — Bucle económico

**Depende de:** H1 cerrado y validado.
**Alcance:** cadáveres con estado de conservación, carnicero y boticario, peso del botín, extracción.
**Hecho cuando:** el jugador cambia cómo pelea para conseguir mejores cuerpos, de forma observable.

Tareas:
1. Entidad "cadáver": se genera al morir un enemigo, leyendo el `damage_type` del golpe final desde `combat/damage_type.gd`.
2. Tabla de estado de conservación por tipo de daño (supuesto de trabajo, sección 2): cortante = alto valor, quemadura/aplastamiento = valor bajo o nulo, resto en punto medio.
3. Compradores: **carnicero** (compra todo, poco dinero — el suelo garantizado) y **boticario** (paga bien por cuerpos frescos sin quemar, mal por carbonizados/aplastados). Falsificador y clan rival quedan para H6 junto al resto de biomas/misiones ricas en esos objetos.
4. Peso del botín: cuantos más cuerpos cargues, más lento vuelves al punto de extracción. Sistema de inventario simple ligado a velocidad de movimiento.
5. Punto de extracción y flujo de "vuelta con el botín".
6. UI de venta mínima.

---

### H3 — Casino mínimo

**Depende de:** H2.
**Alcance:** cambista con comisión del 15 %, y el juego de dados de tres caras. Sin medidor de sospecha, sin pergaminos.
**Hecho cuando:** la comisión del 15 % pica lo suficiente como para que el jugador quiera intentar recuperarla jugando.

Tareas:
1. Tres monedas como recursos de `GameState`: manchada, limpia, fichas (fichas se introducen aquí aunque su única salida — pergaminos — llegue en H6; se necesitan ya porque H4 vota con fichas).
2. Cambista: manchada → limpia con 15 % de comisión.
3. Juego de dados de tres caras: apuesta alto/bajo, otorga fichas al ganar.
4. Sin trampas todavía (la mecánica de sospecha que las castiga es de H6) — se implementa el juego limpio primero.

---

### H4 — Bóveda y votación

**Depende de:** H3.
**Alcance:** bote compartido, votación con fichas, revelación de votos.
**Hecho cuando:** cuatro personas reales discuten antes de apostar. **Este hito se valida con gente, no con tests** — hay que jugarlo con 3 amigos más, no basta con QA en solitario.

Tareas:
1. Bóveda compartida: el dinero de la misión pertenece a los 4 jugadores enteros (no se divide).
2. Votación: cada jugador pone una ficha sobre la mesa para apostar de la bóveda. Tabla de máximo apostable según votos (1→20 %, 2→50 %, 3→75 %, 4→100 %).
3. Al resolver, mostrar quién votó a favor.
4. Usurero: si la bóveda llega a cero, ofrece fondo mínimo a cambio del 20 % de las próximas 5 misiones.
5. Modo Mesa Alta (opcional al crear partida): sin votación ni límites.

> Como el brief avisa que este hito depende de gente y no de código, conviene reservar tiempo de playtest con 3 personas más antes de darlo por cerrado, no solo tiempo de desarrollo.

---

### H5 — Hub y taberna

**Depende de:** H4.
**Alcance:** aldea navegable (Puerto Bajo, 4 alturas), tiendas de dinero limpio, taberna con brindis y desglose.
**Hecho cuando:** los jugadores se quedan en la taberna sin que nada les obligue.

Tareas:
1. Hub navegable: Muelle (nivel 0) → Calle de los Faroles (nivel 1) → Muelle Alto (nivel 2, casino) → Terrazas (nivel 3).
2. Tiendas de dinero limpio: forja (3 niveles de mejora de arma, sin aleatoriedad), sastrería (cosmético puro), herboristería (máx. 3 consumibles por jugador y misión), casa del equipo (mejoras compradas con la bóveda: cocina, almacén, palomar, jardín).
3. Taberna El Ancla Rota: brindis (bonus de grupo para la siguiente misión, mejor si las bebidas son distintas), desglose de contribución por jugador, pizarra de deudas y récords, música diegética con canciones desbloqueables, emotes/sillas sin función mecánica.
4. Reforzar aquí el freno de diseño: bonus de comida/casa se aplican a todo el grupo, ninguna mejora pasa de +20 %.

---

### H6 — Estilos restantes e historia

**Depende de:** H5.
**Alcance:** Agua, Rayo, Tierra, sistema de sellos y pergaminos, medidor de sospecha (trampas en el casino), prólogo y elección de estilo, biomas completos, falsificador y clan rival como compradores.

Aquí es donde se cierra el resto del diseño documentado en `diseno-juego-ninja.md` que no es estrictamente necesario para validar si el juego "funciona": historia, biomas restantes, Cartas Selladas y Peleas del Sótano, prisioneros vivos.

---

## 6. Agentes especializados creados

Para que el trabajo en cada sistema no se pise ni pierda las reglas invariantes al delegar tareas, se han creado subagentes en `.claude/agents/`, cada uno dueño de un dominio del juego. Se invocan con el Agent tool cuando toque trabajar en su área:

| Agente | Dominio | Se usa desde |
|---|---|---|
| `pilar-agent` | **Director de proyecto (código).** Contexto completo (diseño + plan + progreso real). Dice qué toca ahora y qué agente lanzar. No implementa nada. | **Siempre el primero, al empezar cada sesión de código** |
| `arte-pilar-agent` | **Director de la parte visual.** Contexto de `plan-assets.md` + `assets-progreso.md` + progreso de código, para saber si toca placeholder o arte final. Dice qué pieza tocar, con qué herramienta (Claude/PixelLab) y con qué specs. No genera arte él mismo. | **Siempre el primero, en la sesión de la persona de assets** |
| `combat-agent` | Movimiento, apuntado, las 5 ranuras por estilo, chakra, combinaciones, hitboxes | H1 |
| `netcode-agent` | Arquitectura multijugador host-autoritativo, validación de combos con latencia | H1 (paso 12) en adelante |
| `economy-agent` | Cadáveres, estado de conservación, compradores, peso, prisioneros vivos | H2 |
| `casino-agent` | Monedas, comisión, los 4 juegos, sospecha, bóveda y votación, Usurero | H3-H4 |
| `hub-agent` | Puerto Bajo, tiendas de dinero limpio, taberna El Ancla Rota | H5 |
| `narrative-agent` | Historia, misiones, biomas, diálogos, pergaminos/sellos | H6 |

Cada agente de sistema tiene embebidas las reglas invariantes de la sección 3 que le afectan, para no tener que repetírselas cada vez.

### Flujo de trabajo recomendado en cada sesión

1. **Lanzar `pilar-agent` primero.** Lee el brief, el diseño, este plan y el estado real del todolist (y del repo, por si algo quedó sin marcar), y responde con: dónde estamos, qué tarea toca, y qué agente hay que lanzar para hacerla.
2. **Lanzar el agente de sistema que indique el Pilar** (`combat-agent`, `netcode-agent`, etc.) para ejecutar esa tarea concreta.
3. Marcar la tarea como completada en el todolist (`TaskUpdate`) cuando esté hecha y validada.
4. En la siguiente sesión, volver a empezar por `pilar-agent` — nunca asumir de memoria en qué punto se quedó el proyecto.

---

## 7. Todolist de seguimiento

Se ha creado una lista de tareas rastreable (TaskCreate) que sigue exactamente el orden de esta sección 5, empezando por los 12 pasos de H1. Se irá marcando cada tarea como completada a medida que se implemente, y no se salta ninguna sin justificarlo explícitamente.
