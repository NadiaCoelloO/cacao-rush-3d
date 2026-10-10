# HP-001 E2b — analytic VRAM estimate (Intel UHD)

Same method as [`HP001_E1_VRAM_UHD.md`](HP001_E1_VRAM_UHD.md). Lavapipe counters are **not** the UHD number.

E2b adds Identidad-passed **canopy v2** (LOOK dosel replaced), **dock v2**, **groundcover v2** (Pads default + sparse cream flowers), a 2K dawn panorama, and distant waterfall cards. Trunk kit stays v4.

## 1. Textures (resident)

E2a textures **25.73 MB** plus:

| Texture | Res | Format | + mips |
|---|---|---|---:|
| `canopy_cuyabeno_hp_atlas_albedo_1k` (RGBA MASK) | 1024² | DXT5 | **1.33** |
| `canopy_cuyabeno_hp_atlas_normal_1k` | 1024² | BC5 | **1.33** |
| `canopy_cuyabeno_hp_atlas_orm_1k` | 1024² | DXT5 | **1.33** |
| `hp001_cuyabeno_sky_2k` panorama | 2048×1024 | DXT1 | **1.33** |
| `hp001_waterfall_card` | 384×1024 | DXT5 | **0.33** |
| **E2b maps** | | | **5.65 MB** |
| **Textures subtotal** | | | **≈ 31.4 MB** |

Canopy/dock/GC LOD1/2 discard embedded copies.

## 2. Mesh vertex + index

E2a meshes **7.83 MB** plus canopy Small/Medium/Large LOD0/1/2 (~6.4k / 1.8k / 36 tris) + hanging unused: **≈ 1.4 MB** with LOD0/1 shadow copies. Waterfall 3 planes negligible. **Meshes ≈ 9.2 MB**.

## 3. Framebuffers

Unchanged: **106.0 MB**. SDFGI is **off** (UHD).

## 4. Total vs 192 MB

| Bucket | MB |
|---|---:|
| Textures | 31.4 |
| Meshes | 9.2 |
| MultiMesh | 0.10 |
| 1080p targets + shadow atlas | 106.0 |
| **UHD estimate** | **≈ 147** |
| Cap | 192 |
| Headroom | **≈ 45** |

## 5. Engine monitors (lavapipe, 1920×1080)

Not the UHD VRAM number. Primitive / draw caps apply.

| View | Primitives | Draws |
|---|---:|---:|
| gameplay | 100,207 | 144 |
| laguna | 96,066 | 136 |
| dosel | 225,277 | 190 |
| dock closeup | 70,305 | 93 |
| pods | 75,216 | 77 |
| Hard cap | 350,000 | 250 |
| Target | 250,000 | — |

Dosel is under the 350k ceiling with ~125k headroom. All views under 250 draws. `maya_feel_check` 54/54. LOD hole-check PASS (canopy included, LOD2 never culled).
