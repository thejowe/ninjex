class_name MobMurcielago
extends EnemigoSimple
## Mob murciélago (scope nuevo, sin bioma asignado todavía -- ver
## plan-desarrollo.md sección 2). Reutiliza toda la IA/red de EnemigoSimple
## (patrulla/persigue/ataca, host-autoritativo, recibir_daño/morir via RPC).
## Los números (poca vida, daño bajo, ataca seguido para "estorbar" sin ser
## amenaza real) se fijan como overrides de los @export heredados en
## mob_murcielago.tscn, no aquí -- así se ven y ajustan desde el propio nodo
## de escena, igual que test_room.tscn hace con `tipo` en Comprador.
##
## Decisión explícita del usuario: se implementa saltándose el gate de
## "bloqueado hasta playtest H4/H5/H6" que marcaba plan-desarrollo.md sección 2
## (el playtest no se ha hecho). Queda anotado ahí mismo, no oculto.

## No deja cadáver: rompe a propósito el patrón de EnemigoSimple (que sí
## instancia un Cadaver en morir()). El murciélago estorba, no da botín.
func _spawn_cadaver(_cadaver_id: int, _tipo_dano_final: String) -> void:
	pass
