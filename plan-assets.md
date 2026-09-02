# Plan de assets

**Para:** la persona encargada del arte del proyecto.
**Basado en:** `diseno-juego-ninja.md`, `brief-traspaso-claude-code.md` y `plan-desarrollo.md`.

Este documento traduce el diseño del juego a una lista de trabajo concreta, organizada en las mismas fases que el desarrollo de código (`plan-desarrollo.md`, hitos H1-H6), para que el arte avance en paralelo sin bloquear ni ser bloqueado innecesariamente.

> **Actualización importante:** el código de H1 a H5 (y el combate de H6: Agua/Rayo/Tierra) **ya está implementado y jugado**, todavía con arte 100 % placeholder (`ColorRect`/`Tween`, sin sprites). Esto significa que la mayoría de las fases de abajo ya pueden pasar de 🟡 *placeholder* a 🟢 *arte final* sin miedo a que el diseño cambie debajo — la carpeta real donde va cada cosa es `assets/sprites/{legs,torso,fx}/` y `assets/audio/` dentro del proyecto Godot (ver `plan-desarrollo.md` sección 3). También ten en cuenta que **H4 y H5 se recortaron a propósito** (sin bóveda con votación, Mesa Alta, sastrería, casa del equipo, música/emotes/sillas/pizarra) — no produzcas assets para esas piezas descartadas salvo que el usuario las pida explícitamente de vuelta.

---

## 0. Regla que condiciona todo el orden

> "Producir arte final antes de que el combate esté cerrado" está en la lista de formas clásicas de que el proyecto muera (brief, sección 6).

Esto **no significa parar hasta H1**. Significa dos velocidades distintas:

- **Placeholder / exploración** (fase 0 y durante H1): se puede y se debe avanzar ya. Guía de estilo, concept art, rig funcional del personaje, tileset mínimo de prueba. No hace falta que sea bonito, hace falta que exista para poder probar el juego.
- **Arte final / pulido**: solo se produce sobre sistemas que ya pasaron su criterio de "hecho" en `plan-desarrollo.md`. Antes de H1 validado (dos personas jugando 20 min sin aburrirse), no vale la pena pulir animaciones de combate — el timing o el tamaño de hitbox todavía puede cambiar y se tira el trabajo.

Por eso este documento marca cada bloque como 🟡 *placeholder ya* o 🟢 *final cuando el hito de código correspondiente esté cerrado*.

**Coordinación:** la sesión de la persona de assets debe empezar siempre invocando a `arte-pilar-agent` (`.claude/agents/arte-pilar-agent.md`) — es el equivalente de `pilar-agent` pero para la parte visual. Lee este documento, el checklist `assets-progreso.md` y el estado real del todolist de código para decidir qué pieza toca ahora, con qué herramienta generarla (Claude para concept/prompts/organización, PixelLab para el pixel art final) y con qué especificaciones exactas. No hace falta que la persona de assets memorice este documento entero sesión a sesión: para eso está el agente.

---

## 1. Especificaciones técnicas propuestas (a confirmar con el desarrollador antes de producir en serio)

> **Aclaración importante sobre la cámara, porque genera confusión fácil:** la cámara del juego (`Camera2D` en Godot) es técnicamente **cenital** — mira derecho hacia abajo sobre un plano 2D, como cualquier juego top-down. **Pero el arte NO se dibuja como si se viera desde arriba.** Se dibuja en **perspectiva tres cuartos (~60°)**: el personaje se ilustra mostrando cara/torso/piernas en ángulo, como en un RPG 2D clásico (Zelda 16-bit, Stardew Valley, etc.), no la coronilla desde el cenit. Es la técnica estándar para que los personajes se reconozcan y tengan lectura de armas/gestos. La única excepción son las **Zonas** (efectos de suelo): esas sí van dibujadas totalmente planas/cenitales, precisamente para contrastar con el resto del arte que está en ángulo — si no, el jugador no sabe dónde acaba el efecto.

| Parámetro | Propuesta | Notas |
|---|---|---|
| Estilo | Pixel art, personajes/entorno en perspectiva tres cuartos (~60°); Zonas de suelo en plano cenital | Coherente en todo el juego, luz de tarde/noche predominante |
| Tamaño de tile de entorno | 32×32 px | Bloque base de suelo/pared |
| Canvas de personaje por capa | 32×48 px | Mantiene el ancho del bloque (32) pero más alto para proporciones humanas (cabeza/torso/piernas) |
| Iconos de inventario | 16×16 px | Objetos pequeños (llaves, limas, comida) para caber en menús sin tapar pantalla |
| Muebles y objetos grandes | 32×64 o 64×64 px | Mesas largas, camas, carros — combinan varios bloques |
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

> **Scope nuevo pedido por el usuario (2026-09-02), no parte del diseño original — mismo tratamiento que la Máquina Expendedora en H6:** cada infraestructura entrable del hub (casino, Taberna, Forja, Herboristería, Mercado Negro, Sastrería, Casa del equipo) pasa a funcionar como en los juegos estilo Pokémon — transición a pantalla en negro y carga de una **escena de interior separada** — y cada interior tiene su propio bioma/mood distintivo, al mismo nivel de detalle que los 5 biomas de misión de la sección 9 (no el tratamiento genérico "interior mínimo" que tenían hasta ahora).
>
> **Esto añade scope real, no estaba implícito.** Verificado contra el código: `scenes/world/hub/hub.tscn` es una escena única — las tiendas son zonas de interacción dentro del mismo hub, sin carga de escena independiente ni fundido a negro (ese patrón solo existe hoy para el cambio Hub↔Misión, ver `NetworkManager.confirm_iniciar_mision`/`confirm_volver_hub`). Implementar la transición y la escena de interior por tienda es trabajo de **código** (`hub-agent`), no solo de arte — este documento solo fija la especificación visual para cuando ese trabajo se aborde. La parte de arte (paleta/mood/props por interior de abajo) se puede preparar en 🟡 concept ya; el interior final en 🟢 espera a que `hub-agent` construya la escena separada donde montarlo.

**Interiores de tienda — cada uno con su propia especificación de bioma (paleta, iluminación/mood, props, ambientación), mismo nivel de detalle que los biomas de misión:**

- **Forja** — mood: industrial, calor, oficio. Paleta: negros/grises de metal frío contra naranjas y rojos intensos del fuego de la fragua. Iluminación: fuente puntual cálida (el fuego) como único foco fuerte en una sala si no oscura, en penumbra. Props: yunque, fuelle, armero de piezas a medio forjar, chispas animadas, cubos de agua para templar. NPC herrero con delantal de cuero.
- **Herboristería** — mood: calma, natural, casi médico. Paleta: verdes apagados y marrones tierra, algún acento violeta/azul de tintes raros. Iluminación: suave, difusa, sin sombras duras — luz de vela o farol tamizada por hierbas colgando. Props: manojos de hierbas secas colgando del techo, morteros, frascos y tarros etiquetados, mesa de preparación. NPC herborista con delantal manchado de tintes.
- **Mercado negro** — mood: turbio, furtivo, secreto a voces. Paleta: azules y violetas muy oscuros, con acentos puntuales de un naranja/amarillo sucio (lámparas de aceite, no farolillos limpios). Iluminación: baja, deliberadamente insuficiente — zonas en sombra donde no se ve bien qué se vende. Props: cajas de contrabando a medio abrir, telas cubriendo mercancía, mostrador improvisado (no una tienda "oficial"). NPC con capucha o rostro parcialmente oculto.
- **Sastrería** — mood: refinado, colorido, el interior más "limpio" del hub. Paleta: contraste vivo de telas de colores (rojos, azules, dorados) sobre madera clara, rompiendo con el resto del hub que es predominantemente nocturno/húmedo. Iluminación: la más brillante y cálida del hub, casi de escaparate. Props: rollos de tela, maniquíes con prendas a medio hacer, espejo, mesa de corte con tijeras y alfileres. NPC sastre con cinta métrica al cuello.
- **Casa del equipo** — mood: personal, acogedor, "propio" — no una tienda, un hogar. Paleta: neutros cálidos (madera, textil) como base, con acentos que cambian según qué mejoras tenga el grupo (Cocina: rojos/naranjas de fogón; Almacén: madera de cajas apiladas; Jardín: verdes de macetas; Palomar: grises/blancos de plumaje). Iluminación: hogareña, uniforme, sin dramatismo — es el único interior "de descanso" sin tensión de ninguna clase. Props variables por mejora activa (ver Fase H5 diseño original): fogón, estanterías de almacén, macetas, jaulas de palomas.
- **Casino (interior completo, Muelle Alto)** — mood: **tenebroso y siniestro**, el opuesto deliberado a la Taberna. Paleta: rojos vino y púrpuras muy oscuros sobre negro, acentos de dorado sucio (no oro limpio — dinero con mala procedencia). Iluminación: focos duros y localizados sobre las mesas de juego (dados, Rueda del Clan, Cartas Selladas), el resto de la sala en penumbra casi opresiva; humo ambiental. Props: mesas de fieltro desgastado, fichas y monedas desperdigadas, sala privada con cortina pesada, tienda de pergaminos en una esquina más discreta. Amplía el "interior mínimo" ya descrito en la sección 6 (H3) y el casino completo de la sección 9 (H6) — esta es la capa de mood que faltaba.

**Taberna El Ancla Rota (interior completo)** — mood: **alegre y acogedora**, el opuesto deliberado al casino. Paleta: naranjas y amarillos cálidos (fuego de chimenea, madera pulida por el uso), sin los tonos fríos/húmedos del resto del hub nocturno. Iluminación: uniforme y cálida, fuente principal la chimenea/lámparas de mesa, ambiente "hogar" incluso siendo un local público:
- Barra, mesas, sillas con pose de sentarse, escenario del músico, chimenea encendida.
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
