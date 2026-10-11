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

## Look (E2h)

Identidad + QA en el mismo pase. Fill Maya **0.90** (aprobado). `player_maya.gd` no se tocó.

1. Granos: cara `#6b3a1f`–`#8B4A2B`, sin mezcla a crema `#f8d090`. Rim fino 1–2 px `#CE722E` (inverted hull, igual que Maya). Cara medida ≈(155,78,37).
2. 24/24 C00–C23, incluidos C08/C09/C15 sobre tops. Rim vs selva: mediana de medianas **7.27**, mínimo **4.41** (C08). Todos mediana ≥4.4 y min ≥3.
3. H04/H05: bloque de pizarra fría facetado, no óvalo cacao.
4. Maya p10 (10 % más oscuro del cuerpo) ≥4.4 en x36 **5.74**, x66 **6.10**, `3d_cacao` **6.10**. Cuerpo entero ≥4.4 en los 8 x.
5. Spawn x04: se ocultó `SELVA_GP_PlatformSolid_01` (caja LOOK 4×1×3 en x=6.5) que tapaba a Maya. Siguen ocultos dock HP y tótem en follow cam; las cámaras de arte los encienden.
6. Corona: alpha de `hp001_selva_silhouette.png`, copas irregulares, sin corte recto ni dither.
7. Baseline 2D: Cacao.Game (Vite) **no se ejecutó**. `render_selva1_2d.py` usa el fallback del pin `render.ts:1136–1139` (`#6b3a1f` elipse, sin highlight). Extra `2d_grains_c08.png`. En 2D los granos sobre tierra dan ~1.07; el rim 3D es el salto.

Piso falso y corredor en layer 13 se mantienen. Vulkan Forward+.

### Contraste Maya (WCAG, cuerpo+sombras vs selva; p10 = 10 % más oscuro)

| x m | still | body RGB | jungle RGB | cuerpo | p10 | ≥4.4 cuerpo / p10 |
|---:|---|---|---|---:|---:|:---:|
| 4.54 | `3d_x04.png` | 181,152,99 | 23,29,11 | **6.27** | 2.46 | cuerpo sí · p10 no (no exigido) |
| 36.00 | `3d_x36.png` | 220,177,108 | 27,34,14 | **8.23** | **5.74** | sí / sí |
| 66.00 | `3d_x66.png` | 219,176,107 | 22,28,12 | **8.66** | **6.10** | sí / sí |
| 86.67 | `3d_x87.png` | 220,176,109 | 16,22,7 | **9.19** | **6.47** | sí / sí |
| 95.33 | `3d_x95.png` | 201,170,102 | 28,34,16 | **7.33** | **6.02** | sí / sí |
| 133.33 | `3d_x133.png` | 202,171,102 | 28,35,15 | **7.35** | **5.88** | sí / sí |
| 162.67 | `3d_x163.png` | 203,172,103 | 28,36,16 | **7.36** | **5.83** | sí / sí |
| 193.33 | `3d_x193.png` | 222,179,98 | 27,34,15 | **8.37** | **6.09** | sí / sí |

Viento H03 **7.52** / cacao **8.66** (p10 **6.10**). Mínimo del sweep cuerpo: **6.27** en x=04. p10 exigido (x36 / x66 / cacao): **5.74 / 6.10 / 6.10**.

### Contraste granos C00–C23 (rim `#CE722E` vs selva; cara queda cacao)

| id | still | face RGB | rim RGB | mediana | min | ≥4.4 / ≥3 |
|---|---|---|---|---:|---:|:---:|
| C00 | `3d_x04.png` | 157,79,38 | 240,150,52 | **7.41** | 7.41 | sí |
| C01 | `3d_x04.png` | 154,77,37 | 240,150,52 | **7.43** | 7.43 | sí |
| C02 | `3d_x04.png` | 155,78,37 | 240,150,52 | **7.43** | 7.43 | sí |
| C03 | `3d_x04.png` | 153,77,37 | 240,150,52 | **7.52** | 7.52 | sí |
| C04 | `3d_x36.png` | 154,77,37 | 240,150,52 | **7.10** | 7.10 | sí |
| C05 | `3d_x36.png` | 155,78,37 | 240,150,52 | **7.27** | 7.27 | sí |
| C06 | `3d_x36.png` | 155,78,37 | 240,150,52 | **7.27** | 7.27 | sí |
| C07 | `3d_x36.png` | 155,78,37 | 240,150,52 | **7.27** | 7.27 | sí |
| C08 | `3d_x66.png` | 155,78,38 | 161,120,60 | **4.41** | 4.40 | sí (top) |
| C09 | `3d_x66.png` | 155,78,37 | 161,120,60 | **4.49** | 4.48 | sí (top) |
| C10 | `3d_x66.png` | 155,78,37 | 240,150,52 | **7.41** | 7.41 | sí |
| C11 | `3d_x87.png` | 155,78,37 | 240,150,52 | **7.39** | 7.39 | sí |
| C12 | `3d_x87.png` | 155,78,37 | 240,150,52 | **8.05** | 8.05 | sí |
| C13 | `3d_x95.png` | 155,78,37 | 240,150,52 | **7.86** | 7.86 | sí |
| C14 | `3d_x95.png` | 155,78,37 | 240,150,52 | **7.79** | 7.79 | sí |
| C15 | `3d_x109.png` | 77,51,34 | 240,150,52 | **5.03** | 5.03 | sí (top) |
| C16 | `3d_x109.png` | 144,72,34 | 240,150,52 | **6.45** | 6.45 | sí |
| C17 | `3d_hazard.png` | 155,78,37 | 240,150,52 | **6.22** | 6.22 | sí |
| C18 | `3d_hazard.png` | 155,78,37 | 240,150,52 | **7.21** | 7.21 | sí |
| C19 | `3d_hazard.png` | 155,78,38 | 240,150,52 | **7.35** | 7.35 | sí |
| C20 | `3d_x163.png` | 155,78,37 | 240,150,52 | **6.20** | 6.20 | sí |
| C21 | `3d_x163.png` | 155,78,37 | 240,150,52 | **6.47** | 6.47 | sí |
| C22 | `3d_x163.png` | 155,78,37 | 240,150,52 | **6.70** | 6.70 | sí |
| C23 | `3d_x193.png` | 155,78,37 | 240,150,52 | **6.20** | 6.20 | sí |

Mediana de medianas **7.27**. Mínimo **4.41** (C08, top de plataforma). 2D pin fallback `#6b3a1f`: C08/C09 **1.07** vs tierra; C15 **1.42**. Cacao.Game no se ejecutó.

### Contraste cacao (rim vs zona oscura)

| still | pod RGB | bg RGB | ratio | ≥4.4 |
|---|---|---|---:|:---:|
| `HP001_E2h_engine_totem_pods_v4.png` | 221,194,128 | 226,202,139 | 1.08 | máscara tomó el halo del haz (E2g era 5.94) |

## Checks

| check | resultado |
|---|---|
| `maya_feel_check` | **54/54 PASS** |
| `hp001_lod_hole_check` | **PASS** |
| `SELVA_CHECK` | 21 / 6 / 24 / 2 / 1 · offset (0, 1, 24.1256) · P01 6.6667 |
| `selva1_run_probe` | **PASS** ticks=1556 · far_x=194.32 · G00=1 · 0 muertes |
| `player_maya.gd` | no tocado |
| capturas | Vulkan 1.4 Forward+ (llvmpipe), no OpenGL |
| contraste Maya | 8 x cuerpo ≥4.4; p10 exigido x36/x66/cacao **5.74 / 6.10 / 6.10** |
| contraste granos | 24/24 mediana ≥4.4, min ≥3. Mediana de medianas **7.27**, mín **4.41** C08 |

## sha256

SHA de E2g 3d_* stills: **reemplazados**. HEAD de este commit de stills.

| archivo | sha256 |
|---|---|
| `3d_entrance.png` | `cdb74f5cc6c9d13fdfb068d57b388675e5a219bddb95573a3efaf217a9f601d3` |
| `3d_hazard.png` | `d1aea5253b657657fab254812892d0f748bf3f3b1a81c88a2558b927d3475c8a` |
| `3d_cacao.png` | `b4a32528ca9f05517ea67d35e20f1662f590bced9141be77acd199f165ed0c67` |
| `3d_x04.png` | `c662113ed832217e168724b45ca33e917e9bbf36bf55a5df058b2700a371460f` |
| `3d_x36.png` | `aa63bfa3297bb536f8b32e9b020ebcb622f889f2ebaebb84c47fcea966ac544b` |
| `3d_x66.png` | `8985b4c0ac8aeeb2780906357ee5263c977f3e9638b39b438276d1b140c89508` |
| `3d_x87.png` | `9aa835ea3901486dd4daedb5a95eea9942ca0241cc0bfb505f92faaf3cd1e01f` |
| `3d_x95.png` | `ca74ee544b770713dba3eebe762426313967c0a15128764ee21f03335636a7ff` |
| `3d_x133.png` | `f49e9985577d5ae978e4692d5e0261c0d0825e7c10b80e12f225e6a0122a5757` |
| `3d_x163.png` | `1e62d5d30a8972489de226ee37680f947d7a894bf7b070b204b6faf7417f1d93` |
| `3d_x193.png` | `1d5a53fcbc37c636a0e29453ee1be3deba5290293e663e44e1da012764f3c158` |
| `3d_x109.png` | `245484b13381f4283dc29b6225038d3fbdb1d8ba24bab6c7a1598845fc7b5660` |
| `2d_entrance.png` | `da8c544df1e8c1e3f40a1e974493456e57223dd2a7a173d44c257bdf65235c39` |
| `2d_hazard.png` | `b181184b3af1d01769948443e455996eb09de96ced50a8c75d1bcb7aabe4e795` |
| `2d_cacao.png` | `497974338ca4ef00c0f77596afdbcd539aa805d8fa785d5068aa4f1efde5c598` |
| `2d_grains_c06.png` | `cbce134e3cd6f599eb98431c4b906ddd2f872e16f0061fe89544ed0c549c9315` |
| `2d_grains_c08.png` | `fb570ec524a5092b79b79fe2136c3a5d15231d4f87623ff70d6798ebefce07d4` |
| `2d_grains_c16.png` | `81d83b681de4728f0f6dbace8b00c1b9e295bb376c82b60c5665b705fe5743ae` |
| `cmp_cuyabeno_2d_3d.png` | `0fdad0f4949b19d0c6c68caec4ac43e5a411f68c73c05ed33545107adf901dc9` |
| `HP001_E2h_engine_gameplay.png` | `53c9d41895e3b55b8504b3b3acee506b55ff66556933fefd0c4f2a32443b899c` |
| `HP001_E2h_engine_laguna.png` | `88a04b6b1e1d668b487890015d2d34035e0dfaf7608ada5becd052077301a7fb` |
| `HP001_E2h_engine_dosel.png` | `dea9ade8cdaf1da6c96905459d8845a6750368eeeb546a5c9f4702824303a48f` |
| `HP001_E2h_engine_dock_closeup.png` | `1b7689573bb7c315d2471c43f763bcb40945196baa9685a49801782fbb5d8c71` |
| `HP001_E2h_engine_totem_pods_v4.png` | `c7d0c03003928f0689195d18521967b70a92b7ce77a84d3e9406be9fe1c49cdf` |
| `HP001_E2h_engine_cmp_bg.png` | `1154330d4bfee535026c143b67cf499ab9bda87d2a00370cd99181854ab08be3` |
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
