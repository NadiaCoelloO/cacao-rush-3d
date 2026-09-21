# Lote 1 greybox — measured 2026-09-21 (Blender 5.2.2 LTS)

Display biome: **Cuyabeno** (not Yasuni, not "Selva Dulce"). Structural paths stay `worlds/selva/`.

| Asset | Path | LOD0 / cap | LOD1 / cap | LOD2 / cap | Status |
|-------|------|------------|------------|------------|--------|
| hero_grey | assets/greybox/heroes/hero_grey.glb | 896 / 25000 | 358 / 12000 | 106 / 5000 | PASS |
| chunk_selva_floor | assets/greybox/worlds/selva/chunk_selva_floor.glb | 380 / 80000 | 152 | 56 | PASS |

Maps: unlit mid-grey (no final palette). Atlas 2K later for selva biome.
Scale: 1u=1m, glTF 2.0 Y-up (Godot 4). Maya height ~1.9m. Walkable ~18m.
Scripts: assets/scripts/bpy/hero_maya_grey.py, chunk_selva_floor.py
Identity: greybox OK — notify Identidad before leaving grey.