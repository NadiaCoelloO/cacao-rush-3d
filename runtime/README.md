# runtime/ — CacaoRush3D (Godot 4)

**Engine LOCKED: Godot 4.2+ / 4.3** (Forward Plus). No R3F.

Fase 2 vertical slice: dual-mode selector + **Maya** on **Cuyabeno** (world id `selva`).

## Open in Godot

1. Install [Godot 4.2+](https://godotengine.org/download) (4.3 OK).
2. Project → Import → choose this folder (`runtime/`).
3. Main scene: `scenes/mode_select.tscn` (set in `project.godot`).
4. Press Play.

## Dual-mode

| Button | Behavior |
|---|---|
| **Arcade 2D** | Info only — 2D truth is [`sand-vivid-dawn-sail`](https://github.com/NadiaCoelloO/sand-vivid-dawn-sail) @ tip `8e7ce7ad87f37ac79731806b5668bf47f84382d6` (separate build; no launch from here). |
| **3D Cinemático** | Loads `scenes/pilot_cuyabeno.tscn`. |

## Pilot: Cuyabeno

- Display name: **Cuyabeno** (not Selva Dulce, not Yasuní).
- Code / asset folder id: `selva`.
- Controls: A/D or arrows move · Space/W jump · Esc back to mode select.
- Feel (`player_maya.gd`): 2D `sim.ts` run/jump/gravity port at 24 px/m — COYOTE **0.1**, BUFFER **0.12**, CUT **0.48** per tick, 2 jumps, 2D `followCam` framing, fall-kill respawn 80 px below the floor.
- Headless feel check: `godot --headless --path runtime -s res://tests/maya_feel_check.gd` (exit 0 = pass).

## Greybox tris (no high-poly yet)

| Asset | Tris |
|---|---|
| `hero_grey.glb` | 896 / 25 000 |
| `chunk_selva_floor.glb` | 380 / 80 000 |
| `totem_warp_cuyabeno.glb` | 858 / 2 000 (LOD1 360) — CIN-001 ASSET OK @ d93f777 |

Source: `assets/greybox/` + CIN-001 totem in `models/`. See [models/README.md](models/README.md). CSG placeholders remain if a glTF is missing.

## Layout

```
runtime/
  project.godot
  scenes/mode_select.tscn
  scenes/pilot_cuyabeno.tscn
  scripts/mode_select.gd
  scripts/pilot_cuyabeno.gd
  scripts/player_maya.gd
  models/          # drop .glb here
  import/          # import notes
```
