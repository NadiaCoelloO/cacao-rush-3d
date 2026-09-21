# Port map — `src/game` → 3D (1:1)

Base: `NadiaCoelloO/sand-vivid-dawn-sail` @ `f278dd97`

| 2D module | 3D responsibility |
|---|---|
| `sim.ts` | Port physics/feel **verbatim** (coyote 0.1, buffer 0.12, cut 0.48, gravity/accel constants) |
| `types.ts` | Same `CharacterId`, `WorldId`, `HazardKind`, Actions shape |
| `characters.ts` | Same stats/powers; heroes must stay distinct |
| `levels.ts` | Same level data / screen layout for Selva pilot |
| `save.ts` | `cacao-rush-save-v1` — share or parallel (see dual-mode scope) |
| `assets.ts` / sprites | **Replace** with glTF under `assets/`; do not invent new mechanics from art |
| `render.ts` | Replace with cinematic camera/lights (runtime) |
| `input.ts` | Same Actions mapping |
| `stories.ts` | Copy/hooks OK; Identidad may rename worlds later |

## Do not reinvent

Feel, hitboxes semantics, warp/save rules, hero power differences. If two heroes play the same in 3D → return ticket.
