# HP-001 E2h — analytic VRAM estimate (Intel UHD)

Same method as [`HP001_E2g_VRAM_UHD.md`](HP001_E2g_VRAM_UHD.md). Lavapipe counters are **not** the UHD number.

E2h keeps the painted sil ALPHA crown, Maya fill 0.90, thin outline, and no false floor. Grain face is cacao (`#6b3a1f`–`#8B4A2B`) with a 1–2 px `#CE722E` hull. LOOK feel-ledge crate hidden on follow cam. No extra textures.

## 1–4. UHD total

Unchanged vs E2g: **≈ 148 MB** / 192 MB cap.

## 5. Engine monitors (lavapipe, Vulkan Forward+)

LOOK-001 stills at 1920×1080, `force_lod0`. Captured with `VK_ICD_FILENAMES=lvp_icd.json` + xvfb, **not** `--headless` OpenGL.

| View | Primitives | Draws |
|---|---:|---:|
| gameplay | 80,917 | 192 |
| laguna | 101,758 | 150 |
| dosel | 236,073 | 202 |
| dock closeup | 71,275 | 79 |
| pods | 81,778 | 88 |
| cmp_bg | 120,968 | 63 |
| Hard cap | 350,000 | 250 |
| Target | 250,000 | — |

`SELVA_CAPTURE` 1280×720 (40×22.5 m follow cam):

| Shot | Primitives | Draws | maya_px |
|---|---:|---:|---:|
| entrance | 38,443 | 97 | 55.68 |
| hazard | 12,419 | 41 | 56.06 |
| cacao | 14,602 | 57 | 55.68 |

All views under 350k / 250 draws.

`maya_feel_check` **54/54 PASS**. LOD hole-check **PASS**.

`SELVA_CHECK` platforms=21 hazards=6 pickups=24 checks=2 goal=1. Pit `kill_y=−18.4167`.

`selva1_run_probe` **PASS** ticks=1556 far_x=194.32 G00=1 deaths=0. `player_maya.gd` not modified.

Maya WCAG: body ≥4.4 at 8 x. p10 (required) x36 **5.74** · x66 **6.10** · cacao **6.10**. Grains C00–C23 median-of-medians **7.27**, min **4.41** (C08). Face stays cacao ~ (155,78,37).

2D baseline: pin fallback `#6b3a1f` (`render.ts:1136–1139`). Cacao.Game Vite app was not executed.

HEAD: recorded on `cursor/hp001-e1-cuyabeno` next to this stills commit. Draft PR, no merge.

## 6. sha256

See [`COMPARATIVO_2D_3D.md`](COMPARATIVO_2D_3D.md) and `build_report.json` `e2h.captures`.
