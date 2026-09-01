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

### H5 — Hub, tiendas y taberna: **✅ hecho por completo, incluida la capa acogedora**
Hub navegable en 4 alturas (Muelle con Taberna, Calle de los Faroles con Forja/Herboristería/Sastrería, Muelle Alto con el casino completo, Terrazas con la Casa del equipo). Forja (3 niveles de daño, techo +20 % respetado), Herboristería (4 consumibles, máx. 3 cargados), **Sastrería** (tinte cosmético por jugador, sin efecto en balance) y **Casa del equipo** (Cocina: reducción de daño de grupo temporal; Almacén: +2 cadáveres cargables para todo el grupo; Jardín: descuento en Herboristería; Palomar bloqueado — depende del sistema de misiones, ver abajo, ya existe pero no se ha reenganchado). Taberna completa: brindis (+15 % daño de grupo 180 s), **pizarra de deudas** (fía el brindis sin fondos en vez de bloquear, `NetworkManager.taberna_deuda_pendiente`), **pizarra de récords** (pérdidas en el casino y cuerpos destrozados por jugador), **música diegética comprable** (lista fija de 3 canciones, recorte documentado de "se desbloquean según avanzas") y **emotes/sillas** cosméticos. Sin desglose de contribución todavía (bloqueado: depende del concepto de misión completada, que ya existe desde este mismo hito — candidato a reenganchar en la próxima pasada) ni "quién ha caído más veces" (bloqueado: no hay sistema de muerte/respawn de jugador).

### H6 — Estilos restantes e historia: **✅ combate, casino completo, Sellos+pergaminos, prólogo/estilo y sistema de misión/biomas hechos**, resto **⬜ pendiente**
- **Combate**: Agua, Rayo, Tierra completos, 4 combinaciones de suelo nuevas (charco electrificado, barro, vapor, tormenta de polvo).
- **Sellos y pergaminos**: scaffold de Sellos (acción R + 3 direccionales) + **Tienda de Pergaminos** en el Muelle Alto — cada técnica oculta se compra con **fichas** (tercera moneda, individual por jugador, ganada en los 4 juegos de casino) y queda gateada tras la compra (`NetworkManager.pergaminos_sellos_comprados`). Ya no es un freebie.
- **Casino**: los 4 juegos completos (Dados, Rueda del Clan, Cartas Selladas, Peleas del Sótano), medidor de sospecha por jugador, trampa de Viento en Dados y de Rayo **y de Sellos** en Cartas (`revelar_carta_npc`, desbloqueada ahora que existen los pergaminos).
- **Prólogo y elección de estilo**: pantalla previa al spawn (`scenes/ui/prologo.tscn`, `scenes/ui/seleccion_estilo.tscn`), cada jugador elige su estilo antes de entrar.
- **Sistema de misión y biomas**: cambio de escena Hub↔Misión (RPC `NetworkManager.confirm_iniciar_mision`/`confirm_volver_hub`), Tablón de misiones en el Muelle, y los 5 biomas (`scenes/world/mision_*`) con 3 áreas encadenadas por `PuertaMision`, jefe de zona por bioma y `ExtraccionMision` que devuelve al Hub cargando lo que se lleve encima. **Recorte documentado**: los 5 biomas comparten layout (solo cambian color/ambientación y stats de `EnemigoSimple`); particularidades del brief (marea, niebla, oscuridad, convoyes) son producción de nivel/arte futura. Sin temporizador forzado de 12-18 min.

**Lo que NO se ha tocado todavía de H6**: nada de lo listado en la versión anterior de este párrafo — ver abajo, ya está todo cerrado. Los diálogos de NPCs (tabernera, viejo maestro, usurero, pescador) ya están hechos (`NetworkManager.misiones_completadas`).

**Objetivo explícito de misión (H6, completado tras la redacción original de este documento)**: Costa, Peaje y Cantera ahora piden un objetivo real ligado a un comprador concreto (vender al Falsificador, vender al Clan Rival, capturar prisioneros vivos) en vez de la misión genérica "mata al jefe y extrae" — `scripts/world/tablon_misiones.gd`. Bambú y Ruinas quedan sin objetivo especial a propósito.

**Máquina Expendedora de cadáveres — quinto comprador (H6, scope nuevo pedido por el usuario, no estaba en `brief-traspaso-claude-code.md` ni `diseno-juego-ninja.md` originales)**: `Comprador.Tipo.MAQUINA_EXPENDEDORA` — paga el valor base con un 15 % de comisión fija, sin ponderar por tipo de daño (a diferencia de los otros cuatro compradores, que sí premian/penalizan según cómo mataste). Usos compartidos de grupo por misión (5 si el bioma tiene jefe de zona, 3 si no), se recargan de a uno cada 60 s de cooldown al agotarse (`NetworkManager.usos_maquina_restantes`/`usos_maquina_maximo`). Colocada en los 5 biomas junto al comprador de objetivo de cada uno. Es "comodidad": no exige optimizar el tipo de golpe, así que no compite con la regla de que el valor del cadáver depende de cómo mataste — sigue siendo mejor negocio vender a un comprador afín si el cuerpo encaja en su demanda.

**Falsificador, clan rival y prisioneros vivos (mecanismo)**: `Comprador.Tipo` tiene ahora `FALSIFICADOR` (paga mal por cuerpos desfigurados: quemadura/aplastamiento) y `CLAN_RIVAL` (paga mal por cuerpos "anónimos": contundente, sin firma de técnica) — criterios distintos y documentados en `comprador.gd`, ninguno reutiliza el del otro. Prisioneros vivos: aguantar el Agarre del Físico hasta el final (sin lanzar) ya no libera al enemigo, lo somete y genera un `Prisionero` cargable con el mismo sistema que `Cadaver` (`carried_cadaver_paths`/`MAX_CADAVERES_CARGADOS`); vale 2.5× un cadáver normal al venderse, y si muere mientras se carga (fuego amigo) se convierte en `Cadaver` normal en vez de perder el valor entero. **Decisión documentada**: la ranura Sellos (R + 3 direccionales) ya tiene sus 6 técnicas asignadas una por estilo, no queda hueco para una séptima de captura — se reutilizó el Agarre en su lugar, no la ranura que menciona el brief literalmente.

**Aviso de tecla al acercarse a un punto de interacción** y varios **fixes de red/colisión** (jugador spawneaba en la esquina, dash atravesaba paredes, daño no se sincronizaba al segundo jugador, host nunca arrancaba el servidor) ya están hechos — no son tareas pendientes.

---

## 2. Qué queda por hacer de verdad (código) — todolist real

**Este checklist ES el todolist de código, no una copia.** Vive en este archivo a propósito, porque es lo único que llega igual a cualquier dispositivo con un `git pull` — una herramienta tipo `TaskList` puede no existir según el entorno donde corra la sesión (no es parte del repo, no viaja con git). Si en tu sesión sí existe una herramienta de tareas, úsala como ayuda visual si quieres, pero **la fuente de verdad es marcar `[x]` aquí y hacer commit** — nunca al revés.

- [ ] **Playtest de validación con gente real** de H4/H5/H6. Ninguno de los recortes de H4 (sin votación) se ha probado todavía con un grupo real jugando a la vez.
- [ ] **Mob murciélago** (scope nuevo, pendiente para DESPUÉS del playtest — no lanzar todavía). Poca vida, estorba/interrumpe (sin ser una amenaza de daño relevante), no deja cadáver al morir, sin bioma asignado todavía (alcance genérico, no específico de un bioma concreto). Depende del veredicto del playtest de H4/H5/H6 de arriba. Agente: `combat-agent`.
- [x] **Fichas y tienda de pergaminos** (H6). Desbloqueó la trampa de Sellos en Cartas Selladas. Agente: `casino-agent`.
- [x] **Falsificador, clan rival y prisioneros vivos** (H6, mecanismo): compradores y captura vía Agarre construidos y documentados. Incluye el objetivo explícito de misión que engancha cada uno a un bioma concreto (Costa/Peaje/Cantera). Agente: `economy-agent`.
- [x] **Máquina Expendedora de cadáveres** (H6, quinto comprador, scope nuevo pedido por el usuario — no estaba en el diseño original, ver nota en sección 1 H6): comisión fija del 15 % sin ponderar por tipo de daño, usos compartidos de grupo con recarga por cooldown, colocada en los 5 biomas. Agente: `economy-agent`.
- [x] **Los 5 biomas y el sistema de misión** (H6): Costa, Bosque de Bambú, Camino de Peaje, Cantera Vieja, Ruinas del Clan — tres áreas encadenadas, jefe de zona, vuelta a extracción. Agente: `narrative-agent`.
- [x] **Historia y diálogos de NPCs** (H6, al final): tabernera, viejo maestro, usurero, pescador, con una línea nueva por misión completada. Agente: `narrative-agent`.
- [x] **Extras de taberna**: música diegética, emotes, sillas, pizarra de deudas y récords. Agente: `hub-agent`.
- [x] **Desglose de contribución de la Taberna**: quedó bloqueado en H5 por falta del concepto de misión — ya existe, se puede reenganchar. Baja prioridad. Agente: `hub-agent`.

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
      mision_costa/, mision_bambu/, mision_peaje/, mision_cantera/, mision_ruinas/  # los 5 biomas
      tablon_misiones.tscn, puerta_mision.tscn, extraccion_mision.tscn
    ui/                       # prologo.tscn, seleccion_estilo.tscn
  scripts/
    player/
    styles/                   # style_data.gd
    combat/                   # ground_zone, projectile, status_tag, zone_preview
    economy/                  # incluye tienda_pergaminos.gd, silla_taberna.gd
    network/                  # network_manager.gd (host-autoritativo)
    ui/                       # prologo.gd, seleccion_estilo.gd
    world/                    # tablon_misiones.gd, puerta_mision.gd, extraccion_mision.gd
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
| `combat-agent` | Combate y estilos | Nada pendiente |
| `netcode-agent` | Red host-autoritativa | Mantenimiento y lo que necesiten las piezas nuevas |
| `economy-agent` | Cadáveres, compradores, tiendas de grupo | Nada pendiente. Falsificador/clan rival/prisioneros con objetivo de misión y la Máquina Expendedora (quinto comprador) ya están hechos |
| `casino-agent` | Casino, bóveda | Nada pendiente. **La votación de bóveda y el Modo Mesa Alta están descartados, no los reintroduzcas sin que el usuario lo pida.** |
| `hub-agent` | Hub, tiendas, taberna | Nada pendiente. Hub, 4 tiendas, capa acogedora de Taberna y desglose de contribución completos |
| `narrative-agent` | Historia, misiones, biomas | Sistema de misión, 5 biomas, prólogo, elección de estilo y diálogos de NPCs hechos. Nada pendiente propio (ver ítems de baja prioridad de `economy-agent`/`hub-agent`) |
