# HP-001 E2c — analytic VRAM estimate (Intel UHD)

Same method as [`HP001_E2b_VRAM_UHD.md`](HP001_E2b_VRAM_UHD.md). Lavapipe counters are **not** the UHD number.

E2c keeps the E2b art (canopy v2, dock v2, wet earth, olive crowns, FG lianas, lily) and adds the full **selva-1** play strip plus the 40×22.5 m side camera. Sky / silhouette / liana / jungle-sky textures are listed in `LOOK-001_manifest.json`.

## 1. Textures (resident)

E2b textures **≈ 31.4 MB** plus:

| Texture | Res | Format | + mips |
|---|---|---|---:|
| `hp001_selva_silhouette` | 1024×256 | DXT5 | **0.33** |
| `hp001_fg_liana` | 512×1024 | DXT5 | **0.33** |
| `hp001_jungle_sky_2d` (2D source, not sampled in-engine) | — | — | **0** |
| **E2c maps** | | | **0.66 MB** |
| **Textures subtotal** | | | **≈ 32.1 MB** |

`hp001_cuyabeno_sky_2k` was already in E2b.

## 2. Mesh vertex + index

E2b meshes **≈ 9.2 MB**. Selva-1 boxes / lips / beans / spikes are runtime `BoxMesh` / `SphereMesh` / `SurfaceTool` — a few dozen KB. **Meshes ≈ 9.2 MB**.

## 3. Framebuffers

Unchanged: **106.0 MB**. SDFGI is **off** (UHD).

## 4. Total vs 192 MB

| Bucket | MB |
|---|---:|
| Textures | 32.1 |
| Meshes | 9.2 |
| MultiMesh | 0.10 |
| 1080p targets + shadow atlas | 106.0 |
| **UHD estimate** | **≈ 147** |
| Cap | 192 |
| Headroom | **≈ 45** |

## 5. Engine monitors (lavapipe)

LOOK-001 stills at 1920×1080, `force_lod0`. Selva-1 geo is hidden on art cameras (laguna / dosel / dock / pods / cmp_bg) so the 200 m strip does not blow the draw cap. Gameplay and `SELVA_CAPTURE` keep the 1:1 level.

| View | Primitives | Draws |
|---|---:|---:|
| gameplay | 109,037 | 190 |
| laguna | 100,554 | 141 |
| dosel | 234,869 | 193 |
| dock closeup | 71,275 | 79 |
| pods | 81,472 | 83 |
| cmp_bg | 120,966 | 62 |
| Hard cap | 350,000 | 250 |
| Target | 250,000 | — |

`SELVA_CAPTURE` 1280×720 (40×22.5 m follow cam):

| Shot | Primitives | Draws | maya_px |
|---|---:|---:|---:|
| entrance | 44,757 | 84 | 55.68 |
| hazard | 5,480 | 42 | 55.68 |
| cacao | 4,346 | 42 | 55.68 |

Dosel is under the 350k ceiling with ~115k headroom. All views under 250 draws.

`maya_feel_check` **54/54 PASS**. LOD hole-check **PASS** (constants + instantiated `pilot_cuyabeno.tscn` MultiMeshes).

`SELVA_CHECK` platforms=21 hazards=6 pickups=24 checks=2 goal=1. `camera_offset=(0, 1, 24.1256)` P01_top=6.6667.

`player_maya.gd` was not modified.

HEAD: `06fcdb9e5579d9981aabd8f0bdbf98489b8d04cc` (`cursor/hp001-e1-cuyabeno`). Draft PR, no merge.

## 6. sha256

See [`COMPARATIVO_2D_3D.md`](COMPARATIVO_2D_3D.md) and `build_report.json` `e2c.captures`.
