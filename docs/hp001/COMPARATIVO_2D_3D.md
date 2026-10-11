# Comparativo 2D / 3D — Cuyabeno (`selva-1`)

Piloto Godot 4.2. Escala **24 px = 1 m**. Y 2D hacia abajo; Y Godot hacia arriba. Pies de Maya: centro X del hitbox, base Y (`PH = 42`). Profundidad greybox de los sólidos: 64 px = 2.6667 m, centrada en z = 0.

El piso de entrada se baja **13.3333 m** para que su top quede en Godot y = 0 (el harness de feel aterriza a y≈0 y el `CSGPlatform` de 1 m sigue en y = 1). El primer oneway queda entonces a **6.6667 m**.

## Fuente

El pin pedido `NadiaCoelloO/sand-vivid-dawn-sail@5fd45031` no se pudo leer desde aquí (404). El layout y los timings salen de `NadiaCoelloO/Cacao.Game` `levels.ts` / `sim.ts` (`selva-1`, `sitSpikes`, `freeCoins`). QA verificó que esa geometría es la misma. 21 plataformas, 6 peligros, 24 granos (lista completa del archivo; el brief decía 23), 2 postes, 1 meta. Subtítulo del pin: **Laguna negra de Sucumbíos**.

El tótem (7.5, 0, 0), el muelle (10, 0, −4) y la laguna quedan como arte: fuera del carril o encima de P00. No añaden colisión.

`player_maya.gd`, el feel y la cápsula de Maya no se tocaron.

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

## Look (E2i)

Identidad ya PASABA. QA no reproduce el rim-vs-selva de E2h y da NO PASA solo en legibilidad. Este pase usa **su método** y las coordenadas de cada muestra. Fill Maya **0.90**. `player_maya.gd` no se tocó.

1. Granos: cara cacao `#6b3a1f`–`#8B4A2B` ≈(157,79,38). Rim naranja subido `#FFC060` (filmic ~255,229,124) **dentro** de un outline oscuro `#2c1810` (filmic ~51,24,14). Medida: mediana de la CARA contra el rim/outline inmediato (2–10 px), no el rim contra la selva lejana. 24/24 vs pin 2D (mediana 4.03 / mín 1.95): mediana de medianas **4.68**, mínimo **4.68**, mín-de-mín **4.84**. C08/C09/C15 sobre tops incluidos.
2. Maya: p10 del cuerpo **excluyendo 2 px de antialiasing** (y el bleed marrón del hull). ≥4.4 en los **8 x**. Mínimo del sweep **5.96** (x163). x36 **7.66** (QA tenía 4.24). Crema, sin naranja. Wrap cream en layer 2; fill 0.90 no se tocó.
3. `SELVA_GP_Platforms` oculto en follow cam (ledge visual x −6.4…5.75, sin colisión). Siguen ocultos `PlatformSolid*` / Floor / FloorClutter.
4. Corona: lóbulos anchos de várzea (coseno de baja frecuencia) + alguna emergente aislada. Sin picos de cordillera.
5. H04/H05: tronco caído `#4A4440`, cilindro acostado + extremo facetado. Distintos del grano por forma. Sin rim naranja.
6. Baseline 2D: Cacao.Game (Vite) **no se ejecutó**. Pin fallback `#6b3a1f` (`render.ts:1136–1139`).

Piso falso y corredor en layer 13 se mantienen. Vulkan Forward+.

### Contraste Maya (QA: p10 del cuerpo sin AA de borde)

Cuerpo = cream/tan. p10 = 10 % más oscuro **después** de erosionar 2 px (AA / hull). Fondo = selva inmediata. Coordenadas en píxeles del still 1280×720.

| x m | still | body RGB | p10 RGB | jungle RGB | cuerpo | p10 | p10 center px | p10 samples px | bg center px |
|---:|---|---|---|---|---:|---:|---|---|---|
| 4.54 | `3d_x04.png` | 188,158,97 | 180,147,94 | 23,29,11 | **6.74** | **5.98** | 150.0, 396.0 | (146,370) (154,422) | 156.2, 381.1 |
| 36.00 | `3d_x36.png` | 221,174,115 | 222,166,90 | 26,33,14 | **8.18** | **7.66** | 574.5, 380.0 | (574,380) (572,380) (577,380) | 580.4, 380.5 |
| 66.00 | `3d_x66.png` | 220,173,113 | 221,165,89 | 22,28,12 | **8.51** | **7.96** | 574.1, 380.1 | (574,380) (572,380) (577,380) (572,381) | 580.4, 380.6 |
| 86.67 | `3d_x87.png` | 221,174,115 | 222,167,90 | 17,22,7 | **9.09** | **8.57** | 574.5, 380.0 | (574,380) (572,380) (577,380) | 580.4, 380.5 |
| 95.33 | `3d_x95.png` | 199,166,113 | 189,153,101 | 28,34,16 | **7.09** | **6.15** | 581.0, 420.0 | (581,420) | 583.7, 402.6 |
| 133.33 | `3d_x133.png` | 199,166,112 | 189,153,101 | 27,35,15 | **7.05** | **6.11** | 581.0, 420.0 | (581,420) | 583.7, 402.6 |
| 162.67 | `3d_x163.png` | 199,166,112 | 188,152,101 | 29,36,16 | **6.95** | **5.96** | 581.0, 420.0 | (581,420) | 582.6, 416.9 |
| 193.33 | `3d_x193.png` | 228,180,93 | 212,163,82 | 27,34,15 | **8.57** | **7.14** | 972.8, 412.2 | (973,420) (972,422) (973,396) (973,424) | 967.5, 402.4 |

`3d_cacao` p10 **7.96** @ (574.5, 380.0). Los 8 x p10 ≥4.4. JSON: `e2i_contrast.json`.

### Contraste granos C00–C23 (QA: cara vs fondo local inmediato)

Cara = cacao interior. Fondo = rim `#FFC060` (filmic 255,229,124) que rodea la cara; el outline `#2c1810` queda por fuera. Pin 2D a vencer: mediana 4.03 / mín 1.95.

| id | still | face RGB | bg RGB | med | min | face center px | face bbox | face samples px | bg center px |
|---|---|---|---|---:|---:|---|---|---|---|
| C00 | `3d_x04.png` | 154,78,37 | 255,229,124 | **4.80** | 4.89 | 203.9, 295.6 | 203,287–206,301 | (203,295) (203,287) (206,301) | 204.4, 293.6 |
| C01 | `3d_x04.png` | 155,78,37 | 255,229,124 | **4.77** | 4.93 | 288.6, 290.6 | 280,278–297,299 | (289,291) (280,285) (297,282) | 290.0, 290.4 |
| C02 | `3d_x04.png` | 156,79,38 | 255,229,124 | **4.71** | 4.87 | 365.6, 291.8 | 357,279–374,305 | (366,292) (357,288) (374,288) | 365.6, 291.6 |
| C03 | `3d_x04.png` | 156,78,38 | 255,229,124 | **4.74** | 4.93 | 336.6, 80.3 | 328,71–345,92 | (337,80) (328,74) (345,75) | 334.7, 78.5 |
| C04 | `3d_x04.png` | 156,79,38 | 255,229,124 | **4.71** | 4.87 | 769.3, 82.9 | 761,71–778,96 | (769,83) (761,78) (778,79) | 769.9, 82.6 |
| C05 | `3d_x36.png` | 157,79,38 | 255,229,124 | **4.68** | 4.87 | 532.6, 300.4 | 524,288–541,313 | (533,300) (524,297) (541,297) | 532.6, 300.2 |
| C06 | `3d_x36.png` | 157,79,38 | 255,229,124 | **4.68** | 4.87 | 618.2, 263.2 | 610,250–627,276 | (618,263) (610,259) (627,261) | 617.8, 263.3 |
| C07 | `3d_x36.png` | 157,79,38 | 255,229,124 | **4.68** | 4.87 | 703.6, 300.8 | 695,288–712,314 | (704,301) (695,298) (712,297) | 704.0, 300.6 |
| C08 | `3d_cacao.png` | 157,79,38 | 255,229,124 | **4.68** | 4.84 | 264.4, 580.7 | 256,569–273,591 | (264,581) (256,577) (273,578) | 264.2, 577.8 |
| C09 | `3d_cacao.png` | 157,79,38 | 255,229,124 | **4.68** | 4.87 | 411.7, 579.3 | 403,568–420,591 | (412,579) (403,577) (420,575) | 412.3, 579.0 |
| C10 | `3d_x66.png` | 157,79,38 | 255,229,124 | **4.68** | 4.87 | 596.8, 302.1 | 588,289–605,315 | (597,302) (588,300) (605,298) | 596.8, 302.1 |
| C11 | `3d_x87.png` | 157,79,38 | 255,229,124 | **4.68** | 4.87 | 192.3, 376.8 | 183,364–201,389 | (192,377) (183,375) (201,374) | 192.5, 376.7 |
| C12 | `3d_x87.png` | 156,79,38 | 255,229,124 | **4.71** | 4.87 | 532.5, 291.5 | 524,279–541,304 | (532,292) (524,288) (541,288) | 532.5, 291.8 |
| C13 | `3d_x95.png` | 157,79,38 | 255,229,124 | **4.68** | 4.87 | 425.6, 291.7 | 417,279–434,305 | (426,292) (417,288) (434,288) | 425.4, 292.0 |
| C14 | `3d_x95.png` | 157,79,38 | 255,229,124 | **4.68** | 4.87 | 596.7, 292.1 | 588,279–605,305 | (597,292) (588,289) (605,288) | 597.0, 292.1 |
| C15 | `3d_x109.png` | 155,78,37 | 255,229,124 | **4.77** | 4.93 | 512.0, 422.4 | 504,417–520,430 | (512,422) (504,417) (520,417) | 511.9, 426.2 |
| C16 | `3d_x109.png` | 155,78,37 | 255,229,124 | **4.77** | 4.93 | 639.5, 422.3 | 631,417–648,430 | (639,422) (631,417) (648,417) | 639.5, 426.8 |
| C17 | `3d_hazard.png` | 156,79,38 | 255,229,124 | **4.71** | 4.87 | 148.9, 343.5 | 140,331–158,356 | (149,344) (140,340) (158,341) | 148.4, 343.3 |
| C18 | `3d_hazard.png` | 157,79,38 | 255,229,124 | **4.68** | 4.87 | 489.7, 299.5 | 481,287–498,312 | (490,299) (481,297) (498,295) | 490.1, 297.5 |
| C19 | `3d_hazard.png` | 157,79,38 | 255,229,124 | **4.68** | 4.87 | 915.1, 468.0 | 906,455–924,481 | (915,468) (906,470) (924,466) | 914.9, 468.2 |
| C20 | `3d_hazard.png` | 157,79,38 | 255,229,124 | **4.68** | 4.87 | 1171.8, 382.3 | 1163,370–1181,395 | (1172,382) (1163,379) (1181,380) | 1171.4, 382.2 |
| C21 | `3d_x163.png` | 156,79,38 | 255,229,124 | **4.71** | 4.87 | 575.4, 294.5 | 567,282–584,307 | (575,295) (567,291) (584,292) | 574.9, 294.5 |
| C22 | `3d_x163.png` | 156,79,38 | 255,229,124 | **4.71** | 4.87 | 918.3, 250.5 | 910,238–927,263 | (918,251) (910,246) (927,247) | 918.4, 250.1 |
| C23 | `3d_x193.png` | 157,79,38 | 255,229,124 | **4.68** | 4.87 | 938.9, 301.3 | 930,289–948,314 | (939,301) (930,299) (948,299) | 938.7, 301.7 |

Mediana de medianas **4.68**. Mínimo **4.68**. Mín-de-mín **4.84**. Pin 2D **4.03 / 1.95**. Cacao.Game no se ejecutó. Samples extra en `e2i_contrast.json`.

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
| contraste granos | 24/24 cara vs rim local ≥4.03 / ≥1.95. Mediana de medianas **4.68**, mín **4.68** |

## sha256

SHA de E2h 3d_* stills: **reemplazados**. HEAD de este commit de stills.

| archivo | sha256 |
|---|---|
| `3d_entrance.png` | `70b059680a19306409665f7ca999496a913a01061d25843cc79983c097cd1c1c` |
| `3d_hazard.png` | `a9bd0cec80afbfa9c95927050ce80cfb43079ea9cf12f2065e5cfa1f2b5c2d60` |
| `3d_cacao.png` | `16ab7a042eed3f358068c3f73feeaf7e11a469d430861eaaf832f3e35390c7d0` |
| `3d_x04.png` | `adf48f68d754199a594256b4884ab74cf9c9bfa64f762b9131c03cf0d9721481` |
| `3d_x36.png` | `40b3bc872998dc3e0af886d703013fcc746d1c3f99c131d6074b8de49ab385dd` |
| `3d_x66.png` | `13eaadb2b74be665f69b79b07e60562b96744b28821b121c29374c37b93d526d` |
| `3d_x87.png` | `d4f521ab4ed8b903c45898908de870dabe7c80063721e9775bee3e91a9d9977c` |
| `3d_x95.png` | `df3cbdca209dc0850f74cd10e3ef045dc2226a2ba0eb912c04e5a3d2923afb38` |
| `3d_x133.png` | `0748d90c061b0f129b54499bdb8d73ca323d834e493ebf3334af6c04dbcf65d7` |
| `3d_x163.png` | `3af28e7aed0f22552cf220ca7365e294a73185a6c40c4e1e8377b9f7f384b437` |
| `3d_x193.png` | `2baa8074e97c0764af1f255fb02c140aa170373c6a90e64543a51a935d49cc4c` |
| `3d_x109.png` | `7adc3efc166dea861c20cd21388ff9f8c472b43847f4c82b0ede263132715f91` |
| `2d_entrance.png` | `da8c544df1e8c1e3f40a1e974493456e57223dd2a7a173d44c257bdf65235c39` |
| `2d_hazard.png` | `b181184b3af1d01769948443e455996eb09de96ced50a8c75d1bcb7aabe4e795` |
| `2d_cacao.png` | `497974338ca4ef00c0f77596afdbcd539aa805d8fa785d5068aa4f1efde5c598` |
| `2d_grains_c06.png` | `cbce134e3cd6f599eb98431c4b906ddd2f872e16f0061fe89544ed0c549c9315` |
| `2d_grains_c08.png` | `fb570ec524a5092b79b79fe2136c3a5d15231d4f87623ff70d6798ebefce07d4` |
| `2d_grains_c16.png` | `81d83b681de4728f0f6dbace8b00c1b9e295bb376c82b60c5665b705fe5743ae` |
| `cmp_cuyabeno_2d_3d.png` | `3d2928eeffc9c51694f4e17d2d428f7773ce6398ee16cc0a58cbb5d2e46afa25` |
| `HP001_E2i_engine_gameplay.png` | `4cef83eb78a1c53f6aaf7281d540eadea5caa63651667bc237533b587578d218` |
| `HP001_E2i_engine_laguna.png` | `d3339c0adf1ffd294caccc4a0b0adaf44e43b6501e9078ae7272edf971eb3f4a` |
| `HP001_E2i_engine_dosel.png` | `b4bf61cc0b7b9d40bdd8c72f72053d0427c531a138eb54ca4c21e54953097f8a` |
| `HP001_E2i_engine_dock_closeup.png` | `1740396ee33f99de4763d27fa3dd9312c37215cdcc27073355fc71b5043fa142` |
| `HP001_E2i_engine_totem_pods_v4.png` | `96c4cc01bb2772b6127f14f3446303b21e52532e69c32809c2b8bf7d73aefdc0` |
| `HP001_E2i_engine_cmp_bg.png` | `bbd1e98392214ac824b8678b15cdf8360c3d42b8a7b03e2dbca2af994260f06c` |
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
