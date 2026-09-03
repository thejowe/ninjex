extends Resource
class_name PergaminoTechnique
## Una tecnica de pergamino comprable, del pool de un estilo (T4, rework de
## combate 2026-09-03, plan-desarrollo.md seccion 2.1). Distinta de la
## tecnica de FABRICA de cada hueco Q/E (esa sigue siendo el id fijo
## "factory" resuelto directo en player.gd, nunca vive en este pool) --
## estas son las que la Tienda de Pergaminos (T5, casino-agent) va a poder
## vender a cambio de fichas y asignar a Q o a E indistintamente, por eso
## cada una lleva su propio "shape" en vez de heredar cono-fijo (Q) /
## area-fija (E) de las de fabrica.
##
## Numeros y nombres son PLACEHOLDER (igual que el resto del rework de
## combate) -- el pool es el mismo catalogo para los 6 estilos por ahora
## (ver StyleData._build_default_pergaminos_pool()); darle sabor elemental
## propio a cada tecnica (como ya tienen Zona/Impulso/Potenciador/Sellos) es
## trabajo de tuning/arte fuera de esta tanda, no de T4.

## Identificador estable usado por NetworkManager.loadout_equipped y
## NetworkManager.pergaminos_aprendidos -- nunca cambiar una vez usado en
## partidas guardadas/tests, es la clave que referencia la tecnica.
@export var id: String = ""
@export var display_name: String = "Tecnica sin nombre (placeholder)"
## "cone" = golpe unico frente al jugador, como la Q de fabrica (usa range/
## cone_degrees). "area" = estallido alrededor del jugador, como la E de
## fabrica (usa radius). Cualquier tecnica puede ir en Q o en E indistinto;
## el shape decide la forma del hitbox, no la tecla.
@export_enum("cone", "area") var shape: String = "cone"
## Se ignora si el estilo no usa chakra (melee_only), igual que el resto de
## costes de ranura -- ver comentario de projectile_chakra_cost en el grupo
## Proyectil de arriba.
@export var chakra_cost: float = 20.0
## Cooldown propio: reutiliza el _slot_cooldowns["loadout_q"/"loadout_e"] ya
## existente de T1 (una tecnica nueva en el mismo hueco no necesita timer
## propio) -- ver player.gd submit_loadout_technique.
@export var cooldown: float = 4.0
@export var damage: float = 15.0
## Solo se usa si shape == "cone". Nombre "hit_range" y no "range" para no
## sombrear la funcion global range() dentro de la clase.
@export var hit_range: float = 90.0
@export var cone_degrees: float = 60.0
## Solo se usa si shape == "area".
@export var radius: float = 100.0
## Coste en fichas para comprarla en la Tienda de Pergaminos (T5). Vive aqui
## y no en un catalogo aparte de casino-agent porque el precio es un dato
## del propio estilo/tecnica, igual que sellos_technique_name ya vive en
## StyleData en vez de en tienda_pergaminos.gd.
@export var ficha_price: int = 30
