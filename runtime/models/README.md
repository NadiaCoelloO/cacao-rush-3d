# runtime/models

Godot 4 imports glTF from here (`res://models/`) for the Fase 2 pilot (world id `selva` · display **Cuyabeno**).

Greybox models below are **real binary glTF** (`.glb`, magic `glTF`) committed with git — no stubs.

| File | Source | Tris (greybox) | Size | SHA256 |
|------|--------|----------------|------|--------|
| `hero_grey.glb` | `assets/greybox/heroes/hero_grey.glb` (T-020 cream/tan, slots `Maya_Body` / `Maya_Hair` / `Maya_Pack`, ASSET OK @ 402121f) | 896 / 25k | 111048 B | `1e299bf47c6924048ceb0cb88c58943af651197c866914ffa7039d1b3cc1c10e` |
| `chunk_selva_floor.glb` | `assets/greybox/worlds/selva/chunk_selva_floor.glb` | 380 / 80k | 49428 B | `444d56329bbb38ab96645816c648888e4161723c115aa684d17ded4af02ef676` |
| `totem_warp_cuyabeno.glb` | CIN-001 (ASSET OK @ d93f777) | 858 / 2000 (LOD1 360) | 103188 B | `e4b5a10c1f9d3e9d338fe37beca7542dcea8ec74d505e2a9b9fb5b790845f1bf` |
| `chunk_selva_platform_solid.glb` | `assets/greybox/worlds/selva/` | 120 / 2000 (LOD1 42) | 17308 B | `ec363297b08a48d0bfb98aca29dde210ea8b6b035fa5a705c382f642d2675044` |
| `chunk_selva_oneway.glb` | `assets/greybox/worlds/selva/` | 60 / 2000 (LOD1 24) | 10136 B | `749e23865518be9153015a6a86e3967031b6d0df5c7bdc4659cf6ea193f2220e` |
| `selva_look001_LOD0.glb` | `assets/greybox/worlds/selva/LOOK-001/` | 12960 / 80k | 1371152 B | `c2bb89d5663a2aaf7655a73480e72b48fa210c02f71d696871763b557dfaff24` |
| `selva_look001_LOD1.glb` | `assets/greybox/worlds/selva/LOOK-001/` | 5616 / 80k | 590596 B | `9adcd3a70764575fb77e4821a78bec32ed316190108bfa427e1ba01fc17c18f8` |
| `selva_look001_LOD2.glb` | `assets/greybox/worlds/selva/LOOK-001/` | 1982 / 80k | 203936 B | `a49d8e9cac430b2d64ea2b8ea3e085d8c71ab81c81d7100b498e90cd40371b1c` |

## CIN-001 totem warp

- Empty `VFX_WarpBeam_Spawn` only (no beam mesh). High-poly HOLD.
- Loaded as PackedScene by `scripts/pilot_cuyabeno.gd` under `WorldRoot/TotemWarpAnchor` **(7.5, 0, 0)** m in `scenes/pilot_cuyabeno.tscn`; the CSG `TotemPlaceholder` is hidden once it loads.
- Budget: `assets/budgets/ASSET_totem_warp_cuyabeno.md` · Script: `assets/scripts/bpy/totem_warp_cuyabeno.py`.

## LOOK-001 (Cuyabeno cinematic look)

- Geometry only in the GLB (vertex colours + simple PBR/unlit/emissive). Water ripples, fog, sky, warp beam and film grade are rebuilt in Godot — `docs/LOOK-001_GODOT.md`, `runtime/scripts/look001_cuyabeno.gd`.
- Instanced by `scripts/pilot_cuyabeno.gd` under `WorldRoot` with VisibilityRange (LOD0 0–35 m, LOD1 30–70 m, LOD2 65 m+). When LOOK GLBs load, `chunk_selva_floor.glb` and `totem_warp_cuyabeno.glb` are **not** also instanced (the look chunk already includes the totem).
- Baked `SELVA_GP_Oneway_01` (Assets Blender `(1,0,1.8)`) is hidden; `chunk_selva_oneway.glb` is placed at **Godot (6, 1, 0)** (PR#3 / tip `5fd45031` selva-1 oneway #0).
- `CSGOneway` at that anchor is **4×0.18×2 m with `use_collision=true`** (PR#3 box). Hidden placeholder keeps the collider. 3D oneway is not a true one-way yet.

## Platforms (Pista 3D greybox)

- `chunk_selva_platform_solid` — solid walkable block 3.0×2.0×1.0 m; budget `ASSET_chunk_selva_platform_solid.md`
- `chunk_selva_oneway` — thin slab 4.0×2.0×0.18 m + underside chevron cue (visual only); budget `ASSET_chunk_selva_oneway.md`
- Scripts: `assets/scripts/bpy/chunk_selva_platform_solid.py`, `chunk_selva_oneway.py`
- Sources: `assets/source/*.blend`

## Notes

- Prefer binary `.glb`. MCP text pushes cannot write glTF binaries (they corrupt into text); update these files with **git** only, then verify with `sha256sum runtime/models/*.glb`.
- `ResourceLoader.exists` swaps glTF in for the CSG placeholders at runtime; placeholders remain as a fallback if a file is missing.
