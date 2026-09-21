# Technical budgets

## Mesh / texture ceilings

| Class | Tris (LOD0) | LODs | Maps | Shader |
|---|---|---|---|---|
| Hero | ≤ 25 000 | 3 (≤25k / ≤12k / ≤5k) | 2K A-N-R (grey: flat/1K OK) | 1 |
| Fauna | ≤ 8 000 | 2–3 | 1K | 1 |
| Chunk (≈1 screen) | ≤ 80 000 | 3 | atlas 2K | ≤ few materials |
| Prop / pickup | ≤ 2 000 | 1–2 | 1K or atlas | 1 |

## Units / export

- Scale: **1u = 1m**
- Format: **glTF 2.0, Y-up**
- English file/node names

## Target platform (proposal)

**Primary recommendation: Godot 4** — native glTF, strong lighting/camera for cinematic track, desktop + export path.

**Alternative:** Three.js / React Three Fiber **only if** dual-mode must live in the same Vite web preview as 2D (`:8080`).

**One pipeline only** — never both. Coordinador locks in review.

## Performance

- Target **60 fps** on mid laptop / mid phone (slice)
- FIXED_DT gameplay = `1/60` (match 2D), independent of render fps when possible
