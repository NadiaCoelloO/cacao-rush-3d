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

## Target platform — LOCKED

**Godot 4** — unique pipeline. **No R3F / Three.js.**

Native glTF, cinematic lights/camera. Dual-mode launches Godot build for 3D track.

## Performance

- Target **60 fps** mid laptop / mid phone (slice)
- FIXED_DT gameplay = `1/60` (match 2D)

## Gate

High-poly finales after greybox OK. Runtime full = Fase 2 vertical slice (Maya + Cuyabeno) in Godot 4 after scaffold merge.
