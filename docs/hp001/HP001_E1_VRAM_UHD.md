# HP-001 E1 — analytic VRAM estimate (Intel UHD)

Lavapipe reports `RENDER_VIDEO_MEM_USED` ≈ **624 MB** / `RENDER_TEXTURE_MEM_USED` ≈ **558 MB**. That is a software-Vulkan host pool (uncompressed staging + extra copies) and must not go to Coordinador as the UHD number.

This note is the UHD estimate: **S3TC/BC compressed textures with mipmaps**, resident mesh buffers, MultiMesh instance buffers, and 1080p Forward+ framebuffers + the directional shadow atlas. Nothing in this file is applied to the project; it is measurement only.

Assumptions (Intel UHD 620-class, Godot 4.2 Forward+):
- Albedo / emission: **DXT1/BC1** (RGB, 4 bpp) + mipmaps (×4/3).
- Normal: **BC5/RGTC2** (8 bpp) + mipmaps.
- ORM: **DXT5/BC3** (8 bpp) + mipmaps.
- Vertex: 56 B (position 12 + normal 12 + tangent 16 + UV 8 + pad).
- Index: 4 B, 3 per triangle. Shadow-mesh copies counted for LOD0/1 where `create_shadow_meshes=true`.
- Main view 1920×1080, `msaa_3d=2x` (project), directional atlas **4096** 16-bit (engine default; not overridden), 2 cascades.
- HP LOD1/2 **discard** embedded maps and reuse LOD0 materials, so those 1K/2K copies are **not** resident.
- LOOK GLBs are vertex-colour only (no maps).

## 1. Textures (resident)

| Texture | Res | Format | Raw (no mips) | + mips (×4/3) |
|---|---|---|---:|---:|
| `totem_warp_cuyabeno_hp_albedo_1k` | 1024² | DXT1 | 0.50 | **0.67** |
| `totem_warp_cuyabeno_hp_normal_1k` | 1024² | BC5 | 1.00 | **1.33** |
| `totem_warp_cuyabeno_hp_orm_1k` | 1024² | DXT5 | 1.00 | **1.33** |
| `totem_warp_cuyabeno_hp_emission_1k` | 1024² | DXT1 | 0.50 | **0.67** |
| `trunk_selva_bark_atlas_albedo_2k` | 2048² | DXT1 | 2.00 | **2.67** |
| `trunk_selva_bark_atlas_normal_2k` | 2048² | BC5 | 4.00 | **5.33** |
| `trunk_selva_bark_atlas_orm_2k` | 2048² | DXT5 | 4.00 | **5.33** |
| Blackwater ripple ×2 (`NoiseTexture2D` 256², as normal) | 256² ×2 | BC5 | 0.13 | **0.17** |
| Fog `NoiseTexture3D` 64³ (R8) | 64³ | R8 | 0.25 | **0.25** |
| `icon.svg` + misc 2D | — | DXT1 | — | **0.05** |
| **Textures subtotal** | | | | **18.40 MB** |

LOD1/2 GLBs embed duplicate 1K/2K maps; import `embedded_image_handling=0` discards them. Runtime `material_override` uses the LOD0 copy.

## 2. Mesh vertex + index (every resident LOD)

All three totem LODs, all three trunk-kit LODs (9 meshes, MultiMesh shares the mesh), LOOK LOD0/1/2 (loaded even when `visibility_range` hides them), hero 3 LODs, oneway / floor / platform greybox.

| Group | Verts | Tris | VBO (56 B) | IBO (12 B/tri) | Shadow copy | Total |
|---|---:|---:|---:|---:|---:|---:|
| Totem HP LOD0/1/2 | 5 856 | 9 764 | 0.31 | 0.11 | 0.28 (LOD0/1) | **0.70** |
| Trunk kit all LOD × 3 variants | 12 914 | 18 444 | 0.69 | 0.21 | 0.68 (LOD0/1) | **1.58** |
| LOOK-001 LOD0+1+2 | 55 787 | 20 558 | 2.98 | 0.24 | 0.00 (vertex colour, no extra) | **3.22** |
| hero_grey LOD0/1/2 | 2 978 | 1 355 | 0.16 | 0.02 | 0.12 | **0.30** |
| Floor / oneway / solid greybox | ~2 100 | ~900 | 0.11 | 0.01 | 0.08 | **0.20** |
| Beam cylinders + leaf cards (runtime) | ~1 200 | ~800 | 0.06 | 0.01 | 0.00 | **0.07** |
| **Meshes subtotal** | | | | | | **6.07 MB** |

## 3. MultiMesh instance buffers

57 `MultiMeshInstance3D` (3 variants × 3 LODs × spatial cells), 22 instance transforms total (12 × float32 = 48 B each) → **0.001 MB**. AABB / RID overhead < **0.05 MB**. **≈ 0.05 MB**.

## 4. Framebuffers and shadows (1080p Forward+)

| Buffer | Size math | MB |
|---|---|---:|
| HDR colour RGBA16F 1920×1080 | 1920×1080×8 | 15.82 |
| Depth D32 1920×1080 | 1920×1080×4 | 7.91 |
| MSAA 2× colour + depth (resolve kept) | ×1 extra colour/depth | 23.73 |
| Glow / bloom pyramid (RGB16F, half-res chain) | ~¼ + ⅛ + … of 1920×1080×6 | 4.0 |
| SSR (colour + roughness/hi-Z, ~1080p RGBA16F + 16-bit) | 1920×1080×(8+2) | 19.8 |
| Volumetric fog froxel 32×32×32 RGBA16F ×2 (temporal) | 32³×8×2 | 0.50 |
| Reflection probe 256² cubemap RGB16F | 256×256×6×6 | 2.25 |
| Directional shadow atlas 4096², 16-bit, 2 cascades | 4096²×2 | 32.0 |
| **Targets subtotal** | | **106.0 MB** |

## 5. Total vs 192 MB cap

| Bucket | MB |
|---|---:|
| Textures (BC/S3TC + mips) | 18.4 |
| Mesh VBO/IBO (+ shadow meshes) | 6.1 |
| MultiMesh | 0.05 |
| 1080p targets + shadow atlas | 106.0 |
| **UHD estimate** | **≈ 131 MB** |
| Cap | 192 |
| Headroom | **≈ 61 MB** |

**Under the 192 MB cap** on a real Intel UHD with S3TC/BC. The 624 MB lavapipe counter is not the UHD figure.

If a playtest on Nadia’s UHD still climbs (shared 128 MB bus, browser, denser SSR), cut in this order — **not applied**:

1. **`trunk_selva_bark_atlas_normal_2k` → 1K** (BC5 5.33 → 1.33 MB, **−4.0 MB**). ORM 2K→1K is the next **−4.0 MB**. Albedo can stay 2K (bark read at play distance).
2. Shadow atlas **4096 → 2048** (**−24 MB**). Biggest single cut; darkens far contact, not playable KEY energy.
3. **Disable MSAA 2×** (**−24 MB**). Softens silhouettes; lights unchanged.
4. Drop resident LOOK LOD1/2 GPU meshes (keep files, instance only the in-range LOD) (**−1.5 MB** meshes; small).

Do not cut totem 1K maps; the pods close-up needs them.
