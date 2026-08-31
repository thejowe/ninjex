# Plan de desarrollo

**Decisiones bloqueantes (confirmadas por el usuario):**
- Motor: **Godot 4**
- Equipo: **un desarrollador en solitario**, arte propio o comprado
- Alcance inmediato: **vertical slice jugable** (no el juego completo)

---

## Preguntas abiertas que siguen pendientes

Estas no bloquean el arranque de H1, pero hay que resolverlas antes de tocar el código que dependa de ellas:

| Pregunta | Bloquea |
|---|---|
| Fórmula concreta de valor del cadáver según tipo de daño | H2 (economía de cadáveres) |
| Cómo se sincroniza la ventana de 0,5 s de combo con latencia real | H1, tarea de combinaciones |
| Si el mando entra en el alcance del prototipo o se descarta | H1, sistema de apuntado |
| Nombres definitivos de los seis estilos (`Físico` es marcador de posición) | Cosmético, no bloquea código |

Se resuelven cuando toque esa tarea, no antes.

---

## Hitos y dependencias

```
H1 Prototipo de combate
 └─ H2 Bucle económico
     └─ H3 Casino mínimo
         └─ H4 Bóveda compartida
             └─ H5 Hub y taberna
                 └─ H6 Estilos restantes e historia
```

Cada hito depende estrictamente del anterior. No se empieza un hito sin el criterio de "hecho" del anterior cumplido.

---

## H1 — Prototipo de combate

Alcance: Fuego, Viento, Físico. Una sala, enemigos de comportamiento simple, dos jugadores.
**Hecho cuando:** dos personas pelean 20 min sin aburrirse, viento+fuego colocado con el cursor se siente bien, y el Físico llega a tiempo a la pelea.

### Estructura de carpetas (Godot 4)

```
res://
  scenes/
    main/            # escena raíz, spawn de jugadores
    player/
    enemies/
    combat/
      zones/         # escenas de efectos de suelo
      projectiles/
    world/
      test_room/
  scripts/
    player/
    styles/          # una clase por estilo (Resource o Node)
    combat/
      status_tag.gd  # etiqueta elemental flotante
    network/
  resources/
    styles/          # datos de cada estilo como Resource (.tres)
  assets/
    sprites/
      legs/
      torso/
      fx/
    audio/
```

Motivo de separar `resources/styles` de `scripts/styles`: los datos de cada estilo (daños, costes, tiempos) deben poder ajustarse sin tocar código, para iterar rápido en playtesting.

### Arquitectura base

- Host-autoritativo desde el primer commit (restricción técnica del brief). Usar `MultiplayerSpawner` + `MultiplayerSynchronizer` de Godot 4 para posición/estado, y RPCs para acciones (ataques, combos).
- Combos: el cliente ejecuta y valida localmente; el host confirma y solo corrige si el resultado es imposible (no si es distinto). Esto se implementa como una tarea propia, no se pospone: si se deja para el final, hay que reescribir el input del jugador.
- Sprite en 3 capas por personaje: `legs` (dirección de movimiento), `torso` (rota con el cursor), `fx` (efecto elemental, sprite independiente). Se monta como escena con 3 `Sprite2D`/`AnimatedSprite2D` hijos desde la primera tarea de movimiento, aunque el arte sea placeholder.

### Orden de implementación

1. **Setup del proyecto**: estructura de carpetas, control de versiones, escena `main` vacía.
2. **Arquitectura de red mínima**: `MultiplayerSpawner`, un jugador se conecta como host, arquitectura preparada para un segundo actor aunque el playtest inicial sea con uno solo.
3. **Movimiento**: teclado (WASD), capa `legs` orientada a la dirección de movimiento.
4. **Apuntado**: capa `torso` rota hacia el cursor. Placeholder de esquema de mando pendiente de la decisión abierta.
5. **Básico** (clic izq.): melé encadenable 3 golpes, sin coste. Tercer golpe deja la etiqueta elemental flotando 1,5 s.
6. **Chakra**: recurso por estilo, se recupera solo golpeando con el Básico. Sin esto los siguientes pasos no se pueden validar.
7. **Proyectil** (clic der.): coste bajo, va hacia el cursor.
8. **Zona** (Q): indicador previo, coste alto, se coloca en el punto del cursor.
9. **Impulso** (Espacio): movilidad o defensa, recarga corta.
10. **Físico completo**: sustituye Proyectil por agarre y Zona por lanzamiento; Puertas (3 niveles, drena vida, vulnerabilidad al cerrar).
11. **Combinaciones de suelo**: zona sobre zona (viento+fuego primero, es el caso de validación del hito).
12. **Potenciador** (E) y **combinaciones de cuerpo**: requiere un segundo jugador real para probarse con sentido.
13. **Segundo jugador en red**: pasar de un actor a dos, validar host-autoritativo con latencia real.
14. **Enemigos simples**: IA básica en la sala de prueba, sin comportamiento avanzado.
15. **Playtest de 20 minutos**: criterio de "hecho" del hito.

Nota de dependencia real: los pasos 12 y 13 están acoplados — el Potenciador no se puede validar de verdad sin el segundo jugador, así que en la práctica van juntos aunque el brief los liste por separado.

---

## H2 — Bucle económico

Depende de H1. Alcance: cadáveres con estado de conservación, carnicero y boticario, peso del botín, extracción.
**Hecho cuando:** el jugador cambia cómo pelea para conseguir mejores cuerpos, de forma observable.

Tareas:
1. Entidad cadáver con `estado_conservacion` determinado por el tipo de daño del golpe final (cortante, contundente, quemadura, eléctrico, aplastamiento, veneno).
2. Fórmula de valor por estado — **pendiente de la pregunta abierta**, resolver antes de esta tarea.
3. Carnicero (compra todo, poco dinero) y boticario (órganos frescos) como los dos primeros compradores.
4. Peso del botín: velocidad de vuelta al punto de extracción según carga.
5. Flujo de extracción completo: matar → recoger → volver → vender.

---

## H3 — Casino mínimo

Depende de H2. Alcance: cambista con comisión del 15 %, juego de dados. Sin sospecha, sin pergaminos.
**Hecho cuando:** la comisión pica lo suficiente como para querer recuperarla jugando.

Tareas:
1. Cambista: dinero manchado → limpia, comisión 15 %.
2. Dados de tres caras (apuesta alto/bajo).
3. Sin medidor de sospecha todavía — se añade en H6 junto con el resto de juegos y trampas.

---

## H4 — Bóveda compartida

Depende de H3. Alcance: bote compartido, apuesta libre por cualquier jugador del grupo, sin votación.
**Hecho cuando:** cualquier jugador puede apostar del bote común sin fricción y se siente dinero de todos. Se valida con gente, no con tests.

Tareas:
1. Bóveda compartida: el dinero de la misión pertenece a los cuatro jugadores enteros.
2. Cualquier jugador puede apostar directamente del pool compartido, sin votación ni límite por número de jugadores.
3. El Usurero cuando la bóveda llega a cero.

---

## H5 — Hub y taberna

Depende de H4. Alcance: aldea navegable, tiendas de dinero limpio, taberna con brindis y desglose.
**Hecho cuando:** los jugadores se quedan en la taberna sin que nada les obligue.

Tareas:
1. Hub navegable en cuatro alturas (Muelle, Calle de los Faroles, Muelle Alto, Terrazas).
2. Tiendas de dinero limpio: forja, sastrería, herboristería, casa del equipo.
3. Taberna: brindis con bonus de grupo, desglose de contribución, pizarra de deudas y récords.

---

## H6 — Estilos restantes e historia

Depende de H5. Alcance: Agua, Rayo, Tierra, sistema de sellos y pergaminos, prólogo, elección de estilo.

Tareas:
1. Estilos Agua, Rayo, Tierra completos (básico/proyectil/zona/impulso/potenciador + combinaciones nuevas).
2. Sellos: secuencia de 3 direccionales manteniendo R, técnicas ocultas de pergamino.
3. Resto de juegos de casino (ruleta, cartas selladas, peleas del sótano) y medidor de sospecha completo.
4. Prólogo, elección de estilo, resto de biomas de misión.

---

## Qué NO hacer todavía

Por orden explícito del brief, no antes de que el hito correspondiente esté cerrado:
- No implementar los 6 estilos antes de validar que 3 funcionan (H1).
- No construir el hub completo antes de tener una sala de combate divertida (H1 antes que H5).
- No empezar por historia o diálogo (eso es H6).
- No saltar a 4 jugadores en red directamente (H1 valida con 2).
- No producir arte final antes de cerrar el combate (H1).

---

## Siguiente paso

H1, tarea 1: setup del proyecto Godot 4 y estructura de carpetas. Agente a lanzar: **combat-agent** (todo H1 es combate: movimiento, apuntado, chakra, estilos, combinaciones, red host-autoritativo para el combate).
