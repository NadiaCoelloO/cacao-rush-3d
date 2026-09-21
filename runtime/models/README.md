# runtime/models/

Greybox glTF for the Godot project (`res://models/`).

## Source of truth

| Model | Repo path | Tris (greybox) |
|---|---|---|
| `hero_grey.glb` | `assets/greybox/heroes/hero_grey.glb` | **896** / 25k |
| `chunk_selva_floor.glb` | `assets/greybox/worlds/selva/chunk_selva_floor.glb` | **380** / 80k |
| `totem_warp_cuyabeno.glb` | `runtime/models/` (CIN-001) | **858** / 2k (LOD1 360) |

World id: `selva` · Display: **Cuyabeno**.

## CIN-001 totem warp — ASSET OK @ d93f777

- SHA256 `e4b5a10c1f9d3e9d338fe37beca7542dcea8ec74d505e2a9b9fb5b790845f1bf`
- Empty `VFX_WarpBeam_Spawn` only (no beam mesh). High-poly HOLD.
- Wired in `scenes/pilot_cuyabeno.tscn` at `WorldRoot/TotemWarpAnchor` **(7.5, 0, 0)** m near CSG platform.
- Budget: `assets/budgets/ASSET_totem_warp_cuyabeno.md` · Script: `assets/scripts/bpy/totem_warp_cuyabeno.py`

### Sync binary onto this branch (if missing)

Binary lives on `main` @ `d93f777`. Copy into the feature branch before playtest with live glTF:

```bash
git fetch origin main
git checkout origin/main -- runtime/models/totem_warp_cuyabeno.glb
cp assets/greybox/heroes/hero_grey.glb runtime/models/
cp assets/greybox/worlds/selva/chunk_selva_floor.glb runtime/models/
sha256sum runtime/models/totem_warp_cuyabeno.glb
# expect e4b5a10c1f9d3e9d338fe37beca7542dcea8ec74d505e2a9b9fb5b790845f1bf
git add runtime/models/*.glb && git commit -m "feat(fase2): sync greybox GLBs into runtime/models" && git push
```

Until then, pilot uses **CSG placeholders** (totem post + floor boxes); `ResourceLoader.exists` swaps in glTF when present.
