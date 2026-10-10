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

## Look (E2d)

La cámara lateral 40×22.5 lleva hijas fijas: banda de cúmulos (`hp001_cuyabeno_sky_2k`, solo el tercio de nubes, franja de juego más oscura/saturada) y **2 franjas** de selva lejana con bruma (`hp001_selva_silhouette`), detrás del carril, sin inclinación extra. Lianas de primer plano en el borde izquierdo del cuadro (`hp001_fg_liana`), fuera del hitbox. Copas y troncos de fondo (MultiMesh + LOD) a lo largo de todo selva-1, z < 0. Cards de tope en `Cam_Dosel` (layer 10) para que el corte de arriba no salga sesgado. Maya crema con outline sutil (cápsula, sin colisión). P00 tierra húmeda con emisión, sin sombras recibidas. Ranas y rocas al tamaño del hitbox; viento con rayas. Capturas en Vulkan Forward+. `player_maya.gd` no se tocó.

## Checks

| check | resultado |
|---|---|
| `maya_feel_check` | **54/54 PASS** |
| `hp001_lod_hole_check` | **PASS** (constantes + escena instanciada) |
| `SELVA_CHECK` | 21 / 6 / 24 / 2 / 1 · offset (0, 1, 24.1256) · P01 6.6667 |
| `selva1_run_probe` | pendiente (este commit) |
| `player_maya.gd` | no tocado |

## sha256

| archivo | sha256 |
|---|---|
| `3d_entrance.png` | `0268a7876740fc903671855af1e1794c95001179da1dcdcb120285740579e4fe` |
| `3d_hazard.png` | `743370b1de6aaa02ef8d73187dcca8275c9ef7ebc26885e5a003e6abc4df01d8` |
| `3d_cacao.png` | `e3b7ece05a6507afada8bb3973b4b5c1f99b0eab72911a256d27cf6cf86f6bfd` |
| `2d_entrance.png` | `da8c544df1e8c1e3f40a1e974493456e57223dd2a7a173d44c257bdf65235c39` |
| `2d_hazard.png` | `e7350d1c326b25d6f929b7ee5d263071010ce49b7a9d454025e505c2f35d1fd0` |
| `2d_cacao.png` | `497974338ca4ef00c0f77596afdbcd539aa805d8fa785d5068aa4f1efde5c598` |
| `cmp_cuyabeno_2d_3d.png` | `4ebc36a30197cfdc997c27045e77a79b83c223be6945037bd4177c6e4c7228a1` |
| `HP001_E2c_engine_gameplay.png` | `ddc3c6aaa85e1ad6cc3c5f84f0cd0bb607b2915f8d60600f1af8f3f6ef8bc153` |
| `HP001_E2c_engine_laguna.png` | `6b5ecc523b05762c9a1423bbaa421afeaecc8c9b748fedd5468bca4a0938f37c` |
| `HP001_E2c_engine_dosel.png` | `e6c2daa60c92137738910d16147e1e0c36fc9db4416c58e680a0d7990fd205c7` |
| `HP001_E2c_engine_dock_closeup.png` | `c1c2bc660a19977b926e3fb93e3eab29d107de02f5ed2e2e5fce257408169b88` |
| `HP001_E2c_engine_totem_pods_v4.png` | `791a727f247d1af2ed42ebf10187ac0c2ac0085534798de89124dff1f7a1469f` |
| `HP001_E2c_engine_cmp_bg.png` | `f5ece443287daf62a7e166bfce2ad2f01ffe7293339628867b6909dc15bba803` |
| `hp001_cuyabeno_sky_2k.png` | `5bb9b19567cec3f1131e4121b73a0b59722e9f1350abbd12a0b6995144edbeb3` |
| `hp001_selva_silhouette.png` | `0de3d409577f49290c3a5298b434bc2f0e055af752fd5ee97c860eb328a24157` |
| `hp001_fg_liana.png` | `c20cc367e02193110fd091642e6cc5a252019cb9f2f9b5fdd11cc1f540f8fa90` |
| `hp001_jungle_sky_2d.jpg` | `1553cb6e9f537c7d98049fd541f3ae7d832dfaae8049a2aabfa221513935d2ac` |

## Pendiente

| pieza | estado |
|---|---|
| geometría del 2D | completa (21 / 6 / 24 / 2 / 1) |
| oneway drop-through, pinchos, ranas, viento, rocas, granos, postes, meta | cableados |
| caja P03 pound | no. Maya no tiene pound |
| one-way fuera del mantle | no. Haría falta `player_maya.gd` |
