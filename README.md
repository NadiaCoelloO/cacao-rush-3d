# Cacao Rush — 3D

Cinematic **3D** port of *Cacao Rush* (Ecuador arcade).

## Dual mode

Players choose:

| Mode | Repo |
|------|------|
| Arcade 2D (source of truth) | [`NadiaCoelloO/sand-vivid-dawn-sail`](https://github.com/NadiaCoelloO/sand-vivid-dawn-sail) |
| 3D cinematic | **this repo** |

**Contract:** 2D validates gameplay; 3D ports (no redesign). Code/commits in English; production reports in voseo.

## Owners

- **Pista 3D (Astra)** — port owner, budgets, dual-mode selector, vertical slice
- **Assets 3D (Blender)** — bpy → LOD → glTF/`.glb`, Maya grey blockout first
- **Cine** — non-loop pieces later (intro / trailers); not gameplay

## Phase 1 (in flight)

1. Documented bpy pipeline (model → LOD → export Y-up `.glb`)
2. Maya grey blockout
3. Pilot environment kit (Selva EC)
4. Prioritized asset list + tris budgets

No high-poly until Pista 3D greenlights.

## Identity gates

- Secret display/id: **Mindo** (copy may say Chocó Andino; no separate world)
- Nix hair: solid **purple/violet** (no white-cap)
- Ecuador toponyms / biome fauna; no ninja aesthetic

## Layout (suggested)

```
docs/           # budgets, port map, pipeline
assets/blender/ # bpy scripts, .blend sources
assets/glb/     # exported LODs
runtime/        # 3D game code (when started)
```
