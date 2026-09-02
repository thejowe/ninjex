# Progreso de assets

Checklist de producción visual, mantenido por `arte-pilar-agent`. Refleja el desglose de `plan-assets.md`. 🟡 = placeholder/exploración, ya se puede producir. 🟢 = arte final, esperar a que el hito de código correspondiente esté validado.

Marca `[x]` solo cuando la pieza esté generada **y** guardada en su carpeta de `art/` correspondiente.

## Fase 0 — antes/durante H1 (🟡 ya)

- [ ] Guía de estilo visual (paleta general, referencia de iluminación tres cuartos) — **sigue pendiente**; las paletas propuestas para los 7 interiores de H5 (ver sección H5 abajo y prompts de la sesión 2026-09-02) son un primer borrador de esto, no un sustituto. Confirmar y consolidar aquí en cuanto se generen los primeros interiores para no arrastrar inconsistencia.
- [ ] Mood board / concept art de Puerto Bajo
- [ ] Concept art de personaje — Fuego
- [ ] Concept art de personaje — Viento
- [ ] Concept art de personaje — Físico
- [ ] Rig placeholder: piernas genéricas
- [ ] Rig placeholder: torso genérico
- [ ] Tileset mínimo — sala de prueba H1

## H1 — Prototipo de combate (🟡 placeholder → 🟢 solo tras validar H1)

- [ ] Piernas: idle, caminar, impulso/dash, knockback, muerte
- [ ] Torso: idle-aim, Básico (cadena 3 golpes), Proyectil, Zona (canalizar+soltar), Impulso, Potenciador
- [ ] Físico — variantes propias: cadena de 5 puñetazos, Agarre, Lanzamiento, 3 posturas de Puertas
- [ ] Efecto elemental Fuego: Básico, Proyectil, Zona, Impulso, Potenciador
- [ ] Efecto elemental Viento: Básico, Proyectil, Zona, Impulso, Potenciador
- [ ] Combinación Viento sobre Fuego (tormenta ígnea)
- [ ] Indicador de colocación de Zona (plano en pantalla)
- [ ] Etiqueta elemental flotante (1,5 s)
- [ ] Enemigo simple (`enemy_grunt`): idle, persigue, ataca, recibe golpe, muere
- [ ] HUD de combate: barra de chakra, barra de vida, iconos de las 5 ranuras × 3 estilos

## H2 — Bucle económico

- [ ] Cadáver: variantes de conservación (intacto, contundente/veneno, quemadura, aplastamiento/eléctrico)
- [ ] Icono de peso/carga en HUD
- [ ] NPC + puesto: carnicero
- [ ] NPC + puesto: boticario
- [ ] Marcador de punto de extracción
- [ ] UI de venta

## H3 — Casino mínimo (🟢 arte final — H3 código hecho; el interior real vive ahora en H5+, ver desglose de los 7 interiores abajo)

- [ ] 🟢 Mesa cambista (prop, dentro de `art/environments/hub_interior_casino/`) — ver desglose H5
- [ ] 🟢 NPC cambista
- [ ] 🟢 Iconos de las 3 monedas (manchada, limpia, fichas) — 16×16 px c/u, `art/ui/`
- [ ] 🟢 Feedback visual de tirada de dados (mesa de dados + animación de resultado)

## H4 — Bóveda y votación (🟢 el Usurero; ❌ votación descartada, no producir)

- [ ] 🟢 UI de bóveda compartida (bote/HUD numérico de `dinero_manchado`/`dinero_limpio`, ya de facto la bóveda desde H2/H3)
- [x] ~~UI de votación (ficha sobre la mesa + revelación de voto)~~ — **descartado por decisión de diseño** (`plan-desarrollo.md` H4: "la votación grupal... se descartaron por decisión explícita del usuario"). No producir este asset.
- [ ] 🟢 NPC/aparición del Usurero (vive dentro de `art/environments/hub_interior_casino/`, con personalidad visual propia — "el desastre convertido en trama")

## H5 — Hub y taberna (🟢 arte final — código H5 hecho por completo, las 7 escenas de interior ya construidas en placeholder de color, listas para vestir)

**Convención de carpeta/nombre nueva (2026-09-02), documentada aquí para que el código pueda encontrar cada pieza sin preguntar:**
`art/environments/hub_interior_<nombre>/` uno por interior (`hub_interior_forja/`, `hub_interior_herboristeria/`, `hub_interior_mercado_negro/`, `hub_interior_sastreria/`, `hub_interior_casa_equipo/`, `hub_interior_casino/`, `hub_interior_taberna/`), espejo de `scenes/world/interiors/*.tscn`. Dentro de cada uno: `tile_<pieza>.png` (32×32), `prop_<pieza>.png` (32×64 o 64×64), `npc_<nombre>_idle.png` (32×48). Iconos transversales (bebidas, monedas) van a `art/ui/` porque se comparten entre interiores/HUD, no dentro de la carpeta de un interior concreto.

**Fachadas y calles del hub (exterior, no interiores):**
- [ ] Puerto Bajo — Muelle (nivel 0)
- [ ] Puerto Bajo — Calle de los Faroles (nivel 1)
- [ ] Puerto Bajo — Muelle Alto, fachada casino (nivel 2)
- [ ] Puerto Bajo — Terrazas (nivel 3)

**Los 7 interiores (mood/paleta ya especificados en `plan-assets.md` sección 8) — orden de prioridad sugerido en la respuesta de esta sesión:**
- [ ] 🟢 Interior Taberna El Ancla Rota — tiles piso/pared cálidos, barra, mesas+sillas (con pose de sentarse), escenario del músico, chimenea encendida, pizarra de deudas/récords (legible)
- [ ] 🟢 NPCs Taberna: tabernera, viejo maestro, usurero, pescador (retrato/expresión)
- [ ] 🟢 Iconos de bebidas (sistema de brindis) — 16×16 px, `art/ui/`
- [ ] 🟢 Emotes de personaje (sentarse, brindar, dormirse en la mesa)
- [ ] 🟢 Interior Casino (Muelle Alto) — tiles piso/pared tenebrosos, mesas de fieltro, sala privada con cortina, rincón de tienda de pergaminos, humo ambiental
- [ ] 🟢 NPC Casino: cambista (ya listado en H3) + personalidad visual del Usurero (ya listado en H4)
- [ ] 🟢 Interior Forja — tiles piso/pared industriales, yunque, fuelle, armero, chispas animadas, cubo de templar
- [ ] 🟢 NPC herrero (delantal de cuero)
- [ ] 🟢 Interior Herboristería — tiles piso/pared calmos, hierbas colgando, morteros, frascos/tarros, mesa de preparación
- [ ] 🟢 NPC herborista (delantal manchado de tintes)
- [ ] 🟢 Interior Mercado negro — tiles piso/pared turbios, cajas de contrabando, telas cubriendo mercancía, mostrador improvisado
- [ ] 🟢 NPC(s) mercado negro (rostro parcialmente oculto) + ya existen 4 tipos de comprador (`Comprador.tscn`) que necesitan sprite final: Boticario, Falsificador, Clan rival, Carnicero
- [ ] 🟢 Interior Sastrería — tiles piso/pared brillantes, rollos de tela, maniquíes, espejo, mesa de corte
- [ ] 🟢 NPC sastre (cinta métrica al cuello)
- [ ] 🟢 Interior Casa del equipo — base neutra + variantes de props por mejora activa (Cocina/Almacén/Jardín/Palomar)

## H6 — Estilos restantes, biomas e historia

- [ ] Efecto elemental Agua (5 ranuras)
- [ ] Efecto elemental Rayo (5 ranuras)
- [ ] Efecto elemental Tierra (5 ranuras)
- [ ] Combinaciones nuevas (charco electrificado, barro, vapor, tormenta de polvo)
- [ ] Bioma: Costa de los Naufragios
- [ ] Bioma: Bosque de Bambú
- [ ] Bioma: Camino de Peaje
- [ ] Bioma: Cantera Vieja
- [ ] Bioma: Ruinas del Clan
- [ ] Enemigos: contrabandistas, ninjas desertores, bandidos, mercenarios, guardianes antiguos
- [ ] Casino: Rueda del Clan, Cartas Selladas, Peleas del Sótano
- [ ] Medidor de sospecha (3 tramos)
- [ ] Animación de Sellos + iconos de pergaminos
- [ ] NPC falsificador + iconos de objetos
- [ ] NPC clan rival + iconos de objetos
- [ ] Sprite de prisionero vivo
- [ ] Pantalla de elección de estilo + prólogo
- [ ] Retratos/expresiones adicionales de NPCs
