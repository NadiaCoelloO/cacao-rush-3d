# runtime/models/

Greybox glTF for the Godot project (`res://models/`).

## Source of truth (do not duplicate blindly)

| Model | Repo path | Tris (greybox) |
|---|---|---|
| `hero_grey.glb` | `assets/greybox/heroes/hero_grey.glb` | **896** / 25k (LODs 896/358/106) |
| `chunk_selva_floor.glb` | `assets/greybox/worlds/selva/chunk_selva_floor.glb` | **380** / 80k (LODs 380/152/56) |

World id: `selva` · Display: **Cuyabeno** (not Selva Dulce).

## Import into Godot (once per machine)

1. Open Godot 4.2+ / 4.3 → **Import** → select `runtime/` as the project.
2. In the FileSystem dock, create or use `models/`.
3. Drag the two `.glb` files from repo `assets/greybox/...` into `runtime/models/` **or** copy them:
   ```bash
   cp ../assets/greybox/heroes/hero_grey.glb models/
   cp ../assets/greybox/worlds/selva/chunk_selva_floor.glb models/
   ```
4. Let Godot import; scenes `pilot_cuyabeno` / `player_maya` will hide CSG placeholders when `ResourceLoader.exists` succeeds.

Until then, the pilot runs on **CSG placeholders** named to match import intent (`hero_grey` / `chunk_selva_floor`).

No high-poly yet — greybox only.
