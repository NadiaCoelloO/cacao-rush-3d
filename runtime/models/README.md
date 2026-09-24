# runtime/models/

Greybox glTF for the Godot project (`res://models/`).

## Source of truth

| Model | Repo path | Tris (greybox) | On `feat/fase2-godot-slice` |
|---|---|---|---|
| `hero_grey.glb` | `assets/greybox/heroes/hero_grey.glb` | **896** / 25k | **STUB** (~56 B) — need real binary 111064 B, SHA256 `839287ed18e56c90a334b3a8707b757f9f44dd6d944f78c83e67665890fb11f1` |
| `chunk_selva_floor.glb` | `assets/greybox/worlds/selva/chunk_selva_floor.glb` | **380** / 80k | **STUB** (~26 B) — need real binary 49428 B, SHA256 `444d56329bbb38ab96645816c648888e4161723c115aa684d17ded4af02ef676` |
| `totem_warp_cuyabeno.glb` | `runtime/models/` (CIN-001) | **858** / 2k (LOD1 360) | **OK** (~103188 B) |

World id: `selva` · Display: **Cuyabeno**.

## CIN-001 totem warp — ASSET OK @ d93f777

- SHA256 `e4b5a10c1f9d3e9d338fe37beca7542dcea8ec74d505e2a9b9fb5b790845f1bf`
- Empty `VFX_WarpBeam_Spawn` only (no beam mesh). High-poly HOLD.
- Wired in `scenes/pilot_cuyabeno.tscn` at `WorldRoot/TotemWarpAnchor` **(7.5, 0, 0)** m near CSG platform.
- Budget: `assets/budgets/ASSET_totem_warp_cuyabeno.md` · Script: `assets/scripts/bpy/totem_warp_cuyabeno.py`

### Sync hero + floor binaries (git only)

MCP text pushes cannot write glTF binaries (they land as path/placeholder stubs). Copy from assets with **git** (local clone or Assets 3D):

```bash
git checkout feat/fase2-godot-slice
cp assets/greybox/heroes/hero_grey.glb runtime/models/
cp assets/greybox/worlds/selva/chunk_selva_floor.glb runtime/models/
sha256sum runtime/models/hero_grey.glb runtime/models/chunk_selva_floor.glb
# expect 839287ed… and 444d5632…
git add runtime/models/hero_grey.glb runtime/models/chunk_selva_floor.glb
git commit -m "fix(fase2): restore real hero_grey + chunk_selva_floor GLBs"
git push origin feat/fase2-godot-slice
```

Until then, pilot uses **CSG placeholders**; `ResourceLoader.exists` swaps in glTF when the files are real PackedScenes.
