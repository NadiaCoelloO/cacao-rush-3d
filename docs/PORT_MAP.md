# Port map — `src/game` → 3D (1:1)

**Tip pin:** `5fd450312c8e6ad0a214f35b68fd81ec2857fec3`  
**Runtime:** Godot 4 only · Pilot display **Cuyabeno** (id `selva`)  
**Feel deltas:** [PORT_DELTA_OLEADA3_2026-09-25.md](PORT_DELTA_OLEADA3_2026-09-25.md) (mantle 0.28s · proneClearsLip · Maya cream/tan crouch greybox tint → ported in PR#4 · high-poly HOLD)

| 2D module | 3D responsibility |
|---|---|
| `sim.ts` | Verbatim feel (coyote 0.1, buffer 0.12, cut 0.48; mantleT 0.28 / proneClearsLip in `player_maya.gd`) |
| `types.ts` | Same ids / Actions |
| `characters.ts` | maya, teko, luma, rok, nix — distinct |
| `levels.ts` | World `selva` layouts → Cuyabeno presentation |
| `save.ts` | Fase 2: share vs `-3d` |
| `assets.ts` | Replace with glTF (greybox: T-020 crouch/crawl cream/tan = runtime albedo override in `player_maya.gd`) |
| `render.ts` | Godot camera/lights (2D flicker T-021 mostly canvas) |
| `input.ts` | Same Actions |
| `stories.ts` | Titles via Identidad (Cuyabeno) |

Two heroes same feel → return ticket.
