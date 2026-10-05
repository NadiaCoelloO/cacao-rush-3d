# LOOK-001 — Cuyabeno look in Godot 4 (Forward+)

World id `selva` · display **Cuyabeno**. High-poly HOLD. Timings in `player_maya.gd` are untouched (coyote 0.10 / buffer 0.12 / cut 0.48).

Assets drop lives at `assets/greybox/worlds/selva/LOOK-001/` (GLBs + `LOOK-001_manifest.json` + `SHA256SUMS.txt` + brief + oneway delta). Runtime copies: `runtime/models/selva_look001_LOD{0,1,2}.glb`. Reproducible Blender script: `assets/scripts/bpy/world_selva_look001.py`.

## What the GLB does *not* transfer

The LOD glTFs carry geometry, vertex colours, and simple PBR / unlit / emissive slots (`M_SELVA_OPAQUE`, `M_SELVA_BACKDROP`, `M_BLACKWATER`, `M_WARP_GOLD`, `M_WARP_CYAN`). Fog volumes, lights, cameras, warp-beam VFX, water ripples, SSR, the reflection probe, sky and the film grade stay in Godot — see `runtime/scripts/look001_cuyabeno.gd` and `godot_rebuild_notes` in the manifest.

| Slot | Godot |
|---|---|
| M_SELVA_OPAQUE | imported StandardMaterial3D, vertex colour albedo, roughness 0.78 |
| M_SELVA_BACKDROP | unshaded + vertex colour (fog still applies) |
| M_BLACKWATER | `runtime/shaders/blackwater.gdshader` — #10191A, roughness 0.15, two slow world-XZ ripples, **opaque** |
| M_WARP_GOLD / CYAN | imported emissive; energy toggled active 3.0 / 2.4 vs dim 0.35 / 0.25 |
| Warp beam | `runtime/shaders/warp_beam.gdshader` additive cones at `VFX_WarpBeam_Spawn` |
| Fog | Environment volumetric fog (density 0.0025) + 12 FogVolume ellipsoids |
| Sky | ProceduralSkyMaterial residual blue-grey + warm horizon |
| Grade | Filmic tonemap (AgX is 4.4+), glow on levels 3–5, contrast 1.03 / sat 0.95 |

Renderer stays **Forward+** (project lock). Mobile/Compatibility would drop FogVolume; do not switch the project renderer.

## Oneway (PR#3 / tip `5fd45031`)

Assets baked `SELVA_GP_Oneway_01` at Blender `(1, 0, 1.8)` → Godot ≈ `(1, 1.8, 0)`. That is **wrong** for the pilot slice.

The loader **hides** the baked mesh and instances `chunk_selva_oneway.glb` at `WorldRoot/PlatformOnewayAnchor` **Godot (6, 1, 0)** — selva-1 oneway #0, tile x=6. Collision stays the existing CSG port (`CSGFloor` + `CSGPlatform` at x=6); the 3D oneway is not a true one-way collider (same risk as PR#3).

## LOD

| File | Tris | VisibilityRange |
|---|---|---|
| `selva_look001_LOD0.glb` | 12960 | 0–35 m |
| `selva_look001_LOD1.glb` | 5616 | 30–70 m |
| `selva_look001_LOD2.glb` | 1982 | 65 m+ |

Gameplay `SELVA_GP_*` meshes are identical across LODs; collisions never come from the GLB.

## Stills

Review cameras `Cam_Laguna` / `Cam_Dosel` match the manifest (keep-height FOV 49.43° / 64.65°). Capture (non-headless, real renderer):

```
godot --path runtime res://scenes/pilot_cuyabeno.tscn -- --look001-capture=both --look001-out=/path/to/out
```

Writes `LOOK-001_engine_laguna.png` (totem active + beam) and `LOOK-001_engine_dosel.png` (totem dim, beam off), 1920×1080, no HUD.

## Feel check

Same harness as PR#4: `godot --headless --fixed-fps 60 --path runtime -s res://tests/maya_feel_check.gd` — 54 checks. Do not edit `player_maya.gd` for this ticket.
