# HP-001 E2i — analytic VRAM estimate (Intel UHD)

Same method as [`HP001_E2h_VRAM_UHD.md`](HP001_E2h_VRAM_UHD.md). Lavapipe counters are **not** the UHD number.

E2i keeps fill 0.90, painted sil crown (now várzea lobes), no false floor. Grain face stays cacao with a brighter `#FFC060` rim inside a `#2c1810` outline. `SELVA_GP_Platforms` hidden. H04/H05 fallen trunks `#4A4440`. No extra textures.

## 1–4. UHD total

Unchanged vs E2h: **≈ 148 MB** / 192 MB cap.

## 5. Engine monitors (lavapipe, Vulkan Forward+)

LOOK-001 stills at 1920×1080, `force_lod0`. Captured with `VK_ICD_FILENAMES=lvp_icd.json` + xvfb, **not** `--headless` OpenGL.

| View | Primitives | Draws |
|---|---:|---:|
| gameplay | 80,037 | 184 |
| laguna | 92,047 | 89 |
| dosel | 236,302 | 164 |
| dock closeup | 69,787 | 68 |
| pods | 100,020 | 83 |
| cmp_bg | 120,556 | 59 |
| Hard cap | 350,000 | 250 |
| Target | 250,000 | — |

`SELVA_CAPTURE` 1280×720 (40×22.5 m follow cam):

| Shot | Primitives | Draws | maya_px |
|---|---:|---:|---:|
| entrance | 39,527 | 104 | 55.68 |
| hazard | 13,047 | 45 | 56.06 |
| cacao | 15,302 | 62 | 55.68 |

All views under 350k / 250 draws.

`maya_feel_check` **54/54 PASS**. LOD hole-check **PASS**.

`SELVA_CHECK` platforms=21 hazards=6 pickups=24 checks=2 goal=1. Pit `kill_y=−18.4167`.

`selva1_run_probe` **PASS** ticks=1556 far_x=194.32 G00=1 deaths=0. `player_maya.gd` not modified.

Maya WCAG (QA): body ≥4.4 at 8 x. p10 exclude 2 px AA, all 8 x ≥4.4, mín **5.96** (x163), x36 **7.66**. Grains C00–C23 face vs immediate rim: median-of-medians **4.68**, min **4.68** (pin 4.03 / 1.95). Face stays cacao ~ (157,79,38).

2D baseline: pin fallback `#6b3a1f` (`render.ts:1136–1139`). Cacao.Game Vite app was not executed.

HEAD: recorded on `cursor/hp001-e1-cuyabeno` next to this stills commit. Draft PR, no merge.

## 6. sha256

See [`COMPARATIVO_2D_3D.md`](COMPARATIVO_2D_3D.md) and `build_report.json` `e2i.captures`.
