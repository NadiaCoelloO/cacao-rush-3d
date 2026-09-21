# Port map — `src/game` → 3D (1:1)

**Tip pin:** `f278dd9730cb335590d50287303907e57f8f3461`  
**Runtime:** Godot 4 only · Pilot display **Cuyabeno** (id `selva`)

| 2D module | 3D responsibility |
|---|---|
| `sim.ts` | Verbatim feel (coyote 0.1, buffer 0.12, cut 0.48) |
| `types.ts` | Same ids / Actions |
| `characters.ts` | maya, teko, luma, rok, nix — distinct |
| `levels.ts` | World `selva` layouts → Cuyabeno presentation |
| `save.ts` | Fase 2: share vs `-3d` |
| `assets.ts` | Replace with glTF |
| `render.ts` | Godot camera/lights |
| `input.ts` | Same Actions |
| `stories.ts` | Titles via Identidad (Cuyabeno) |

Two heroes same feel → return ticket.
