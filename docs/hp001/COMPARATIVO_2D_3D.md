# Comparativo 2D / 3D — Cuyabeno (`selva-1`)

Piloto Godot 4.2. Escala **24 px = 1 m**. Y 2D hacia abajo; Y Godot hacia arriba. Pies de Maya: centro X del hitbox, base Y (`PH = 42`). Profundidad greybox de los sólidos: 64 px = 2.6667 m, centrada en z = 0.

El piso de entrada se baja **13.3333 m** para que su top quede en Godot y = 0 (el harness de feel aterriza a y≈0 y el `CSGPlatform` de 1 m sigue en y = 1). El primer oneway queda entonces a **6.6667 m**.

## Fuente

El pin pedido `NadiaCoelloO/sand-vivid-dawn-sail@5fd45031` no se pudo leer desde aquí (404). El layout y los timings salen de `NadiaCoelloO/Cacao.Game` `levels.ts` / `sim.ts` (`selva-1`, `sitSpikes`, `freeCoins`). QA verificó que esa geometría es la misma. 21 plataformas, 6 peligros, 24 granos (lista completa del archivo; el brief decía 23), 2 postes, 1 meta. Subtítulo del pin: **Laguna negra de Sucumbíos**.

El tótem (7.5, 0, 0), el muelle (10, 0, −4) y la laguna quedan como arte: fuera del carril o encima de P00. No añaden colisión.

`player_maya.gd`, el feel y la cápsula de Maya no se tocaron.

## HP-001 E3a — skins de plataforma

Rama `cursor/hp001-e3-skins` desde PR#6 `2191c38`. Visual only: las 21 cajas siguen con su `CollisionShape3D`. `Solid_Top` + `Fill` apilado + `Lip` en cada sólida (caja / crumble / móvil incluidas). Rollizo `Oneway` en P01, P07, P10 y P16 (P16 escala Y 1.125). Tiling `N = round((W−0.667)/2)`, `s ∈ [0.83, 1.17]`, CapL/CapR. Dos rollizos en Z para que la cámara de juego no vea franja pisable sin tronco. Mesh + Lip + fascia P00 ocultos. Nombres `Selva1Skin_*` (no `HP001_`).

Identidad en material Godot (`platform_skins_cuyabeno.gdshader`): musgo colgante beige → oliva `#3C4027` / marrón húmedo `#4C3E2E` (quedan pocas raicillas `#8A735A`); puntas crema de raíces oscurecidas; rollizo más pardo + liquen/musgo en la panza, panza levantada con ambient (el fill 0.90 de Maya no se tocó). Granos E2j (marrón + surco + rim `#CE722E`). Sin piso falso.

### Contraste Maya (QA: p10 del cuerpo, 2 px AA fuera)

| still | body RGB | p10 RGB | bg RGB | body | p10 | p10 bbox | p10 samples |
|---|---|---|---|---:|---:|---|---|
| `3d_x04.png` | 195,167,111 | 184,155,99 | 23,29,11 | 7.46 | **6.50** | 152,412–154,422 | (152,412) (154,422) |
| `3d_x36.png` | 221,171,95 | 222,166,90 | 27,34,14 | 7.85 | **7.57** | 572,380–577,380 | (574,380) (572,380) (577,380) |
| `3d_x66.png` | 219,169,94 | 221,165,89 | 22,28,12 | 8.17 | **7.96** | 572,380–577,381 | (574,380) (572,380) (577,380) (572,381) |
| `3d_x87.png` | 221,171,95 | 222,167,90 | 15,21,6 | 8.91 | **8.65** | 572,380–577,380 | (574,380) (572,380) (577,380) |
| `3d_x95.png` | 197,165,110 | 189,153,101 | 28,34,16 | 6.99 | **6.15** | 581,420–581,420 | (581,420) |
| `3d_x133.png` | 197,165,110 | 189,153,101 | 27,34,15 | 7.00 | **6.17** | 581,420–581,420 | (581,420) |
| `3d_x163.png` | 197,165,110 | 189,153,101 | 29,36,16 | 6.85 | **6.03** | 581,420–581,420 | (581,420) |
| `3d_x193.png` | 202,169,114 | 192,156,104 | 28,35,15 | 7.27 | **6.32** | 985,420–985,421 | (985,420) (985,421) |

p10 mín **6.03** (x163). Umbral 4.4. Muestras extra en `e3a_contrast.json`.

### Contraste granos (silueta max(rim, outline) vs fondo local)

Fondo local = litter/tierra vestida en C08/C09/C15/C16; jungla en el resto. Rim `#CE722E` gana contra el litter oscuro.

| id | still | rim | outline | bg | rim r | ol r | sil | win | found px | sil bbox | sil samples |
|---|---|---|---|---|---:|---:|---:|---|---|---|---|
| C00 | `3d_x04.png` | 240,150,52 | 53,25,14 | 24,30,12 | 7.41 | 1.05 | **7.41** | rim | 207.7,285.4 | 202,273–218,298 | (205,281) (202,287) (209,273) (218,278) (203,298) |
| C01 | `3d_x04.png` | 240,150,52 | 52,24,14 | 23,30,11 | 7.43 | 1.05 | **7.43** | rim | 289.7,288.9 | 279,268–298,293 | (297,283) (279,283) (290,268) (298,281) (280,293) |
| C02 | `3d_x04.png` | 240,150,52 | 51,24,14 | 23,30,12 | 7.43 | 1.04 | **7.43** | rim | 365.7,289.4 | 356,273–375,298 | (359,282) (356,287) (364,273) (375,286) (357,298) |
| C03 | `3d_x04.png` | 240,150,52 | 51,24,14 | 33,25,1 | 7.57 | 1.06 | **7.57** | rim | 341.1,80.2 | 342,66–346,86 | (345,76) (342,66) (346,73) (345,86) |
| C04 | `3d_x36.png` | 240,150,52 | 51,24,14 | 28,34,14 | 7.10 | 1.01 | **7.10** | rim | 190.4,213.0 | 179,194–198,220 | (194,202) (179,214) (187,194) (198,209) (180,220) |
| C05 | `3d_grains_c07.png` | 240,150,52 | 51,24,14 | 28,35,15 | 7.03 | 1.01 | **7.03** | rim | 469.1,362.5 | 460,346–478,371 | (463,353) (460,357) (467,346) (478,357) (460,371) |
| C06 | `3d_grains_c07.png` | 240,150,52 | 51,24,14 | 25,32,13 | 7.27 | 1.02 | **7.27** | rim | 554.1,325.6 | 545,309–563,334 | (548,316) (545,320) (552,309) (563,320) (545,334) |
| C07 | `3d_x36.png` | 240,150,52 | 51,24,14 | 25,32,13 | 7.27 | 1.02 | **7.27** | rim | 703.6,298.8 | 694,282–713,307 | (698,289) (694,297) (702,282) (713,295) (695,307) |
| C08 | `3d_x66.png` | 240,150,52 | 57,31,12 | 77,52,16 | 5.03 | 1.32 | **5.03** | rim | 255.1,579.2 | 251,567–257,588 | (252,576) (251,576) (254,567) (257,567) (252,588) |
| C09 | `3d_x66.png` | 240,150,52 | 51,24,14 | 77,52,17 | 5.02 | 1.42 | **5.02** | rim | 402.9,578.6 | 399,567–402,586 | (399,575) (399,571) (401,567) (402,567) (399,586) |
| C10 | `3d_x66.png` | 240,150,52 | 51,24,14 | 24,30,13 | 7.41 | 1.04 | **7.41** | rim | 596.7,300.1 | 587,283–606,309 | (603,291) (587,298) (596,283) (606,296) (588,309) |
| C11 | `3d_x87.png` | 240,150,52 | 51,24,14 | 25,30,14 | 7.39 | 1.04 | **7.39** | rim | 192.4,374.6 | 183,358–202,383 | (186,366) (183,370) (191,358) (202,374) (184,383) |
| C12 | `3d_x87.png` | 240,150,52 | 51,24,14 | 16,21,6 | 8.05 | 1.13 | **8.05** | rim | 532.5,289.5 | 523,273–542,298 | (526,281) (523,287) (530,273) (542,287) (524,298) |
| C13 | `3d_x95.png` | 240,150,52 | 51,24,14 | 19,24,8 | 7.85 | 1.10 | **7.85** | rim | 425.6,289.5 | 416,273–435,298 | (432,282) (416,287) (424,273) (435,287) (417,298) |
| C14 | `3d_x95.png` | 240,150,52 | 51,24,14 | 19,25,9 | 7.79 | 1.09 | **7.79** | rim | 596.7,290.1 | 587,273–606,299 | (590,282) (587,288) (596,273) (606,286) (588,299) |
| C15 | `3d_x109.png` | 240,150,52 | 51,24,14 | 81,44,21 | 5.30 | 1.35 | **5.30** | rim | 516.4,422.9 | 520,416–521,424 | (521,421) (520,422) (521,416) (520,424) |
| C16 | `3d_x109.png` | 240,150,52 | 51,24,14 | 77,43,20 | 5.46 | 1.31 | **5.46** | rim | 639.5,422.5 | 630,416–649,424 | (631,420) (630,416) (649,416) (631,424) |
| C17 | `3d_hazard.png` | 240,150,52 | 51,24,14 | 38,45,23 | 6.20 | 1.15 | **6.20** | rim | 148.9,341.5 | 139,325–158,350 | (142,334) (139,340) (146,325) (158,338) (140,350) |
| C18 | `3d_hazard.png` | 240,150,52 | 51,24,14 | 25,33,13 | 7.21 | 1.01 | **7.21** | rim | 489.8,297.5 | 480,281–499,306 | (484,288) (480,296) (488,281) (499,293) (481,306) |
| C19 | `3d_grains_c21.png` | 240,150,52 | 51,24,14 | 37,44,22 | 6.29 | 1.14 | **6.29** | rim | 42.1,337.5 | 33,321–51,346 | (46,326) (33,331) (40,321) (51,333) (33,346) |
| C20 | `3d_grains_c21.png` | 240,150,52 | 51,24,14 | 36,43,22 | 6.37 | 1.12 | **6.37** | rim | 298.8,252.4 | 288,234–306,259 | (304,246) (288,243) (294,234) (306,248) (289,259) |
| C21 | `3d_grains_c21.png` | 240,150,52 | 51,24,14 | 26,33,14 | 7.19 | 1.01 | **7.19** | rim | 639.5,335.2 | 630,319–649,344 | (633,327) (630,333) (637,319) (649,333) (631,344) |
| C22 | `3d_grains_c21.png` | 240,150,52 | 51,24,14 | 34,42,20 | 6.47 | 1.10 | **6.47** | rim | 981.6,291.5 | 972,275–991,300 | (976,282) (972,290) (980,275) (991,287) (973,300) |
| C23 | `3d_x193.png` | 240,150,52 | 51,24,14 | 38,45,23 | 6.20 | 1.15 | **6.20** | rim | 938.8,299.4 | 929,283–948,308 | (933,290) (929,300) (937,283) (948,294) (930,308) |

Mediana de medianas **7.20**. Mínimo **5.02** (C09, rim vs litter). Pin 2D **4.03 / 3.7**.

### Checks E3a

| check | resultado |
|---|---|
| `maya_feel_check` | **54/54 PASS** |
| `hp001_lod_hole_check` | **PASS** |
| `SELVA_CHECK` | 21 / 6 / 24 / 2 / 1 · skins 63 visuals / **21 colliders** · offset (0, 1, 24.1256) · P01 6.6667 |
| `selva1_run_probe` | **PASS** ticks=1556 · far_x=194.32 · G00=1 · 0 muertes |
| `player_maya.gd` | no tocado |
| perf LOOK gameplay | 112,563 tris / 163 draws |
| perf LOOK dosel | 234,333 tris / 192 draws |
| perf SELVA entrance | 70,061 tris / 98 draws |
| tope | 350k / 250 — PASS |

## Cámara

El `@export camera_offset` de Godot se descarta si está escrito **antes** de `script =`. En `pilot_cuyabeno.tscn` el valor quedó **debajo** de `script =`, y `selva1_play.gd` `_ready` lo vuelve a asignar. `player_maya.gd` no se tocó. El `fov` sigue en 50. Laguna y dosel siguen siendo cámaras de captura aparte.

| | valor |
|---|---|
| fov | 50° vertical |
| camera_offset | (0, 1, **24.1256**) m, leído en runtime |
| alto de fórmula | 2 × 24.1256 × tan(25°) = **22.50 m** |
| ancho en z = 0 | **40.03 m** |
| Maya, hitbox 1.75 m (42 px) | **~56 px** a 1280×720 (1 m = 32 px) |
| medido (entrance, lavapipe) | plane_h **22.5470** m · plane_w **40.0342** m · maya_px **55.68** |

Después del follow, la escena clampea el foco a x en [20, 182.67] m y y en [−2.083, 18.083] m: la misma ventana de 40 × 22.5 m pegada al borde del nivel (con el Y_SHIFT). El look-ahead de 2 m sigue siendo el de Maya.

## Tomas

Misma pose en los dos renders. 2D: `renderGame` (implementación fiel: sky + plataformas + peligros + granos + Maya teal `#3d8a72`), 960×540, `camLook = 48`, `time = 0`, escalado nearest a 1280×720. 3D: viewport 1280×720, HUD oculto, 60 frames para asentar el follow y el clampeo.

| id | pies 2D | pies 3D m | nota |
|---|---|---|---|
| entrance | (96, 662) | (4.5417, 0, 0) | Entrada: P00, oneway #0 a 6.67 m, tótem |
| hazard | (3187, 230) | (133.3333, 18, 0) | Viento H03 + roca H04 sobre P15 |
| cacao | (1568, 470) | (65.875, 8, 0) | Granos C10 + oneway P07 |

La fila 2 de `cmp_cuyabeno_2d_3d.png` es el gameplay 2D contra el 3D **en el mismo tramo**. Las filas 3 y 4 son el tramo con peligro y el tramo con cacao.

## Jugabilidad cableada

Valores copiados de `sim.ts`. Nada de esto toca `player_maya.gd`.

| pieza | comportamiento |
|---|---|
| pinchos H00 | overlap del hurtbox `(x+4, y+8, w-8, h-10)` → `kill` |
| ranas H01–H02 | igual; `chase=false` (no venom) así que no caminan; el AABB queda en reposo |
| viento H03 | no mata; suma `vx` 150 px/s² al cuerpo si hay overlap (`applyWind`) |
| rocas H04–H05 | `along = (time*vx + phase*40) % (range+80)`; fuera de rango vuelven a `ox-80` |
| kill | vidas 5, `invuln` 0.8, `hitstop` 0.08, `deathT` 0.55, respawn con `invuln` 1.1 |
| pozo | `sim.ts` `p.y > height+80` → pies Godot **−18.4167 m**. Play pone `kill_y = −80` (el default −3.33 no se usa). `selva1_play._kill()` resta vida. Feel no se toca. |
| monedas | distancia al centro < 28 px. Se ocultan. 24 granos |
| K00 / K01 | salto activa, guarda el spawn (`x+4`, pies en la base), `poleLock` 0.35 s |
| G00 | overlap marca la meta, oculta el grano y deja `win` 1.35 s |
| one-way | la colisión se apaga si los pies están bajo `top−0.06`, y también mientras `_drop_timer > 0` (abajo+salto, 0.18 s) |
| crumble / móviles | 0.46 s / 2.7 s, y `sin`/`cos` del 2D |

En play, `CSGFloor`, `CSGPlatform` y `CSGOneway` tienen `use_collision = false`. El harness de feel enciende el piso 24 m y el `CSGPlatform` de 1 m (cara izquierda 4.5, caja 4 m para que el salto desde x=0 aterrice) y no construye selva-1. `CSGOneway` sigue apagado: es una caja sólida y taparía el mantle.

## Equivalencias

Geometría: las 21 plataformas, 6 peligros, 24 pickups, 2 postes y 1 meta. Centro y tamaño en metros. Los móviles están en t = 0. Y Godot = `(LEVEL_H − y_2d) / 24 − 13.3333`.

### Plataformas

| id | kind | tag | AABB 2D px | centro 3D m | tamaño 3D m | top m |
|---|---|---|---|---|---|---:|
| P00 | solid | suelo de entrada | (0, 704, 320, 320) | (6.6667, −6.6667, 0) | (13.3333, 13.3333, 2.6667) | 0 |
| P01 | oneway | one-way #0 (top 6.67 m) | (192, 544, 96, 16) | (10, 6.3333, 0) | (4, 0.6667, 2.6667) | 6.6667 |
| P02 | solid | suelo tras el primer hueco | (448, 672, 256, 352) | (24, −6, 0) | (10.6667, 14.6667, 2.6667) | 1.3333 |
| P03 | crate | caja | (544, 544, 96, 20) | (24.6667, 6.25, 0) | (4, 0.8333, 2.6667) | 6.6667 |
| P04 | moving | plataforma móvil horizontal | (800, 608, 128, 22) | (36, 3.5417, 0) | (5.3333, 0.9167, 2.6667) | 4 |
| P05 | solid | suelo ancho del primer poste | (1216, 640, 448, 384) | (60, −5.3333, 0) | (18.6667, 16, 2.6667) | 2.6667 |
| P06 | solid | techo de arrastre (crawlCover, gap 30 px) | (1280, 546, 224, 64) | (58, 5.25, 0) | (9.3333, 2.6667, 2.6667) | 6.5833 |
| P07 | oneway | one-way | (1536, 512, 96, 16) | (66, 7.6667, 0) | (4, 0.6667, 2.6667) | 8 |
| P08 | crumble | tronco que cede | (1728, 576, 160, 20) | (75.3333, 4.9167, 0) | (6.6667, 0.8333, 2.6667) | 5.3333 |
| P09 | solid | suelo de la rana | (1984, 512, 192, 512) | (86.6667, −2.6667, 0) | (8, 21.3333, 2.6667) | 8 |
| P10 | oneway | one-way | (2112, 352, 96, 16) | (90, 14.3333, 0) | (4, 0.6667, 2.6667) | 14.6667 |
| P11 | solid | columna | (2240, 352, 96, 672) | (95.3333, 0.6667, 0) | (4, 28, 2.6667) | 14.6667 |
| P12 | solid | suelo del paso estrecho | (2432, 640, 320, 384) | (108, −5.3333, 0) | (13.3333, 16, 2.6667) | 2.6667 |
| P13 | solid | techo de arrastre estrecho (squeezeCover, gap 18 px) | (2496, 558, 192, 64) | (108, 4.75, 0) | (8, 2.6667, 2.6667) | 6.0833 |
| P14 | moving | plataforma móvil vertical | (2816, 288, 128, 22) | (120, 16.875, 0) | (5.3333, 0.9167, 2.6667) | 17.3333 |
| P15 | solid | repisa del viento | (3072, 320, 256, 192) | (133.333, 12, 0) | (10.6667, 8, 2.6667) | 16 |
| P16 | oneway | one-way | (3392, 448, 160, 18) | (144.667, 10.2917, 0) | (6.6667, 0.75, 2.6667) | 10.6667 |
| P17 | solid | suelo de la segunda rana | (3584, 384, 192, 192) | (153.333, 9.3333, 0) | (8, 8, 2.6667) | 13.3333 |
| P18 | crumble | tronco que cede | (3840, 448, 128, 18) | (162.667, 10.2917, 0) | (5.3333, 0.75, 2.6667) | 10.6667 |
| P19 | moving | plataforma móvil horizontal | (4032, 416, 128, 22) | (170.667, 11.5417, 0) | (5.3333, 0.9167, 2.6667) | 12 |
| P20 | solid | suelo de meta | (4416, 480, 448, 544) | (193.333, −2, 0) | (18.6667, 22.6667, 2.6667) | 9.3333 |

- P04 reposo px (800, 608) amp (160, 0) periodo 2.7 fase 0. t = 0 → (800, 608, 128, 22).
- P14 reposo px (2816, 512) amp (0, −224) periodo 3.2 fase 0. t = 0 → (2816, 288, 128, 22).
- P19 reposo px (4032, 416) amp (128, 0) periodo 2.5 fase 0. t = 0 → (4032, 416, 128, 22).

### Peligros

| id | kind | AABB 2D px | centro 3D m | tamaño XY m | periodo | fase |
|---|---|---|---|---|---|---|
| H00 | spikes | (1568, 623, 96, 18) | (67.3333, 3, 0) | 4 × 0.75 | — | — |
| H01 | frog | (2016, 496, 18, 16) | (84.375, 8.3333, 0) | 0.75 × 0.6667 | 1.6 | 0.2 |
| H02 | frog | (3616, 368, 18, 16) | (151.042, 13.6667, 0) | 0.75 × 0.6667 | 1.5 | 0.8 |
| H03 | wind | (3072, 96, 704, 320) | (142.667, 18.6667, 0) | 29.333 × 13.333 | — | vx 150 |
| H04 | rock | (3200, 0, 22, 20) | (133.792, 28.9167, 0) | 0.9167 × 0.8333 | — | 0.2 |
| H05 | rock | (3584, 0, 22, 20) | (149.792, 28.9167, 0) | 0.9167 × 0.8333 | — | 1.4 |

### Pickups

Elipsoides `#6B3A1F`, radio de recogida 28 px.

| id | centro 2D px | centro 3D m |
|---|---|---|
| C00 | (160, 608) | (6.6667, 4, 0) |
| C01 | (217.6, 596) | (9.0667, 4.5, 0) |
| C02 | (275.2, 608) | (11.4667, 4, 0) |
| C03 | (256, 448) | (10.6667, 10.6667, 0) |
| C04 | (576, 448) | (24, 10.6667, 0) |
| C05 | (832, 512) | (34.6667, 8, 0) |
| C06 | (896, 490) | (37.3333, 8.9167, 0) |
| C07 | (960, 512) | (40, 8, 0) |
| C08 | (1344, 628) | (56, 3.1667, 0) |
| C09 | (1456, 628) | (60.6667, 3.1667, 0) |
| C10 | (1600, 416) | (66.6667, 12, 0) |
| C11 | (1792, 480) | (74.6667, 9.3333, 0) |
| C12 | (2048, 416) | (85.3333, 12, 0) |
| C13 | (2176, 256) | (90.6667, 18.6667, 0) |
| C14 | (2304, 256) | (96, 18.6667, 0) |
| C15 | (2560, 630) | (106.667, 3.0833, 0) |
| C16 | (2656, 630) | (110.667, 3.0833, 0) |
| C17 | (2880, 256) | (120, 18.6667, 0) |
| C18 | (3136, 224) | (130.667, 20, 0) |
| C19 | (3456, 352) | (144, 14.6667, 0) |
| C20 | (3648, 288) | (152, 17.3333, 0) |
| C21 | (3904, 352) | (162.667, 14.6667, 0) |
| C22 | (4160, 320) | (173.333, 16, 0) |
| C23 | (4608, 384) | (192, 13.3333, 0) |

### Postes y meta

| id | qué | AABB 2D px | centro 3D m |
|---|---|---|---|
| K00 | poste | (1248, 568, 36, 72) | (52.75, 4.1667, 0) |
| K01 | poste | (3104, 248, 36, 72) | (130.083, 17.5, 0) |
| G00 | meta cacao | (4672, 424, 48, 56) | (195.667, 10.5, 0) |

Spawn 2D (96, 640) → pies (4.5417, 0.9167, 0). En el harness de feel Maya nace en (0, 1.2, 0) y aterriza en P00.

## One-way

P01 / P07 / P10 / P16 son one-way reales (drop-through), no una caja sólida. P01 top = 6.6667 m. El `CSGOneway` 4×0.18×2 de PR#3 queda sin colisión; el mesh LOOK es solo arte.

En el 2D los one-way no entran en `solids()`, así que el mantle no los agarra. En 3D el mantle sigue viendo el mask de colisión; sacarlos exige tocar `player_maya.gd`. No se tocó.

## Look (E2j)

QA ya PASABA en `ff07d81`. Identidad marca regresión solo en dos puntos: el anillo `#FFC060` cerrado lee como moneda dorada, y la corona de lóbulos anchos lee como lomas. Maya wrap/fill 0.90 y las rocas `#4A4440` no se tocaron. Fill Maya **0.90**. `player_maya.gd` no se tocó.

1. Granos: cara cacao `#6b3a1f`–`#8B4A2B`. Rim fino `#CE722E` (filmic ~240,150,52) solo arriba + 3/4, no un anillo cerrado. Outline oscuro fino `#2c1810` (filmic ~51,24,14) completo — es lo que QA usa contra los tops claros. Forma: óvalo vertical con surco central. Medida QA: silueta = max(rim vs fondo local, outline vs fondo local). Fondo local = lip del top para C08/C09/C15/C16; selva para el resto. 24/24 vs pin 2D (mediana 4.03 / mín 3.7): mediana de medianas **7.20**, mínimo **4.12**. C08/C09/C15/C16 = **4.12** (outline vs lip). Stills extra `3d_grains_c07.png`, `3d_grains_c16.png`, `3d_grains_c21.png`.
2. Maya: p10 del cuerpo **excluyendo 2 px de antialiasing**. ≥4.4 en los **8 x**. Mínimo del sweep **5.96** (x163). Crema, sin naranja. Wrap cream en layer 2; fill 0.90 no se tocó.
3. `SELVA_GP_Platforms` sigue oculto. H04/H05 siguen tronco caído `#4A4440`.
4. Corona: casi horizontal, muchas copas redondeadas chicas y medianas de várzea (semicírculos superpuestos), alguna emergente y huecos de cielo chicos. Sin ondas grandes ni picos. El corte queda muy por encima de los tops.
5. Baseline 2D: Cacao.Game (Vite) **no se ejecutó**. Pin fallback `#6b3a1f` (`render.ts:1136–1139`).

Piso falso y corredor en layer 13 se mantienen. Vulkan Forward+.

### Contraste Maya (QA: p10 del cuerpo sin AA de borde)

Cuerpo = cream/tan. p10 = 10 % más oscuro **después** de erosionar 2 px (AA / hull). Fondo = selva inmediata. Coordenadas en píxeles del still 1280×720.

| x m | still | body RGB | p10 RGB | jungle RGB | cuerpo | p10 | p10 center px | p10 samples px | bg center px |
|---:|---|---|---|---|---:|---:|---|---|---|
| 4.54 | `3d_x04.png` | 188,158,98 | 180,147,94 | 23,29,11 | **6.74** | **5.98** | 150.0, 396.0 | (146,370) (154,422) | 156.2, 381.1 |
| 36.00 | `3d_x36.png` | 221,174,115 | 222,166,90 | 26,33,14 | **8.18** | **7.66** | 574.5, 380.0 | (574,380) (572,380) (577,380) | 580.4, 380.5 |
| 66.00 | `3d_x66.png` | 220,173,113 | 221,165,89 | 22,28,12 | **8.51** | **7.96** | 574.1, 380.1 | (574,380) (572,380) (577,380) (572,381) | 580.4, 380.6 |
| 86.67 | `3d_x87.png` | 221,174,115 | 222,166,90 | 17,22,7 | **9.09** | **8.50** | 574.5, 380.0 | (574,380) (572,380) (577,380) | 580.4, 380.5 |
| 95.33 | `3d_x95.png` | 199,166,113 | 189,153,101 | 28,34,16 | **7.09** | **6.15** | 581.0, 420.0 | (581,420) | 583.7, 402.6 |
| 133.33 | `3d_x133.png` | 199,166,112 | 189,153,101 | 27,35,15 | **7.05** | **6.11** | 581.0, 420.0 | (581,420) | 583.7, 402.6 |
| 162.67 | `3d_x163.png` | 199,166,112 | 188,152,101 | 29,36,16 | **6.95** | **5.96** | 581.0, 420.0 | (581,420) | 582.6, 416.9 |
| 193.33 | `3d_x193.png` | 228,180,93 | 212,163,82 | 27,34,15 | **8.57** | **7.14** | 972.8, 412.2 | (973,420) (972,422) (973,396) (973,424) | 967.5, 402.4 |

`3d_cacao` p10 **7.96** @ (574.1, 380.1). Los 8 x p10 ≥4.4. JSON: `e2j_contrast.json`.

### Contraste granos C00–C23 (QA: silueta max(rim, outline) vs fondo local)

Rim = `#CE722E` filmic (240,150,52), 3/4 superior. Outline = `#2c1810` filmic (51,24,14), hull completo. Fondo local = lip tan en C08/C09/C15/C16; selva en el resto. Silueta = el máximo de los dos contrastes. Pin 2D a vencer: mediana 4.03 / mín 3.7.

| id | still | rim RGB | outline RGB | bg RGB | rim | outline | sil | gana | sil center px | sil bbox | sil samples px | bg center px |
|---|---|---|---|---|---:|---:|---:|---|---|---|---|---|
| C00 | `3d_x04.png` | 240,150,52 | 53,25,14 | 24,30,12 | 7.41 | 1.05 | **7.41** | rim | 207.8, 281.4 | 202,273–218,298 | (205,281) (202,287) (209,273) (218,278) (203,298) | 205.8, 284.8 |
| C01 | `3d_x04.png` | 240,150,52 | 52,24,14 | 23,30,11 | 7.43 | 1.05 | **7.43** | rim | 291.3, 282.9 | 279,268–298,293 | (297,283) (279,283) (290,268) (298,281) (280,293) | 291.0, 289.3 |
| C02 | `3d_x04.png` | 240,150,52 | 51,24,14 | 23,30,12 | 7.43 | 1.04 | **7.43** | rim | 365.5, 283.7 | 356,273–375,298 | (359,282) (356,287) (364,273) (375,286) (357,298) | 365.5, 288.7 |
| C03 | `3d_x04.png` | 240,150,52 | 51,24,14 | 33,25,1 | 7.57 | 1.06 | **7.57** | rim | 345.0, 75.6 | 342,66–346,86 | (345,76) (342,66) (346,73) (345,86) | 349.7, 66.0 |
| C04 | `3d_x36.png` | 240,150,52 | 51,24,14 | 28,34,14 | 7.10 | 1.01 | **7.10** | rim | 190.3, 204.6 | 179,194–198,220 | (194,202) (179,214) (187,194) (198,209) (180,220) | 187.2, 214.0 |
| C05 | `3d_grains_c07.png` | 240,150,52 | 51,24,14 | 28,35,15 | 7.03 | 1.01 | **7.03** | rim | 468.8, 356.0 | 460,346–478,371 | (463,353) (460,357) (467,346) (478,357) (460,371) | 469.0, 361.8 |
| C06 | `3d_grains_c07.png` | 240,150,52 | 51,24,14 | 25,32,13 | 7.27 | 1.02 | **7.27** | rim | 553.8, 319.2 | 545,309–563,334 | (548,316) (545,320) (552,309) (563,320) (545,334) | 553.9, 324.4 |
| C07 | `3d_x36.png` | 240,150,52 | 51,24,14 | 25,32,13 | 7.27 | 1.02 | **7.27** | rim | 703.7, 292.7 | 694,282–713,307 | (698,289) (694,297) (702,282) (713,295) (695,307) | 703.6, 297.6 |
| C08 | `3d_x66.png` | 240,150,52 | 51,24,14 | 161,120,60 | 1.73 | 4.12 | **4.12** | outline | 251.1, 580.1 | 250,567–254,591 | (250,580) (250,572) (252,567) (254,591) (251,591) | 251.9, 592.5 |
| C09 | `3d_x66.png` | 240,150,52 | 51,24,14 | 161,120,60 | 1.73 | 4.12 | **4.12** | outline | 398.5, 581.0 | 397,567–402,591 | (398,581) (397,573) (399,567) (402,590) (399,591) | 400.0, 592.4 |
| C10 | `3d_x66.png` | 240,150,52 | 51,24,14 | 24,30,13 | 7.41 | 1.04 | **7.41** | rim | 596.8, 294.3 | 587,283–606,309 | (603,291) (587,298) (596,283) (606,296) (588,309) | 596.6, 299.5 |
| C11 | `3d_x87.png` | 240,150,52 | 51,24,14 | 25,30,14 | 7.39 | 1.04 | **7.39** | rim | 192.1, 368.8 | 183,358–202,383 | (186,366) (183,370) (191,358) (202,374) (184,383) | 192.4, 373.8 |
| C12 | `3d_x87.png` | 240,150,52 | 51,24,14 | 16,21,6 | 8.05 | 1.13 | **8.05** | rim | 532.5, 283.6 | 523,273–542,298 | (526,281) (523,287) (530,273) (542,287) (524,298) | 532.5, 288.6 |
| C13 | `3d_x95.png` | 240,150,52 | 51,24,14 | 19,24,8 | 7.85 | 1.10 | **7.85** | rim | 425.5, 283.7 | 416,273–435,298 | (432,282) (416,287) (424,273) (435,287) (417,298) | 425.5, 288.6 |
| C14 | `3d_x95.png` | 240,150,52 | 51,24,14 | 19,25,9 | 7.79 | 1.09 | **7.79** | rim | 596.7, 284.4 | 587,273–606,299 | (590,282) (587,288) (596,273) (606,286) (588,299) | 596.6, 289.4 |
| C15 | `3d_x109.png` | 240,150,52 | 51,24,14 | 161,120,60 | 1.73 | 4.12 | **4.12** | outline | 519.3, 429.1 | 509,418–523,435 | (519,429) (509,434) (522,418) (523,418) (509,435) | 517.5, 437.0 |
| C16 | `3d_x109.png` | 240,150,52 | 51,24,14 | 161,120,60 | 1.73 | 4.12 | **4.12** | outline | 639.5, 429.5 | 629,418–650,435 | (639,435) (629,418) (650,418) (632,435) | 639.5, 436.7 |
| C17 | `3d_hazard.png` | 240,150,52 | 51,24,14 | 38,45,23 | 6.20 | 1.15 | **6.20** | rim | 148.5, 335.2 | 139,325–158,350 | (142,334) (139,340) (146,325) (158,338) (140,350) | 148.6, 340.7 |
| C18 | `3d_hazard.png` | 240,150,52 | 51,24,14 | 25,33,13 | 7.21 | 1.01 | **7.21** | rim | 489.4, 291.4 | 480,281–499,306 | (484,288) (480,296) (488,281) (499,293) (481,306) | 489.5, 294.5 |
| C19 | `3d_grains_c21.png` | 240,150,52 | 51,24,14 | 37,44,22 | 6.29 | 1.14 | **6.29** | rim | 41.7, 329.9 | 33,321–51,346 | (46,326) (33,331) (40,321) (51,333) (33,346) | 41.9, 336.6 |
| C20 | `3d_grains_c21.png` | 240,150,52 | 51,24,14 | 36,43,22 | 6.37 | 1.12 | **6.37** | rim | 298.1, 246.9 | 288,234–306,259 | (304,246) (288,243) (294,234) (306,248) (289,259) | 302.7, 249.4 |
| C21 | `3d_grains_c21.png` | 240,150,52 | 51,24,14 | 26,33,14 | 7.19 | 1.01 | **7.19** | rim | 639.5, 329.5 | 630,319–649,344 | (633,327) (630,333) (637,319) (649,333) (631,344) | 639.5, 335.0 |
| C22 | `3d_grains_c21.png` | 240,150,52 | 51,24,14 | 34,42,20 | 6.47 | 1.10 | **6.47** | rim | 981.8, 285.6 | 972,275–991,300 | (976,282) (972,290) (980,275) (991,287) (973,300) | 981.6, 290.8 |
| C23 | `3d_x193.png` | 240,150,52 | 51,24,14 | 38,45,23 | 6.20 | 1.15 | **6.20** | rim | 938.9, 293.4 | 929,283–948,308 | (933,290) (929,300) (937,283) (948,294) (930,308) | 938.7, 298.7 |

Mediana de medianas **7.20**. Mínimo **4.12**. Mín-de-mín **4.12**. Pin 2D **4.03 / 3.7**. C08/C09/C15/C16 = outline vs lip **4.12**. Stills extra C07/C16/C21. Cacao.Game no se ejecutó. Samples extra en `e2j_contrast.json`.

## Checks

| check | resultado |
|---|---|
| `maya_feel_check` | **54/54 PASS** |
| `hp001_lod_hole_check` | **PASS** |
| `SELVA_CHECK` | 21 / 6 / 24 / 2 / 1 · offset (0, 1, 24.1256) · P01 6.6667 |
| `selva1_run_probe` | **PASS** ticks=1556 · far_x=194.32 · G00=1 · 0 muertes |
| `player_maya.gd` | no tocado |
| capturas | Vulkan 1.4 Forward+ (llvmpipe), no OpenGL |
| contraste Maya | 8 x cuerpo ≥4.4; p10 (sin AA) en los 8 x, mín **5.96** (x163); x36 **7.66** |
| contraste granos | 24/24 silueta max(rim, outline) vs fondo local ≥4.03 / ≥3.7. Mediana **7.20**, mín **4.12** (C08/C09/C15) |

## sha256

SHA de E2i 3d_* stills: **reemplazados**. HEAD de este commit de stills.

SHA de E3a 3d_* stills (reemplazan E2j). Fuentes de plataforma verificadas contra `skins_v2` SHA256SUMS.

| archivo | sha256 |
|---|---|
| `platform_skins_cuyabeno_LOD0.glb` | `0391365ecf2130309498c165683ab6ad057379672470f9b59b17480c64c4d365` |
| `platform_skins_cuyabeno_LOD1.glb` | `743b61b6ba0f8b2be8f2d173e6fc03448db90be65627a2b8e1eaf2ff783816cb` |
| `platform_skins_cuyabeno_LOD2.glb` | `e245088db888e36996d4e9a1fefb51b0df8da923d47c43c7a2d38ac45ff9be16` |
| `platform_skins_cuyabeno.blend` | `95c932776667fca29171f41a68d2df2972141aa033f9f8951cb36c840bc3c2d1` |
| `platform_skins_cuyabeno.py` | `4754d0f9642a5fafa277a1f6a5dd75bd8acec1263c06e0b300b49c3075af7ddf` |
| `T_PlatformSkins_Cuyabeno_A.png` | `8485cb1094a1f9a15d02ea17500b55293e5604c8792f710491f61c1cb39b7554` |
| `README_platform_skins.md` | `83d03f538d44bd3154c07a2bf4e03a0ba712f40f0712038857fbdb906dd8df5a` |
| `3d_entrance.png` | `9dcc17ecd4a1203fc1af62081aa2feb3ce918be851b788796a483463da6ec7a5` |
| `3d_hazard.png` | `63491d859bce551e5cf164de2a78f851f9f4a516e4e7d8f3d7b5725dffa53875` |
| `3d_cacao.png` | `4fde1e75a3d0739f9ba09ca94df53db4098987916faae3b939c149010e23d2d4` |
| `3d_x04.png` | `736b3bdd17492667e47ab18b121ff8d48100773d14b0b7b291def77396a51bc3` |
| `3d_x36.png` | `9087871b8eda5e721264a5746fa76431dabe24e822aecbccfe577eca3238aedc` |
| `3d_x66.png` | `19be562441673f7554a272e2ec055c4228069688ee18cb010cd7e18e551a722b` |
| `3d_x87.png` | `714ff634bdbe10aedada04c8052798809a647cabe83477913481e7f17eed1c8b` |
| `3d_x95.png` | `a20015edb86248b5ca83d731d85a13c949af9464d4b7ca06a1b9ca0a58e5b486` |
| `3d_x133.png` | `caeb8486f4c5fd41659b06e8772eaf87cbacde58bdc55cd37f75f5fb2abde777` |
| `3d_x163.png` | `75ad4ddb6a566650fd658884f19169c1d7df8c87aff1936078223871b0e451cb` |
| `3d_x193.png` | `0c7ce0c90197bd868a5aa72d2a5543790ccfc2c8ad7749f19f1f23e4c632c425` |
| `3d_x109.png` | `55ab3e8ed0c880f843ec3d9866aee3221ed27f968bf962940df6320a0d381c35` |
| `3d_grains_c07.png` | `b26d8053e52d75d7a19c43c52ccba208fe3210b002d8712359b43895b9350e67` |
| `3d_grains_c16.png` | `fdb89d6be5b965f4c17767d3235f9edb4919df275894d4486066c1cdd5d91703` |
| `3d_grains_c21.png` | `0e82bc0d6782784e8d671a4da852511bf98dc9e0bff2ad844d125f0eec5c3ada` |
| `3d_platform_close.png` | `0e1de3451a01558278f18a85a5ef3aeb427d44b5fe42fc34f05ea676138dc3a2` |
| `2d_entrance.png` | `da8c544df1e8c1e3f40a1e974493456e57223dd2a7a173d44c257bdf65235c39` |
| `2d_hazard.png` | `b181184b3af1d01769948443e455996eb09de96ced50a8c75d1bcb7aabe4e795` |
| `2d_cacao.png` | `497974338ca4ef00c0f77596afdbcd539aa805d8fa785d5068aa4f1efde5c598` |
| `2d_grains_c06.png` | `cbce134e3cd6f599eb98431c4b906ddd2f872e16f0061fe89544ed0c549c9315` |
| `2d_grains_c08.png` | `fb570ec524a5092b79b79fe2136c3a5d15231d4f87623ff70d6798ebefce07d4` |
| `2d_grains_c16.png` | `81d83b681de4728f0f6dbace8b00c1b9e295bb376c82b60c5665b705fe5743ae` |
| `cmp_cuyabeno_2d_3d.png` | `d1b3372ec89673e95bf8bb7b555634fa464b41b7340c20cf498de780aeb4273d` |
| `HP001_E3a_engine_gameplay.png` | `7b4d6907aac58c529807399408fa7bd1783c437dc0bd280906cabf37cc4c24f2` |
| `HP001_E3a_engine_platform_close.png` | `68ddf522f49957c0249e5bbbb568c55da85e6ee07e5b7bbe9a691d614f38509a` |
| `HP001_E3a_engine_platform_face.png` | `6a0a272e7561b64eca771f966afeae00b38b6e8cfb22cd800bd109243514dd62` |
| `HP001_E3a_engine_laguna.png` | `6b9e4f627cf0b94f6a13a754f5880d9be9da2a59002346fb6d964acd1c3b2857` |
| `HP001_E3a_engine_dosel.png` | `89a71a4eaf41dffddf610ef145d094bc199ae70a4ebfa3120bd798124c154276` |
| `HP001_E3a_engine_dock_closeup.png` | `8a68b4951f423374ce570055c27f1202b3ae897bc44f126ae1a363f47e4c751a` |
| `HP001_E3a_engine_totem_pods_v4.png` | `b2d1830a7bcc9865e08df785f3e58be1b10cda54cbb6ae1ffe35190df773f745` |
| `HP001_E3a_engine_cmp_bg.png` | `0883ce7315291053b54356b1b6eedfb19b44798c2a1ac421df3a85e97fee3739` |
| `HP001_E2j_engine_laguna.png` | `a4fce65aa17a1dccdf464e8a284b146f25b6438df3c8c1d7dedccf163043c2f3` |
| `HP001_E2j_engine_dosel.png` | `c27154c092b3020610eda621763ff067636863f5832564efb61c6e977dbe8e8e` |
| `HP001_E2j_engine_dock_closeup.png` | `5bb13b09f0fa3cc560852316e3c00d358d29e80de41f0d5a7d55497c640933d7` |
| `HP001_E2j_engine_totem_pods_v4.png` | `44be09c922945515e0ef47eeb3505be846b1a6e8ecb48ddd4331846c58fcbf6b` |
| `HP001_E2j_engine_cmp_bg.png` | `55c1d34263bd9a007956c41c42c668710f210836de9d4ba5d11f927b53614b42` |
| `hp001_selva_silhouette.png` | `0de3d409577f49290c3a5298b434bc2f0e055af752fd5ee97c860eb328a24157` |
| `hp001_fg_liana.png` | `c20cc367e02193110fd091642e6cc5a252019cb9f2f9b5fdd11cc1f540f8fa90` |
| `hp001_jungle_sky_2d.jpg` | `1553cb6e9f537c7d98049fd541f3ae7d832dfaae8049a2aabfa221513935d2ac` |
| `hp001_cumulus_band.jpg` | `f4b54542b6aa82442f11c03cbe0de2512211ce8ecdf9f290f1d2a9db8a4d7da1` |

## Pendiente

| pieza | estado |
|---|---|
| geometría del 2D | completa (21 / 6 / 24 / 2 / 1) |
| oneway drop-through, pinchos, ranas, viento, rocas, granos, postes, meta | cableados |
| caja P03 pound | no. Maya no tiene pound |
| one-way fuera del mantle | no. Haría falta `player_maya.gd` |
