# LOOK-001 / WORLD-001 — oneway delta (solo lectura)

Fecha: 2026-10-05 · tip 2D `5fd45031` · pilot PR#4 `f9a879d` · platforms PR#3 `0b35977e` · Assets LOOK-001 out.

## 2D tip (levels.ts selva-1, `T = 32`)
Cuatro oneways en el nivel completo:
| # | plat() px | tiles (x/T, y/T, w/T) | h px |
|---|-----------|------------------------|------|
| 0 | (192, 544, 96, 16) | (6, 17, 3) | 16 |
| 1 | (1536, 512, 96, 16) | (48, 16, 3) | 16 |
| 2 | (2112, 352, 96, 16) | (66, 11, 3) | 16 |
| 3 | (3392, 448, 160, 18) | (106, 14, 5) | 18 |

El piloto 3D solo cubre el tramo inicial: el oneway canónico del slice es el **#0** (x ≈ 6 tiles).

## Pilot @ f9a879d (rama PR#4 / LOOK base)
`runtime/scenes/pilot_cuyabeno.tscn`: **no hay nodo oneway**. Solo `CSGFloor` (24×0.5×8) y `CSGPlatform` en Godot **(6, 0.5, 0)** size 3×1×3. Totem @ x=7.5.

## Pilot @ 0b35977e (PR#3 plataformas)
Sí cablea oneway:
- `PlatformSolidAnchor` @ Godot **(3.5, 0, 0)** — solid 3×1×2
- `PlatformOnewayAnchor` @ Godot **(6, 1, 0)** — thin 4×0.18×2 (hacia el totem)
Alineado con el oneway #0 del tip en X (tile 6 → x=6).

## Assets LOOK-001
Módulo `SELVA_GP_Oneway_01` (4×2×0.18 + cue) en Blender **(1.0, 0, 1.8)** → Godot ≈ **(1.0, 1.8, 0)** (axis Blender→Godot: `(x,z,-y)`).
Manifest ya marca REVIEW PLACEMENT.

## Diferencia (para cablear Godot)
1. **PR#4 no tiene oneway**; LOOK-001 añadió uno decorativo/gameplay en X=1 — **no coincide** con tip ni con PR#3.
2. Posición correcta del oneway del slice piloto: **Godot (6, 1, 0)** como PR#3 (o equivalente al tip #0), no (1, 1.8, 0).
3. Al cablear LOOK: mover/reemplazar el oneway de Assets a la ancla PR#3; no inventar rutas nuevas; colisiones siguen siendo las del port (oneway 3D aún no es one-way verdadero — riesgo ya documentado en PR#3).
4. Oneways #1–#3 del tip quedan fuera del piloto actual (nivel largo); no meterlos en LOOK-001.

## Acción pendiente
Cuando haya cuota / rama: al integrar `selva_look001_LOD*.glb`, reubicar `SELVA_GP_Oneway_01` a (6,1,0) o excluirlo del GLB y usar el ancla de PR#3. Código/assets: sin push a main sin OK Nadia; este doc sí puede vivir en main.
