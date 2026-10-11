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

## Look (E2g)

Identidad ya PASA ≥2D. QA NO PASA era solo legibilidad: píldora de outline, cuerpo+sombras <4.4 en x66/x87, granos planos, piso falso en pozos, dither en la corona.

1. Outline = inverted hull 1–2 px (grow 0.040 m ≈ 1.3 px a 720p). Sin cápsula extra de torso (era la píldora de ~27 px).
2. Mediana del **cuerpo entero** (crema lit + tan en sombra) vs selva justo afuera ≥4.4:1 en los 8 x. x66 **8.66**, x87 **9.19**. Franja mid-route oscurecida; fill Maya 0.90, crema, solo layer 2.
3. Corona de la franja: silueta de copas pintada (`hp001_selva_silhouette.png`, corte suave). Sin dither de ruido.
4. 24 granos: rim + key cálido (`#c87838` → `#f8d090`). Tras el grade leen cream-gold. Mediana de medianas **13.54**, mínimo **9.48**. C07 **13.49**, C16 **11.88**, C21 **12.00**.
5. Piso falso: se sacó `P00_EarthFill` (220 m). La fascia queda dentro de P00 (0–13.3 m). En P00→P02 (13.3–18.7 m) y el resto de pozos se ve vacío de selva / cielo.
6. Banco de corredor (troncos + copas) en layer 13, cull en la follow cam — se acaba el follaje flotante de la fila 4 del cmp.
7. Referencia 2D renderGame: `2d_grains_c06.png` / `2d_grains_c16.png` (crescente cálido). En 2D los granos siguen 1.97–3.66 vs cielo/tierra; el rim es el salto 3D.

Plataformas #3E2C20. QA: pozo −18.4167, probe G00. Vulkan Forward+. `player_maya.gd` no se tocó.

### Contraste Maya (WCAG, cuerpo+sombras vs selva media)

| x m | still | body RGB | jungle RGB | cuerpo | outline | ≥4.4 |
|---:|---|---|---|---:|---:|:---:|
| 4.54 | `3d_x04.png` | 218,188,92 | 27,33,14 | **8.92** | 11.77 | sí |
| 36.00 | `3d_x36.png` | 220,177,108 | 27,34,14 | **8.23** | 5.73 | sí |
| 66.00 | `3d_x66.png` | 219,176,107 | 22,28,12 | **8.66** | 5.63 | sí |
| 86.67 | `3d_x87.png` | 220,176,109 | 16,22,7 | **9.19** | 5.80 | sí |
| 95.33 | `3d_x95.png` | 201,170,102 | 28,34,16 | **7.33** | 6.49 | sí |
| 133.33 | `3d_x133.png` | 202,171,102 | 28,35,15 | **7.35** | 6.57 | sí |
| 162.67 | `3d_x163.png` | 203,172,103 | 28,36,16 | **7.36** | 11.56 | sí |
| 193.33 | `3d_x193.png` | 222,179,98 | 27,34,15 | **8.37** | 8.03 | sí |

Viento H03 **7.52** / cacao **8.66**. Mínimo del sweep: **7.33** en x=95.

### Contraste granos C00–C23 (rim vs selva, mediana ≈4.5 / min ≥3)

| id | still | grain RGB | bg RGB | mediana | p15 | ≥4.4 / ≥3 |
|---|---|---|---|---:|---:|:---:|
| C00 | `3d_x04.png` | 255,237,180 | 24,30,12 | **14.66** | 14.05 | sí |
| C01 | `3d_x04.png` | 255,230,171 | 23,30,11 | **13.98** | 13.78 | sí |
| C02 | `3d_x04.png` | 255,230,170 | 23,30,11 | **13.98** | 13.78 | sí |
| C03 | `3d_x04.png` | 255,238,166 | 63,61,34 | **9.48** | 9.47 | sí |
| C04 | `3d_x04.png` | 255,230,170 | 56,54,29 | **10.01** | 9.66 | sí |
| C05 | `3d_x36.png` | 255,229,168 | 25,32,13 | **13.58** | 13.29 | sí |
| C06 | `3d_x36.png` | 255,228,168 | 25,32,13 | **13.49** | 13.20 | sí |
| C07 | `3d_x36.png` | 255,228,168 | 25,32,13 | **13.49** | 13.20 | sí |
| C08 | `3d_cacao.png` | 255,233,175 | 21,27,11 | **14.69** | 14.58 | sí |
| C09 | `3d_cacao.png` | 255,231,172 | 20,25,10 | **14.73** | 14.72 | sí |
| C10 | `3d_x66.png` | 255,228,168 | 24,30,13 | **13.75** | 13.55 | sí |
| C11 | `3d_x87.png` | 255,233,174 | 25,30,14 | **14.20** | 13.91 | sí |
| C12 | `3d_x87.png` | 255,229,168 | 16,21,6 | **15.04** | 14.72 | sí |
| C13 | `3d_x95.png` | 255,230,170 | 18,24,8 | **14.79** | 14.48 | sí |
| C14 | `3d_x95.png` | 255,228,168 | 19,25,8 | **14.45** | 14.15 | sí |
| C15 | `3d_x109.png` | 255,228,167 | 37,44,22 | **11.66** | 11.57 | sí |
| C16 | `3d_x109.png` | 255,227,166 | 35,42,21 | **11.88** | 11.71 | sí |
| C17 | `3d_hazard.png` | 255,234,175 | 37,45,23 | **12.03** | 11.78 | sí |
| C18 | `3d_hazard.png` | 255,229,169 | 26,33,13 | **13.44** | 13.16 | sí |
| C19 | `3d_hazard.png` | 255,231,171 | 24,31,12 | **13.93** | 13.45 | sí |
| C20 | `3d_x163.png` | 255,231,172 | 37,44,22 | **11.91** | 11.66 | sí |
| C21 | `3d_x163.png` | 255,228,168 | 34,42,20 | **12.00** | 11.83 | sí |
| C22 | `3d_x163.png` | 255,230,170 | 32,39,18 | **12.61** | 12.17 | sí |
| C23 | `3d_x193.png` | 255,230,170 | 38,45,23 | **11.67** | 11.26 | sí |

Mediana de medianas **13.54**. 2D renderGame (referencia): C06 2.19 · C07 2.46 · C16 2.63 vs cielo/tierra del `renderGame`.

### Contraste cacao (rim vs zona oscura)

| still | pod RGB | bg RGB | ratio | ≥4.4 |
|---|---|---|---:|:---:|
| `HP001_E2g_engine_totem_pods_v4.png` | 217,187,119 | 81,55,22 | **5.94** | sí |

## Checks

| check | resultado |
|---|---|
| `maya_feel_check` | **54/54 PASS** |
| `hp001_lod_hole_check` | **PASS** (constantes + escena instanciada) |
| `SELVA_CHECK` | 21 / 6 / 24 / 2 / 1 · offset (0, 1, 24.1256) · P01 6.6667 |
| `selva1_run_probe` | **PASS** ticks=1556 · far_x=194.32 · G00=1 · 0 muertes. Pozo verificado y=−18.45 |
| `player_maya.gd` | no tocado |
| capturas | Vulkan 1.4 Forward+ (llvmpipe), no OpenGL |
| contraste Maya (WCAG) | 8 x cuerpo+sombras ≥4.4; mínimo **7.33:1** en x=95. x66 **8.66**. x87 **9.19** |
| contraste granos | 24/24 mediana ≥4.4 (mín **9.48** C03). C07 13.49 · C16 11.88 · C21 12.00 |

## sha256

SHA de E2f 3d_* stills: **reemplazados** (ver `build_report.json`). HEAD de este commit de stills.

| archivo | sha256 |
|---|---|
| `3d_entrance.png` | `c0bee39cf8551ef34fa19a54a1c66887985033bed5cc5c0359508540f26b1173` |
| `3d_hazard.png` | `9aaf70e789eb1f2edee1659c4813862cd8d16d5af739b27586318f5cb37f9b91` |
| `3d_cacao.png` | `96c40296c05257793a17a92b62306879fa19e6346b7431b33607cd32b39fcd25` |
| `3d_x04.png` | `d2bc1b973fffbd3e88e23a01005ec4a6c7eb5292a398c3e31951868f547018cd` |
| `3d_x36.png` | `332ba05c3da6c2629f803b61ddd0e97d0c668234fc1faac8b5619ff985964b27` |
| `3d_x66.png` | `c162501aedb23b6b487f80a25eea27021584c74c68ab3882e7fe8c976c1cda30` |
| `3d_x87.png` | `d8d22f7ca2691b9398af0285fc88fbaaa06144d19409c5efdcd00756f108e99e` |
| `3d_x95.png` | `0bad2cf4d52daef0bd95ca6893d6417bbeb7b2d7069cef3faa5b591359770afb` |
| `3d_x133.png` | `d6cd074239d2c66bf0aa7ed9c20a13c7c6b17f30d84b3b1d8a2a3bb8c2c43449` |
| `3d_x163.png` | `d3cdf08730e660e02d40d4f7c9b6b8312acae0bddff03c2fb2823e4378c2dba5` |
| `3d_x193.png` | `fec7df0f968403949212d382ee01778132e435c164e51a7ee12e48cb4eb692ed` |
| `3d_x109.png` | `d708db984b8b03a3a9363561610271b067cf66d72a892c72e07f9ace319fcc19` |
| `2d_entrance.png` | `659420aa0cd5f622cc2e7b344cac70d68e141bf4975beafe2337ce496c6d9418` |
| `2d_hazard.png` | `5df9c022beb649060c8381cd3196e5d20f524d85de3c31ffd6d91194a044a6c9` |
| `2d_cacao.png` | `3bfc1f5c8d2c38168ff00684e7f44bbde063c896bd6eb3c6d57832b3c4de868f` |
| `2d_grains_c06.png` | `c1dfaa852554fd5f0b04f5de5ef46eaaca0d0b9a49636f79360194ba3bc0e6b5` |
| `2d_grains_c16.png` | `5aa1006f1ebac828b0cc726b834a4cb25a1ea0ca0317dfca7ac578e97e7d8bc8` |
| `cmp_cuyabeno_2d_3d.png` | `1a6ba0f2f1f223a79b14e79f4265bebb8fbfeb412b40d49a35c604739288000a` |
| `HP001_E2g_engine_gameplay.png` | `3d1282596f2042097d48c431b88c45167abc923f4ebcb63da93c5452df3d3b09` |
| `HP001_E2g_engine_laguna.png` | `0d59c6437f2000b43cfaf8db09080ec7f64a966eb95392768ea8862faca79534` |
| `HP001_E2g_engine_dosel.png` | `7366ad2bbb298f7bd3e5e18178fbff02831220ef1ef296c71534445de1ab01c5` |
| `HP001_E2g_engine_dock_closeup.png` | `3ce3b1b478591f3148978d92c137814e62128fe2ba347824422a9c5395c75366` |
| `HP001_E2g_engine_totem_pods_v4.png` | `bfc48252de590291f19452231c5d34f8bff26d7fb3651a5cf935640f8e67c56c` |
| `HP001_E2g_engine_cmp_bg.png` | `f39c580e43f37458210a7c6b707c9f31b380df24aaded893a200317d2b188bdc` |
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
