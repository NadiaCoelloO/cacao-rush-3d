# Port delta — oleada 3+4 (2026-09-25 Guayaquil)

**2D truth (READ ONLY):** `NadiaCoelloO/sand-vivid-dawn-sail`  
**Tip pin:** `5fd450312c8e6ad0a214f35b68fd81ec2857fec3` (post T-014; supersedes `e7fd5c28`)  
**Status:** preproducción · High-poly HOLD · PR#3/#4 open (no merge without Nadia playtest OK)  
**Source notes:** ChatGPT refs `06-pista-2d/SYNC_T-014_*` … `SYNC_T-021_*` · oleada-4 Fable pack

Until Nadia’s **go 3D**, record 1:1 port debt here. Do not “improve” timings.

## Cadence 17:00 — what changed since `0c4116ce` (15:00)

| Area | Status |
|---|---|
| PR#4 oleada 4 (Fable) | **Done on branch** `cursor/maya-feel-parity-d54e` @ `7f718ce7` — T-019 mantle + T-018 `proneClearsLip` in `player_maya.gd`; headless `maya_feel_check.gd` **41/41**. Draft. **Do not merge** until Nadia playtest. |
| PR#3 platforms wire | Still open @ `0b35977e` — playtest hold. Untouched this cadence. |
| 2D tip after `e7fd5c28` | T-017 kakaw rename · T-016 water biomes · T-015 Ecuador toponyms · T-014 Nix outfit → tip `5fd45031` |
| High-poly | HOLD |

## Merged 2D PRs (feel / palette) — oleada 3

| Ticket | 2D PR | Merge SHA | Topic | 3D action |
|---|---|---|---|---|
| T-020 | [#12](https://github.com/NadiaCoelloO/sand-vivid-dawn-sail/pull/12) | `fb4f333a9370dca2fd360f04a3292689b157503e` | Maya crouch/crawl cream/tan (recolor only) | Assets note — materials match idle cream/tan, not olive. Greybox HOLD (no crouch mesh). |
| T-019 | [#13](https://github.com/NadiaCoelloO/sand-vivid-dawn-sail/pull/13) | `bfb78275fe65dce792e23896536731e2ff984262` | Mantle every hero from ledge tip | **Ported on PR#4** (`MANTLE_T = 0.28`). Not on `main` until merge. |
| T-018 | [#14](https://github.com/NadiaCoelloO/sand-vivid-dawn-sail/pull/14) | `cccb37f1f896dc928ecd335eeed90da22d3027fc` | `proneClearsLip` in `updateCrouch` | **Ported on PR#4**. Not on `main` until merge. |
| T-021 | [#15](https://github.com/NadiaCoelloO/sand-vivid-dawn-sail/pull/15) | `e7fd5c28356fde01a8261a77b8bc6a55b3f513a3` | Sprite flicker | 2D-canvas. 3D n/a unless presentation flicker appears. |

## Merged 2D PRs after oleada 3 tip — pin `5fd45031`

| Ticket | 2D PR | Merge SHA | Topic | 3D action |
|---|---|---|---|---|
| T-017 | [#8](https://github.com/NadiaCoelloO/sand-vivid-dawn-sail/pull/8) | `b8f3ca97e9d99af6457c89a4e1a5b13f41c2e938` | Residual `shuriken` → `kakaw` ids | Align any residual 3D copy/ids when heroes/powers land. No feel change. |
| T-016 | [#9](https://github.com/NadiaCoelloO/sand-vivid-dawn-sail/pull/9) | `b234686ffc148f19feedbc4ba03bcf36341e9f78` | Lava→water out-of-biome | Feel/hazard port later: water kill AABB 1:1 (Cayambe/Amazonía/Cascada). Volcano lava unchanged. Pilot Cuyabeno unaffected for now. |
| T-015 | [#10](https://github.com/NadiaCoelloO/sand-vivid-dawn-sail/pull/10) | `835b58b64c87db91e5eee11b7d4272ec5f008e06` | Official Ecuador toponyms | Display already **Cuyabeno** for `selva`. World ids unchanged. Keep Identidad table. |
| T-014 | [#11](https://github.com/NadiaCoelloO/sand-vivid-dawn-sail/pull/11) | `5fd450312c8e6ad0a214f35b68fd81ec2857fec3` | Nix cape purple + dark coat/body/boots | Assets note when Nix leaves grey: cape purple; coat/body/boots black/dark-gray; hair untouched. No gameplay ticket. |

## Constants (copy 1:1 — live on PR#4, not `main`)

- `MANTLE_T = 0.28` (seconds)
- `PH_CROUCH = 24` · `PH_PRONE = 14` (2D px; 24 px/m → 1.0 m / 0.583 m)
- Lip probe: `dir * 8` (2D px) inside crouch update — port geometry, do not retune

## Out of scope this cadence

- No high-poly assets
- No merge of PR#3 / PR#4 without Nadia/Coordinador OK
- No writes to `sand-vivid-dawn-sail`
- No new Godot gameplay on `main` (feel stays on PR#4 draft)

## Related open work (do not merge here)

- PR#3 `feat/wire-selva-platforms` @ `0b35977e` — wire solid+oneway into pilot
- PR#4 `cursor/maya-feel-parity-d54e` @ `7f718ce7` (draft) — Maya feel 1:1 + oleada 4 mantle/prone; playtest then merge
