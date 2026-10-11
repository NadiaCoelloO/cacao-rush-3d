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

## Look (E2f)

QA e Identidad se contradecían sobre el disco negro pegado a Maya (QA: otro outline, cuerpo 1.0–1.6:1 contra el cielo dorado; Identidad: cápsula negra). E2f lo saca.

Composición tipo 2D, hijas de la cámara 40×22.5:

1. Outline fino solamente (cabeza y manos). Sin disco / halo / viñeteo en Maya.
2. Cielo dorado + cúmulos (`hp001_cumulus_band.jpg`) **arriba** del cuadro. Detrás de la franja de juego (agua/tierra hasta ~salto de Maya) va una capa **continua** de selva media en sombra: oliva / marrón oscuro desaturado, mottling de follaje, niebla cálida suave en la corona. El borde superior es irregular y difuso (dither + scallop), muy por encima de los tops, para que no se lea como piso falso sobre los pozos. Opaca — tapa el clear color negro. Esta capa **es** el fondo real del cuerpo.
3. Contraste del cuerpo vs esa selva en 8 x a lo largo de la ruta; si un tramo no llega a 4.4 se oscurece la franja ahí, no a Maya. La entrada/muelle va más oscura.
4. Wrap del panorama con crossfade (sin costura vertical dura).
5. Cacao con rim cálido claro, ≥4.4:1 sobre zonas oscuras.
6. `hp001_cumulus_band.jpg` en `LOOK-001_manifest.json`.

Plataformas #3E2C20 con labio claro. Viento: 4 trazos finos. QA: pozo −18.4167, peligros al hitbox, probe G00. Capturas Vulkan Forward+. `player_maya.gd` no se tocó.

### Contraste Maya (WCAG, cuerpo vs selva media)

| x m | still | body RGB | jungle RGB | cuerpo | outline | ≥4.4 |
|---:|---|---|---|---:|---:|:---:|
| 4.54 | `3d_x04.png` | 201,173,86 | 34,42,21 | **7.92** | 11.51 | sí |
| 36.00 | `3d_x36.png` | 201,153,90 | 38,47,24 | **5.45** | 6.99 | sí |
| 66.00 | `3d_x66.png` | 202,150,81 | 49,59,32 | **4.50** | 7.85 | sí |
| 86.67 | `3d_x87.png` | 202,153,90 | 36,45,22 | **5.62** | 6.93 | sí |
| 95.33 | `3d_x95.png` | 215,163,85 | 45,55,29 | **5.53** | 9.19 | sí |
| 133.33 | `3d_x133.png` | 215,163,85 | 45,54,28 | **5.59** | 8.82 | sí |
| 162.67 | `3d_x163.png` | 214,163,85 | 37,46,23 | **6.23** | 9.05 | sí |
| 193.33 | `3d_x193.png` | 217,164,93 | 41,50,26 | **6.02** | 9.52 | sí |

Entrada 7.48 / viento H03 5.34 / cacao 4.50. Mínimo del sweep: **4.50** en x=66.

### Contraste cacao (rim vs zona oscura)

| still | pod RGB | bg RGB | ratio | ≥4.4 |
|---|---|---|---:|:---:|
| `HP001_E2f_engine_totem_pods_v4.png` | 218,189,120 | 81,56,23 | **5.98** | sí |

## Checks

| check | resultado |
|---|---|
| `maya_feel_check` | **54/54 PASS** |
| `hp001_lod_hole_check` | **PASS** (constantes + escena instanciada) |
| `SELVA_CHECK` | 21 / 6 / 24 / 2 / 1 · offset (0, 1, 24.1256) · P01 6.6667 |
| `selva1_run_probe` | **PASS** ticks=1556 · far_x=194.32 · G00=1 · 0 muertes. Pozo verificado y=−18.45 |
| `player_maya.gd` | no tocado |
| capturas | Vulkan 1.4 Forward+ (llvmpipe), no OpenGL |
| contraste Maya (WCAG) | 8 x ≥4.4; mínimo **4.50:1** en x=66. Entrada **7.48**. Viento **5.34**. Cacao rim **5.98** |

## sha256

SHA de E2e y stills E2e: **reemplazados** (ver `build_report.json`). HEAD de este commit de stills.

| archivo | sha256 |
|---|---|
| `3d_entrance.png` | `d94e46778e796f0a539ed276da6f239204042176aed7e0e15fde326305676b88` |
| `3d_hazard.png` | `cb4517e267246e50f513cccc3f58e20e1ded59c942ec5dc6833a631b083da511` |
| `3d_cacao.png` | `3636d901acabdb92899bf33cb0f15119605ff02867a880566c6201f5dfc565cf` |
| `3d_x04.png` | `164ecf650e72bf2af9808a76794cb8e2f409b9af578dde57f4313ac8479551f6` |
| `3d_x36.png` | `d65dc226f5b67e9308ccad5e8435718f0466cfcaf70930bdfd1679c251dd840d` |
| `3d_x66.png` | `b3f8c075fb8fea46efc3d0215137df892a8d964e9a6f12004362fdb90c32eead` |
| `3d_x87.png` | `5170baa37f25c14da8016bf26a5d9680158293a623ed3ab0fee879ca49d620a6` |
| `3d_x95.png` | `882f6a6077543cb727b275dccc502794370d81c8805a82db51d506bca7cf8f8b` |
| `3d_x133.png` | `250c4077809ac6bd8d1b28d479026cbef9d0aa94ffb59b84ffe4d455e4dbc156` |
| `3d_x163.png` | `78f4c24102e89f18994568ba90255980b18e2e621ddeb36ef7b6113a30fb8ddb` |
| `3d_x193.png` | `c8fcf67399514d86277637e4bd7274b63f2f49beff69b59666c4de353b989498` |
| `2d_entrance.png` | `da8c544df1e8c1e3f40a1e974493456e57223dd2a7a173d44c257bdf65235c39` |
| `2d_hazard.png` | `b181184b3af1d01769948443e455996eb09de96ced50a8c75d1bcb7aabe4e795` |
| `2d_cacao.png` | `497974338ca4ef00c0f77596afdbcd539aa805d8fa785d5068aa4f1efde5c598` |
| `cmp_cuyabeno_2d_3d.png` | `70b0c104f1bdf4405246528a6317ca0118b5463f60db78d681a914f21eb64e43` |
| `HP001_E2f_engine_gameplay.png` | `a730421803d47f2bab87949e8cb018d7271e54c7046ff3394a0345eb65316f90` |
| `HP001_E2f_engine_laguna.png` | `02ed21acad50cf95f919f57b831d17e22e1b78c32f961a8dde1e29650ee61f24` |
| `HP001_E2f_engine_dosel.png` | `e7f3531d43e6743654868ee8310fa2b754b41b985c18e3d3d6226af26a00f55d` |
| `HP001_E2f_engine_dock_closeup.png` | `9549314eabe91fdce936effa2e77ef3cd6999f4592b99482817b761fb434d89c` |
| `HP001_E2f_engine_totem_pods_v4.png` | `0ecdaed17de901b045e6c379cb2dabb0574f61435333fd9ccbdef9b36530f5e9` |
| `HP001_E2f_engine_cmp_bg.png` | `c505dbfd550d6f62ed2c290777ec07e541cfdebf5cc3bb1369b7a250b1a46f6e` |
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
