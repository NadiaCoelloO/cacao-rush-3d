# Lote 1 greybox — measured 2026-09-21 (Blender 5.2.1 LTS)

Display biome: **Cuyabeno**. Structural paths stay `worlds/selva/`.

| Asset | Path | LOD0 / cap | LOD1 / cap | LOD2 / cap | Status |
|-------|------|------------|------------|------------|--------|
| hero_grey | assets/greybox/heroes/hero_grey.glb | 896 / 25000 | 358 / 12000 | 106 / 5000 | PASS |
| chunk_selva_floor | assets/greybox/worlds/selva/chunk_selva_floor.glb | 380 / 80000 | 152 | 56 | PASS |
| totem_warp_cuyabeno | runtime/models/totem_warp_cuyabeno.glb | 858 / 2000 | 360 | — | PASS |

Maps: unlit/simple PBR greybox (no final palette). Atlas 2K later for selva biome.
Scale: 1u=1m, glTF 2.0 Y-up (Godot 4). Maya height ~1.7–1.9m. Walkable ~18m.
Scripts: assets/scripts/bpy/hero_maya_grey.py, chunk_selva_floor.py, totem_warp_cuyabeno.py
CIN-001: warp post + lianas + cacao oro crown; beam oro|azul = VFX only (`VFX_WarpBeam_Spawn`).
Identity: greybox OK — notify Identidad before leaving grey.
