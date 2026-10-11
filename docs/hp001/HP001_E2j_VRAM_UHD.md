# HP-001 E2j — analytic VRAM estimate (Intel UHD)

Same method as [`HP001_E2i_VRAM_UHD.md`](HP001_E2i_VRAM_UHD.md). Lavapipe counters are **not** the UHD number.

E2j keeps fill 0.90, cream wrap, no false floor. Grain face stays cacao with a thin `#CE722E` rim on the top + 3/4 only (not a closed `#FFC060` coin) inside a `#2c1810` outline. Crown is almost-horizontal várzea copas. `SELVA_GP_Platforms` hidden. H04/H05 fallen trunks `#4A4440`. No extra textures.

## 1–4. UHD total

Unchanged vs E2i: **≈ 148 MB** / 192 MB cap.

## 5. Engine monitors (lavapipe, Vulkan Forward+)

LOOK-001 stills at 1920×1080, `force_lod0`. Captured with `VK_ICD_FILENAMES=lvp_icd.json` + xvfb, **not** `--headless` OpenGL.

| View | Primitives | Draws |
|---|---:|---:|
| gameplay | 83,457 | 184 |
| laguna | 100,018 | 140 |
| dosel | 234,333 | 192 |
| dock closeup | 69,787 | 68 |
| pods | 80,138 | 75 |
| cmp_bg | 120,556 | 59 |
| Hard cap | 350,000 | 250 |
| Target | 250,000 | — |

`SELVA_CAPTURE` 1280×720 (40×22.5 m follow cam):

| Shot | Primitives | Draws | maya_px |
|---|---:|---:|---:|
| entrance | 41,351 | 104 | 55.68 |
| hazard | 13,959 | 45 | 56.06 |
| cacao | 16,442 | 62 | 55.68 |

All views under 350k / 250 draws.

`maya_feel_check` **54/54 PASS**. LOD hole-check **PASS**.

`SELVA_CHECK` platforms=21 hazards=6 pickups=24 checks=2 goal=1. Pit `kill_y=−18.4167`.

`selva1_run_probe` **PASS** ticks=1556 far_x=194.32 G00=1 deaths=0. `player_maya.gd` not modified.

Maya WCAG (QA): body ≥4.4 at 8 x. p10 exclude 2 px AA, all 8 x ≥4.4, mín **5.96** (x163), x36 **7.66**. Grains C00–C23 silhouette max(rim `#CE722E`, outline `#2c1810`) vs local bg: median-of-medians **7.20**, min **4.12** (pin 4.03 / 3.7). C08/C09/C15/C16 outline vs lip **4.12**. Extra stills C07/C16/C21.

2D baseline: pin fallback `#6b3a1f` (`render.ts:1136–1139`). Cacao.Game Vite app was not executed.

HEAD: recorded on `cursor/hp001-e1-cuyabeno` next to this stills commit. Draft PR, no merge.

## 6. sha256

See [`COMPARATIVO_2D_3D.md`](COMPARATIVO_2D_3D.md) and `build_report.json` `e2j.captures`.
