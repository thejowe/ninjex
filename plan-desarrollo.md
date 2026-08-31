# Plan de desarrollo

**Basado en:** `brief-traspaso-claude-code.md` + `diseno-juego-ninja.md` + el historial real de commits de este repo.
**Estado:** el juego tiene un vertical slice jugable funcionando (H1-H6 con recortes explícitos, ver abajo). Este documento se reescribió para reflejar la realidad del código, no una planificación previa a él — hubo desarrollo en paralelo (varias sesiones/agentes trabajando sobre el mismo repo) que avanzó más rápido que la documentación, así que este archivo se sincroniza contra `git log`, nunca al revés.

---

## 0. Decisiones confirmadas

| Decisión | Respuesta |
|---|---|
| Motor | **Godot 4** |
| Equipo | Un desarrollador de código en solitario + **una persona dedicada a assets** (ver `plan-assets.md`) |
| Alcance | Vertical slice jugable — **ya construido**, con recortes deliberados sobre el diseño original (detallados hito a hito abajo) |

**Preguntas abiertas del brief original — resueltas:**
- Fórmula de valor del cadáver: resuelta en `scripts/economy/economia_cadaveres.gd` (multiplicador base por tipo de daño, cortante 1.5 hasta quemadura 0.1).
- Ventana de sincronización de combos con latencia: resuelta con el patrón RPC `submit_*` (cliente) / `confirm_*` (host autoritativo) en todas las acciones de combate.
- Mando (gamepad): sigue fuera de alcance. No se ha tocado.
- Nombres definitivos de los 6 estilos: **resuelto**. Único cambio real: "Físico" → **"Taijutsu"** (`resources/styles/fisico.tres`, `style_name`). El resto (Fuego/Agua/Rayo/Viento/Tierra) ya tenía nombre definitivo desde el principio.

---

## 1. Estado real por hito (leer esto antes de lanzar cualquier agente)

### H1 — Prototipo de combate: **✅ hecho y validado**
Fuego, Viento, Taijutsu (ex-Físico) completos (Básico/Proyectil-Agarre/Zona-Lanzamiento/Impulso/Potenciador, Puertas), combinación Viento+Fuego (tormenta ígnea), enemigo simple host-autoritativo, segundo jugador validado con 2 instancias reales. Pasada de legibilidad visual (barras de vida/chakra, flash de golpe, screen shake, color por estilo) ya incluida, aunque sigue siendo **arte placeholder** (`ColorRect`/`Tween`, sin sprites finales).

### H2 — Bucle económico: **✅ hecho**
Cadáver con `estado_conservacion` por tipo de daño del golpe final, fórmula de valor, Carnicero y Boticario, carga de hasta 3 cadáveres con penalización de velocidad, venta al pool compartido `dinero_manchado`.

### H3 — Casino mínimo: **✅ hecho**
Cambista (15 % comisión), Mesa de Dados de tres caras con apuesta ajustable (sin mínimo fijo de 20) en manchado o limpio. HUD mínimo de dinero.

### H4 — Bóveda compartida: **✅ hecho, con alcance recortado por decisión explícita del usuario**
Solo se implementó **el Usurero** (presta cuando `dinero_manchado` y `dinero_limpio` están exactamente a cero, deuda real en negativo que se recorta un 20 % de las próximas 5 ganancias). **La votación grupal, la revelación de votos y el Modo Mesa Alta se descartaron por decisión explícita del usuario**: cualquier jugador del grupo puede apostar del bote común directamente, sin votar ni pedir permiso — la bóveda compartida ya existe de facto en `dinero_manchado`/`dinero_limpio` desde H2/H3. Esto **no es un olvido ni una suposición** — está confirmado en el brief y el diseño (sección "Bóveda compartida, sin votación").

### H5 — Hub, tiendas y taberna: **✅ hecho por completo**
Hub navegable en 4 alturas (Muelle con Taberna, Calle de los Faroles con Forja/Herboristería/Sastrería, Muelle Alto con el casino completo, Terrazas con la Casa del equipo). Forja (3 niveles de daño, techo +20 % respetado), Herboristería (4 consumibles, máx. 3 cargados), Taberna (brindis compartido: +15 % daño de grupo 180 s), **Sastrería** (tinte cosmético por jugador, sin efecto en balance) y **Casa del equipo** (Cocina: reducción de daño de grupo temporal; Almacén: +2 cadáveres cargables para todo el grupo; Jardín: descuento en Herboristería; Palomar bloqueado — depende del sistema de misiones que todavía no existe). Música/emotes/sillas/pizarra de deudas y récords siguen **sin construir** (nunca se asignaron a ningún agente todavía, no hay decisión de cortarlos — ver todolist).

### H6 — Estilos restantes e historia: **✅ combate, casino, arranque de historia y sistema de misión/biomas hechos**, resto **⬜ pendiente**
- **Combate**: Agua, Rayo, Tierra completos, 4 combinaciones de suelo nuevas (charco electrificado, barro, vapor, tormenta de polvo).
- **Sellos**: scaffold completo — acción `sellos` (mantener R + 3 direccionales, inmóvil mientras dura), grupo `Sellos` en `style_data.gd`, una técnica oculta placeholder por estilo (nova/corte/curación/descarga/puño sísmico/golpe fantasma). **Sin restricción de desbloqueo todavía**: cualquiera con el estilo equipado puede usarla ya — falta el sistema de pergaminos/fichas para que sea algo que se compre, no un freebie.
- **Casino**: los 4 juegos completos (Dados, Rueda del Clan, Cartas Selladas, Peleas del Sótano), medidor de sospecha por jugador (verde/ámbar/rojo), trampa de Viento en Dados y de Rayo en Cartas (la trampa de Sellos en Cartas sigue bloqueada, depende de pergaminos).
- **Prólogo y elección de estilo**: pantalla previa al spawn ya existe (`scenes/ui/prologo.tscn`, `scenes/ui/seleccion_estilo.tscn`), cada jugador elige su estilo antes de entrar y el host se lo asigna en `_spawn_player()` en vez del hardcodeado anterior.

- **Sistema de misión y biomas**: cambio de escena Hub↔Misión (instanciar/desinstanciar bajo `Misiones` en `main.tscn`, RPC `NetworkManager.confirm_iniciar_mision`/`confirm_volver_hub` igual en todos los peers), Tablón de misiones en el Muelle (F1-F5 elige bioma), y los 5 biomas (`scenes/world/mision_*`) con 3 áreas encadenadas por `PuertaMision` (se abre sola cuando el grupo de enemigos de esa área queda vacío, sin RPC propio — reutiliza que la muerte de `EnemigoSimple` ya replica igual en todos los peers), un jefe de zona por bioma (grupo `mision_jefe`) y `ExtraccionMision` (F6, bloqueada hasta matar al jefe) que devuelve al Hub cargando lo que se lleve encima. **Recorte documentado**: los 5 biomas comparten layout y disposición (solo cambian color/ambientación y las estadísticas de `EnemigoSimple` por `@export`); las particularidades del brief (marea, niebla, oscuridad, convoyes) no tienen mecánica propia todavía — es producción de nivel/arte futura, mismo criterio que ya se aplicó a Rueda del Clan/Peleas del Sótano. Sin temporizador forzado de 12-18 min (guía de contenido, no de código).

**Lo que NO se ha tocado todavía de H6**: fichas (tercera moneda) y tienda de pergaminos, Falsificador y clan rival como compradores, prisioneros vivos, historia/diálogos de NPCs más allá del prólogo.

**Aviso de tecla al acercarse a un punto de interacción** y varios **fixes de red/colisión** (jugador spawneaba en la esquina, dash atravesaba paredes, daño no se sincronizaba al segundo jugador, host nunca arrancaba el servidor) ya están hechos — no son tareas pendientes.

---

## 2. Qué queda por hacer de verdad (código) — todolist real

**Este checklist ES el todolist de código, no una copia.** Vive en este archivo a propósito, porque es lo único que llega igual a cualquier dispositivo con un `git pull` — una herramienta tipo `TaskList` puede no existir según el entorno donde corra la sesión (no es parte del repo, no viaja con git). Si en tu sesión sí existe una herramienta de tareas, úsala como ayuda visual si quieres, pero **la fuente de verdad es marcar `[x]` aquí y hacer commit** — nunca al revés.

- [ ] **Playtest de validación con gente real** de H4/H5/H6. Ninguno de los recortes de H4 (sin votación) se ha probado todavía con un grupo real jugando a la vez.
- [ ] **Fichas y tienda de pergaminos** (H6): la tercera moneda del brief, ganada jugando en el casino, que compra técnicas ocultas de Sellos. *Desbloquea* la trampa de Sellos pendiente en Cartas Selladas. Agente: `casino-agent`.
- [ ] **Falsificador, clan rival y prisioneros vivos** (H6) — *depende de los biomas/misión de abajo*: necesita objetivos y capturas que solo existen dentro de una misión real. Agente: `economy-agent`.
- [x] **Los 5 biomas y el sistema de misión** (H6): Costa, Bosque de Bambú, Camino de Peaje, Cantera Vieja, Ruinas del Clan — tres áreas encadenadas, jefe de zona, vuelta a extracción. Recorte documentado arriba (layout compartido, particularidades de brief pendientes de producción de nivel/arte). Agente: `narrative-agent`.
- [ ] **Historia y diálogos de NPCs** (H6, al final) — *depende de los biomas/misión*: tabernera, viejo maestro, usurero, pescador, con una línea nueva por misión completada. Agente: `narrative-agent`.
- [ ] **Extras de taberna**: música diegética, emotes, sillas, pizarra de deudas y récords. Sin asignar todavía, prioridad baja — es la capa acogedora, no bloquea nada del bucle jugable. Agente: `hub-agent`.

No se retoma la votación de bóveda ni el Modo Mesa Alta salvo que el usuario lo pida explícitamente — esa sí es una decisión de diseño confirmada, no scope pendiente.

**Sobre el arte:** deliberadamente no está en esta lista. El trabajo de assets tiene su propio plan (`plan-assets.md`) y su propio checklist de progreso (`assets-progreso.md`), gestionado por `arte-pilar-agent` — un sistema de seguimiento completamente aparte, para que ninguno de los dos equipos bloquee al otro. La única conexión es que `arte-pilar-agent` lee (nunca edita) la sección 1 de este documento para saber qué hitos de código ya están validados.

---

## 3. Estructura de carpetas (real, ya en uso)

```
res://
  scenes/
    main/                  # escena raíz, spawn de jugadores
    player/
    enemies/
    combat/
      zones/                # ground_zone, zone_preview
      projectiles/
    cadavers/
    economy/                 # cambista, comprador, forja, herboristeria, sastreria, casa_equipo, taberna, usurero, mesa_dados, ruleta, cartas_selladas, peleas_sotano
    world/
      test_room/             # sala de combate + casino
      hub/                    # Puerto Bajo (4 alturas)
    ui/                       # prologo.tscn, seleccion_estilo.tscn
  scripts/
    player/
    styles/                   # style_data.gd
    combat/                   # ground_zone, projectile, status_tag, zone_preview
    economy/
    network/                  # network_manager.gd (host-autoritativo)
    ui/                       # prologo.gd, seleccion_estilo.gd
  resources/
    styles/                    # .tres por estilo: fuego, viento, fisico(Taijutsu), agua, rayo, tierra
  assets/
    sprites/{legs,torso,fx}/    # todavía vacíos de arte final
    audio/
```

**Arquitectura de red:** host-autoritativo desde el primer commit. `MultiplayerSpawner`/`MultiplayerSynchronizer` para posición/estado, patrón RPC `submit_*` (cliente pide) / `confirm_*` (host resuelve y confirma a todos los peers) para toda acción de combate y economía.

**Sprite en 3 capas:** `legs` (dirección de movimiento) / `torso` (rota al cursor) / `fx` (efecto elemental independiente) — ya montado en `player.tscn`, pendiente de sustituir el placeholder por arte final.

---

## 4. Reglas invariantes (siguen vigentes para todo lo que falta)

- Ninguna técnica necesaria para avanzar en la historia está detrás del casino.
- Las técnicas compradas y el progreso de historia nunca entran en la bóveda; solo se arriesga dinero líquido.
- Las fichas no se venden por dinero real, ni directa ni indirectamente.
- Ninguna mejora permanente supera el +20 % sobre la base (ya respetado en Forja, Casa del equipo).
- Los bonus de comida y casa se aplican a todo el grupo, no solo a quien pagó (ya respetado en Taberna y Casa del equipo).
- Ningún estilo puede ser puramente de apoyo: todos hacen daño y todos aportan al grupo.

---

## 5. Agentes especializados

Los mismos 7 agentes de `.claude/agents/` siguen aplicando, con el dominio actualizado a lo que queda por hacer (ver el system prompt de cada uno para el detalle):

| Agente | Dominio | Qué le queda por delante |
|---|---|---|
| `pilar-agent` | Director de proyecto (código) | Siempre el primero — leer este documento actualizado antes de asignar nada, comparar contra `git log` porque puede haber avanzado más de una sesión en paralelo |
| `arte-pilar-agent` | Director de la parte visual | Coordina con `plan-assets.md`/`assets-progreso.md` — gran parte de H1-H6 ya puede pasar a arte final |
| `combat-agent` | Combate y estilos | Nada pendiente de combate puro por ahora — el siguiente enganche de Sellos (integrar con pergaminos) es tarea de `casino-agent` |
| `netcode-agent` | Red host-autoritativa | Mantenimiento y lo que necesiten las piezas nuevas |
| `economy-agent` | Cadáveres, compradores, tiendas de grupo | Falsificador, clan rival, prisioneros vivos (depende de biomas/misión) |
| `casino-agent` | Casino, bóveda | Fichas y tienda de pergaminos — es lo único que le queda. **La votación de bóveda y el Modo Mesa Alta están descartados, no los reintroduzcas sin que el usuario lo pida.** |
| `hub-agent` | Hub, tiendas, taberna | El hub mecánico y las 4 tiendas ya están completas. Le queda la capa acogedora de la Taberna: música, emotes, sillas, pizarra |
| `narrative-agent` | Historia, misiones, biomas | Prólogo y elección de estilo ya hechos. Le queda todo el sistema de misión + los 5 biomas + historia/diálogos de NPCs |
