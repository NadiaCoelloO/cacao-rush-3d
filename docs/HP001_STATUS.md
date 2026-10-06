# HP-001 Cuyabeno · estado (2026-10-06 13:10 Guayaquil)

Nota de estado, solo docs. Nada de assets, GLB ni .blend en main.

## E1 · tótem warp + kit de troncos
- Blender: PASA (tótem + troncos v3).
- Godot: PR#6 (draft, base = rama de PR#5) @ `fb5e85db`. Identidad dio **ASSET OK** en el gate final de Godot.
  - Haz del tótem al ras de la copa con fade de 0.35 m; agujeros de LOD de troncos corregidos (201/201).
  - Tris: gameplay 199k, laguna 153k, dosel 265k (sobre la meta de 250k, bajo el techo de 350k), vainas 222k.
  - VRAM UHD analítica ≈131 MB (`docs/hp001/HP001_E1_VRAM_UHD.md` en PR#6).
- Merge: decisión de Nadia. Nadie mergea PR#3/#4/#5/#6 sin su OK.

## E2 · dosel + muelle + suelo
- Brief: `docs/BRIEF_HP001_E2_ASSETS.md` (meta ≤45k tris visibles en la vista dosel por lo que ya suma E1).
- En curso en Assets 3D (Blender); salidas en el box, todavía sin gate de Identidad.

## Fuera de esto
- High-poly en general sigue en HOLD salvo HP-001 aprobado.
- Arcade 2D (`sand-vivid-dawn-sail`) solo lectura, tip `5fd45031` sin cambios.
