# Comparativo 2D / 3D — Ruinas de Kakaw (`ruinas-1`)

Piloto greybox Godot 4.2. Escala **24 px = 1 m** (`PX_TO_M` de `player_maya.gd`). Y 2D hacia abajo; Y Godot hacia arriba. Origen de los pies de Maya: `x` del centro del hitbox, `y` de la base (`PH = 42`). Profundidad greybox de los sólidos: 64 px = 2.6667 m, centrada en z = 0. No es un eje del 2D.

## Fuente

El pin pedido `NadiaCoelloO/sand-vivid-dawn-sail@5fd450312c8e6ad0a214f35b68fd81ec2857fec3` responde 404 con el token de este entorno. No se escribió, no se commiteó y no se abrió un PR en ese repo.

El layout se leyó del hermano público `NadiaCoelloO/Cacao.Game@77e55b5278` `src/game/levels.ts`, función `make("ruinas-1", …)` más `linkSecrets`, `sitSpikes` y `freeCoins`. El nivel existe: mundo `ruinas`, nombre **Ruinas de Kakaw**, subtítulo **El patio de las lanzas**, 4800×1152 px (`T*150` × `T*36`, `T = 32`). Los cuatro oneways de `selva-1` de ese archivo coinciden con `docs/ONEWAY_DELTA_selva.md`, que sí fue verificado contra el tip `5fd45031`. Un drift posterior de la geometría de ruinas en el pin no es verificable desde aquí.

Niveles destino `jardin-1` y `pichincha-1` no forman parte de este piloto. Solo entran las entradas que viven dentro de `ruinas-1`.

## Tomas

Misma pose de Maya en los dos renders. 2D: `renderGame` de `render.ts` sobre `createGame` (`preview` local, canvas 960×540, `camLook = 48`, `time = 0`). 3D: viewport 1280×720, `Camera3D` hija de `PlayerMaya` (`fov` 50, `camera_offset` (0, 1, 12), look-ahead 2 m), HUD oculto, 60 frames de física para asentar el follow. El 2D se escaló nearest-neighbour a 1280×720 (factor 720/540) y se puso a la izquierda.

La cámara 2D ve 960×540 px (40 × 22.5 m) y se clampea al borde del nivel. La cámara de juego 3D, a 12 m con fov vertical 50, encuadra cerca de 20 × 11 m. El recorte es más cerrado; el tramo es el mismo.

| id | pies 2D (x, y) | pies 3D (m) | qué se ve |
|---|---|---|---|
| patio | (291, 822) | (12.6667, 12, 0) | suelo de entrada, pozo y techo de arrastre |
| jardin | (403, 1095) | (17.3333, 0.625, 0) | secreto: caída `jardin` entre los muros |
| mantle | (356, 150) | (15.375, 40, 0) | de pie en el labio derecho del muro izquierdo |

![patio](cmp_patio.png)

![jardin](cmp_jardin.png)

![mantle](cmp_mantle.png)

## Perf greybox (vista de juego, OpenGL llvmpipe)

`Viewport.RENDER_INFO_TYPE_VISIBLE` después del frame de la toma. Presupuesto de referencia del brief: ≤ 80 draws y ≤ 180k tris.

| toma | tris | draws | objects | tris mundo | draws mundo |
|---|---:|---:|---:|---:|---:|
| patio | 2567 | 80 | 80 | 1212 | 35 |
| jardin | 1547 | 81 | 81 | 192 | 36 |
| mantle | 2543 | 70 | 70 | 1188 | 25 |

Los sólidos estáticos, pinchos, monedas, postes, meta y la caída van en una malla por material (`SurfaceTool`). Móviles, crumble y láseres quedan por instancia porque se mueven o parpadean. El salto de draws entre “mundo” y la toma completa es el héroe `hero_grey.glb` de Maya, que este piloto no toca. Jardin queda en 81 draws con Maya en cuadro; el mundo solo está en 25–36.

## Equivalencias

Columna **estado**: `presente` si el volumen XY del 2D está en la escena. Nada de esta lista se omitió ni se inventó. Las notas de simulación están en [Faltantes](#faltantes).

Centro y tamaño 3D en metros. Los móviles se listan en el reposo del 2D y en t = 0 (`ny = oy + ay` cuando `phase = 0`).

### Plataformas

| id | kind | tag | AABB 2D (x, y, w, h) px | centro 3D m | tamaño 3D m | top m | estado |
|---|---|---|---|---|---|---:|---|
| P00 | solid | suelo de entrada | (0, 864, 320, 288) | (6.667, 6, 0) | (13.33, 12, 2.667) | 12 | presente |
| P01 | solid | muro de escalada izquierdo del pozo | (320, 192, 64, 960) | (14.67, 20, 0) | (2.667, 40, 2.667) | 40 | presente |
| P02 | solid | muro de escalada derecho del pozo | (448, 192, 64, 960) | (20, 20, 0) | (2.667, 40, 2.667) | 40 | presente |
| P03 | solid | suelo tras el pozo | (512, 864, 256, 288) | (26.67, 6, 0) | (10.67, 12, 2.667) | 12 | presente |
| P04 | solid | techo de arrastre (crawlCover, gap 30 px) | (576, 770, 192, 64) | (28, 14.58, 0) | (8, 2.667, 2.667) | 15.92 | presente |
| P05 | solid | bloque medio | (768, 640, 192, 512) | (36, 10.67, 0) | (8, 21.33, 2.667) | 21.33 | presente |
| P06 | solid | columna | (832, 256, 64, 256) | (36, 32, 0) | (2.667, 10.67, 2.667) | 37.33 | presente |
| P07 | solid | bloque grande | (1024, 544, 256, 608) | (48, 12.67, 0) | (10.67, 25.33, 2.667) | 25.33 | presente |
| P08 | oneway | one-way | (960, 416, 96, 18) | (42, 30.29, 0) | (4, 0.75, 2.667) | 30.67 | presente |
| P09 | crate | caja | (1216, 704, 160, 22) | (54, 18.21, 0) | (6.667, 0.9167, 2.667) | 18.67 | presente |
| P10 | moving | plataforma móvil vertical | (1280, 608, 96, 22) | (55.33, 22.21, 0) | (4, 0.9167, 2.667) | 22.67 | presente t=0 |
| P11 | solid | repisa alta | (1536, 256, 320, 128) | (70.67, 34.67, 0) | (13.33, 5.333, 2.667) | 37.33 | presente |
| P12 | solid | suelo bajo la repisa | (1536, 768, 320, 256) | (70.67, 10.67, 0) | (13.33, 10.67, 2.667) | 16 | presente |
| P13 | crumble | piedra que cede (alta) | (1920, 576, 128, 448) | (82.67, 14.67, 0) | (5.333, 18.67, 2.667) | 24 | presente |
| P14 | oneway | one-way | (2112, 448, 160, 22) | (91.33, 28.88, 0) | (6.667, 0.9167, 2.667) | 29.33 | presente |
| P15 | solid | suelo del poste secreto pichincha | (2368, 640, 192, 384) | (102.7, 13.33, 0) | (8, 16, 2.667) | 21.33 | presente |
| P16 | crumble | piedra que cede | (2624, 544, 128, 22) | (112, 24.88, 0) | (5.333, 0.9167, 2.667) | 25.33 | presente |
| P17 | moving | plataforma móvil horizontal | (2880, 448, 128, 22) | (122.7, 28.88, 0) | (5.333, 0.9167, 2.667) | 29.33 | presente t=0 |
| P18 | solid | bloque ancho | (3328, 576, 320, 448) | (145.3, 14.67, 0) | (13.33, 18.67, 2.667) | 24 | presente |
| P19 | oneway | one-way | (3456, 384, 96, 18) | (146, 31.62, 0) | (4, 0.75, 2.667) | 32 | presente |
| P20 | solid | suelo del paso bajo | (3776, 704, 192, 320) | (161.3, 12, 0) | (8, 13.33, 2.667) | 18.67 | presente |
| P21 | solid | techo de arrastre estrecho (squeezeCover, gap 18 px) | (3776, 622, 160, 64) | (160.7, 20.75, 0) | (6.667, 2.667, 2.667) | 22.08 | presente |
| P22 | solid | bloque | (4032, 512, 128, 512) | (170.7, 16, 0) | (5.333, 21.33, 2.667) | 26.67 | presente |
| P23 | solid | columna alta | (4032, 192, 64, 192) | (169.3, 36, 0) | (2.667, 8, 2.667) | 40 | presente |
| P24 | solid | suelo de meta | (4288, 384, 512, 640) | (189.3, 18.67, 0) | (21.33, 26.67, 2.667) | 32 | presente |

Reposos de los móviles (antes del seno/coseno):

- P10 reposo px (1280, 384) amp (0, 224) periodo 4 fase 0. En t = 0 el JSON ya trae la posición desplazada (1280, 608, 96, 22).
- P17 reposo px (2880, 448) amp (224, 0) periodo 3.1 fase 0. En t = 0 el JSON ya trae la posición desplazada (2880, 448, 128, 22).

### Peligros

Los pinchos ya pasaron por `sitSpikes` (diente 16 px, sentados en el sólido de abajo). Las láseres están encendidas en t = 0: `(time + phase) % period < period * 0.42`.

| id | kind | AABB 2D px | centro 3D m | tamaño XY m | periodo | fase | estado |
|---|---|---|---|---|---|---|---|
| H00 | spikes | (1024, 527, 128, 18) | (45.33, 25.67, 0) | 5.333 × 0.75 | — | — | presente |
| H01 | spikes | (1600, 751, 192, 18) | (70.67, 16.33, 0) | 8 × 0.75 | — | — | presente |
| H02 | spikes | (2432, 623, 128, 18) | (104, 21.67, 0) | 5.333 × 0.75 | — | — | presente |
| H03 | spikes | (3392, 559, 128, 18) | (144, 24.33, 0) | 5.333 × 0.75 | — | — | presente |
| H04 | laser | (1344, 384, 10, 256) | (56.21, 26.67, 0) | 0.4167 × 10.67 | 2.4 | 0 | presente |
| H05 | laser | (2752, 512, 10, 256) | (114.9, 21.33, 0) | 0.4167 × 10.67 | 2.8 | 0.5 | presente |
| H06 | laser | (3776, 256, 10, 320) | (157.5, 30.67, 0) | 0.4167 × 13.33 | 2.2 | 0.3 | presente |

Profundidad visual, no del 2D: pinchos z = 0.45 m, láser z = 0.25 m.

### Pickups

Centros después de `freeCoins`. Radio 2D 12 px = 0.5 m. Esferas de cacao, sin vaina.

| id | centro 2D px | centro 3D m | radio m | estado |
|---|---|---|---:|---|
| C00 | (192, 768) | (8, 16, 0) | 0.5 | presente |
| C01 | (256, 752) | (10.67, 16.67, 0) | 0.5 | presente |
| C02 | (320, 768) | (13.33, 16, 0) | 0.5 | presente |
| C03 | (396.8, 512) | (16.53, 26.67, 0) | 0.5 | presente |
| C04 | (576, 852) | (24, 12.5, 0) | 0.5 | presente |
| C05 | (640, 852) | (26.67, 12.5, 0) | 0.5 | presente |
| C06 | (896, 544) | (37.33, 25.33, 0) | 0.5 | presente |
| C07 | (864, 192) | (36, 40, 0) | 0.5 | presente |
| C08 | (1088, 352) | (45.33, 33.33, 0) | 0.5 | presente |
| C09 | (1344, 256) | (56, 37.33, 0) | 0.5 | presente |
| C10 | (1600, 160) | (66.67, 41.33, 0) | 0.5 | presente |
| C11 | (1664, 151.34) | (69.33, 41.69, 0) | 0.5 | presente |
| C12 | (1728, 151.34) | (72, 41.69, 0) | 0.5 | presente |
| C13 | (1792, 160) | (74.67, 41.33, 0) | 0.5 | presente |
| C14 | (2176, 352) | (90.67, 33.33, 0) | 0.5 | presente |
| C15 | (2496, 626) | (104, 21.92, 0) | 0.5 | presente |
| C16 | (2944, 352) | (122.7, 33.33, 0) | 0.5 | presente |
| C17 | (3520, 288) | (146.7, 36, 0) | 0.5 | presente |
| C18 | (3840, 608) | (160, 22.67, 0) | 0.5 | presente |
| C19 | (4096, 128) | (170.7, 42.67, 0) | 0.5 | presente |
| C20 | (4480, 288) | (186.7, 36, 0) | 0.5 | presente |

### Secretos, postes y meta

| id | qué | AABB 2D px | centro 3D m | tamaño 3D m | estado |
|---|---|---|---|---|---|
| K00 | poste secreto → pichincha | (2368, 568, 36, 72) | (99.42, 22.83, 0) | (1.5, 3, 2.667) | presente |
| K01 | poste | (3552, 504, 36, 72) | (148.8, 25.5, 0) | (1.5, 3, 2.667) | presente |
| G00 | meta cacao | (4608, 328, 48, 56) | (193, 33.17, 0) | (2, 2.333, 2.667) | presente |
| F00 | caída secreta → jardin | (368, 992, 160, 192) | (18.67, 2.667, 0) | (6.667, 8, 2.667) | presente |

Postes visuales z = 0.45 m. Meta visual z = 0.7 m. La caída usa el mismo AABB 3D que el 2D, material musgo `#657047`.

Spawn 2D (96, 768) → pies 3D (4.5417, 14.25, 0), sobre P00.

## Faltantes

Geometría del nivel: **0 faltantes**. Los 25 volúmenes, 7 peligros, 21 pickups, 2 postes, 1 meta y 1 caída están en `pilot_ruinas.tscn` / `pilot_ruinas.gd`.

Lo que el 2D simula y este greybox no cablea (a propósito: no se tocó el feel ni la colisión de Maya):

| pieza | en 3D | falta |
|---|---|---|
| pinchos H00–H03 | dientes visibles, sin colisión (en 2D tampoco son `solids`) | el overlap que hace `kill` |
| láseres H04–H06 | haz que parpadea con el duty 0.42 | el daño al cruzarlos |
| monedas C00–C20 | esferas | recogerlas |
| poste K00 | volumen, color cacao | activar y warpear a `pichincha-1` |
| poste K01 | volumen | activar el checkpoint |
| caída F00 | volumen musgo entre P01 y P02 | warpear a `jardin-1` |
| meta G00 | bloque cacao | marcar la meta tomada |
| caja P09 | sólido estático | romperse al pound (Maya no tiene pound) |
| one-way P08 P14 P19 | colisión apagada si los pies están bajo `top − 0.06` | drop-through con abajo+salto (sigue dentro de `player_maya.gd`, sin cablear) |
| muros P01 P02 | sólidos de 40 m; Maya puede hacer mantle en el labio con el feel actual | la escalada de Nix (`character id == "nix"` en el 2D). Maya no trepa |
| crumble P13 P16 | se rompe a los 0.46 s de estar parado y vuelve a los 2.7 s | — |
| móviles P10 P17 | `nx = ox + sin(t)·ax`, `ny = oy + cos(t)·ay` | — |

Delta de consulta, sin cambiar el feel: en 3D el mantle de Maya mira todo collider de la máscara, así que un one-way puede entrar en esa consulta. En el 2D los one-way no están en `solids()`.

## Paleta

Piedra `#77766A`, piedra clara `#AAA083`, piedra húmeda `#46514B` (crumble), techo `#5C5B52`, madera `#63503A`, musgo `#657047`, pincho `#A34D36`, miel `#E3C58C` (láser y sol), cacao `#D7A43B` / `#C97632`. Cielo `#C0CEC7`, niebla `#A1B3AA` densidad 0.006. Sol elevación 28°, acimut 48°. Sin magenta, sin ojos, cacao no figurativo.
