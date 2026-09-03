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

**Panel de HUD fijo, companeros y minimapa (scope nuevo pedido por el usuario, 2026-09-02, no estaba en `brief-traspaso-claude-code.md` ni `diseno-juego-ninja.md` originales)**: hasta esta tarea, vida y chakra solo existían como barras flotantes sobre la cabeza (`Visuals/StatusBars`, espacio de mundo) y `$HUD` (CanvasLayer, espacio de pantalla) solo tenía dinero/estado/interacción. Se añadió a `player.tscn`/`player.gd`:
- `$HUD/OwnStatsPanel`: vida y chakra propios, grandes, fijos arriba a la derecha (`_update_own_stats_panel()`), con texto numérico ("Vida 86/100"). Chakra se oculta igual que la barra de mundo cuando `style_data.chakra_max <= 0` (Taijutsu).
- `$HUD/CompanionsPanel`: hasta 3 filas (`Row1`/`Row2`/`Row3`, partida de 2-4 jugadores) con vida/chakra en pequeño de cada compañero conectado, ordenadas por peer_id para que no salten de fila (`_nearby_companions()`/`_update_companions_panel()`).
- `$HUD/MinimapRadar` (`scripts/ui/minimap_radar.gd`): radar abstracto arriba a la izquierda — círculo de fondo + un punto de color por compañero según su posición relativa (`global_position` propia menos la suya, escalada a un radio fijo `WORLD_RANGE` placeholder). **Decisión técnica**: radar abstracto en vez de mapa real con `SubViewport`+cámara cenital porque es más barato en rendimiento y no depende de ningún tileset — el de entorno todavía no existe (`plan-assets.md`, "no producir arte final antes de H1"). Cuando haya mapas reales, se puede reemplazar sin tocar `player.gd` (la interfaz es solo `set_companions(offsets)`).
- **Decisión documentada — las barras sobre la cabeza NO se quitan**, ni siquiera la propia: se mantienen para todos porque en combate cuerpo a cuerpo son la lectura más rápida (no hay que desviar la vista a una esquina de la pantalla mientras se esquiva/golpea de cerca). El panel fijo es un complemento, no un reemplazo.
- **Sin sincronización nueva**: los tres paneles solo leen `vida_actual`/`chakra_current`/`style_data` de los nodos `Player` en `GRUPO_JUGADORES` — el mismo dato que ya sincronizan `confirm_damage_taken` y el resto de `confirm_*` de `player.gd` (todos `call_local reliable`), igual que ya hacían las barras de mundo. No se inventó ningún RPC ni Dictionary nuevo en `NetworkManager`.
- Panel propio, panel de compañeros y minimapa se ocultan en la copia de cada peer que no sea el dueño (mismo criterio que `MoneyLabel`), para no acumular una segunda copia superpuesta en pantalla por cada jugador conectado.
Agente: `combat-agent`.

### H2 — Bucle económico: **✅ hecho**
Cadáver con `estado_conservacion` por tipo de daño del golpe final, fórmula de valor, Carnicero y Boticario, carga de hasta 3 cadáveres con penalización de velocidad, venta al pool compartido `dinero_manchado`.

### H3 — Casino mínimo: **✅ hecho**
Cambista (15 % comisión), Mesa de Dados de tres caras con apuesta ajustable (sin mínimo fijo de 20) en manchado o limpio. HUD mínimo de dinero.

### H4 — Bóveda compartida: **✅ hecho, con alcance recortado por decisión explícita del usuario**
Solo se implementó **el Usurero** (presta cuando `dinero_manchado` y `dinero_limpio` están exactamente a cero, deuda real en negativo que se recorta un 20 % de las próximas 5 ganancias). **La votación grupal, la revelación de votos y el Modo Mesa Alta se descartaron por decisión explícita del usuario**: cualquier jugador del grupo puede apostar del bote común directamente, sin votar ni pedir permiso — la bóveda compartida ya existe de facto en `dinero_manchado`/`dinero_limpio` desde H2/H3. Esto **no es un olvido ni una suposición** — está confirmado en el brief y el diseño (sección "Bóveda compartida, sin votación").

### H5 — Hub, tiendas y taberna: **✅ hecho por completo, incluida la capa acogedora**
Hub navegable en 4 alturas (Muelle con Taberna, Calle de los Faroles con Forja/Herboristería/Sastrería, Muelle Alto con el Casino completo — movido desde `test_room`, ver nota de abajo —, Terrazas con la Casa del equipo). Forja (3 niveles de daño, techo +20 % respetado), Herboristería (4 consumibles, máx. 3 cargados), **Sastrería** (tinte cosmético por jugador, sin efecto en balance) y **Casa del equipo** (Cocina: reducción de daño de grupo temporal; Almacén: +2 cadáveres cargables para todo el grupo; Jardín: descuento en Herboristería; **Palomar reenganchado** — compra única y permanente que habilita rechazar una misión en marcha, tecla F14/`submit_abandonar_mision` en `player.gd`, ver nota de abajo). Taberna completa: brindis (+15 % daño de grupo 180 s), **pizarra de deudas** (fía el brindis sin fondos en vez de bloquear, `NetworkManager.taberna_deuda_pendiente`), **pizarra de récords** (pérdidas en el casino y cuerpos destrozados por jugador), **música diegética comprable** (lista fija de 3 canciones, recorte documentado de "se desbloquean según avanzas"), **emotes/sillas** cosméticos y **desglose de contribución** (tecla F10, `submit_taberna_ver_desglose` en `player.gd` — lista cuánto dinero manchado aportó cada jugador al bote común vendiendo cadáveres, `NetworkManager.taberna_aportado_manchado`, más las misiones completadas por el grupo como dato compartido ya que no tienen atribución individual). Sin "quién ha caído más veces" (bloqueado: no hay sistema de muerte/respawn de jugador).

**Interiores de tienda con fundido a negro (H5+, scope nuevo pedido por el usuario el 2026-09-02, no estaba en `brief-traspaso-claude-code.md` ni `diseno-juego-ninja.md` originales — ver `plan-assets.md` sección 8 para la especificación visual completa)**: hasta esta tarea, `scenes/world/hub/hub.tscn` era una escena única — las tiendas eran zonas de interacción dentro del mismo hub, sin carga de escena independiente ni fundido a negro (ese patrón solo existía para el cambio Hub↔Misión). Ahora cada infraestructura entrable del hub funciona "estilo Pokémon": al entrar por su puerta física (`PuertaTienda`, tecla F11) se funde la pantalla a negro (`scripts/ui/fade_transition.gd`, autoload `FadeTransition`, reusable), se instancia una **escena de interior separada** con mood/paleta propios bajo `NetworkManager.interior_root`, y se reposiciona al grupo entero dentro — mismo patrón RPC host-autoritativo que `confirm_iniciar_mision`/`confirm_volver_hub` (`NetworkManager.confirm_entrar_tienda`/`confirm_salir_tienda`, ver `player.gd submit_entrar_tienda`/`submit_salir_tienda`). Salir es F12 desde el marcador `SalidaTienda` del interior. Hub/misión/interior son mutuamente excluyentes (`NetworkManager.interior_actual`).

Interiores construidos, uno por tienda, en `scenes/world/interiors/` (`forja_interior.tscn`, `herboristeria_interior.tscn`, `mercado_negro_interior.tscn`, `sastreria_interior.tscn`, `casa_equipo_interior.tscn`, `taberna_interior.tscn`, `casino_interior.tscn`): cada uno con placeholder de color/iluminación acorde al mood de `plan-assets.md` (ColorRect, sin arte final — igual de placeholder que el resto del Hub hasta ahora), y con la mecánica real ya existente movida dentro (Forja/Herboristería/Sastrería/CasaEquipo/Taberna+Tabernera instanciadas dentro de su interior, no ya sueltas en la fachada del Hub). El **Mercado negro** existe ahora como lugar físico del Hub por primera vez: reutiliza `Comprador.tscn` ya existente (economy-agent) con los 4 tipos (Boticario/Falsificador/Clan rival/Carnicero) — antes solo Boticario/Carnicero existían, y solo en `test_room` (sala de pruebas de combate, no el Hub).

**Decisión documentada sobre el Casino — cerrada**: el Casino ya se movió al Hub, agente `casino-agent`. Sus 7 sub-escenas (Cambista, Mesa de Dados, Usurero, Ruleta, Cartas Selladas, Peleas del Sótano, Tienda de Pergaminos), antes sueltas en `test_room`, viven ahora en `scenes/world/interiors/casino_interior.tscn` con el mood ya especificado en `plan-assets.md` sección 8 ("tenebroso y siniestro": rojos vino/púrpura sobre negro, focos duros solo sobre las mesas de juego, penumbra opresiva, humo ambiental, cortina pesada de sala privada). Registrado en `NetworkManager.TIENDAS_INTERIOR["casino"]`, mismo patrón `confirm_entrar_tienda`/`confirm_salir_tienda` que el resto. Puerta física `PuertaCasino` colocada en Muelle Alto (`hub.tscn`), que hasta ahora estaba vacío. `test_room` se queda como sala de pruebas de combate (enemigos, Boticario/Carnicero) — no se ha borrado, sigue cargada desde `main.tscn`.

**Recorte documentado**: la Taberna interior no trae consigo al Viejo Maestro/Usurero/Pescador aunque `plan-assets.md` los liste como "NPCs fijos" de la taberna en la ficción — esos tres siguen en sus ubicaciones ya establecidas por otros agentes (Terrazas/Casino interior/Muelle respectivamente, el Usurero desde la nota de arriba ya vive dentro de `casino_interior.tscn`, no en `test_room`); moverlos junto a la Tabernera es fuera de alcance de esta tarea. Solo se trajo a la Tabernera, que ya vivía junto a la Taberna en el Muelle.

**Palomar reenganchado (tarea posterior a H6, tras el sistema de misiones de `tablon_misiones.gd`)**: punto de diseño verificado antes de implementar — hoy no existe ninguna penalización por abandonar una misión ya aceptada; lo que no existe es la posibilidad misma de abandonarla. `submit_volver_hub` (única forma de volver al Hub desde una misión) exige a la vez estar en el rango de `ExtraccionMision` y que el jefe de zona esté muerto, así que sin ambas condiciones el grupo queda atrapado hasta terminar la misión. Por tanto el Palomar no quita una penalización (no había nada que quitar): **habilita** una acción nueva, `submit_abandonar_mision`/tecla F14, que deja rechazar la misión activa desde cualquier punto sin exigir ni el rango de extracción ni el jefe muerto. "Sin penalización" se traduce en que `NetworkManager.misiones_completadas` no sube al usarlo (rechazar no es completar) pero tampoco se descuenta nada del dinero ya ganado en la misión. Compra única y permanente de grupo (`NetworkManager.casa_equipo_palomar_comprado`), mismo patrón que Almacén/Jardín — ver `scripts/economy/casa_equipo.gd` para el detalle completo.

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

### Infraestructura fuera de hitos (scope nuevo, no en `brief-traspaso-claude-code.md` ni `diseno-juego-ninja.md` originales — detectado en `git log` el 2026-09-03, no estaba documentado en este archivo)

**Pantalla de inicio, lobby y transporte Steam P2P** (commit `59d75d3`, agente: `netcode-agent`): antes del prólogo/selección de estilo existente se añadió un título (Jugar/Salir) y un lobby (crear/unirse sala, lista de jugadores en vivo, invitar amigos por overlay de Steam) — `scenes/ui/menu_inicio.tscn`, `scenes/ui/lobby.tscn`. El transporte de red migró de **ENet por IP a Steam P2P** (`addons/godotsteam/`, App ID de test 480), manteniendo intacto el modelo host-autoritativo `submit_*`/`confirm_*` ya usado en el resto de `NetworkManager`. Esto no cambia ningún hito ni criterio de "hecho": es la capa de conexión, no una mecánica de juego.

**Pase de dureza de red: caída del host, reconexión y late-join** (commit `416d78c`, agente: `netcode-agent`): auditoría del sistema de interiores nuevo (H5+) que corrigió dos huecos — un cliente dentro de una misión o tienda se quedaba congelado si el host caía (ahora `NetworkManager.host_disconnected` + `main.gd` recargan la escena y vuelven al menú), y un peer que se unía tarde o se reconectaba mientras el grupo ya estaba dentro de una misión/interior no recibía ese estado (nuevo `_sync_new_peer()`/`confirm_sync_mision_a_peer()`/`confirm_sync_interior_a_peer()`). También endurece `confirm_iniciar_mision` para rechazar si ya hay un interior activo, mismo criterio que ya tenía `confirm_entrar_tienda` en sentido inverso.

---

## 2. Qué queda por hacer de verdad (código) — todolist real

**Este checklist ES el todolist de código, no una copia.** Vive en este archivo a propósito, porque es lo único que llega igual a cualquier dispositivo con un `git pull` — una herramienta tipo `TaskList` puede no existir según el entorno donde corra la sesión (no es parte del repo, no viaja con git). Si en tu sesión sí existe una herramienta de tareas, úsala como ayuda visual si quieres, pero **la fuente de verdad es marcar `[x]` aquí y hacer commit** — nunca al revés.

- [ ] **Playtest de validación con gente real** de H4/H5/H6. Ninguno de los recortes de H4 (sin votación) se ha probado todavía con un grupo real jugando a la vez.
- [x] **Panel de HUD fijo, compañeros y minimapa** (H1, scope nuevo pedido por el usuario, 2026-09-02 — ver nota en sección 1 H1): vida/chakra propios grandes arriba a la derecha, vida/chakra de hasta 3 compañeros debajo en pequeño, minimapa como radar abstracto arriba a la izquierda. Barras sobre la cabeza mantenidas para todos (combate cercano). Agente: `combat-agent`.
- [x] **Mob murciélago** (scope nuevo). Poca vida (`vida_maxima = 12`), daño bajo (`daño_ataque = 3`, cooldown corto `0.5s` para que estorbe/interrumpa sin ser amenaza real), no deja cadáver al morir (`MobMurcielago` extiende `EnemigoSimple` y sobreescribe `_spawn_cadaver()` a no-op — `scenes/enemies/mob_murcielago.gd`), sin bioma asignado todavía (alcance genérico, instanciado en `test_room.tscn` junto a `EnemigoSimple`). **Implementado saltándose el gate de playtest de H4/H5/H6 de arriba, por decisión explícita del usuario** — el playtest en sí sigue sin hacerse (ver ítem de arriba, que sigue abierto). Agente: `combat-agent`.
- [x] **Fichas y tienda de pergaminos** (H6). Desbloqueó la trampa de Sellos en Cartas Selladas. Agente: `casino-agent`.
- [x] **Falsificador, clan rival y prisioneros vivos** (H6, mecanismo): compradores y captura vía Agarre construidos y documentados. Incluye el objetivo explícito de misión que engancha cada uno a un bioma concreto (Costa/Peaje/Cantera). Agente: `economy-agent`.
- [x] **Máquina Expendedora de cadáveres** (H6, quinto comprador, scope nuevo pedido por el usuario — no estaba en el diseño original, ver nota en sección 1 H6): comisión fija del 15 % sin ponderar por tipo de daño, usos compartidos de grupo con recarga por cooldown, colocada en los 5 biomas. Agente: `economy-agent`.
- [x] **Los 5 biomas y el sistema de misión** (H6): Costa, Bosque de Bambú, Camino de Peaje, Cantera Vieja, Ruinas del Clan — tres áreas encadenadas, jefe de zona, vuelta a extracción. Agente: `narrative-agent`.
- [x] **Historia y diálogos de NPCs** (H6, al final): tabernera, viejo maestro, usurero, pescador, con una línea nueva por misión completada. Agente: `narrative-agent`.
- [x] **Extras de taberna**: música diegética, emotes, sillas, pizarra de deudas y récords. Agente: `hub-agent`.
- [x] **Desglose de contribución de la Taberna**: quedó bloqueado en H5 por falta del concepto de misión — ya existe, se puede reenganchar. Baja prioridad. Agente: `hub-agent`.
- [x] **Pantalla de inicio, lobby y transporte Steam P2P** (scope nuevo, detectado en `git log` sin documentar — ver nota en sección 1): título, lobby con invitación por overlay de Steam, migración de ENet a Steam P2P sin tocar el modelo host-autoritativo. Agente: `netcode-agent`.
- [x] **Pase de dureza de red: caída del host, reconexión y late-join** (scope nuevo, detectado en `git log` sin documentar — ver nota en sección 1): resincronización de peers tardíos/reconectados dentro de misiones e interiores, recarga a menú si el host cae en pleno interior/misión. Agente: `netcode-agent`.
- [x] **Interiores de tienda con fundido a negro** (H5+, scope nuevo pedido por el usuario el 2026-09-02, ver nota en sección 1 H5 y `plan-assets.md` sección 8): sistema genérico reusable (`FadeTransition` autoload + `NetworkManager.confirm_entrar_tienda`/`confirm_salir_tienda`, mismo patrón que Misiones) y 6 escenas de interior con mood propio (Forja, Herboristería, Mercado negro, Sastrería, Casa del equipo, Taberna). Casino deliberadamente fuera de esta pasada (sigue en `test_room`, coordinación pendiente con `casino-agent` — ver nota en sección 1). Agente: `hub-agent`.

No se retoma la votación de bóveda ni el Modo Mesa Alta salvo que el usuario lo pida explícitamente — esa sí es una decisión de diseño confirmada, no scope pendiente.

### 2.1 Rework de combate pedido por el usuario el 2026-09-03 (nuevo, no estaba en `brief-traspaso-claude-code.md` ni `diseno-juego-ninja.md` originales)

**Choca con reglas invariantes ya cerradas del diseño — ver diagnóstico completo entregado por `pilar-agent` en la sesión de hoy.** Resumen de los choques más importantes:
- **Chakra pasivo por tiempo**: contradice directamente "el chakra se recupera golpeando con el Básico, nunca con el tiempo" — la regla más repetida del diseño (`diseno-juego-ninja.md` sección 1, `brief-traspaso-claude-code.md` sección 2.1, `.claude/agents/combat-agent.md`). El usuario lo pidió explícitamente, así que se trata como **decisión consciente de sustituir la regla**, no como omisión — queda documentado aquí para que no se lea como un bug futuro.
- **Cooldown por ranura**: cambia el rol del Básico (de "generador de chakra" a "la única ranura sin cooldown"), interactúa con la ventana de combo de 0,6 s, la ventana de etiqueta de 1,5 s y la ventana de sincronización de red de ~0,5 s + RTT de las combinaciones.
- **Q/E personalizados por estilo**: hoy Q y E son ranuras fijas del esquema universal (Zona y Potenciador), iguales para los 6 estilos por diseño ("cada estilo tiene exactamente cinco cosas"). Aviso técnico: **todas** las teclas A-Z y 0-9 en `project.godot` ya están asignadas a alguna acción — no hay ninguna letra libre para una ranura nueva.
- **Sustitución de ataque al comprar pergamino**: hoy la Tienda de Pergaminos desbloquea de forma incondicional la única técnica Sellos fija por estilo (`style_data.sellos_technique_name`) — no existe ni un pool de técnicas por estilo ni un concepto de "ranura ya equipada" que sustituir.

**Supuestos de trabajo de esta pasada (recomendación de `pilar-agent`, pendiente de confirmación del usuario si prefiere otra interpretación):**

| Punto ambiguo | Supuesto de trabajo |
|---|---|
| Qué son exactamente Q/E "personalizados" | Q y E pasan a ser 2 huecos de loadout por estilo (uno cada uno), cada uno con una técnica equipada de un pool de técnicas aprendibles del estilo. Sustituye conceptualmente al Sellos-único-en-R actual. |
| A qué sustituye la compra de un pergamino | A la técnica que hoy ocupe el hueco Q o E que el jugador elija sustituir en el momento de la compra (no automático). |
| A quién afecta la ranura de Soporte nueva | Puede targetear a uno mismo o a un aliado según la técnica (no hereda la restricción de "nunca a uno mismo" del Potenciador — esa regla es exclusiva de esa ranura). |
| Qué recurso gasta la ranura de Soporte | El mismo chakra (ya pasivo), para no crear un cuarto recurso. |
| Tecla de la ranura de Soporte | Una tecla de función libre (F1-F9, F13, F15+; F10-F12 y F14 ya están en uso) — decisión final la toma `combat-agent` al implementar. |
| Chakra pasivo: ¿reemplaza del todo el golpe-recupera-chakra del Básico, o convive? | Reemplaza del todo, tal y como se pidió literalmente. `pilar-agent` recomienda evaluar en playtest si conviene mantener un bonus extra de chakra al golpear con Básico encima del pasivo (opción B), pero no es lo pedido — se implementa la opción A (reemplazo total) salvo que el usuario diga lo contrario. |

**Tareas (orden de ejecución — casi todas comparten `scripts/player/player.gd`/`scripts/styles/style_data.gd`/`project.godot`, así que se hacen en serie, no en paralelo, salvo la excepción marcada):**

- [x] **T1 — Recurso de combate: chakra pasivo + cooldown por ranura** (`combat-agent`, primero, nada más depende de nada existente). Chakra pasa de recuperarse solo golpeando con Básico a regenerarse pasivamente por tiempo; cada ranura (Proyectil/Agarre, Zona/Lanzamiento, Potenciador, Sellos, Loadout Q/E, Soporte) gana un cooldown propio que obliga a volver al Básico (sin cooldown) entre usos. El Impulso ya tenía cooldown propio de antes, sin cambios ahí. La regeneración autoritativa corre en el host para la copia de CADA jugador (`multiplayer.is_server()`, no `is_multiplayer_authority()`, para que también cubra a los peers remotos); el resto de peers predice la misma fórmula localmente y el host corrige cada 0.5s con `confirm_chakra_sync` (mismo patrón `submit_*`/`confirm_*`, adaptado a un tick periódico en vez de una petición puntual porque la regeneración no la dispara ningún input). Ver `scripts/player/player.gd` (`chakra_current`, `_slot_cooldowns`, `_advance_chakra_regen`/`_server_regen_chakra`/`_predict_chakra_regen`/`confirm_chakra_sync`) y `scripts/styles/style_data.gd` (`chakra_regen_per_second`, `*_cooldown` por ranura). `chakra_recovered_per_hit` se deja declarado pero deprecado (documentado en el propio campo) para no tener que tocar los 6 `.tres`.
- [x] **T2 — Ranuras Q/E de loadout por estilo** (`combat-agent`, depende de T1). Zona se reasignó de Q a Mayús/Shift y Potenciador de E a Ctrl (mismos nombres de acción `zone_cast`/`potenciador` en `project.godot`, solo cambia la tecla física); Q y E pasan a ser 2 huecos de técnica equipable por estilo (`loadout_q`/`loadout_e`), cada uno con su técnica de fábrica (golpe en cono / estallido de área) definida en `style_data.gd` y con nombre propio por estilo en cada `.tres`. Punto de extensión para T4: `player.gd._equipped_loadout_technique()` resuelve la técnica activa de cada hueco por id (hoy solo `"factory"`) leyendo `NetworkManager.loadout_equipped` (Dictionary nuevo, sin escritor todavía) — T4 solo necesita añadir más ids al `match` de `submit_loadout_technique()`, no rehacer la ranura.
- [x] **T3 — Ranura de Soporte nueva** (`combat-agent`, depende de T1, misma sesión que T2 por solapar archivos). Tecla `F15` (F1-F14 ya estaban todas ocupadas, no solo F10-F12/F14 como se asumía — revisado contra `project.godot`). Cura a un aliado en el cono de apuntado o, si no hay ninguno, a uno mismo (única ranura que puede afectar a quien la lanza, a diferencia del Potenciador). Gasta el chakra pasivo de T1, sin recurso nuevo. Ver `soporte_*` en `style_data.gd` y `submit_soporte`/`confirm_soporte_cast`/`confirm_soporte_received` en `player.gd`.
- [ ] **T4 — Pool de técnicas de pergamino por estilo** (`combat-agent`, depende de T2). Cada estilo pasa de tener una única técnica Sellos comprable a tener varias técnicas aprendibles asignables a los huecos Q/E de T2.
- [ ] **T5 — Flujo de compra con sustitución en la Tienda de Pergaminos** (`casino-agent`, depende de T4 commiteado). Comprar ya no desbloquea sin más: pide elegir qué técnica equipada (Q o E) se sustituye por la nueva.
- [ ] **T6 — Auditoría de red del nuevo recurso** (`netcode-agent`, depende de T1 commiteado; **puede ir en paralelo con T2/T3** porque es mayormente revisión/lectura sobre `network_manager.gd` con ediciones acotadas, no una reescritura de `player.gd`). Confirmar que la regeneración pasiva y los cooldowns son autoritativos en host y no explotables por un cliente modificado, y si hace falta un tick periódico de sync para que el chakra de los compañeros en el HUD no se vea desfasado entre eventos.

Agente principal: `combat-agent` (T1-T4). Reparto: `casino-agent` (T5), `netcode-agent` (T6, auditoría).

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
      test_room/             # sala de pruebas de combate (enemigos, Boticario/Carnicero) -- el casino ya no vive aqui
      hub/                    # Puerto Bajo (4 alturas) -- solo fachadas/puertas, la mecanica vive en interiors/
      interiors/               # escenas de interior de cada tienda entrable, incluido el casino (H5+, ver seccion 1)
      mision_costa/, mision_bambu/, mision_peaje/, mision_cantera/, mision_ruinas/  # los 5 biomas
      tablon_misiones.tscn, puerta_mision.tscn, extraccion_mision.tscn, puerta_tienda.tscn, salida_tienda.tscn
    ui/                       # prologo.tscn, seleccion_estilo.tscn, fade_transition.tscn
  scripts/
    player/
    styles/                   # style_data.gd
    combat/                   # ground_zone, projectile, status_tag, zone_preview
    economy/                  # incluye tienda_pergaminos.gd, silla_taberna.gd
    network/                  # network_manager.gd (host-autoritativo)
    ui/                       # prologo.gd, seleccion_estilo.gd, fade_transition.gd (autoload FadeTransition, H5+)
    world/                    # tablon_misiones.gd, puerta_mision.gd, extraccion_mision.gd, puerta_tienda.gd, salida_tienda.gd
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
| `combat-agent` | Combate y estilos | T1-T3 del rework de combate de la sección 2.1 ya hechos (chakra pasivo + cooldowns, loadout Q/E, ranura de Soporte). Queda T4 (pool de técnicas de pergamino equipables en Q/E) |
| `netcode-agent` | Red host-autoritativa | Mantenimiento y lo que necesiten las piezas nuevas |
| `economy-agent` | Cadáveres, compradores, tiendas de grupo | Nada pendiente. Falsificador/clan rival/prisioneros con objetivo de misión y la Máquina Expendedora (quinto comprador) ya están hechos |
| `casino-agent` | Casino, bóveda | Nada pendiente. **La votación de bóveda y el Modo Mesa Alta están descartados, no los reintroduzcas sin que el usuario lo pida.** |
| `hub-agent` | Hub, tiendas, taberna | Nada pendiente. Hub, 4 tiendas, capa acogedora de Taberna y desglose de contribución completos |
| `narrative-agent` | Historia, misiones, biomas | Sistema de misión, 5 biomas, prólogo, elección de estilo y diálogos de NPCs hechos. Nada pendiente propio (ver ítems de baja prioridad de `economy-agent`/`hub-agent`) |
