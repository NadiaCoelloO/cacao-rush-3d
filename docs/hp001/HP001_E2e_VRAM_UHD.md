# HP-001 E2e — analytic VRAM estimate (Intel UHD)

Same method as [`HP001_E2d_VRAM_UHD.md`](HP001_E2d_VRAM_UHD.md). Lavapipe counters are **not** the UHD number.

E2e keeps the follow-cam cards, corridor trees, Maya outline, dosel fringe, and earth fascia. Adds a cropped cumulus-band JPEG (painted `jungle-sky.jpg`, hills/falls removed) and drops the white ellipse / bamboo-rod meshes.

## 1–4. UHD total

Unchanged vs E2d aside from one extra JPEG: **≈ 148 MB** / 192 MB cap.

## 5. Engine monitors (lavapipe, Vulkan Forward+)

LOOK-001 stills at 1920×1080, `force_lod0`. Captured with `VK_ICD_FILENAMES=lvp_icd.json` + xvfb, **not** `--headless` OpenGL.

| View | Primitives | Draws |
|---|---:|---:|
| gameplay | 132,360 | 224 |
| laguna | 105,222 | 153 |
| dosel | 239,545 | 206 |
| dock closeup | 71,283 | 82 |
| pods | 81,474 | 84 |
| cmp_bg | 120,968 | 63 |
| Hard cap | 350,000 | 250 |
| Target | 250,000 | — |

`SELVA_CAPTURE` 1280×720 (40×22.5 m follow cam):

| Shot | Primitives | Draws | maya_px |
|---|---:|---:|---:|
| entrance | 68,152 | 124 | 55.68 |
| hazard | 43,888 | 78 | 56.06 |
| cacao | 45,899 | 99 | 55.68 |

All views under 350k / 250 draws.

`maya_feel_check` **54/54 PASS**. LOD hole-check **PASS**.

`SELVA_CHECK` platforms=21 hazards=6 pickups=24 checks=2 goal=1. Pit `kill_y=−18.4167`, play `player.kill_y=−80`. Subtitle **Laguna negra de Sucumbíos**.

`selva1_run_probe` **PASS** ticks=1556 far_x=194.32 G00=1 deaths=0. `player_maya.gd` not modified.

Maya WCAG (Vulkan stills): entrance body **5.00:1** / outline **7.77:1**. Wind zone body **4.69:1** / outline **7.62:1**.

HEAD: recorded on `cursor/hp001-e1-cuyabeno` next to this stills commit. Draft PR, no merge.

## 6. sha256

See [`COMPARATIVO_2D_3D.md`](COMPARATIVO_2D_3D.md) and `build_report.json` `e2e.captures`. E2d capture SHAs are marked `replaced`.
