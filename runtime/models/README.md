# runtime/models

Godot 4 imports glTF from here (`res://models/`) for the Fase 2 pilot (world id `selva` · display **Cuyabeno**).

All three greybox models below are **real binary glTF** (`.glb`, magic `glTF`) committed with git — no stubs.

| File | Source | Tris (greybox) | Size | SHA256 |
|------|--------|----------------|------|--------|
| `hero_grey.glb` | `assets/greybox/heroes/hero_grey.glb` | 896 / 25k | 111064 B | `839287ed18e56c90a334b3a8707b757f9f44dd6d944f78c83e67665890fb11f1` |
| `chunk_selva_floor.glb` | `assets/greybox/worlds/selva/chunk_selva_floor.glb` | 380 / 80k | 49428 B | `444d56329bbb38ab96645816c648888e4161723c115aa684d17ded4af02ef676` |
| `totem_warp_cuyabeno.glb` | CIN-001 (ASSET OK @ d93f777) | 858 / 2000 (LOD1 360) | 103188 B | `e4b5a10c1f9d3e9d338fe37beca7542dcea8ec74d505e2a9b9fb5b790845f1bf` |

## CIN-001 totem warp

- Empty `VFX_WarpBeam_Spawn` only (no beam mesh). High-poly HOLD.
- Loaded as PackedScene by `scripts/pilot_cuyabeno.gd` under `WorldRoot/TotemWarpAnchor` **(7.5, 0, 0)** m in `scenes/pilot_cuyabeno.tscn`; the CSG `TotemPlaceholder` is hidden once it loads.
- Budget: `assets/budgets/ASSET_totem_warp_cuyabeno.md` · Script: `assets/scripts/bpy/totem_warp_cuyabeno.py`.

## Notes

- Prefer binary `.glb`. MCP text pushes cannot write glTF binaries (they corrupt into text); update these files with **git** only, then verify with `sha256sum runtime/models/*.glb`.
- `ResourceLoader.exists` swaps glTF in for the CSG placeholders at runtime; placeholders remain as a fallback if a file is missing.
