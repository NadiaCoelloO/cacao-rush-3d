# HP-001 E2g — analytic VRAM estimate (Intel UHD)

Same method as [`HP001_E2f_VRAM_UHD.md`](HP001_E2f_VRAM_UHD.md). Lavapipe counters are **not** the UHD number.

E2g keeps the follow-cam bands, thin Maya outline, painted sil crown, and P00 fascia. Drops the 220 m earth fill and hides the corridor bank on the follow cam (layer 13). Grain materials stay unshaded (no extra textures). Cumulus JPEG unchanged.

## 1–4. UHD total

Unchanged vs E2f: **≈ 148 MB** / 192 MB cap.

## 5. Engine monitors (lavapipe, Vulkan Forward+)

LOOK-001 stills at 1920×1080, `force_lod0`. Captured with `VK_ICD_FILENAMES=lvp_icd.json` + xvfb, **not** `--headless` OpenGL. Follow-cam band cards are hidden on art cameras. Corridor MMIs are layer 13.

| View | Primitives | Draws |
|---|---:|---:|
| gameplay | 109,547 | 192 |
| laguna | 101,758 | 150 |
| dosel | 243,303 | 207 |
| dock closeup | 71,275 | 79 |
| pods | 101,356 | 92 |
| cmp_bg | 120,968 | 63 |
| Hard cap | 350,000 | 250 |
| Target | 250,000 | — |

`SELVA_CAPTURE` 1280×720 (40×22.5 m follow cam):

| Shot | Primitives | Draws | maya_px |
|---|---:|---:|---:|
| entrance | 45,809 | 93 | 55.68 |
| hazard | 12,099 | 35 | 56.06 |
| cacao | 13,902 | 52 | 55.68 |

All views under 350k / 250 draws. Follow-cam draws drop vs E2f (corridor culled).

`maya_feel_check` **54/54 PASS**. LOD hole-check **PASS**.

`SELVA_CHECK` platforms=21 hazards=6 pickups=24 checks=2 goal=1. Pit `kill_y=−18.4167`, play `player.kill_y=−80`. Subtitle **Laguna negra de Sucumbíos**.

`selva1_run_probe` **PASS** ticks=1556 far_x=194.32 G00=1 deaths=0. `player_maya.gd` not modified.

Maya WCAG (Vulkan stills, body+shadows vs play-jungle) at 8 x: **8.92 / 8.23 / 8.66 / 9.19 / 7.33 / 7.35 / 7.36 / 8.37**. All ≥4.4. Grains C00–C23 median-of-medians **13.54**, min **9.48**. Cacao rim vs dark **5.94:1**.

HEAD: recorded on `cursor/hp001-e1-cuyabeno` next to this stills commit. Draft PR, no merge.

## 6. sha256

See [`COMPARATIVO_2D_3D.md`](COMPARATIVO_2D_3D.md) and `build_report.json` `e2g.captures`. E2f 3d_* capture SHAs are marked `replaced`.
