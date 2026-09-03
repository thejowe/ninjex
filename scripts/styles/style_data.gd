extends Resource
class_name StyleData
## Datos ajustables de UN estilo de combate (danos, costes, tiempos).
##
## Se guardan como .tres en res://resources/styles/ para poder tocar
## numeros en playtesting sin recompilar nada. Tanda H1 7-11: se anaden los
## campos de Proyectil/Agarre, Zona/Lanzamiento, Impulso, Puertas y vida,
## ademas de los de Basico+chakra que ya existian.
##
## Un mismo Resource sirve para un estilo "normal" (Fuego, Viento: usan
## chakra, tienen Proyectil y Zona) o para el Fisico (melee_only = true:
## sin chakra, sin Proyectil ni Zona -- los sustituye Agarre y Lanzamiento,
## y tiene Puertas). El player.gd decide que ranura usar mirando este flag,
## en vez de tener una clase distinta por tipo de estilo.

@export var style_name: String = "Estilo base (placeholder)"
## Debe coincidir con los strings ya usados en status_tag.gd: "fuego",
## "viento", "fisico" (o "placeholder" para el resource generico de H1 5-6).
@export var element_name: String = "placeholder"
## Fisico no usa chakra ni tiene Proyectil/Zona: Agarre sustituye a Proyectil
## y Lanzamiento sustituye a Zona. Puertas solo tiene sentido si esto es true.
@export var melee_only: bool = false

@export_group("Chakra")
## Chakra maximo del estilo. En Fisico se deja a 0 (no usa Proyectil/Zona/
## Potenciador/Loadout Q-E/Soporte -- Agarre/Lanzamiento/Puertas/Sellos-fisico
## siguen gratis).
@export var chakra_max: float = 100.0
## DEPRECADO (rework de combate 2026-09-03, plan-desarrollo.md seccion 2.1
## T1): hasta esta tanda el chakra SOLO se recuperaba golpeando con el
## Basico, nunca con el tiempo -- la regla mas repetida del diseno original
## (diseno-juego-ninja.md, brief-traspaso-claude-code.md). El usuario pidio
## explicitamente sustituirla por regeneracion pasiva (ver
## chakra_regen_per_second abajo); se documenta aqui, no se borra el campo,
## para no tener que tocar los 6 .tres que todavia lo declaran -- ya no lo
## lee ningun submit_*/confirm_* de player.gd.
@export var chakra_recovered_per_hit: float = 12.0
## Chakra recuperado por segundo, todo el rato, sin necesidad de golpear con
## nada (T1). Es el reemplazo directo de chakra_recovered_per_hit de arriba.
## Con esto, lo que obliga a volver al Basico entre usos de una ranura ya no
## es "necesito chakra", es el cooldown propio de cada ranura (ver los
## grupos de abajo) -- el Basico sigue siendo la UNICA ranura sin cooldown.
## Se ignora si chakra_max <= 0 (Fisico).
@export var chakra_regen_per_second: float = 10.0

@export_group("Basico")
@export var basic_damage: float = 8.0
## Alcance y semiangulo (grados) del golpe melee para detectar enemigos.
## Se usa para los 3 estilos, incluido Fisico: el "hit real" del Basico
## era un hueco de la tanda anterior (solo llevaba combo+chakra, sin danar
## a nadie) -- se completa aqui porque sin esto el combate no se puede
## probar de verdad.
@export var basic_range: float = 70.0
@export var basic_cone_degrees: float = 80.0
## Ventana en segundos para encadenar el siguiente golpe antes de que el
## combo se reinicie a 0.
@export var basic_combo_window: float = 0.6
## Duracion de la etiqueta elemental que deja el tercer golpe.
@export var basic_tag_duration: float = 1.5

@export_group("Proyectil")
## Coste de chakra para lanzar un Proyectil. No se usa si melee_only.
@export var projectile_chakra_cost: float = 15.0
## Cooldown propio de la ranura (T1, rework de combate 2026-09-03): sin
## esto, con el chakra ya regenerandose solo por tiempo, nada obligaria a
## volver al Basico entre Proyectiles -- ver comentario de
## chakra_regen_per_second arriba.
@export var projectile_cooldown: float = 2.5
@export var projectile_speed: float = 520.0
@export var projectile_damage: float = 14.0
@export var projectile_max_distance: float = 650.0
## Fuego: bola que estalla al impactar -- radio de la explosion (area).
@export var projectile_explosion_radius: float = 55.0
## Viento: cuchilla de aire, atraviesa varios enemigos en linea en vez de
## destruirse al primer impacto.
@export var projectile_pierces: bool = false

@export_group("Agarre (solo Fisico)")
## Cono estrecho de autoapuntado suave frente al jugador para elegir el
## enemigo mas cercano a agarrar.
@export var grab_range: float = 90.0
@export var grab_cone_degrees: float = 40.0
## Distancia a la que se sostiene al enemigo agarrado, delante del jugador.
@export var grab_hold_offset: float = 40.0
## Si no se lanza antes de esto, el agarre se suelta solo.
@export var grab_hold_duration: float = 3.5
## Cooldown propio de la ranura (T1): Fisico no paga chakra por el Agarre,
## pero sigue necesitando algo que le impida re-agarrar sin limite -- mismo
## rol que projectile_cooldown para el resto de estilos (misma ranura, otro
## nombre de campo porque vive en su propio export_group, igual que el resto
## de Agarre/Lanzamiento frente a Proyectil/Zona).
@export var grab_cooldown: float = 2.0

@export_group("Zona")
## Cargar Q mas tiempo sube radio y coste linealmente hasta estos maximos.
@export var zone_chakra_cost_min: float = 30.0
@export var zone_chakra_cost_max: float = 55.0
@export var zone_radius_min: float = 55.0
@export var zone_radius_max: float = 125.0
@export var zone_charge_time_max: float = 1.2
@export var zone_duration: float = 6.0
## Fuego: brasas persistentes, dano por segundo a quien las pise.
@export var zone_damage_per_second: float = 12.0
## Viento: torbellino, fuerza con la que arrastra enemigos al centro.
@export var zone_pull_force: float = 220.0
## Agua/Tierra: charco/barro, multiplica la velocidad de quien pise dentro
## (1.0 = sin efecto, 0.4 = se mueve al 40%). Mecanismo nuevo de H6 --
## reutiliza el mismo "quien esta encima, que le pasa" que ya usan
## damage_per_second (quema) y pull_force (arrastra), pero para ralentizar
## en vez de daño/empuje. Ver GroundZone._apply_slow() y
## EnemigoSimple.slow_multiplier.
@export var zone_slow_factor: float = 1.0
## Cooldown propio de la ranura (T1), ademas del coste de chakra que ya
## tenia -- ver comentario de projectile_cooldown arriba, mismo motivo.
@export var zone_cooldown: float = 3.0

@export_group("Lanzamiento (solo Fisico)")
## Sustituye a la Zona: tira al enemigo agarrado hacia el cursor.
@export var throw_speed: float = 900.0
@export var throw_damage: float = 20.0
## Cooldown propio de la ranura (T1) -- mismo motivo que grab_cooldown.
@export var throw_cooldown: float = 2.0

@export_group("Impulso")
@export var impulse_cooldown: float = 3.0
@export var impulse_distance: float = 180.0
## Cuanto tarda en recorrer esa distancia (mayor = se ve mas "salto", menor
## = mas "parpadeo").
@export var impulse_travel_time: float = 0.22
## Fuego: paso ardiente, deja un rastro de fuego detras.
@export var impulse_trail_duration: float = 3.0
@export var impulse_trail_damage_per_second: float = 10.0
## Viento: salto largo, ignora colisiones/desniveles brevemente tras saltar.
@export var impulse_ignore_collision_duration: float = 0.3
## Fisico: embestida, atraviesa enemigos en el camino.
@export var impulse_pierce_damage: float = 16.0
@export var impulse_pierce_width: float = 34.0
## Agua: el Impulso es un golpe de corriente que cura un poco al usarlo (no
## solo movilidad, a diferencia de Fuego/Viento/Fisico que son puro
## desplazamiento/daño).
@export var impulse_self_heal: float = 0.0
## Rayo: tras el Impulso, breve empuje extra de velocidad de movimiento
## (la sensacion de "salir disparado" que pide el elemento).
@export var impulse_speed_boost_multiplier: float = 1.0
@export var impulse_speed_boost_duration: float = 0.0
## Tierra: al activar el Impulso, onda de choque que daña a los enemigos
## cercanos al punto de partida (ademas del propio desplazamiento).
@export var impulse_shockwave_damage: float = 0.0
@export var impulse_shockwave_radius: float = 0.0

@export_group("Puertas (solo Fisico)")
## Mantener F escala nivel 1 -> 2 -> 3 mientras se mantiene abierto.
@export var puertas_niveles_max: int = 3
@export var puertas_tiempo_por_nivel: float = 2.5
## +X% de dano y velocidad por nivel abierto (nivel * este valor).
@export var puertas_damage_multiplier_per_level: float = 0.35
@export var puertas_speed_multiplier_per_level: float = 0.15
@export var puertas_life_drain_per_second_per_level: float = 4.0
## Segundos de vulnerabilidad al cerrar = tiempo_abierto * este factor.
@export var puertas_vulnerability_factor: float = 0.5
## Multiplicador de dano recibido durante la vulnerabilidad.
@export var puertas_vulnerability_damage_multiplier: float = 2.0
## Con las Puertas abiertas, cualquier Potenciador que reciba dura el doble.
## HOOK preparado para cuando exista el Potenciador (tarea futura, no
## implementada en esta tanda) -- ver Player.potenciador_duration_multiplier().
@export var puertas_potenciador_duration_multiplier: float = 2.0

@export_group("Potenciador")
## Duracion base del Potenciador (segundos). Se multiplica x
## potenciador_duration_multiplier() del objetivo si tiene Puertas abiertas.
@export var potenciador_duration: float = 8.0
## Coste de chakra para lanzarlo. No se usa si melee_only (el Fisico no
## tiene Potenciador propio, ver brief 2.1).
@export var potenciador_chakra_cost: float = 25.0
## Cooldown propio de la ranura (T1) -- ver comentario de projectile_cooldown
## arriba, mismo motivo. Sin uso si melee_only (Fisico no tiene Potenciador
## propio).
@export var potenciador_cooldown: float = 5.0
## Alcance y semiangulo (grados) del cono frente al jugador para elegir el
## aliado mas cercano al que lanzarlo. Mismo patron que grab_range/cone.
@export var potenciador_range: float = 110.0
@export var potenciador_cone_degrees: float = 50.0
## Fuego: mientras el buff este activo, cada golpe de Basico del objetivo
## suma este bonus de dano y se fuerza el tipo "quemadura".
@export var potenciador_fuego_damage_bonus: float = 5.0
## Viento: dash instantaneo del objetivo hacia el que lanza el Potenciador
## al conectar (cierra distancia). Mismo mecanismo que el Impulso propio.
@export var potenciador_viento_dash_distance: float = 220.0
@export var potenciador_viento_dash_travel_time: float = 0.22
## Fisico (solo melee_only): si el objetivo tiene un Potenciador activo (de
## cualquier elemento) y consigue un Agarre, devuelve esta chakra al peer
## que se lo lanzo, y consume el buff.
@export var potenciador_grab_chakra_return: float = 20.0
## Agua: "sana" (brief 2.1) -- cura por goteo al objetivo mientras dure el
## buff, mismo mecanismo que el Unguento de Herboristeria pero repartido en
## potenciador_duration en vez de UNGUENTO_DURATION.
@export var potenciador_agua_heal_total: float = 0.0
## Rayo: "da velocidad" -- multiplicador de velocidad de movimiento del
## objetivo mientras dure el buff.
@export var potenciador_rayo_speed_multiplier: float = 1.0
## Tierra: "da armadura" -- reduce el daño recibido por el objetivo mientras
## dure el buff (0.7 = recibe 70% del daño normal).
@export var potenciador_tierra_damage_reduction: float = 1.0

@export_group("Sellos")
## Tecnica oculta de pergamino (brief "Sellos y cadenas"): secuencia de 3
## direccionales manteniendo R, inmovil mientras se hacen -- el momento de
## riesgo, no el uso habitual. Exactamente UNA tecnica por estilo (los
## numeros de abajo). H6: ya NO es gratis por tener el estilo equipado --
## hace falta haber comprado su pergamino en la Tienda de Pergaminos del
## Muelle Alto (fichas, NetworkManager.pergaminos_sellos_comprados) -- ver
## submit_sellos_technique/submit_comprar_pergamino en player.gd.
@export var sellos_technique_name: String = "Sello sin nombre (placeholder)"
## Coste de chakra. Se ignora si el estilo no usa chakra (melee_only, Fisico:
## chakra_max = 0) -- el Fisico saca su Sello gratis, igual que no paga por
## el Agarre/Lanzamiento.
@export var sellos_chakra_cost: float = 40.0
## Cooldown propio de la ranura (T1) -- ver comentario de projectile_cooldown
## arriba. Se aplica siempre, incluido Fisico (que no paga chakra pero sigue
## necesitando algo que evite repetirlo sin limite -- mismo criterio que
## grab_cooldown/throw_cooldown).
@export var sellos_cooldown: float = 8.0
## Radio de la tecnica (area alrededor del jugador al completar la
## secuencia). No se usa en Fisico, que apunta en cono como el
## Basico/Agarre en vez de area -- ver sellos_fisico_* abajo.
@export var sellos_radius: float = 140.0
## Fuego: nova (tipo quemadura). Rayo: descarga (tipo electrico). Tierra:
## puño sismico (tipo aplastamiento). Los tres usan sellos_damage/sellos_radius
## tal cual, solo cambia el damage_type resultante segun _basic_damage_type().
@export var sellos_damage: float = 45.0
## Viento: ademas del daño en area, arrastra de golpe a los enemigos
## alcanzados hacia el punto de origen esta distancia (tiron instantaneo,
## a diferencia del arrastre progresivo de la Zona).
@export var sellos_viento_pull_distance: float = 90.0
## Agua: en vez de daño de area, cura de golpe al propio jugador esta
## cantidad -- coherente con su identidad de "preparacion y sanacion".
@export var sellos_agua_self_heal: float = 60.0
## Fisico (melee_only): sustituye el area por un cono como el Basico/Agarre,
## sin coste de chakra. Golpe unico mucho mas fuerte que el Basico: el
## "momento de riesgo" del brief para un estilo que no tiene chakra que
## arriesgar.
@export var sellos_fisico_range: float = 100.0
@export var sellos_fisico_cone_degrees: float = 90.0
@export var sellos_fisico_damage: float = 55.0

@export_group("Loadout Q")
## Rework de combate 2026-09-03 (plan-desarrollo.md seccion 2.1, T2): la
## tecla Q deja de ser la Zona fija (movida a Mayus/Shift, ver project.godot)
## y pasa a ser un hueco de tecnica equipable por estilo. Golpe unico en cono
## como el Basico, mas fuerte, con su propio coste de chakra y cooldown --
## esta es la tecnica de FABRICA de este hueco (T2: "al menos una tecnica
## inicial ademas del Sellos ya existente"). El pool de tecnicas comprables
## que se puedan equipar aqui es T4 (fuera de esta tanda) -- ver
## NetworkManager.loadout_equipped para el punto de extension: player.gd
## resuelve la tecnica activa por id ("factory" es la unica que existe hoy)
## en vez de tener el efecto fijo siempre, para que T4 no tenga que tocar la
## ranura en si.
@export var loadout_q_name: String = "Golpe cargado (placeholder)"
## Se ignora si el estilo no usa chakra (melee_only).
@export var loadout_q_chakra_cost: float = 20.0
@export var loadout_q_cooldown: float = 3.5
@export var loadout_q_range: float = 90.0
@export var loadout_q_cone_degrees: float = 70.0
@export var loadout_q_damage: float = 16.0

@export_group("Loadout E")
## Mismo mecanismo que Loadout Q de arriba, hueco independiente (la tecla E
## deja de ser el Potenciador fijo, movido a Ctrl). A diferencia de Q (cono,
## un solo golpe fuerte), la tecnica de fabrica de E es un estallido de area
## alrededor del propio jugador -- variedad de forma entre los dos huecos,
## no solo de numeros.
@export var loadout_e_name: String = "Onda de impacto (placeholder)"
@export var loadout_e_chakra_cost: float = 25.0
@export var loadout_e_cooldown: float = 5.0
@export var loadout_e_radius: float = 90.0
@export var loadout_e_damage: float = 12.0

@export_group("Soporte")
## Ranura nueva (T3, tecla F15 -- ver project.godot, F1-F14 ya estaban
## ocupadas). Cura/escudo/efecto NO ofensivo -- a diferencia del Potenciador,
## esta ranura SI puede afectar a quien la lanza: si hay un aliado en el cono
## de apuntado se cura a el, si no hay nadie en el cono se cura a si mismo
## (ver player.gd submit_soporte). Gasta el mismo chakra pasivo de arriba, no
## crea un recurso nuevo. Igual que el resto de ranuras nuevas de esta tanda,
## exactamente UNA tecnica de fabrica por estilo -- variarla o dar a elegir
## entre varias es fuera de alcance (mismo T4 de Loadout Q/E de arriba).
@export var soporte_name: String = "Apoyo de campo (placeholder)"
@export var soporte_chakra_cost: float = 25.0
@export var soporte_cooldown: float = 6.0
@export var soporte_heal_amount: float = 25.0
@export var soporte_range: float = 120.0
@export var soporte_cone_degrees: float = 60.0

@export_group("Vida")
@export var vida_maxima: float = 100.0
