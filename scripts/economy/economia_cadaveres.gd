class_name EconomiaCadaveres
extends RefCounted
## Formula de valor de H2 (ya decidida por el usuario -- ver plan-desarrollo.md
## linea 111 y brief-traspaso-claude-code.md 2.2). Multiplicador BASE segun
## el tipo de daño del golpe FINAL que mato al enemigo (no el daño
## acumulado durante el combate, ver EnemigoSimple._ultimo_tipo_dano).
##
## Esto es solo la primera capa de la formula: cada comprador (boticario,
## carnicero, y los que lleguen en hitos futuros) pondera distinto ENCIMA
## de este multiplicador -- ver comprador.gd calcular_precio().
##
## No hace falta que sea un Resource editable: son numeros de diseno ya
## cerrados, a diferencia de los estilos (que si necesitan iterarse en
## playtest). Se consulta como EconomiaCadaveres.MULTIPLICADOR_TIPO_DANO.get(tipo, 1.0).

const MULTIPLICADOR_TIPO_DANO := {
	"cortante": 1.5,
	"contundente": 1.0,
	"veneno": 0.9, # Basico/Proyectil de Agua (H6).
	"electrico": 0.8, # Basico/Proyectil de Rayo (H6).
	"aplastamiento": 0.6, # Lanzamiento del Fisico.
	"quemadura": 0.1, # el fuego carboniza el cuerpo: casi no vale nada.
}

## Prisioneros vivos (H6, brief 2.2): "valen 2-3x un cadaver normal". Se
## aplica sobre valor_base directamente en player.gd submit_vender(), SIN
## pasar por Comprador.calcular_precio ni por MULTIPLICADOR_TIPO_DANO -- un
## prisionero vivo no tiene estado_conservacion (no esta desfigurado, esta
## vivo) y lo compran los 4 compradores por igual: modelar 4 formulas nuevas
## solo para el caso "vivo" es complejidad que este vertical slice no
## necesita. 2.5 = punto medio del rango que pide el brief.
const MULTIPLICADOR_PRISIONERO := 2.5
