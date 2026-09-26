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
| **Arcade 2D** | Info only — 2D truth is [`sand-vivid-dawn-sail`](https://github.com/NadiaCoelloO/sand-vivid-dawn-sail) @ tip `5fd450312c8e6ad0a214f35b68fd81ec2857fec3` (separate build; no launch from here). |
| **3D Cinemático** | Loads `scenes/pilot_cuyabeno.tscn`. |

## Pilot: Cuyabeno

- Display name: **Cuyabeno** (not Selva Dulce, not Yasuní).
- Code / asset folder id: `selva`.
- Controls: A/D or arrows move · Space/W jump · S/↓ crouch (crawl while moving; hold near a lip to squeeze under) · hold jump while falling past a ledge tip to mantle · S drops from a hang · Esc back to mode select.
- Feel (`player_maya.gd`): 2D `sim.ts` run/jump/gravity port at 24 px/m — COYOTE **0.1**, BUFFER **0.12**, CUT **0.48** per tick, 2 jumps, 2D `followCam` framing, fall-kill respawn 80 px below the floor.
- Oleada 3/4 feel (`sim.ts` @ `5fd45031`): **T-019 mantle** — ledge tip caught while falling with jump held, `MANTLE_T` **0.28 s** smoothstep pull-up onto the lip (hang x = lip − w + 6 px, head 8 px above the lip, stands at lip + 2 px); **T-018 proneClearsLip** — `PH_CROUCH` 24 px / `PH_PRONE` 14 px hitboxes, crouch ×0.55 / crawl ×0.42 run speed, a lip 8 px ahead that blocks the crouch box but clears the prone box forces the crawl.
- **T-020 greybox cream/tan** (2D PR #12, recolor only): while crouching / crawling `player_maya.gd` overrides the `hero_grey` outfit colour at runtime — crouch **RGB 138,99,65**, crawl **RGB 148,110,76** (average opaque outfit of the 2D `crouch-1` / `crawl-1` PNGs). Only the `Maya_Body` slot of `hero_grey.glb` (Assets @ 402121f, ASSET OK: idle cream body, brown hair, tan pack, unlit Emission) is tinted — hair / pack keep the idle materials, as in the 2D recolor (`TINT_OUTFIT_SLOTS`; add `Maya_Pack` there if Identidad classes the satchel as outfit). If a hero instance has no named slots yet, every `BaseMaterial3D` on it is tinted; the tint goes through `emission` on that unlit export, through `albedo_color` on plain materials (CSG fallback, tinted whole). Standing puts the untouched materials back. No crouch mesh (high-poly HOLD). **Identidad PASA** (greybox, 2026-09-26): tints stay in the ~28° hue band (crouch 27.9°, crawl 28.3°), never olive.
- Headless feel check: `godot --headless --fixed-fps 60 --path runtime -s res://tests/maya_feel_check.gd` (exit 0 = pass, 53 checks: run/jump/buffer, mantle, crouch/prone, T-020 tint + slot selection + Identidad hue band, pilot smoke).

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
