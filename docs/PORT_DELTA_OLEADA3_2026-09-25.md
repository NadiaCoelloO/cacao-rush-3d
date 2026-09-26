# Port delta — oleada 3+4 (2026-09-25 Guayaquil)

**2D truth (READ ONLY):** `NadiaCoelloO/sand-vivid-dawn-sail`  
**Tip pin:** `5fd450312c8e6ad0a214f35b68fd81ec2857fec3` (post T-014; supersedes `e7fd5c28`)  
**Status:** preproducción · High-poly HOLD · PR#3 open · PR#4 T-019 / T-018 / T-020 (greybox tint) — **merge-ready, draft, awaiting Nadia OK** (no merge without Nadia playtest OK)  
**Source notes:** ChatGPT refs `06-pista-2d/SYNC_T-014_*` … `SYNC_T-021_*` · oleada-4 Fable pack · `fable-t020-refs` pack

Until Nadia’s **go 3D**, record 1:1 port debt here. Do not “improve” timings.

## Cadence 17:00 — what changed since `0c4116ce` (15:00)

| Area | Status |
|---|---|
| PR#4 oleada 4 (Fable) | **Done on branch** `cursor/maya-feel-parity-d54e` — T-019 mantle + T-018 `proneClearsLip` in `player_maya.gd` (@ `7f718ce7`, 41/41) **+ T-020 greybox tint** on Assets `hero_grey.glb` @ `402121f` (2026-09-26, 53/53 — see "PR#4 merge-ready note" below). Draft. **Do not merge** until Nadia playtest. |
| PR#3 platforms wire | Still open @ `0b35977e` — playtest hold. Untouched this cadence. |
| 2D tip after `e7fd5c28` | T-017 kakaw rename · T-016 water biomes · T-015 Ecuador toponyms · T-014 Nix outfit → tip `5fd45031` |
| High-poly | HOLD |

## Merged 2D PRs (feel / palette) — oleada 3

| Ticket | 2D PR | Merge SHA | Topic | 3D action |
|---|---|---|---|---|
| T-020 | [#12](https://github.com/NadiaCoelloO/sand-vivid-dawn-sail/pull/12) | `fb4f333a9370dca2fd360f04a3292689b157503e` | Maya crouch/crawl cream/tan (recolor only) | **Greybox tint done on PR#4** (runtime override on Assets `hero_grey.glb` @ 402121f, see status below). Not on `main` until merge. High-poly crouch materials HOLD. No feel/sim ticket. |
| T-019 | [#13](https://github.com/NadiaCoelloO/sand-vivid-dawn-sail/pull/13) | `bfb78275fe65dce792e23896536731e2ff984262` | Mantle every hero from ledge tip | **Ported on PR#4**: `mantleT` + `MANTLE_T = 0.28` s hang→pull-up→stand. Nix tip = mantle (not climb); wall face ≠ tip stays climb. Jump/run speeds unchanged. Not on `main` until merge. |
| T-018 | [#14](https://github.com/NadiaCoelloO/sand-vivid-dawn-sail/pull/14) | `cccb37f1f896dc928ecd335eeed90da22d3027fc` | `proneClearsLip` in `updateCrouch` | **Ported on PR#4**: if `moveX` lip blocks `PH_CROUCH=24` but clears `PH_PRONE=14`, force crawl. Standing pickup/jump/run/climb unchanged. Not on `main` until merge. |
| T-021 | [#15](https://github.com/NadiaCoelloO/sand-vivid-dawn-sail/pull/15) | `e7fd5c28356fde01a8261a77b8bc6a55b3f513a3` | Sprite flicker (`coherentFrames` / `holdPixel` / sync decode) | Mostly 2D-canvas. 3D: only if an equivalent presentation flicker appears — copy behavior, do not invent. |

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
- PR#4 `cursor/maya-feel-parity-d54e` (draft) — Maya feel 1:1 + oleada 4 mantle/prone + T-020 greybox tint on Assets `hero_grey.glb` @ `402121f`; merged up to `main` @ `14b08cb5`; **status below**; playtest then merge

## Oleada 4 port status — PR#4 @ 2D tip `5fd450312c8e6ad0a214f35b68fd81ec2857fec3` (2026-09-25)

Ported into `runtime/scripts/player_maya.gd`, checked by `runtime/tests/maya_feel_check.gd`
(`godot --headless --fixed-fps 60 --path runtime -s res://tests/maya_feel_check.gd`, 53/53 — the
original 41 feel checks unchanged + 8 T-020 tint checks + 2 slot-selection checks + 2 Identidad hue-band guards).
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
| T-020 Maya cream/tan | **greybox done** (2026-09-26) | Runtime material override in `player_maya.gd`: while `updateCrouch` reports crouching the `hero_grey` outfit is **RGB 138,99,65** (average opaque outfit of 2D `crouch-1`), while dragging/crawling **RGB 148,110,76** (`crawl-1`); standing restores the untouched materials. Targets the `Maya_Body` slot of the Assets `hero_grey.glb` (@ 402121f: idle cream body 224,184,136 / brown hair / tan pack, unlit Emission) on all 3 LODs — hair / pack untouched, like the 2D recolor; a visual without named slots (CSG fallback) is tinted whole. Tint goes through `emission` on the unlit export, `albedo_color` otherwise (glTF `MeshInstance3D` surface overrides, `material` on CSG; roughness etc. kept via duplicate). Refreshed after `updateCrouch` and on respawn, so the prone-under-rock hold keeps the crawl tan. No crouch mesh / pose — the placeholder is still squashed to the hitbox height. **Identidad PASA** for the greybox tint (2026-09-26): hue ~28° band — crouch 27.9°, crawl 28.3° — never olive (≈60–90°); guarded in the headless check (`TINT_HUE_DEG` 28 ± 4). **High-poly still HOLD.** |
| T-021 flicker | **n/a in 3D** | No sprite sheets / pixel camera in Godot; no shimmer mechanism to copy. Crouch pose is a single held state. Revisit only if a presentation flicker shows in playtest. |

Not ported (not in this ticket, unchanged from oleada 2): wall slide / wall jump (`probeWall`/`wallDir`), dash,
water, poison, crumble, one-way pass-through.

### PR#4 merge-ready note (T-020 greybox, 2026-09-26)

- T-019 mantle + T-018 proneClearsLip + T-020 greybox tint wired; `maya_feel_check.gd` 53/53 (Godot 4.2.2 headless).
- **Identidad PASA** (greybox T-020 cream/tan, hue ~28° band, no olive) · **ASSET OK** (Orquestador, 2026-09-26) for `hero_grey.glb` @ 402121f on this branch. High-poly still HOLD.
- Assets `hero_grey.glb` @ 402121f (cream/tan idle base, named slots) is the tint target; `runtime/models/README.md` hash row updated. Slot rule (`TINT_OUTFIT_SLOTS = ["Maya_Body"]`): named slots present → only outfit slots tinted, `Maya_Hair` untouched, `Maya_Pack` treated as accessory (add it to the list if Identidad classes the satchel as outfit); no named slots yet → every `BaseMaterial3D` on the hero instance is tinted. Emissive or albedo materials both work. Further Assets pushes stay compatible as long as those slot names hold.
- Tip pin unchanged: `5fd450312c8e6ad0a214f35b68fd81ec2857fec3`.
- **Ready for Nadia OK to merge — stays draft, not merged.** No writes to `sand-vivid-dawn-sail`.
- Deferred: high-poly crouch/crawl materials & pose (Identidad HOLD), PR#3 platform polish, water / dash / wall.
- Observation for Assets (not changed here): Blender `default_value` colours are linear, so the glb's baked idle cream imports as sRGB ≈ 241,221,193 rather than 224,184,136. The runtime tint is sRGB-exact (Godot `Color`), so crouch/crawl match the 2D samples regardless.
