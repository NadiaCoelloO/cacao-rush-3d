# HP-001 E2a — analytic VRAM estimate (Intel UHD)

Same method as [`HP001_E1_VRAM_UHD.md`](HP001_E1_VRAM_UHD.md). Lavapipe still reports `RENDER_VIDEO_MEM_USED` ≈ **677 MB** / `RENDER_TEXTURE_MEM_USED` ≈ **596 MB**. That is the software-Vulkan host pool and must not go to Coordinador as the UHD number.

E2a adds the Identidad-passed **dock** (Straight + End, visual only) and **groundcover** (Fern + CacaoLeaves MultiMesh). The E2 canopy is **not** imported (NO PASA; LOOK dosel stays). `GC_WaterLily` stays in the GLB but is **never instanced**. Trunk kit is v4 (same tri counts as v3; atlas albedo/normal retouched).

Assumptions unchanged: S3TC/BC + mips, 56 B vertex, 4 B index, 1080p Forward+ MSAA 2×, directional atlas 4096 16-bit 2 cascades. LOD1/2 `embedded_image_handling=0` (discard). Dock LOD0 BasisU; groundcover LOD0 BasisU, no shadow meshes.

## 1. Textures (resident)

E1 textures **18.40 MB** plus:

| Texture | Res | Format | Raw (no mips) | + mips (×4/3) |
|---|---|---|---:|---:|
| `dock_cuyabeno_hp_atlas_albedo_1k` | 1024² | DXT1 | 0.50 | **0.67** |
| `dock_cuyabeno_hp_atlas_normal_1k` | 1024² | BC5 | 1.00 | **1.33** |
| `dock_cuyabeno_hp_atlas_orm_1k` | 1024² | DXT5 | 1.00 | **1.33** |
| `groundcover_cuyabeno_atlas_albedo_1k` (RGBA, MASK) | 1024² | DXT5 | 1.00 | **1.33** |
| `groundcover_cuyabeno_atlas_normal_1k` | 1024² | BC5 | 1.00 | **1.33** |
| `groundcover_cuyabeno_atlas_orm_1k` | 1024² | DXT5 | 1.00 | **1.33** |
| **E2a maps** | | | | **7.33 MB** |
| **Textures subtotal** | | | | **25.73 MB** |

Canopy 1K atlases are not in the project. LOD1/2 dock/groundcover GLBs discard their embedded copies.

## 2. Mesh vertex + index (every resident LOD)

E1 mesh bucket **6.07 MB** (totem, trunk kit v4 same tris as v3, LOOK, hero, greybox, beam). E2a adds:

| Group | Verts | Tris | VBO (56 B) | IBO (12 B/tri) | Shadow copy | Total |
|---|---:|---:|---:|---:|---:|---:|
| Dock Straight+End+Step LOD0/1/2 | 13 844 | 9 154 | 0.78 | 0.11 | 0.79 (LOD0/1) | **1.67** |
| Groundcover Fern+Leaves+Lily LOD0/1 (lily mesh resident, not drawn) | 1 320 | 1 387 | 0.07 | 0.02 | 0.00 | **0.09** |
| **E2a meshes** | | | | | | **1.76** |
| **Meshes subtotal** | | | | | | **7.83 MB** |

`Dock_Step` is imported but not placed. `GC_WaterLily` is imported and never instanced.

## 3. MultiMesh instance buffers

57 trunk + 20 groundcover `MultiMeshInstance3D` (Fern/CacaoLeaves × LOD0/1 × 18 m cells), 22 trunk + 28 cover instances (12 × float32 = 48 B each) → **< 0.01 MB**. AABB / RID overhead **≈ 0.08 MB**.

## 4. Framebuffers and shadows (1080p Forward+)

Unchanged from E1: **106.0 MB**.

## 5. Total vs 192 MB cap

| Bucket | E1 MB | E2a MB |
|---|---:|---:|
| Textures (BC/S3TC + mips) | 18.4 | 25.7 |
| Mesh VBO/IBO (+ shadow meshes) | 6.1 | 7.8 |
| MultiMesh | 0.05 | 0.08 |
| 1080p targets + shadow atlas | 106.0 | 106.0 |
| **UHD estimate** | **≈ 131** | **≈ 140** |
| Cap | 192 | 192 |
| Headroom | **≈ 61** | **≈ 52** |

**Under the 192 MB cap.** Cut order if a UHD playtest climbs is unchanged (bark normal 2K→1K, shadow atlas 4096→2048, disable MSAA 2×). Do not cut totem 1K maps.

## 6. Visible tris / draws (Godot Performance, 1920×1080, lavapipe)

Hard 350k tris, target 250k, ≤250 draws. Dosel did **not** exceed 300k, so trunk/groundcover LOD ranges were **not** tightened (before = after). ~66k tris remain under the 350k ceiling (~45k reserved for canopy v2).

| Shot | Visible primitives | Draw calls | vs 350k | vs 250 draws |
|---|---:|---:|---|---|
| gameplay | 222 558 | 146 | OK | OK |
| laguna | 174 230 | 111 | OK | OK |
| dosel | 283 971 | 178 | OK (under 300k; +19k vs E1 dosel 264 948) | OK |
| pods | 223 105 | 113 | OK | OK |
| dock closeup | 228 495 | 155 | OK | OK |

Trunk LOD kept **0–26 / 14–44 / 32–∞**, margin 3. Groundcover LOD0/1 **0–18 / 12–40**, margin 3 (fade after ~37 m). Dock same hysteresis as the totem: **0–36 / 28–66 / 58–∞**, margin 4.
