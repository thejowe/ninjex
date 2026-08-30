# Brief de traspaso — proyecto de juego

**Para:** Claude Code
**Objetivo del encargo:** convertir este brief en un plan de trabajo paso a paso, con tareas ordenadas por dependencia, antes de escribir ningún código.

Este documento es autocontenido. No hace falta la conversación previa.

---

## 0. Antes de planificar: decisiones bloqueantes

Hay tres cosas sin decidir que condicionan todo lo demás. Pregúntalas antes de generar el plan, no después.

**1. Motor.** No está elegido. Recomendación por defecto: **Godot 4**, por ser 2D nativo, ligero, con multijugador de alto nivel incluido y gratis sin royalties. Alternativa razonable si ya hay experiencia previa: Unity. La elección cambia la estructura de carpetas, el sistema de red y las herramientas de tiles, así que todo el plan depende de ella.

**2. Equipo y tiempo.** Ahora mismo se asume un desarrollador en solitario, con arte propio o comprado. Si hay más gente o un artista, el orden de tareas cambia.

**3. Alcance del prototipo.** Confirmar que el objetivo inmediato es un vertical slice jugable, no el juego completo.

Si el usuario no responde alguna, asume Godot 4, un desarrollador, y vertical slice, y dilo explícitamente en el plan.

---

## 1. Qué es el juego

Acción cooperativa para 2–4 jugadores, pixel art, cámara en tres cuartos (~60°), control twin-stick con teclado y ratón. Modo historia. Ambientación: ninjas en una aldea portuaria en decadencia que sobrevive del contrabando.

**Bucle central:**
Pelea limpia → vendes el cuerpo del enemigo → cambias el dinero manchado en el casino → compras técnicas → peleas mejor.

**Los tres sistemas que lo definen:**

1. **El valor del cadáver depende de cómo mataste.** Un corte limpio deja un cuerpo caro. Fuego lo carboniza y no vale nada. El combate se optimiza por valor, no solo por daño.
2. **El casino es infraestructura, no minijuego.** El dinero de los cuerpos está manchado y solo el casino lo cambia, con comisión. Es paso obligatorio, pero apostar nunca lo es.
3. **La bóveda es compartida.** El dinero de una misión lo tienen los cuatro jugadores enteros, no dividido. Apostarlo requiere votación del grupo.

---

## 2. Sistemas a implementar

### 2.1 Combate

**Control:** movimiento con teclado, orientación con cursor. Proyectiles van hacia el cursor. Zonas se colocan en el punto del cursor con indicador previo. Melé y agarres con autoapuntado suave por cono.

**Estructura de habilidades.** Seis estilos, cada uno con exactamente cinco ranuras:

| Ranura | Función | Tecla |
|---|---|---|
| Básico | Melé encadenable (3 golpes), sin coste, recupera chakra | Clic izq. |
| Proyectil | Ataque a distancia, coste bajo | Clic der. |
| Zona | Efecto de suelo, coste alto, indicador antes de soltar | Q |
| Impulso | Movilidad o defensa, recarga corta | Espacio |
| Potenciador | Se lanza sobre un aliado, dura 8 s, nunca afecta a uno mismo | E |
| Sellos | Técnicas ocultas: 3 direccionales manteniendo R, inmóvil mientras | R |

**Regla crítica:** el chakra se recupera golpeando con el Básico, no con el tiempo. Sin esto, en twin-stick todos acampan a distancia.

**Los seis estilos:** Fuego, Agua, Rayo, Viento, Tierra, Físico. Los cinco primeros usan chakra. El Físico no: sustituye Proyectil por agarre y Zona por lanzamiento, y tiene las Puertas (tres niveles que suben daño drenando vida, con vulnerabilidad al cerrar).

**Combinaciones, dos tipos:**
- *De suelo*: una Zona sobre otra ya existente. Viento sobre Fuego = tormenta ígnea. Rayo sobre Agua = charco electrificado. Tierra sobre Agua = barro. Fuego sobre Agua = vapor que ciega. Viento sobre Tierra = polvo.
- *De cuerpo*: un Potenciador sobre un aliado. Viento da impulso, Fuego da puños ardientes, Rayo da velocidad, Agua sana, Tierra da armadura.

El Físico no crea Zonas pero es el único que puede meter enemigos dentro de las ajenas. Con Puertas abiertas, los potenciadores que recibe duran el doble.

Ventana de sincronización para combinaciones: ~0,5 s. El tercer golpe del Básico deja una etiqueta elemental flotando 1,5 s que otro jugador puede activar.

### 2.2 Economía de cadáveres

Cada enemigo muerto genera una entidad cadáver con un **estado de conservación** determinado por el tipo de daño del golpe final: cortante, contundente, quemadura, eléctrico, aplastamiento, veneno.

Cuatro compradores con demandas contradictorias: boticario (órganos frescos), falsificador (caras y documentos), clan rival (bandas y armas), carnicero (todo, poco dinero — es el suelo garantizado).

Los prisioneros vivos (capturas del estilo Sellos) valen 2–3× un cadáver pero hay que extraerlos vivos.

Los cuerpos **pesan**: cuantos más cargas, más lento vuelves al punto de extracción.

### 2.3 Casino

Tres monedas: **manchada** (solo cambiable en el casino), **limpia** (tiendas y taberna), **fichas** (solo se ganan jugando, compran pergaminos).

Comisión de cambio: 15 %.

Cuatro juegos: dados de tres caras, ruleta, cartas selladas contra NPC, y apuestas sobre peleas. Algunos permiten hacer trampa con técnicas ninja, lo que sube un **medidor de sospecha** con tres tramos: verde (nada), ámbar (trampas al doble de coste), rojo (expulsión tres días de juego, sin cambista ni pergaminos).

**Bóveda compartida y votación:**

| Votos a favor | Máximo apostable del bote |
|---|---|
| 1 | 20 % |
| 2 | 50 % |
| 3 | 75 % |
| 4 | 100 % |

Al resolver se muestra quién votó a favor. Si la bóveda queda a cero, aparece el Usurero: fondo mínimo a cambio del 20 % de las cinco misiones siguientes. Modo *Mesa Alta* opcional al crear partida: sin votación ni límites.

### 2.4 Hub, tiendas y taberna

Hub: aldea portuaria en cuatro alturas conectadas por escaleras. Muelle (tablón de misiones y taberna), Calle de los Faroles (comercio), Muelle Alto (casino), Terrazas (casa del equipo y ruinas del clan).

Tiendas de dinero limpio: forja (mejoras de arma, tres niveles, sin aleatoriedad), sastrería (cosmético puro), herboristería (máximo 3 consumibles por jugador y misión), casa del equipo (mejoras de calidad de vida compradas con la bóveda).

Taberna *El Ancla Rota*: brindis que da bonus de grupo para la siguiente misión (bebidas distintas dan mejor bonus que iguales), desglose de la contribución de cada jugador, pizarra con deudas y récords tontos, música diegética con canciones desbloqueables, emotes y sillas sin función mecánica.

### 2.5 Misiones

Duración objetivo **12–18 minutos**. Tres áreas encadenadas, un objetivo, y vuelta al punto de extracción cargando el botín. Cinco biomas: costa, bosque de bambú, camino de montaña, cantera, ruinas del clan.

---

## 3. Restricciones técnicas

**Red.** Host-autoritativo, empezando por 2 jugadores. Los combos se validan en cliente y el host confirma, aceptando el resultado del cliente salvo que sea imposible. Sin esto, las ventanas de combo se sienten mal con latencia.

**El cooperativo va desde el primer commit.** Convertir un juego de un jugador a multijugador después implica reescribir el estado entero. Aunque el primer prototipo sea local, la arquitectura debe contemplar dos actores desde el principio.

**Sprites en tres capas:** piernas (dirección de movimiento), torso (rota con el cursor), efecto elemental (sprite independiente). Así seis estilos no multiplican por seis las animaciones del personaje.

**Efectos de suelo siempre planos**, aunque el escenario esté en perspectiva. Si el charco eléctrico se dibuja en tres cuartos, el jugador no sabe dónde acaba.

**Control:** teclado y ratón es el esquema primario. El mando necesita un esquema de autoapuntado paralelo o queda fuera.

---

## 4. Reglas invariantes

No se rompen aunque simplifiquen la implementación:

- Ninguna técnica necesaria para avanzar en la historia está detrás del casino
- Las técnicas compradas y el progreso de historia nunca entran en la bóveda; solo se arriesga dinero líquido
- Las fichas no se venden por dinero real, ni directa ni indirectamente
- Ninguna mejora permanente supera el +20 % sobre la base
- Los bonus de comida y casa se aplican a todo el grupo, no solo a quien pagó
- Ningún estilo puede ser puramente de apoyo: todos hacen daño y todos aportan al grupo

---

## 5. Hitos, dependencias y criterio de "hecho"

El plan debe respetar este orden. Cada hito depende del anterior.

**H1 — Prototipo de combate**
Alcance: tres estilos (Fuego, Viento, Físico), una sala, enemigos de comportamiento simple, dos jugadores.
*Hecho cuando:* dos personas pueden pelear 20 minutos seguidos sin aburrirse, la combinación viento+fuego colocada con el cursor se siente satisfactoria, y el Físico llega a la pelea a tiempo sin sentirse excluido.

**H2 — Bucle económico**
Depende de H1. Alcance: cadáveres con estado de conservación, carnicero y boticario, peso del botín, extracción.
*Hecho cuando:* el jugador cambia cómo pelea para conseguir mejores cuerpos, de forma observable.

**H3 — Casino mínimo**
Depende de H2. Alcance: cambista con comisión y el juego de dados. Sin sospecha, sin pergaminos.
*Hecho cuando:* la comisión del 15 % pica lo suficiente como para que el jugador quiera intentar recuperarla jugando.

**H4 — Bóveda y votación**
Depende de H3. Alcance: bote compartido, votación con fichas, revelación de votos.
*Hecho cuando:* cuatro personas reales discuten antes de apostar. Este hito se valida con gente, no con tests.

**H5 — Hub y taberna**
Depende de H4. Alcance: aldea navegable, tiendas de dinero limpio, taberna con brindis y desglose.
*Hecho cuando:* los jugadores se quedan en la taberna sin que nada les obligue.

**H6 — Estilos restantes e historia**
Depende de H5. Agua, Rayo, Tierra, sistema de sellos y pergaminos, prólogo y elección de estilo.

---

## 6. Qué NO hacer en el prototipo

Estas son las formas clásicas de que el proyecto muera antes de ser jugable:

- Implementar los seis estilos antes de saber si el combate funciona con tres
- Construir el mundo entero antes de tener una sala divertida
- Empezar por la historia o el diálogo
- Saltar directo a cuatro jugadores en red
- Producir arte final antes de que el combate esté cerrado

---

## 7. Qué se espera de ti, Claude Code

1. Pregunta las tres decisiones bloqueantes del apartado 0.
2. Genera un plan de trabajo en tareas concretas, agrupadas por hito, con dependencias explícitas entre ellas.
3. Para H1, baja al detalle: estructura de carpetas, escenas o entidades necesarias, orden de implementación de sistemas (movimiento → apuntado → básico → chakra → zonas → combinaciones → segundo jugador).
4. Señala los puntos donde la decisión de diseño aún es ambigua y hace falta una respuesta del usuario antes de codificar.
5. No escribas código hasta que el plan esté aprobado.

**Preguntas abiertas conocidas** que el plan debe recoger:
- Fórmula concreta de valor del cadáver según tipo de daño
- Cómo se sincroniza exactamente la ventana de 0,5 s con latencia
- Si el mando entra en el alcance del prototipo o se descarta de momento
- Nombres definitivos de los seis estilos (`Físico` es un marcador de posición y suena a categoría de menú al lado de los cinco elementos)
