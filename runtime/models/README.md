# runtime/models/

Greybox glTF for the Godot project (`res://models/`).

## Source of truth (do not duplicate blindly)

| Model | Repo path | Tris (greybox) |
|---|---|---|
| `hero_grey.glb` | `assets/greybox/heroes/hero_grey.glb` | **896** / 25k (LODs 896/358/106) |
| `chunk_selva_floor.glb` | `assets/greybox/worlds/selva/chunk_selva_floor.glb` | **380** / 80k (LODs 380/152/56) |
| `totem_warp_cuyabeno.glb` | `runtime/models/totem_warp_cuyabeno.glb` (CIN-001) | **858** / 2k (LOD1 360) |

World id: `selva` · Display: **Cuyabeno** (not Selva Dulce).

## CIN-001 totem warp

- **ASSET OK** @ commit `d93f777` — SHA256 `e4b5a10c1f9d3e9d338fe37beca7542dcea8ec74d505e2a9b9fb5b790845f1bf`
- Empty `VFX_WarpBeam_Spawn` only (no beam mesh). High-poly HOLD — greybox only.
- Wired in `scenes/pilot_cuyabeno.tscn` at `WorldRoot/TotemWarpAnchor` (~7.5 m along +X, near CSG platform).
- Budget: `assets/budgets/ASSET_totem_warp_cuyabeno.md` · Script: `assets/scripts/bpy/totem_warp_cuyabeno.py`

## Import into Godot (once per machine)

1. Open Godot 4.2+ / 4.3 → **Import** → select `runtime/` as the project.
2. In the FileSystem dock, create or use `models/`.
3. Ensure these `.glb` files are present under `runtime/models/` (already committed for the Fase 2 slice):
   ```bash
   # From repo root if re-copying from greybox sources:
   cp assets/greybox/heroes/hero_grey.glb runtime/models/
   cp assets/greybox/worlds/selva/chunk_selva_floor.glb runtime/models/
   # totem lives at runtime/models/totem_warp_cuyabeno.glb (CIN-001)
   ```
4. Let Godot import; scenes `pilot_cuyabeno` / `player_maya` hide CSG placeholders when `ResourceLoader.exists` succeeds.

Until then, the pilot runs on **CSG placeholders** named to match import intent (`hero_grey` / `chunk_selva_floor` / totem post).

No high-poly yet — greybox only.
