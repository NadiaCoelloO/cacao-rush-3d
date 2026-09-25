# Port contract (summary)

**2D tip pin:** `NadiaCoelloO/sand-vivid-dawn-sail` @ `e7fd5c28356fde01a8261a77b8bc6a55b3f513a3`  
**Prior pins:** `8e7ce7ad` (oleada 2) · `f278dd97` (oleada 1) — superseded for new port work.  
**Oleada 3 delta:** [PORT_DELTA_OLEADA3_2026-09-25.md](PORT_DELTA_OLEADA3_2026-09-25.md)

**Engine LOCKED:** Godot 4 (no R3F).

**Pilot display:** **Cuyabeno** (world id `selva`).

```
createGame(level, character, resume?) → Game
updateGame(game, actions, dt = FIXED_DT) → side effects
Actions { moveX, jump, jumpHeld, down, power, pause, restart }
FIXED_DT = 1/60
```

Timings copied from 2D — never “improved”.

## Heroes 1:1 with 2D (`characters.ts` order)

| Id | Name | Power (2D truth) |
|---|---|---|
| `maya` | Maya | Dash + estrellas kakaw + 14s breath |
| `teko` | Teko | 3 jumps + swing on kakaw star |
| `luma` | Luma | Glide + overflight |
| `rok` | Rok | Stone + ground pound |
| `nix` | Nix | Climb + violet bolt |

If two heroes play the same in 3D → **return ticket**.

Save share (`cacao-rush-save-v1`) vs `-3d` → **Fase 2 decision**.

Full detail: [PORT_MAP](PORT_MAP.md), [TECH_BUDGET](TECH_BUDGET.md).
