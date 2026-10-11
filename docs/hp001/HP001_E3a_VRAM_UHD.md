# HP-001 E3a — analytic VRAM estimate (Intel UHD)

Same method as [`HP001_E2j_VRAM_UHD.md`](HP001_E2j_VRAM_UHD.md). Lavapipe counters are **not** the UHD number.

E3a adds one 1024² atlas (`T_PlatformSkins_Cuyabeno_A.png`) and combined skin meshes on the 21 boxes. Maya wrap/fill 0.90, grains, and várzea copas stay E2j. No extra Maya HP textures from the tarball.

## 1–4. UHD total

E2j ≈ 148 MB + one 1024² RGBA atlas (~4 MB uncompressed, ~1 MB on disk) ≈ **152 MB** / 192 MB cap.

## 5. Engine monitors (lavapipe, Vulkan Forward+)

LOOK-001 stills at 1920×1080, `force_lod0`. Captured with `VK_ICD_FILENAMES=lvp_icd.json` + xvfb, **not** `--headless` OpenGL.

| View | Primitives | Draws |
|---|---:|---:|
| gameplay | 112,563 | 163 |
| platform close | 110,355 | 99 |
| platform face | 107,816 | 88 |
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
| entrance | 70,061 | 98 | 55.68 |
| hazard | 38,407 | 44 | 56.06 |
| cacao | 45,280 | 60 | 55.68 |

All views under 350k / 250 draws. Combined per platform per LOD so skins add ~21 draws, not hundreds.

`maya_feel_check` **54/54 PASS**. LOD hole-check **PASS**.

`SELVA_CHECK` platforms=21 hazards=6 pickups=24 checks=2 goal=1. Skins dressed=21, colliders=21. Pit `kill_y=−18.4167`.

`selva1_run_probe` **PASS** ticks=1556 far_x=194.32 G00=1 deaths=0. `player_maya.gd` not modified.

Maya WCAG (QA): p10 exclude 2 px AA, all 8 x ≥4.4, mín **6.03** (x163). Grains C00–C23 silhouette max(rim `#CE722E`, outline `#2c1810`) vs local bg (litter on tops): median-of-medians **7.20**, min **5.02** (pin 4.03 / 3.7).

HEAD: recorded on `cursor/hp001-e3-skins` next to this stills commit. Draft PR, no merge.

## 6. sha256

See [`COMPARATIVO_2D_3D.md`](COMPARATIVO_2D_3D.md) and `build_report.json` `e3a`.
