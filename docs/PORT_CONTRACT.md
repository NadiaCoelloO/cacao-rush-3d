# Port contract (summary)

```
createGame(level, character, resume?) → Game
updateGame(game, actions, dt = FIXED_DT) → side effects
Actions { moveX, jump, jumpHeld, down, power, pause, restart }
FIXED_DT = 1/60
```

Timings copied from 2D — never “improved”.

Heroes (must stay distinct): Maya dash+kakaw stars+14s breath; Teko 3 jumps+swing; Luma glide; Rok stone+pound; Nix climb+violet bolt.

Full detail: [PORT_MAP](PORT_MAP.md), [TECH_BUDGET](TECH_BUDGET.md).
