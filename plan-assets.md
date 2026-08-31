# Plan de assets

**Para:** la persona encargada del arte del proyecto.
**Basado en:** `diseno-juego-ninja.md`, `brief-traspaso-claude-code.md` y `plan-desarrollo.md`.

Este documento traduce el diseño del juego a una lista de trabajo concreta, organizada en las mismas fases que el desarrollo de código (`plan-desarrollo.md`, hitos H1-H6), para que el arte avance en paralelo sin bloquear ni ser bloqueado innecesariamente.

---

## 0. Regla que condiciona todo el orden

> "Producir arte final antes de que el combate esté cerrado" está en la lista de formas clásicas de que el proyecto muera (brief, sección 6).

Esto **no significa parar hasta H1**. Significa dos velocidades distintas:

- **Placeholder / exploración** (fase 0 y durante H1): se puede y se debe avanzar ya. Guía de estilo, concept art, rig funcional del personaje, tileset mínimo de prueba. No hace falta que sea bonito, hace falta que exista para poder probar el juego.
- **Arte final / pulido**: solo se produce sobre sistemas que ya pasaron su criterio de "hecho" en `plan-desarrollo.md`. Antes de H1 validado (dos personas jugando 20 min sin aburrirse), no vale la pena pulir animaciones de combate — el timing o el tamaño de hitbox todavía puede cambiar y se tira el trabajo.

Por eso este documento marca cada bloque como 🟡 *placeholder ya* o 🟢 *final cuando el hito de código correspondiente esté cerrado*.

**Coordinación:** al empezar cada sesión de arte, conviene preguntar a `pilar-agent` (o directamente mirar el todolist) en qué hito de código está el proyecto ahora mismo, para saber si toca placeholder o ya se puede pulir algo.

---

## 1. Especificaciones técnicas propuestas (a confirmar con el desarrollador antes de producir en serio)

| Parámetro | Propuesta | Notas |
|---|---|---|
| Estilo | Pixel art, cámara tres cuartos (~60°) | Coherente en todo el juego, luz de tarde/noche predominante |
| Tamaño de tile de entorno | 32×32 px (ajustable) | Confirmar con quien monte los tilesets en Godot |
| Canvas de personaje por capa | 64×64 o 96×96 px | Debe dejar margen para que armas/efectos sobresalgan del cuerpo |
| Animación | 8–12 fps | Estándar de pixel art, no busca fluidez tipo anime |
| Formato fuente | Aseprite (`.aseprite`) | Permite exportar spritesheet y capas por separado fácilmente |
| Formato de entrega a Godot | PNG (spritesheet o frames sueltos) + el `.aseprite` original | El programador importa desde ahí |
| Carpeta de trabajo sugerida | `art/characters/`, `art/enemies/`, `art/environments/<bioma>/`, `art/ui/`, `art/vfx/` | Carpeta de staging separada de `res://`; el programador copia/organiza lo final dentro del proyecto Godot |

Estos números son un punto de partida razonable, no una decisión cerrada — si la persona de assets tiene preferencia técnica distinta, se ajusta antes de producir volumen.

---

## 2. El truco de las 3 capas (léelo antes de dibujar nada de personajes)

El diseño resuelve el problema de "seis estilos × animaciones" con una estructura de **3 capas independientes** por personaje:

1. **Piernas** — sigue la dirección de movimiento. Es **genérica**, no cambia por estilo.
2. **Torso** — rota hacia el cursor. Contiene la animación del ataque en sí (el brazo/arma moviéndose). Es en gran parte **reutilizable entre estilos** — el mismo golpe de espada sirve de base visual para Fuego y para Viento, por ejemplo — salvo en los estilos donde el diseño pide un movimiento distinto (Físico tiene su propia cadena de puñetazos, agarre y lanzamiento en vez de las animaciones estándar).
3. **Efecto elemental** — sprite independiente superpuesto (partículas, color, aura). **Aquí es donde vive la diferencia entre estilos**, no en redibujar el cuerpo entero seis veces.

**Consecuencia práctica para el trabajo:** el grueso del esfuerzo de animación de combate va en 1) un buen set de piernas+torso genérico y 2) los efectos elementales por estilo — no en redibujar personajes completos por cada uno de los seis estilos.

---

## 3. Fase 0 — Antes/durante H1 (🟡 placeholder y exploración, empieza ya)

- **Guía de estilo visual**: paleta de color general del juego, referencia de iluminación tres cuartos, mood boards de la aldea portuaria en decadencia.
- **Concept art de los 3 estilos de H1**: look del personaje jugable con Fuego, Viento y Físico (silueta, paleta por estilo si aplica).
- **Rig placeholder funcional** del personaje jugable: piernas + torso genérico + hueco para el efecto elemental, aunque sean formas simples — lo importante es que `combat-agent` pueda enganchar el sistema de 3 capas cuanto antes.
- **Tileset mínimo de la sala de prueba de H1** (`h1_test_room`): piso y pared, legible, sin necesidad de ser bonito.

---

## 4. Fase H1 — Prototipo de combate (Fuego, Viento, Físico)

🟡 placeholder funcional primero → 🟢 pulido solo después de que H1 valide su criterio de "hecho" (20 min de dos personas jugando sin aburrirse).

**Personaje jugable — capa piernas (genérica):**
- Idle, caminar (direcciones necesarias para la cámara tres cuartos), impulso/dash, recibir golpe (knockback), muerte.

**Personaje jugable — capa torso (genérica + variantes):**
- Idle-aim (apuntando al cursor).
- Básico: cadena de 3 golpes (animación de melé genérica, reutilizable entre Fuego y Viento).
- Proyectil: animación de lanzamiento a distancia.
- Zona: animación de canalizar (mientras se mantiene Q) + soltar.
- Impulso: animación de salto/dash corto.
- Potenciador: animación de lanzar buff sobre un aliado.
- **Variantes propias de Físico** (no comparte con el resto): cadena de puñetazos de 5 golpes (la más larga del juego), Agarre, Lanzamiento, y 3 posturas visuales de Puertas (intensidad creciente, con algo que comunique "vulnerable" al cerrarlas).

**Efecto elemental (capa independiente) — Fuego:**
- Llamarada corta en arco (Básico), bola que estalla al impactar (Proyectil), brasas persistentes con daño por segundo (Zona), rastro de fuego tras el paso (Impulso), puños ardientes sobre el aliado (Potenciador).

**Efecto elemental (capa independiente) — Viento:**
- Cortes rápidos de alcance medio (Básico), cuchilla de aire que atraviesa en línea (Proyectil), torbellino que arrastra hacia el centro (Zona), salto largo (Impulso), impulso de vuelo al aliado (Potenciador).

**Combinación (solo la que aplica con 3 estilos de H1):**
- Viento sobre Fuego → tormenta ígnea que se expande (efecto de suelo compuesto, visualmente distinto de las dos Zonas por separado).

**Indicadores de UI de combate en el mundo:**
- Indicador previo de colocación de Zona (dónde va a caer antes de soltar Q) — **siempre plano en pantalla**, aunque el escenario esté en tres cuartos (si no, el jugador no sabe dónde acaba el efecto).
- Etiqueta elemental flotante: marca visual de 1,5 s tras el 3er golpe del Básico, que otro jugador pueda reconocer al instante como "esto se puede combinar".

**Enemigo simple (`enemy_grunt`):**
- Idle, persigue, ataca, recibe golpe, muere. Estilo simple/genérico, no necesita variedad todavía.

**HUD de combate:**
- Barra de chakra, barra de vida, 5 iconos de ranura (Básico/Proyectil/Zona/Impulso/Potenciador) — un set por cada uno de los 3 estilos de H1.

---

## 5. Fase H2 — Bucle económico

- **Cadáver**: sprite con variantes de estado de conservación según el tipo de daño del golpe final. Mínimo 3-4 variantes claramente distinguibles a simple vista: intacto/limpio (cortante), dañado moderado (contundente/veneno), carbonizado (quemadura), destrozado (aplastamiento/eléctrico). El jugador tiene que poder mirar el cuerpo y saber, sin leer texto, si vale la pena cargarlo.
- **Icono de peso/carga** en el HUD (cuánto llevas encima, cómo afecta a la velocidad).
- **NPCs compradores**: puesto y sprite del **carnicero** y del **boticario** (los dos de H2; falsificador y clan rival van en H6).
- **Punto de extracción**: marcador visual claro (por ejemplo el barco de vuelta).
- **UI de venta**: panel simple mostrando cuerpos llevados y precio ofrecido por comprador.

---

## 6. Fase H3 — Casino mínimo

- Interior mínimo del Muelle Alto: mesa del cambista y mesa de dados de tres caras.
- NPC cambista.
- Iconos de las 3 monedas: manchada, limpia, fichas (deben distinguirse a simple vista entre sí, van a convivir en el mismo HUD).
- Feedback visual de la tirada de dados.

---

## 7. Fase H4 — Bóveda y votación

- UI de la bóveda compartida: bote visible, cantidad total.
- UI de votación: ficha que cada jugador pone sobre la mesa, y revelación de quién votó a favor al resolver.
- NPC/aparición del Usurero (con algo de personalidad visual — es "el desastre convertido en trama", no un cajero neutro).

---

## 8. Fase H5 — Hub y taberna (aquí empieza el grueso de arte final del juego)

**Puerto Bajo, las 4 alturas conectadas por escaleras:**
- Muelle (nivel 0): tablón de misiones, puestos de pescado/redes/contrabando, entrada a la taberna.
- Calle de los Faroles (nivel 1): fachadas de mercado negro, herboristería, taller del falsificador, forja, sastrería.
- Muelle Alto (nivel 2): fachada llamativa del casino (lo único con dinero visible en toda la aldea) + interior con mesas, cambista, tienda de pergaminos, sala privada.
- Terrazas (nivel 3): casa del equipo (personalizable), ruinas de la sede del clan, mirador con vista al mar (sin mecánica, solo ambiente).
- Estética general: farolillos, madera húmeda, tejados apretados, siempre tarde o noche.

**Interiores de tienda:**
- Forja, sastrería, herboristería, mercado negro — cada una con su NPC vendedor.
- Casa del equipo: variantes visuales de sus mejoras (cocina, almacén, palomar, jardín).

**Taberna El Ancla Rota (interior completo):**
- Barra, mesas, sillas con pose de sentarse, escenario del músico.
- Pizarra de deudas y récords (legible, se actualiza con texto/números).
- NPCs fijos con retrato/expresión: tabernera, viejo maestro, usurero, pescador.
- Iconos de bebidas distintas para el sistema de brindis.
- Emotes de personaje (sentarse, brindar, dormirse en la mesa).

---

## 9. Fase H6 — Estilos restantes, biomas e historia

**Estilos Agua, Rayo, Tierra** — mismo patrón que Fuego/Viento: reutilizan piernas+torso genérico, el coste real es el **efecto elemental propio** de cada uno:
- Agua: latigazo que empapa (Básico), chorro a presión (Proyectil), charco que ralentiza (Zona), disolverse/reaparecer (Impulso), sanar/limpiar estado al aliado (Potenciador).
- Rayo: golpe con aturdimiento (Básico), descarga que salta de enemigo (Proyectil), campo eléctrico (Zona), parpadeo instantáneo (Impulso), velocidad de ataque al aliado (Potenciador).
- Tierra: puñetazo pesado (Básico), roca en arco (Proyectil), muro destruible (Zona), anclarse al suelo (Impulso), armadura de piedra al aliado (Potenciador).
- Combinaciones nuevas: charco electrificado (Rayo+Agua), barro (Tierra+Agua), vapor que ciega (Fuego+Agua), tormenta de polvo (Viento+Tierra).

**Los 5 biomas de misión**, cada uno con tileset, props y ambientación propios:
- Costa de los Naufragios (playa, restos de barcos, marea).
- Bosque de Bambú (verde, niebla, vertical).
- Camino de Peaje (montaña, puentes, convoyes).
- Cantera Vieja (piedra, polvo, cavernas, sin luz — hay que iluminar).
- Ruinas del Clan (templo derruido, zona de historia, la más difícil).

**Enemigos por bioma:**
- Contrabandistas, ninjas desertores, bandidos organizados, mercenarios con armadura, guardianes antiguos.

**Casino completo:**
- Rueda del Clan (ruleta con sectores), Cartas Selladas (cartas + 3 NPCs rivales), Peleas del Sótano (arena de combate NPC).
- Medidor de sospecha: indicador visual de los 3 tramos (verde/ámbar/rojo).

**Sellos y pergaminos:**
- Animación de la secuencia de 3 direcciones manteniendo R (comunicar "inmóvil, momento de riesgo").
- Iconos/ilustraciones de pergaminos comprables con fichas.

**Compradores restantes:**
- Falsificador y clan rival: NPC + iconos de lo que buscan (caras, documentos, bandas, armas).
- Prisionero vivo: sprite de captura/transporte, distinto del cadáver.

**Historia:**
- Prólogo y pantalla de elección de estilo inicial.
- Retratos/expresiones adicionales de NPCs para el avance de diálogo por misión completada.

---

## 10. Resumen para priorizar (orden real de trabajo)

1. Guía de estilo + concept art + rig placeholder + tileset de prueba (fase 0, ya).
2. Set piernas/torso genérico + efectos elementales de Fuego y Viento + variantes de Físico + enemigo simple + HUD de combate (H1) — placeholder primero, pulir solo tras validar H1.
3. Cadáveres (variantes por conservación), NPCs carnicero/boticario, punto de extracción (H2).
4. Interior mínimo de casino, NPC cambista, iconos de monedas (H3).
5. UI de bóveda y votación, Usurero (H4).
6. Puerto Bajo completo, tiendas, taberna con todos sus NPCs y detalles (H5) — aquí ya se justifica invertir en arte final con calma.
7. Agua/Rayo/Tierra, los 5 biomas, casino completo, sellos/pergaminos, compradores restantes, historia (H6).
