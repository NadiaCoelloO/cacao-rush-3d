# Brief Assets 3D — lote 1

**Status:** SENT 2026-09-21 · GO 3D  
**Repo:** this repo — paths below  
**2D truth:** `sand-vivid-dawn-sail` @ `f278dd9730cb335590d50287303907e57f8f3461` (READ ONLY)

## Deliver to

- `assets/greybox/heroes/hero_grey.glb`
- `assets/greybox/worlds/selva/chunk_selva_floor.glb`
- `assets/scripts/bpy/`
- `assets/budgets/`

## 1) hero_grey — Maya

- ≤25k / LOD 25k·12k·5k / grey or 1K / 1 unlit
- ~1.8–2.0 m · 1u=1m · Y-up
- Refs: `src/game/characters.ts` (maya); `/game/sprites/maya/idle-*.png`, `run-*`, `jump-*`, `dash-*`

## 2) chunk_selva_floor

- ≤80k / atlas 2K / 3 LODs · ~16–20 m walkable
- Hojarasca + raíces cacao; Ecuador humid; **no** Asia bamboo
- Refs: world `selva`; `/game/maps/jungle-sky.jpg`, `jungle-tile.jpg`

Handoff **ASSET** when BUDGET_TRIS passes. Do not start platform/oneway/crate/backdrop until Astra OK.
