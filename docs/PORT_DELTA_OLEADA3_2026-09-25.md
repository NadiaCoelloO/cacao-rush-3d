# Port delta — oleada 3 (2026-09-25 Guayaquil)

**2D truth (READ ONLY):** `NadiaCoelloO/sand-vivid-dawn-sail`  
**Tip pin:** `e7fd5c28356fde01a8261a77b8bc6a55b3f513a3`  
**Status:** preproducción only · High-poly HOLD · no gameplay 3D ticket yet  
**Source notes:** ChatGPT refs `06-pista-2d/SYNC_T-018_*` … `SYNC_T-021_*` (refreshed ~14:51 Guayaquil)

Until Nadia’s **go 3D**, record 1:1 port debt here. Do not “improve” timings.

## Merged 2D PRs in this tip

| Ticket | 2D PR | Merge SHA | Topic | 3D action |
|---|---|---|---|---|
| T-020 | [#12](https://github.com/NadiaCoelloO/sand-vivid-dawn-sail/pull/12) | `fb4f333a9370dca2fd360f04a3292689b157503e` | Maya crouch/crawl cream/tan (recolor only) | Assets note only — materials match idle cream/tan, not olive. No feel/sim ticket. |
| T-019 | [#13](https://github.com/NadiaCoelloO/sand-vivid-dawn-sail/pull/13) | `bfb78275fe65dce792e23896536731e2ff984262` | Mantle every hero from ledge tip | Feel port: `mantleT` + `MANTLE_T = 0.28` s hang→pull-up→stand. Nix tip = mantle (not climb); wall face ≠ tip stays climb. Jump/run speeds unchanged. |
| T-018 | [#14](https://github.com/NadiaCoelloO/sand-vivid-dawn-sail/pull/14) | `cccb37f1f896dc928ecd335eeed90da22d3027fc` | `proneClearsLip` in `updateCrouch` | Feel port: if `moveX` lip blocks `PH_CROUCH=24` but clears `PH_PRONE=14`, force crawl. Standing pickup/jump/run/climb unchanged. |
| T-021 | [#15](https://github.com/NadiaCoelloO/sand-vivid-dawn-sail/pull/15) | `e7fd5c28356fde01a8261a77b8bc6a55b3f513a3` | Sprite flicker (`coherentFrames` / `holdPixel` / sync decode) | Mostly 2D-canvas. 3D: only if an equivalent presentation flicker appears — copy behavior, do not invent. |

## Constants to copy 1:1 (when feel port runs)

- `MANTLE_T = 0.28` (seconds)
- `PH_CROUCH = 24` · `PH_PRONE = 14` (2D px; scale with existing 24 px/m → 1.0 m / 0.583 m)
- Lip probe: `dir * 8` (2D px) inside crouch update — port geometry, do not retune

## Out of scope this cadence

- No high-poly assets
- No merge of open feel/platform PRs without Nadia/Coordinador OK
- No writes to `sand-vivid-dawn-sail`
- Godot slice on main already has greybox floor / platforms / totem; mantle & prone wait for feel port after playtest OK

## Related open work (do not merge here)

- PR#3 `feat/wire-selva-platforms` — wire solid+oneway into pilot
- PR#4 `cursor/maya-feel-parity-d54e` (draft) — Maya run/jump/coyote @ tip `8e7ce7ad` (oleada 2); explicitly out-of-scope there: ledge/crouch → covered by T-019 / T-018 above
