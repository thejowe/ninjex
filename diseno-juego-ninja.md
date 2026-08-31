# Documento de diseño

Acción cooperativa 2–4 jugadores · pixel art tres cuartos · modo historia
Aldea portuaria en decadencia · ninjas, cadáveres y un casino

**Resolución de arte: sprites 32x32 px.**

---

## 1. Sistema de habilidades

### Estructura común

Cada estilo tiene exactamente **cinco cosas**. Ni una más, para que se aprenda en cinco minutos:

| Ranura | Qué es | Tecla |
|---|---|---|
| **Básico** | Ataque cuerpo a cuerpo encadenable, sin coste | Clic izquierdo |
| **Proyectil** | Ataque a distancia hacia el cursor, coste bajo | Clic derecho |
| **Zona** | Efecto colocado en el suelo con indicador previo, coste alto | Q |
| **Impulso** | Movilidad o defensa, con recarga corta | Espacio |
| **Potenciador** | Se lanza sobre un aliado, dura 8 s | E |

El **Potenciador** es la clave del cooperativo: nunca afecta al que lo lanza. Solo sirve para otros. Eso obliga a mirar al compañero.

### Sellos y cadenas

Propuesta de input, resolviendo el hueco pendiente:

- El **Básico** encadena hasta tres golpes con clics rítmicos. El tercer golpe deja una **etiqueta elemental flotando** durante 1,5 s en el punto de impacto.
- Esa etiqueta es lo que otro jugador puede activar con su propia técnica. Ahí nace la combinación.
- Mantener **Q** carga la Zona: aparece el indicador en el suelo, se coloca al soltar. Cargar más tiempo aumenta el radio y el coste.
- Los **sellos** de las técnicas ocultas (pergaminos del casino) son la única excepción: una secuencia de 3 teclas direccionales mientras mantienes **R**. Lentas, potentes, y te dejan inmóvil mientras las haces. Son el momento de riesgo, no el uso habitual.

**No hay barra de chakra que se rellene sola.** El chakra se recupera golpeando con el Básico. Eso fuerza a entrar en la pelea en vez de acampar a distancia, que es el fallo típico de los twin-stick.

### Los seis estilos

**Fuego** — presión y negación de terreno
- Básico: llamarada corta en arco
- Proyectil: bola que estalla al impactar
- Zona: brasas persistentes, daño por segundo a quien las pise
- Impulso: paso ardiente, deja rastro de fuego
- Potenciador: puños ardientes, los golpes del aliado queman

**Agua** — preparación y sanación
- Básico: latigazo de agua, empapa al golpear
- Proyectil: chorro a presión, empuja levemente
- Zona: charco, ralentiza y deja empapado
- Impulso: se disuelve y reaparece a unos metros
- Potenciador: sella heridas del aliado y limpia quemadura/veneno

**Rayo** — velocidad y control
- Básico: golpe corto con aturdimiento leve al tercer impacto
- Proyectil: descarga que salta a un segundo enemigo cercano
- Zona: campo eléctrico, aturde a intervalos
- Impulso: parpadeo instantáneo hacia el cursor
- Potenciador: el aliado ataca un 40 % más rápido

**Viento** — reposicionamiento
- Básico: cortes rápidos de alcance medio
- Proyectil: cuchilla de aire, atraviesa varios enemigos en línea
- Zona: torbellino que arrastra enemigos al centro
- Impulso: salto largo, ignora desniveles
- Potenciador: impulso al aliado, cierra distancia volando

**Tierra** — resistencia y bloqueo
- Básico: puñetazo pesado, lento y contundente
- Proyectil: roca en arco, cae y aturde
- Zona: muro que bloquea paso y proyectiles, destruible
- Impulso: se ancla al suelo, inmune a empujones 2 s
- Potenciador: armadura de piedra al aliado, absorbe daño

**Físico** — sin chakra, cuerpo a cuerpo puro
- Básico: cadena de puñetazos rápida, la más larga del juego (5 golpes)
- Proyectil: no tiene. En su lugar, **agarre**: coge a un enemigo
- Zona: no tiene. En su lugar, **lanzamiento**: tira al agarrado hacia el cursor
- Impulso: embestida que atraviesa enemigos
- Potenciador: tras un agarre exitoso, devuelve chakra al aliado que le potenció

**Puertas**: mecánica exclusiva del Físico. Mantener **F** abre un nivel. Cada nivel sube daño y velocidad, y drena vida de forma continua. Tres niveles. Al cerrar, queda vulnerable unos segundos proporcionales al tiempo abierto. Con Puertas abiertas, **todos los potenciadores que reciba duran el doble**.

### Combinaciones

Dos formas, ambas activas todo el rato:

**Combinación de suelo** — una técnica de Zona sobre otra ya existente:
- Viento sobre Fuego → tormenta ígnea que se expande
- Rayo sobre Agua → charco electrificado, aturde a todo lo que entre
- Tierra sobre Agua → barro, ralentiza mucho y facilita remates limpios
- Fuego sobre Agua → vapor, bloquea la visión de los enemigos
- Viento sobre Tierra → tormenta de polvo, los enemigos fallan ataques

**Combinación de cuerpo** — un Potenciador sobre un aliado. Ya listadas arriba. La regla es simple: **el suelo lo hacen las Zonas, el cuerpo lo hacen los Potenciadores.**

El Físico no crea Zonas, pero es el único que puede meter enemigos dentro de las de otros. Es su asiento en la mesa.

---

## 2. Mapa

### Estructura general

Un **hub** grande y acogedor, y misiones que salen de él hacia el exterior. Nada de mundo abierto: el hub se recorre a pie y las misiones se eligen desde un tablón.

### El hub: Puerto Bajo

Una aldea portuaria construida en terrazas sobre un acantilado. Farolillos, madera húmeda, tejados apretados, siempre de tarde o de noche. El clan perdió la guerra hace veinte años y ahora sobrevive del contrabando.

Cuatro alturas, conectadas por escaleras:

**Muelle (nivel 0)** — donde llegas y sales
- Tablón de misiones y el barco que te lleva a ellas
- **El Ancla Rota**: la taberna del equipo
- Puestos de pescado, redes, cajas de contrabando

**Calle de los Faroles (nivel 1)** — comercio
- Mercado negro (dinero manchado)
- Herboristería del boticario
- Taller del falsificador
- Forja y sastrería (dinero limpio)

**El Muelle Alto (nivel 2)** — el casino
- Fachada llamativa, lo único con dinero visible en toda la aldea
- Dentro: mesas, cambista, tienda de pergaminos, sala privada

**Las Terrazas (nivel 3)** — vivienda y clan
- Casa del equipo, personalizable
- Ruinas de la sede del clan, donde vive el viejo maestro
- Mirador con vista al mar: sitio tranquilo, cero mecánicas, solo ambiente

### Zonas de misión

Cinco biomas, cada uno con su comprador natural cerca:

| Zona | Ambiente | Enemigos | Particularidad |
|---|---|---|---|
| **Costa de los Naufragios** | Playa, restos de barcos | Contrabandistas | Marea sube y cierra rutas |
| **Bosque de Bambú** | Verde, niebla, vertical | Ninjas desertores | Visión reducida, emboscadas |
| **Camino de Peaje** | Montaña, puentes | Bandidos organizados | Convoyes en movimiento |
| **Cantera Vieja** | Piedra, polvo, cavernas | Mercenarios con armadura | Sin luz, hay que iluminar |
| **Ruinas del Clan** | Templo derruido | Guardianes antiguos | Zona de historia, la más difícil |

### Diseño de una misión

Duración objetivo: **12–18 minutos**. Corto es importante, porque el bucle interesante está en volver a vender y apostar.

Estructura: tres salas o áreas encadenadas, un objetivo (matar a alguien concreto, robar algo, escoltar), y **la vuelta al barco cargando lo que hayas recogido**. Los cuerpos pesan: cuantos más lleves, más lento vas. Ahí está la decisión de cuánto codiciar.

---

## 3. El casino

### Por qué existe en la ficción

El dinero que sacas vendiendo cuerpos está manchado. Nadie en la aldea lo acepta. El casino es el único sitio que lo cambia por moneda limpia, y se queda una comisión del 15 %.

Eso lo hace **de paso obligatorio pero nunca de apuesta obligatoria**. Puedes cambiar y marcharte. Solo pierdes la comisión.

### Tres monedas

| Moneda | Cómo se consigue | Para qué sirve |
|---|---|---|
| **Manchada** | Vender cuerpos y material | Solo cambiarla en el casino |
| **Limpia** | Cambio con comisión, y pagas de misión | Tiendas, taberna, casa, mejoras |
| **Fichas** | Solo jugando en el casino | Pergaminos y técnicas ocultas |

La clave: **las fichas no se compran con dinero limpio**. Solo se ganan en las mesas. Por eso las técnicas raras están detrás del casino sin que la progresión lo esté: todas las técnicas necesarias se ganan en misiones, las del casino son alternativas laterales y cosméticos.

### Los juegos

**Dados de tres caras** — el juego rápido
Apuestas alto o bajo, se tiran tres dados. Aquí entra la trampa: mantener una tecla usa una técnica de **Viento** para empujar un dado justo antes de que pare. Sube el **medidor de sospecha**.

**La Rueda del Clan** — el juego del bote grande
Ruleta con sectores. Apuesta única por ronda, pagos altos. Sin trampa posible: es el juego limpio, para cuando quieres suerte pura.

**Cartas Selladas** — el juego de habilidad
Póker simplificado contra tres NPC. Con **Sellos** puedes ver una carta rival durante medio segundo. Con **Rayo** puedes acelerar tu propio turno y decidir con más tiempo. Es el juego donde el estilo importa de verdad.

**Peleas del Sótano** — el juego social
Combates de NPC en una arena. No juegas: apuestas. Si hay otros jugadores conectados, **podéis apostar sobre vuestros propios duelos**. Es la mesa donde el grupo se pica.

### El medidor de sospecha

Sube al hacer trampa, baja lentamente con el tiempo y jugando limpio. Tres tramos:

- **Verde**: nadie mira
- **Ámbar**: un vigilante te sigue por la sala, las trampas cuestan el doble de chakra
- **Rojo**: te expulsan tres días de juego. Pierdes acceso al cambio de moneda y a los pergaminos

La expulsión es lo que da peso: sin cambista, tu dinero manchado se acumula sin poder usarse. Duele sin bloquear nada de forma permanente.

### La bóveda compartida

El dinero de la misión llega entero a los cuatro. No se divide: **los 2000 los tienen todos**.

Cualquiera del grupo apuesta directamente de la bóveda, sin votar ni pedir permiso. Es dinero de todos, y cualquiera puede arriesgarlo.

Si la bóveda queda a cero, aparece **el Usurero**: te adelanta un fondo mínimo a cambio de un 20 % de las próximas cinco misiones. Aparece por la taberna a recordarlo. El desastre se convierte en trama.

### Reglas duras

- Ninguna técnica necesaria para avanzar está detrás del casino
- Los pergaminos ya comprados y el progreso de historia **nunca** entran en la bóveda
- Solo se arriesga dinero líquido
- **Las fichas no se venden por dinero real.** Ni en ninguna forma indirecta. Es la línea que te mantiene fuera de la regulación de loot boxes

---

## 4. Tiendas y dinero limpio

El dinero limpio es el que gasta el jugador en sentirse mejor. Nada de él es aleatorio: sabes exactamente qué compras.

### Mercado negro (manchado, en la Calle de los Faroles)

Donde vendes. Cuatro compradores fijos con demandas contradictorias:

| Comprador | Quiere | Paga mal por |
|---|---|---|
| **Boticario** | Órganos frescos, cuerpos sin quemar | Cuerpos carbonizados o aplastados |
| **Falsificador** | Caras reconocibles, documentos, ropa | Cuerpos desfigurados |
| **Clan rival** | Bandas de la frente, armas, pruebas | Cuerpos anónimos |
| **Carnicero del puerto** | Peso, sin preguntas | Todo, pero poco |

El carnicero es el suelo: siempre compra, siempre paga poco. Existe para que nunca vuelvas con las manos vacías.

**Prisioneros vivos** (capturas del estilo Sellos) valen entre 2 y 3 veces un cadáver, pero hay que sacarlos vivos de la misión y no atacar por error.

### Tiendas de dinero limpio

**Forja** — mejoras permanentes de arma. Tres niveles por arma, precios crecientes. Sin aleatoriedad, sin rareza. Compras nivel 2, tienes nivel 2.

**Sastrería** — cosmético puro. Ropa, colores, máscaras, bandas. Es donde va a parar el dinero de la gente que juega mucho, y no afecta al equilibrio.

**Herboristería** — consumibles para la misión. Máximo tres por jugador y misión, para que sean una decisión y no un inventario:
- Píldora de soldado: recupera chakra
- Ungüento: cura por goteo 20 s
- Bomba de humo: escape garantizado
- Sales: reducen el desgaste de las Puertas

**Casa del equipo** — mejoras de calidad de vida, compradas entre todos con la bóveda:
- Cocina: comidas que dan bonus antes de salir
- Almacén: aumenta cuántos cuerpos podéis cargar
- Palomar: permite rechazar una misión sin penalización
- Jardín: cultiva reactivos para la herboristería

### Boosts, con freno

Los bonus permanentes escalan mal en cooperativo: el que juega más se vuelve intocable y el amigo nuevo no puede seguir el ritmo. Dos frenos:

1. **Techo bajo**: ninguna mejora pasa de +20 % sobre la base
2. **Bonus de grupo, no individual**: las comidas y los bonus de la casa se aplican a todos los que salgan en la misión, vengan o no de tu dinero

---

## 5. La taberna: El Ancla Rota

El sitio donde el juego respira. Está en el muelle, es lo primero que ves al volver de una misión, y es donde se reparte lo que habéis ganado.

### Función mecánica

**El brindis.** Al volver de una misión, el equipo puede sentarse a beber. Cada jugador pide algo, y la ronda cuesta dinero limpio de la bóveda. Efecto: un bonus de grupo que dura **la siguiente misión**, y que depende de qué haya pedido cada uno. Cuatro bebidas distintas dan un bonus mejor que cuatro iguales. Empuja a hablar antes de pedir.

**El desglose.** Sobre la mesa aparece lo que hizo cada uno: cuerpos intactos, bajas, combinaciones habilitadas, curaciones. Es donde el que hizo el trabajo sucio ve reconocida su parte aunque el dinero esté mezclado.

**Cuentas pendientes.** La taberna fía. Si bebéis sin dinero, se apunta en la pizarra. La deuda se acumula visible en la pared, y la tabernera la menciona cada vez que entráis. Nunca bloquea nada: solo da vergüenza.

### Función acogedora

Esto no es relleno. Es lo que hace que el juego se recuerde como cálido y no como una máquina de picar cadáveres.

- **Nadie te apura.** No hay temporizador, no hay evento que empiece. Puedes quedarte sentado.
- **Conversaciones que avanzan.** Cada NPC fijo (la tabernera, el viejo maestro, el usurero, el pescador) tiene una línea nueva por misión completada. Historias pequeñas que se desarrollan en el fondo.
- **Emotes y sillas.** Los jugadores pueden sentarse en sitios concretos, brindar entre ellos, dormirse en la mesa. Cosas sin función que la gente usa para hacer fotos.
- **Música diegética.** Un músico en la esquina. Puedes pedirle canciones con dinero limpio, y se desbloquean más según avanzas. La banda sonora del hub la eliges tú.
- **La pizarra.** Además de las deudas, registra récords tontos del grupo: quién ha perdido más en el casino, quién ha destrozado más cuerpos, quién ha caído más veces. Historia compartida, escrita sola.

### Por qué la taberna importa al diseño

Es el contrapeso emocional. El bucle del juego es violento y avaro: matas, troceas, vendes, apuestas. Sin un sitio donde parar, el tono acogedor no existe: solo hay una hoja de cálculo con sangre.

La taberna es donde el juego dice **"esta gente son amigos"** en vez de "esta gente son un equipo eficiente". Y es gratis de producir comparado con una zona de combate.

---

## Orden de construcción

1. **Prototipo de combate**: Fuego, Viento y Físico. Una sala, enemigos tontos, dos jugadores en red o con mando. Pregunta a responder: ¿la combinación colocada con el cursor se siente bien, y el Físico llega a tiempo?
2. **Bucle económico**: añadir cadáveres con estado de conservación, el carnicero y el boticario. Sin casino.
3. **Casino mínimo**: solo el cambista y los dados. Comprobar si el 15 % de comisión pica lo suficiente como para querer jugar.
4. **Bóveda compartida**: apuesta libre del bote común, sin votación. Probar con cuatro personas reales cómo se siente arriesgar dinero que es de todos.
5. **Taberna y hub**: cuando el bucle ya funcione. Es la capa que lo hace acogedor, no la que lo hace jugable.
6. **Historia y estilos restantes**: al final, sobre una base que ya se sostiene.

**Lo que no debe entrar en el prototipo**: los seis estilos, la historia, el mundo entero, el multijugador de cuatro. Son las cuatro formas clásicas de que un proyecto indie se muera antes de ser jugable.
