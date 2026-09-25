# Port contract (summary)

**2D tip pin:** `NadiaCoelloO/sand-vivid-dawn-sail` @ `5fd450312c8e6ad0a214f35b68fd81ec2857fec3` (oleada 3+4)  
**Prior pins:** `e7fd5c28` (oleada 3 docs) · `8e7ce7ad` (oleada 2) · `f278dd97` (oleada 1) — superseded for new port work.  
**Oleada 3 delta:** [PORT_DELTA_OLEADA3_2026-09-25.md](PORT_DELTA_OLEADA3_2026-09-25.md) — T-019 mantle + T-018 proneClearsLip ported in `runtime/scripts/player_maya.gd` (PR#4).

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
