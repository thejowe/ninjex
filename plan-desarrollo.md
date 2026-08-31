# Plan de desarrollo

**Basado en:** `brief-traspaso-claude-code.md` + `diseno-juego-ninja.md` + el historial real de commits de este repo.
**Estado:** el juego tiene un vertical slice jugable funcionando (H1-H6 con recortes explícitos, ver abajo). Este documento se reescribió para reflejar la realidad del código, no una planificación previa a él — hubo desarrollo en paralelo que avanzó más rápido que la documentación.

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
- Nombres definitivos de los 6 estilos: no se renombraron. "Físico" se mantiene tal cual en código y en el diseño.

---

## 1. Estado real por hito (leer esto antes de lanzar cualquier agente)

### H1 — Prototipo de combate: **✅ hecho y validado**
Fuego, Viento, Físico completos (Básico/Proyectil-Agarre/Zona-Lanzamiento/Impulso/Potenciador, Puertas de Físico), combinación Viento+Fuego (tormenta ígnea), enemigo simple host-autoritativo, segundo jugador validado con 2 instancias reales. Pasada de legibilidad visual (barras de vida/chakra, flash de golpe, screen shake, color por estilo) ya incluida, aunque sigue siendo **arte placeholder** (`ColorRect`/`Tween`, sin sprites finales).

### H2 — Bucle económico: **✅ hecho**
Cadáver con `estado_conservacion` por tipo de daño del golpe final, fórmula de valor, Carnicero y Boticario, carga de hasta 3 cadáveres con penalización de velocidad, venta al pool compartido `dinero_manchado`.

### H3 — Casino mínimo: **✅ hecho**
Cambista (15 % comisión), Mesa de Dados de tres caras con apuesta ajustable (sin mínimo fijo de 20, decisión directa del usuario) en manchado o limpio. HUD mínimo de dinero.

### H4 — Bóveda y votación: **✅ hecho, con alcance recortado por decisión explícita del usuario**
Solo se implementó **el Usurero** (presta cuando `dinero_manchado` y `dinero_limpio` están exactamente a cero, deuda real en negativo que se recorta un 20 % de las próximas 5 ganancias). **La bóveda con votación grupal, la revelación de votos y el Modo Mesa Alta se descartaron**: la decisión tomada fue que cualquiera puede apostar del bote común sin confirmación del grupo, porque la bóveda compartida ya existe de facto en `dinero_manchado`/`dinero_limpio` desde H2/H3. Esto **no es un olvido** — si en algún momento se quiere recuperar la votación grupal, es una decisión de diseño a retomar explícitamente, no algo que un agente deba añadir por su cuenta.

### H5 — Hub y taberna: **✅ hecho, recortado a lo mecánico por decisión explícita del usuario**
Hub navegable en 4 alturas (Muelle con Taberna, Calle de los Faroles con Forja y Herboristería, Muelle Alto vacío — el casino se quedó en la sala de pruebas, Terrazas solo caminable). Forja (3 niveles de daño, techo de +20 % respetado), Herboristería (4 consumibles, máx. 3 cargados), Taberna (brindis compartido: +15 % daño de grupo 180 s). **Sastrería, casa del equipo, música/emotes/sillas/pizarra de deudas y récords se descartaron explícitamente** — brief 2.4/2.5. Misma razón que H4: es scope recortado a propósito, no pendiente.

### H6 — Estilos restantes: **✅ combate hecho**, resto del hito **⬜ pendiente**
Agua, Rayo, Tierra completos con sus 5 estilos cada uno, 4 combinaciones de suelo nuevas (charco electrificado, barro, vapor, tormenta de polvo). **Lo que NO se ha tocado todavía de H6**: sistema de Sellos y pergaminos, medidor de sospecha y trampas en el casino, Rueda del Clan / Cartas Selladas / Peleas del Sótano, Falsificador y clan rival como compradores, prisioneros vivos, los 5 biomas de misión, prólogo y elección de estilo, historia/diálogos de NPCs.

**Aviso de tecla al acercarse a un punto de interacción** y varios **fixes de red/colisión** (jugador spawneaba en la esquina, dash atravesaba paredes, daño no se sincronizaba al segundo jugador, host nunca arrancaba el servidor) ya están hechos — no son tareas pendientes.

---

## 2. Qué queda por hacer de verdad (código) — todolist real

**Este checklist ES el todolist de código, no una copia.** Vive en este archivo a propósito, porque es lo único que llega igual a cualquier dispositivo con un `git pull` — una herramienta tipo `TaskList` puede no existir según el entorno donde corra la sesión (no es parte del repo, no viaja con git). Si en tu sesión sí existe una herramienta de tareas, úsala como ayuda visual si quieres, pero **la fuente de verdad es marcar `[x]` aquí y hacer commit** — nunca al revés.

Orden de trabajo (cada ítem no depende estrictamente de los demás salvo que se diga lo contrario — ver notas de dependencia):

- [ ] **Playtest de validación de H4/H5 con gente real.** El brief pedía validar la bóveda con 4 personas discutiendo — como se recortó la votación, esto ya no aplica tal cual, pero conviene una sesión de juego real de varias personas para confirmar que el recorte se siente bien y no falta nada crítico antes de seguir construyendo encima.
- [ ] **Sellos y pergaminos** (H6): secuencia de 3 direcciones manteniendo R, técnicas ocultas, tienda de pergaminos comprables con fichas. Agente: `combat-agent`.
- [ ] **Medidor de sospecha y trampas del casino** (H6): tres tramos verde/ámbar/rojo, trampa con Viento en la Mesa de Dados subiendo sospecha. Agente: `casino-agent`.
- [ ] **Resto de juegos de casino** (H6): Rueda del Clan, Cartas Selladas, Peleas del Sótano. Agente: `casino-agent`.
- [ ] **Los 5 biomas y el sistema de misión** (H6): Costa, Bosque de Bambú, Camino de Peaje, Cantera Vieja, Ruinas del Clan — duración 12-18 min, tres áreas encadenadas, vuelta a extracción. Agente: `narrative-agent`.
- [ ] **Falsificador, clan rival y prisioneros vivos** (H6) — *depende del ítem anterior*: necesita biomas/misiones que generen los objetos que piden. Agente: `economy-agent`.
- [ ] **Prólogo, elección de estilo, historia y diálogos de NPCs** (H6, al final) — *depende de los biomas/misión*. Agente: `narrative-agent`.

No se retoma la bóveda con votación, Mesa Alta, sastrería, casa del equipo, música/emotes/pizarra salvo que el usuario lo pida explícitamente — están descartadas del alcance actual, no en una cola de "pendiente".

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
    economy/                 # cambista, comprador, forja, herboristeria, taberna, usurero, mesa_dados
    world/
      test_room/             # sala de combate + casino
      hub/                    # Puerto Bajo (4 alturas)
  scripts/
    player/
    styles/                   # style_data.gd
    combat/                   # ground_zone, projectile, status_tag, zone_preview
    economy/
    network/                  # network_manager.gd (host-autoritativo)
  resources/
    styles/                    # .tres por estilo: fuego, viento, fisico, agua, rayo, tierra
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
- Ninguna mejora permanente supera el +20 % sobre la base (ya respetado en Forja).
- Los bonus de comida y casa se aplican a todo el grupo, no solo a quien pagó (ya respetado en el brindis de la Taberna).
- Ningún estilo puede ser puramente de apoyo: todos hacen daño y todos aportan al grupo.

---

## 5. Agentes especializados

Los mismos 7 agentes de `.claude/agents/` siguen aplicando, con el dominio actualizado a lo que queda por hacer (ver el system prompt de cada uno para el detalle):

| Agente | Dominio | Qué le queda por delante |
|---|---|---|
| `pilar-agent` | Director de proyecto (código) | Siempre el primero — ahora debe leer este documento actualizado, no asumir que H1-H5 están vacíos |
| `arte-pilar-agent` | Director de la parte visual | Coordina con `plan-assets.md`/`assets-progreso.md` — gran parte de H1-H5 ya puede pasar a arte final |
| `combat-agent` | Combate y estilos | Solo queda Sellos/pergaminos (parte de combate) |
| `netcode-agent` | Red host-autoritativa | Mantenimiento y lo que necesiten las piezas nuevas |
| `economy-agent` | Cadáveres, compradores | Falsificador, clan rival, prisioneros vivos |
| `casino-agent` | Casino, bóveda | Sospecha/trampas, Rueda del Clan, Cartas Selladas, Peleas del Sótano. **La bóveda con votación está descartada del alcance actual — no la reintroduzcas sin que el usuario lo pida.** |
| `hub-agent` | Hub, tiendas, taberna | El hub mecánico ya está. **Sastrería, casa del equipo y los extras de taberna están descartados del alcance actual — no los añadas sin que el usuario lo pida.** |
| `narrative-agent` | Historia, misiones, biomas | Es quien más trabajo tiene por delante: todo el sistema de misión + los 5 biomas + prólogo + historia |
