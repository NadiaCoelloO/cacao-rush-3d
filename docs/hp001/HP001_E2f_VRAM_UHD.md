# HP-001 E2f — analytic VRAM estimate (Intel UHD)

Same method as [`HP001_E2e_VRAM_UHD.md`](HP001_E2e_VRAM_UHD.md). Lavapipe counters are **not** the UHD number.

E2f keeps the follow-cam cards, corridor trees, thin Maya outline, dosel fringe, and earth fascia. Drops the Maya-parented disk/halo. Play-jungle band is an opaque unshaded quad (no extra texture). Cumulus JPEG unchanged.

## 1–4. UHD total

Unchanged vs E2e: **≈ 148 MB** / 192 MB cap.

## 5. Engine monitors (lavapipe, Vulkan Forward+)

LOOK-001 stills at 1920×1080, `force_lod0`. Captured with `VK_ICD_FILENAMES=lvp_icd.json` + xvfb, **not** `--headless` OpenGL. Follow-cam band cards are hidden on art cameras.

| View | Primitives | Draws |
|---|---:|---:|
| gameplay | 131,692 | 220 |
| laguna | 105,214 | 151 |
| dosel | 239,529 | 203 |
| dock closeup | 71,275 | 79 |
| pods | 81,474 | 84 |
| cmp_bg | 120,968 | 63 |
| Hard cap | 350,000 | 250 |
| Target | 250,000 | — |

`SELVA_CAPTURE` 1280×720 (40×22.5 m follow cam):

| Shot | Primitives | Draws | maya_px |
|---|---:|---:|---:|
| entrance | 67,954 | 121 | 55.68 |
| hazard | 43,882 | 77 | 56.06 |
| cacao | 45,701 | 96 | 55.68 |

All views under 350k / 250 draws.

`maya_feel_check` **54/54 PASS**. LOD hole-check **PASS**.

`SELVA_CHECK` platforms=21 hazards=6 pickups=24 checks=2 goal=1. Pit `kill_y=−18.4167`, play `player.kill_y=−80`. Subtitle **Laguna negra de Sucumbíos**.

`selva1_run_probe` **PASS** ticks=1556 far_x=194.32 G00=1 deaths=0. `player_maya.gd` not modified.

Maya WCAG (Vulkan stills, body vs play-jungle band) at 8 x: **7.92 / 5.45 / 4.50 / 5.62 / 5.53 / 5.59 / 6.23 / 6.02**. All ≥4.4. Cacao rim vs dark **5.98:1**.

HEAD: recorded on `cursor/hp001-e1-cuyabeno` next to this stills commit. Draft PR, no merge.

## 6. sha256

See [`COMPARATIVO_2D_3D.md`](COMPARATIVO_2D_3D.md) and `build_report.json` `e2f.captures`. E2e capture SHAs are marked `replaced`.
