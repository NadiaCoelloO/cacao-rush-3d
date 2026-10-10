# HP-001 E2d — analytic VRAM estimate (Intel UHD)

Same method as [`HP001_E2c_VRAM_UHD.md`](HP001_E2c_VRAM_UHD.md). Lavapipe counters are **not** the UHD number.

E2d adds follow-cam cards (cumulus + 2 jungle strips + FG lianas), corridor MultiMesh trees, Maya outline, dosel cap cards, and the selva-1 earth fill. Textures unchanged from E2c.

## 1–4. UHD total

Unchanged vs E2c: **≈ 147 MB** / 192 MB cap. Cards are a few QuadMeshes. Corridor MultiMeshes reuse the trunk/canopy kit.

## 5. Engine monitors (lavapipe, Vulkan Forward+)

LOOK-001 stills at 1920×1080, `force_lod0`. Captured with `VK_ICD_FILENAMES=lvp_icd.json` + xvfb, **not** `--headless` OpenGL.

| View | Primitives | Draws |
|---|---:|---:|
| gameplay | 130,520 | 201 |
| laguna | 104,016 | 145 |
| dosel | 238,333 | 198 |
| dock closeup | 71,277 | 80 |
| pods | 81,474 | 84 |
| cmp_bg | 120,968 | 63 |
| Hard cap | 350,000 | 250 |
| Target | 250,000 | — |

`SELVA_CAPTURE` 1280×720 (40×22.5 m follow cam):

| Shot | Primitives | Draws | maya_px |
|---|---:|---:|---:|
| entrance | 66,906 | 113 | 55.68 |
| hazard | 42,666 | 68 | 56.06 |
| cacao | 44,657 | 89 | 55.68 |

All views under 350k / 250 draws.

`maya_feel_check` **54/54 PASS**. LOD hole-check **PASS**.

`SELVA_CHECK` platforms=21 hazards=6 pickups=24 checks=2 goal=1. Pit `kill_y=−18.4167`, play `player.kill_y=−80`. Subtitle **Laguna negra de Sucumbíos**.

`selva1_run_probe` **FAIL** far_x=93.31 G00=0 (5 deaths). Pit line verified (feet y=−18.45). `player_maya.gd` not modified.

HEAD is recorded in `build_report.json` `e2d` after this commit. Draft PR, no merge.

## 6. sha256

See [`COMPARATIVO_2D_3D.md`](COMPARATIVO_2D_3D.md) and `build_report.json` `e2d.captures`. E2a/E2b/E2c capture SHAs are marked `replaced`.
