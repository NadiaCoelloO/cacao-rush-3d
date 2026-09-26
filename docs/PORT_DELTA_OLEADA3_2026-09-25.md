# Port delta — oleada 3 (2026-09-25 Guayaquil)

**2D truth (READ ONLY):** `NadiaCoelloO/sand-vivid-dawn-sail`  
**Tip pin:** `e7fd5c28356fde01a8261a77b8bc6a55b3f513a3` (oleada 3 docs) → `5fd450312c8e6ad0a214f35b68fd81ec2857fec3` (oleada 4 port, see status below)  
**Status:** T-019 / T-018 / T-020 (greybox tint) in PR#4 — **merge-ready, draft, awaiting Nadia OK** · High-poly HOLD  
**Source notes:** ChatGPT refs `06-pista-2d/SYNC_T-018_*` … `SYNC_T-021_*` (refreshed ~14:51 Guayaquil)

Until Nadia’s **go 3D**, record 1:1 port debt here. Do not “improve” timings.

## Merged 2D PRs in this tip

| Ticket | 2D PR | Merge SHA | Topic | 3D action |
|---|---|---|---|---|
| T-020 | [#12](https://github.com/NadiaCoelloO/sand-vivid-dawn-sail/pull/12) | `fb4f333a9370dca2fd360f04a3292689b157503e` | Maya crouch/crawl cream/tan (recolor only) | Greybox tint done in PR#4 (runtime albedo override, see below). High-poly crouch materials remain an Assets note. No feel/sim ticket. |
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
- PR#4 `cursor/maya-feel-parity-d54e` (draft) — Maya run/jump/coyote @ tip `8e7ce7ad` (oleada 2) **+ oleada 4 port below**

## Oleada 4 port status — PR#4 @ 2D tip `5fd450312c8e6ad0a214f35b68fd81ec2857fec3` (2026-09-25)

Ported into `runtime/scripts/player_maya.gd`, checked by `runtime/tests/maya_feel_check.gd`
(`godot --headless --fixed-fps 60 --path runtime -s res://tests/maya_feel_check.gd`, 48/48 — the
original 41 feel checks unchanged + 7 T-020 tint checks).
Same tick order as `sim.ts updateGame()`: applyRun → applyJump → applyGravity → resolve →
(`hanging` ? `tickMantle` : `ledgeGrab`) → `updateCrouch` → kill → followCam.
Source read: `sim.ts` snapshot at the tip carried in the oleada-4 refs pack (`MANTLE_T`, `mantleT`,
`proneClearsLip`, `PH_CROUCH`/`PH_PRONE` present; run/jump constants unchanged vs `8e7ce7ad`).
The 2D repo is private, so the SHA could not be re-fetched from GitHub in the port run — re-verify
`sim.ts` @ `5fd45031` against the constants below on the next cadence.

| Ticket | Status | 1:1 in 3D |
|---|---|---|
| T-019 mantle | **ported** | `ledgeSide` (22 px in / 18 px out), `findLedge` (hand = top − 8 px, \|lip − hand\| ≤ 26 px, best < 28 px), `ledgeGrab` (falling, jump held, not rising > 40 px/s; hang x = lip − w + 6 px, head 8 px above lip, `blockedAt` stand check), `tickMantle` smoothstep over `MANTLE_T = 0.28 s` → stand at lip + 2 px, grounded, jumps refilled, coyote. `down` releases the hang (applyRun). Jump from hang = 2D wall kick `−hangDir · runSpeed · 0.95` + `jumpVel`. Solids are read as XY AABBs from the physics colliders (CSG box, StaticBody box/convex/concave). Nix wall-face climb: no Nix in 3D yet — untouched. |
| T-018 proneClearsLip | **ported** | `PH_CROUCH` 24 px / `PH_PRONE` 14 px capsules swapped by `tryHeight` (grow needs headroom), `updateCrouch` (`down && !jumpHeld && (grounded \|\| dragging)`, crawl if \|vx\| > 18 px/s or standing box blocked or `proneClearsLip(sign moveX)` — probe `dir · 8 px`, blocks 24 − 1 px, clears 14 − 1 px), `applyRun` crouchMul 0.55 / 0.42, camera focus follows `p.h/2`. `applyJump` dropT 0.18 s on down + jump (no jump); the one-way pass-through itself stays with the PR#3 wiring. New input `move_down` (S / ↓) = 2D `Actions.down`. |
| T-020 Maya cream/tan | **greybox done** (2026-09-26) | Runtime material override in `player_maya.gd`: while `updateCrouch` reports crouching the `hero_grey` albedo is **RGB 138,99,65** (average opaque outfit of 2D `crouch-1`), while dragging/crawling **RGB 148,110,76** (`crawl-1`); standing restores the untouched greybox materials (glTF `MeshInstance3D` surface overrides, `material` on the CSG fallback; roughness etc. kept via duplicate). Refreshed after `updateCrouch` and on respawn, so the prone-under-rock hold keeps the crawl tan. No crouch mesh / pose — the placeholder is still squashed to the hitbox height. **High-poly HOLD** until Identidad PASA; per-part cream vs hair/pack split stays an Assets note. |
| T-021 flicker | **n/a in 3D** | No sprite sheets / pixel camera in Godot; no shimmer mechanism to copy. Crouch pose is a single held state. Revisit only if a presentation flicker shows in playtest. |

Not ported (not in this ticket, unchanged from oleada 2): wall slide / wall jump (`probeWall`/`wallDir`), dash,
water, poison, crumble, one-way pass-through.

### PR#4 merge-ready note (T-020 greybox, 2026-09-26)

- T-019 mantle + T-018 proneClearsLip + T-020 greybox tint wired; `maya_feel_check.gd` 48/48 (Godot 4.2.2 headless).
- Tip pin unchanged: `5fd450312c8e6ad0a214f35b68fd81ec2857fec3`.
- **Ready for Nadia OK to merge — stays draft, not merged.** No writes to `sand-vivid-dawn-sail`.
- Deferred: high-poly crouch/crawl materials & pose (Identidad HOLD), PR#3 platform polish, water / dash / wall.
