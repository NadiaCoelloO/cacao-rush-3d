# HP-001 E2d — analytic VRAM estimate (Intel UHD)

Same method as [`HP001_E2c_VRAM_UHD.md`](HP001_E2c_VRAM_UHD.md). Lavapipe counters are **not** the UHD number.

E2d adds follow-cam cards (cumulus + 2 jungle strips + FG lianas), corridor MultiMesh trees, Maya outline, dosel cap fringe, and the selva-1 earth fascia. Textures unchanged from E2c.

## 1–4. UHD total

Unchanged vs E2c: **≈ 147 MB** / 192 MB cap. Cards are a few QuadMeshes. Corridor MultiMeshes reuse the trunk/canopy kit.

## 5. Engine monitors (lavapipe, Vulkan Forward+)

LOOK-001 stills at 1920×1080, `force_lod0`. Captured with `VK_ICD_FILENAMES=lvp_icd.json` + xvfb, **not** `--headless` OpenGL.

| View | Primitives | Draws |
|---|---:|---:|
| gameplay | 131,332 | 210 |
| laguna | 104,020 | 146 |
| dosel | 239,143 | 206 |
| dock closeup | 71,279 | 80 |
| pods | 81,474 | 84 |
| cmp_bg | 120,968 | 63 |
| Hard cap | 350,000 | 250 |
| Target | 250,000 | — |

`SELVA_CAPTURE` 1280×720 (40×22.5 m follow cam):

| Shot | Primitives | Draws | maya_px |
|---|---:|---:|---:|
| entrance | 67,714 | 121 | 55.68 |
| hazard | 43,474 | 76 | 56.06 |
| cacao | 45,463 | 96 | 55.68 |

All views under 350k / 250 draws.

`maya_feel_check` **54/54 PASS**. LOD hole-check **PASS**.

`SELVA_CHECK` platforms=21 hazards=6 pickups=24 checks=2 goal=1. Pit `kill_y=−18.4167`, play `player.kill_y=−80`. Subtitle **Laguna negra de Sucumbíos**.

`selva1_run_probe` **PASS** ticks=1556 far_x=194.32 G00=1 deaths=0. Pit line verified (feet y=−18.45 on earlier fail). `player_maya.gd` not modified.

HEAD: stamped next to this file after the stills commit. Draft PR, no merge.

## 6. sha256

See [`COMPARATIVO_2D_3D.md`](COMPARATIVO_2D_3D.md) and `build_report.json` `e2d.captures`. E2a/E2b/E2c capture SHAs are marked `replaced`.
