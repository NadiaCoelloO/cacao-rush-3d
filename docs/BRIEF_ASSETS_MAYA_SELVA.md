# Brief Assets 3D — lote 1

**Status:** SENT · GO 3D · engine **Godot 4** · display **Cuyabeno**  
**2D tip:** `sand-vivid-dawn-sail` @ `e7fd5c28356fde01a8261a77b8bc6a55b3f513a3`

## Deliver to

- `assets/greybox/heroes/hero_grey.glb`
- `assets/greybox/worlds/selva/chunk_selva_floor.glb`
- `assets/scripts/bpy/` · `assets/budgets/`

## 1) hero_grey — Maya

≤25k / LOD 25k·12k·5k / grey · ~1.8–2.0 m · 1u=1m · Y-up  
Refs: `src/game/characters.ts`; `/game/sprites/maya/idle-*.png` …

## 2) chunk_selva_floor — Cuyabeno (id `selva`)

≤80k / atlas 2K / 3 LODs · ~16–20 m  
Hojarasca + raíces cacao; Ecuador humid; **no** Asia bamboo  
**Do not** label UI/docs «Selva Dulce» or Yasuní — display **Cuyabeno**  
Refs: `/game/maps/jungle-sky.jpg`, `jungle-tile.jpg`

ASSET handoff when BUDGET_TRIS passes.

## Assets note — Maya crouch/crawl palette (T-020, 2026-09-25)

2D PR#12 recolored Maya `crouch-1..6` / `crawl-1..6` from olive → **cream/tan sampled from idle**. Poses/alpha unchanged; no hitbox/timing change.

**3D:** when materials leave greybox, crouch/crawl must match idle cream/tan (not olive). High-poly HOLD until Nadia go 3D. See [PORT_DELTA_OLEADA3_2026-09-25.md](PORT_DELTA_OLEADA3_2026-09-25.md).
