# cacao-rush-3d

Cacao Rush — **3D cinematográfico** (dual-mode con arcade 2D).

| | |
|---|---|
| **2D truth (READ ONLY)** | [`NadiaCoelloO/sand-vivid-dawn-sail`](https://github.com/NadiaCoelloO/sand-vivid-dawn-sail) @ `f278dd97` |
| **This repo** | assets (Blender/glTF) + 3D runtime |
| **Rule** | 2D validates; 3D **ports** — same gameplay, cinematic camera/lights/staging |

## Layout

```
assets/greybox/     # blockout glTF (Assets 3D)
assets/scripts/bpy/ # reproducible Blender scripts
assets/budgets/     # tris/maps/LOD sheets
docs/               # Phase 1 contracts (Pista 3D)
runtime/            # engine project (TBD)
```

## Docs (Fase 1 A–E)

- [DUAL_MODE_SCOPE](docs/DUAL_MODE_SCOPE.md) — «Elegí tu versión»
- [TECH_BUDGET](docs/TECH_BUDGET.md) — ceilings + platform
- [ASSET_PRIORITY](docs/ASSET_PRIORITY.md) — Maya + Selva first
- [BRIEF_ASSETS_MAYA_SELVA](docs/BRIEF_ASSETS_MAYA_SELVA.md) — lote 1
- [PORT_MAP](docs/PORT_MAP.md) — `src/game` → 3D 1:1
- [PORT_CONTRACT](docs/PORT_CONTRACT.md) — API / timings

## Status

GO 3D Nadia OK 2026-09-21. Fase 1 preprod in flight. No full campaign loop yet.
