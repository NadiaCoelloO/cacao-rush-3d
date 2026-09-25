# Brief Assets 3D — lote 1

**Status:** SENT · GO 3D · engine **Godot 4** · display **Cuyabeno**  
**2D tip:** `sand-vivid-dawn-sail` @ `5fd450312c8e6ad0a214f35b68fd81ec2857fec3`

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

## Assets note — Nix outfit (T-014, 2026-09-25)

2D PR#11: cape stays **purple**; coat / body / boots → **black / dark-gray**; hair (T-013) untouched. Sprite-only; no hitbox/timing change.

**3D:** when Nix leaves greybox, match that palette. High-poly HOLD. No Nix mesh in lote 1 yet.
