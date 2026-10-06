# HP-001 Delivery 1 - Cuyabeno high-poly: totem_warp_cuyabeno_hp + trunk_selva_kit_hp

For Cuyabeno only (world id `selva`). Built by `hp001_e1_cuyabeno.py` in Blender 5.2.1 LTS (background), seed 20261006. Not wired into Godot and not in any repo yet: it waits for Identidad's PASS. **Current version: v3** (totem = v2, PASSED Identidad; trunk kit = v3 after Identidad NO PASA minor on the v2 epiphytes).

Rebuild: `blender --background --python hp001_e1_cuyabeno.py -- --out <dir>` (`--no-render` skips the stills). `--only totem` rebuilds only the totem (textures, GLBs, blend, stills) and leaves every trunk file untouched; `--only trunks` rebuilds only the trunk kit and leaves every totem file byte-identical. The script exits 1 if any LOD is over budget, if the pod count is not 3, if the pods leave the greybox footprint, or if a still/texture has magenta pixels.

## Revision log

- **v3 (2026-10-06, trunks only; built with `--only trunks`)**. Identidad gate on E1 v2: TOTEM PASSES (its files are byte-identical to v2 and were not rebuilt). TRUNKS: NO PASA, minor: bark, lichen, moss, buttresses and lianas approved; the epiphytes failed (fans on the fork tops read as palm/agave; the mid-height clumps stuck out as horizontal fronds).
  - All epiphytes removed from the fork tops and crotches; the broken mossy stubs are bare (the E2 canopy attaches there).
  - Epiphytes are now only compact bromeliad rosettes hugging the shaft at mid-height: short, broad, CUPPED leaves with rounded tips (6-sided cupped section in LOD0, 4-sided in LOD1; closed thin solids, opaque), rising in a tight vase (outer whorl 5 leaves rising ~10-52 deg off the rosette axis, inner whorl 3 leaves ~4-24 deg; LOD1 4 + 2), the leaves on the bark side stand up flush on the bark; about 0.4-0.6 m across and 0.25-0.36 m tall, the base sits on the bark. 2 per variant in LOD0 and LOD1, none in LOD2. Exit 1 if a rosette is outside 0.25-0.65 m across, if a leaf sinks > 3 cm into the bark, or if a liana passes within 4 cm of a leaf.
  - Lianas unchanged (same paths, sections and segment counts as v2).
  - Buttress UV seam fixed: v2 mapped each fin wall planar from its own root, so U jumped by up to 0.63-0.90 tile on every fin crest. v3 mirrors the second wall about the crest (U continuous over the crest; the grain is book-matched there instead of cut) and keeps it planar, so texel density stays uniform (max horizontal stretch 1.0x). The remaining U step (<= 0.19 tile) moved to the shadowed root crease where the wall meets the shaft; above the fins the shaft mapping is unchanged from v2.
  - Unchanged: bark/lichen/moss atlas, pivot, buttresses, waterline, -0.5 m roots, forks and broken stubs, identity transforms (MultiMesh-ready), one material + one 2K atlas. Tri counts and bark hue/sat below.

| File (v3, trunks) | v2 SHA256 (delivered, gated NO PASA minor) | v3 SHA256 |
|---|---|---|
| HP001_trunks_34.png | `dd27046267d13e6071c59ee584eb7960029af8e1b4ebb16bfb6fecbad6978346` | `f2f7e577eb7d16f12724c7d5fd9a4bca40f404dcbcebb3acef9556b14339572f` |
| HP001_trunks_bark_closeup.png | `49c0068e822238888741e24eec64f15d715d99881a1eb5d5603aa2776c6b73b8` | `9cbf8c89fa9155d5c3d3c29c7dd997459bff6154fc406d54aad95358a1ed7be6` |
| HP001_trunks_front.png | `f9452291ceb2d62850fc1fa6ceb97764bda714768932e5dc388c73bdd58b1876` | `11b3a12fbd28220313f66f2013f5a6ab698ef4b35f6e653472437c9626b73531` |
| textures/trunk_selva_bark_atlas_albedo_2k.png | `14417535f9a9eb2f93321a77342c8b5bf6a1465158cb6fe5e9cd758c5f5583ed` | `14417535f9a9eb2f93321a77342c8b5bf6a1465158cb6fe5e9cd758c5f5583ed` |
| textures/trunk_selva_bark_atlas_normal_2k.png | `90722ad6a069e57b636ec982db22b1413df87b9dade72deeda4cdb61c40ba7e5` | `90722ad6a069e57b636ec982db22b1413df87b9dade72deeda4cdb61c40ba7e5` |
| textures/trunk_selva_bark_atlas_orm_2k.png | `2172a5ef24f0807a4774fcf3cd817a9956d5a68fbd96a0a0ad55bc049d5b73e9` | `2172a5ef24f0807a4774fcf3cd817a9956d5a68fbd96a0a0ad55bc049d5b73e9` |
| trunk_selva_kit_hp.blend | `4630500504307f8052d7ca5d1435b87a4d7a69f12c94976c68cb709a1fc5303b` | `8503b459d8959b16097513d3987f79ab31140347a2ea31be93c5a99f1f028e32` |
| trunk_selva_kit_hp_LOD0.glb | `5ac5a5b5f7c37db3c75d37b083f6d513905b494be46bb460c724974a5fa622ba` | `a95c01da5b54e8238bcc5010dff9c86d894870cfeaa9f9cf3b723eff60b1fd73` |
| trunk_selva_kit_hp_LOD1.glb | `2ce349eeaf33578c11e28b1e823d592c150acf33a3e3b254c7f14aad0ae2cb32` | `b4ae905b5e962bf3f9b6320608ba6a876e7944138536ed49abb9c735b5c59bb3` |
| trunk_selva_kit_hp_LOD2.glb | `8fc3fd7c77e4137a8b1803d17e1a7cd0003512d4b7788c95c9911635b451428c` | `cb21854ca1aaa035bdf88ab01c398e796ff4a5c08acff34bdd161758688b0bc2` |

- **v2 (2026-10-06, both pieces; Identidad NO PASA on v1)**. Locked by Pista 3D: totem height 2.61 OK; the beam uses `BeamOrigin` (pod cluster centre, identity lock); `VFX_WarpBeam_Spawn` stays only as a legacy empty, not wired; greybox transform bug noted.
  - TOTEM: the v1 post read as a classical column/baluster (lathe symmetry, stepped plinth, round mouldings, flat capital). v2 post = hand-carved TREE TRUNK: irregular tapered section (drifting 2/3/4/5/7-lobe noise, no lathe symmetry), slight bow/lean (max ~4.8 cm at z~1.05, 0 at the base and at the pods), 5 short roots/buttresses instead of the stepped plinth (exactly inside the 0.95 x 0.95 footprint), the round mouldings replaced by 3 FLAT INCISED bands cut 8 mm into the surface (z 0.55 / 1.50 / 2.20, hand-wobbled), diamond lattice + zigzag carving kept, patches of leftover bark (raised ~12 mm, darker, rougher, fissured) between the carved areas, and a chopped/sawn trunk top instead of the flat capital (slanted uneven cut, broken notch, growth rings + radial checks + axe/saw marks + bark lip on the 1K cap texture). The stems enter the trunk just under the cut. FROZEN (bit-identical geometry): the 3 pods, the stems, BeamOrigin, pivot, footprint, height 2.61. Lianas kept (re-wrapped on the new trunk).
  - TRUNKS: v1 read as bare poles / dead pines with reddish bark (~RGB 67,43,32, hue 19, sat 0.35). v2: cool desaturated grey-brown bark (see measured hue/sat below), bark plates + fissures + fine fissure network + short cross-checks in the normal map, geometric irregularity on the shaft (drifting lobes, shallow vertical ridges, burls), stronger lean + wobble, pale lichen crusts (mostly lower trunk), a dark water-stain band with moss just above the waterline, 1-2 bromeliad-like epiphyte clumps (broad strap leaves with ROUNDED tips, closed thin solids, opaque) + 1 hanging liana per variant in LOD0/LOD1 (dropped in LOD2). Buttresses, waterline, -0.5 m roots, forks and base pivot unchanged. Still one shared material + one 2K atlas.
  - TRUNK POLISH (v2, same day, trunks only, built with `--only trunks`; the totem files are byte-identical to the v2 totem). Review of the v2 trunk stills: at the 3/4 framing the trunks still read as bare poles with Y-forks; epiphytes tiny, liana a hairline. Changes:
    - Epiphytes 2.5-3x bigger (leaf length Thin 1.25 / Medium 1.65 / Thick 2.15 m, was 0.46 / 0.62 / 0.80; broad strap leaves with ROUNDED tips, closed thin solids, opaque): one vase-shaped clump on every fork limb right at the crotch (Thin 1, Medium 2, Thick 2) plus one mid-shaft clump (~0.5 H) per variant, in LOD0 (8/7 leaves) and LOD1 (5 leaves). LOD2 drops them.
    - Lianas: 2 per variant in LOD0 and LOD1, 3.0-5.0 cm thick (tapering): one loose catenary loop from a fork limb down past mid-height and back up into the trunk, one draping off a limb and hanging almost to the water (end z Thin 1.10 / Medium 0.45 / Thick 0.60 m). Clearance to the trunk/buttress mesh is checked (exit 1 if < 1 cm).
    - Fork tips: every limb ends in a broken stub (blunt taper, splintered jagged rim, sunken break face) with moss and dark splintered wood on the last ~20 % and on the break; the trunk top is a broken, splintered, mossy stub instead of a cone point. Fork positions unchanged. LOD2 now keeps the fork stubs too (5-sided), so its silhouette matches LOD0/1.
    - Bark close-up: the buttress fins no longer stretch the texture. Shaft/gap vertices keep the v2 U mapping; each fin wall is mapped planar (U = distance along the wall / bare perimeter), so texel density is ~uniform on the fins (this put a UV seam on each fin crest; fixed in v3). Moss band broader and patchier: water-stain/flood line at atlas row ~206 (was ~183) with a ragged top, holes of bare bark in the band, moss tongues and patches up to row ~290; lichen starts above it.
    - Tris paid from shaft ring density only (rings per bark tile: Medium/Thick LOD0 2 -> 1, LOD1 1 -> 0); buttress rings unchanged. Buttresses, waterline, -0.5 m roots, base pivot, identity transforms (MultiMesh-ready), one material + one 2K atlas unchanged. Bark colour: see the measured hue/sat below (neutral key light for the trunk stills).

| File (trunk polish) | v2 SHA256 before the polish | v2 SHA256 after the polish (delivered) |
|---|---|---|
| HP001_trunks_34.png | `3af3b538e5f38aff13ad3bd0566b2181c8ad9f04e65b310ebf21c9655dae17cf` | `dd27046267d13e6071c59ee584eb7960029af8e1b4ebb16bfb6fecbad6978346` |
| HP001_trunks_bark_closeup.png | `8359936c60ba072849b2a922430ce808b50d61f5061c45c81d472d019b8bd02d` | `49c0068e822238888741e24eec64f15d715d99881a1eb5d5603aa2776c6b73b8` |
| HP001_trunks_front.png | `feb4c6535124968dea7d776dfe8ed01375cabfc55533352f8077d393106a6277` | `f9452291ceb2d62850fc1fa6ceb97764bda714768932e5dc388c73bdd58b1876` |
| textures/trunk_selva_bark_atlas_albedo_2k.png | `705bf4a6ba2f18cef27991f1e020ac3ce998623ef9a4ecd7b1b8d9b3be41cd48` | `14417535f9a9eb2f93321a77342c8b5bf6a1465158cb6fe5e9cd758c5f5583ed` |
| textures/trunk_selva_bark_atlas_normal_2k.png | `5a1175b547ad0ccf14e5dfc39c9da3e33f00291886d8c49a48317ceef41bab57` | `90722ad6a069e57b636ec982db22b1413df87b9dade72deeda4cdb61c40ba7e5` |
| textures/trunk_selva_bark_atlas_orm_2k.png | `5fed65af1e686a8b6fc48d3276bcc809d57430e6b2f5b1cab55d3c4251ea87f2` | `2172a5ef24f0807a4774fcf3cd817a9956d5a68fbd96a0a0ad55bc049d5b73e9` |
| trunk_selva_kit_hp.blend | `5a1452702532f83b602eef7e52b7d89f4b47206242331d44944724a8226b38d6` | `4630500504307f8052d7ca5d1435b87a4d7a69f12c94976c68cb709a1fc5303b` |
| trunk_selva_kit_hp_LOD0.glb | `80561361e6df5056efd9677edab633768dfa9a0231af6598295f9e1389b0c784` | `5ac5a5b5f7c37db3c75d37b083f6d513905b494be46bb460c724974a5fa622ba` |
| trunk_selva_kit_hp_LOD1.glb | `ec19ab3d68410755059fd9773de7bef02081bedad422b3f0a1bd1ffd56a9ecfe` | `2ce349eeaf33578c11e28b1e823d592c150acf33a3e3b254c7f14aad0ae2cb32` |
| trunk_selva_kit_hp_LOD2.glb | `61bb3ae5e468b27a856165a70dad65e93ba9db472696cf1bc8a553c1d2879b16` | `8fc3fd7c77e4137a8b1803d17e1a7cd0003512d4b7788c95c9911635b451428c` |

  - v1 -> current SHA256 of every changed deliverable (v1 = the files Identidad reviewed; current = totem v2 + trunks v3):

| File | v1 SHA256 | current SHA256 |
|---|---|---|
| HP001_totem_34.png | `ab4945f20e358a1bfb67493311b8b34432e7c8eeb4a4fd14d4adacdcc925ef55` | `0589423c6caca19347944ebadf7a587c9f4f1daed84336f147c759ab0bf6296e` |
| HP001_totem_front.png | `f9334d05954403c41efcbb40606d032cfd7cadcdd2e9a93437a5884f02088035` | `238bc608ccc1a8d8365a5898e6f3b3e8cff2caea94a20a52d02abf9c78b2ea05` |
| HP001_totem_pods_closeup.png | `075da7071e5ba6c6984a3f76d3b51f0be28a406d030a7cefbf97fe064953c8ab` | `188884cdc0bd4aabfc71018e182624e20d998c36616749e9a21375f5fa3afffa` |
| HP001_trunks_34.png | `2a6593603a8059c147e74754cfcaba8ee3e99197bebd2c687d20198e4afc1af4` | `f2f7e577eb7d16f12724c7d5fd9a4bca40f404dcbcebb3acef9556b14339572f` |
| HP001_trunks_front.png | `9269b93a178af9006b68595083df18431c25e579da0c113dfc7b91c832c1f8bc` | `11b3a12fbd28220313f66f2013f5a6ab698ef4b35f6e653472437c9626b73531` |
| textures/totem_warp_cuyabeno_hp_albedo_1k.png | `bb90dc8d6b4120b03ce9888cf4e29679a2e8447f45f723eeadc49ef536880f8e` | `aaa4f4ad2a11117e37cb9e64ca1a60af1fa27b1e76fbe3274cd648c3a77dd04e` |
| textures/totem_warp_cuyabeno_hp_emission_1k.png | `617c2d2cc69924641d1c852646bcc86f94c2b331c6b70d22ce595b4af451ea03` | `92bc5efc52873720baa8cd5c16d5eb03755d2625882b891ba708e2d2d4544c1e` |
| textures/totem_warp_cuyabeno_hp_normal_1k.png | `f3d77bf27dd5f03d2484f02fe35f508922069bdbe98b40948af2361dfc6799a3` | `047117c0aad631c07cd11837103e0a531174c8469a2e31759a52bbd3febb6499` |
| textures/totem_warp_cuyabeno_hp_orm_1k.png | `9716c5075e24131e04552fb60a8095b512ca55d3d1b4a7ce27b3a957a79f8e75` | `42d90b823f167b3e9a790eb20d9d72387e3b21f8e6ef89129de0becf7b6fc9cd` |
| textures/trunk_selva_bark_atlas_albedo_2k.png | `0ec3dfdd42fbd62acd344cd9de4343b9b89817ef7b6fc36bd46161cdd09dcfbd` | `14417535f9a9eb2f93321a77342c8b5bf6a1465158cb6fe5e9cd758c5f5583ed` |
| textures/trunk_selva_bark_atlas_normal_2k.png | `fd43e5cc89dfe1e05257058009d35f3dfb3a266965d0fb52e7b4440351f65fd5` | `90722ad6a069e57b636ec982db22b1413df87b9dade72deeda4cdb61c40ba7e5` |
| textures/trunk_selva_bark_atlas_orm_2k.png | `1887d3656055c5bd1c4c95a74954af9c8fac20f9b0fe27513a6cc010a65cd493` | `2172a5ef24f0807a4774fcf3cd817a9956d5a68fbd96a0a0ad55bc049d5b73e9` |
| totem_warp_cuyabeno_hp.blend | `de62bfd72fb0a9e72b6fa54508d332c61bc8544839c771fd7403312221b6d70d` | `6a883c0b1f64f507cbd9d95cae0a8cdcc249390971dc84f0d52fd1c752ed951c` |
| totem_warp_cuyabeno_hp_LOD0.glb | `de5f6b22dab86bb4980570be5256601b713a96538e38d9941f39a23692d32b88` | `53a9660266ef561091cdc0991f09c00279f2d480c14909f91cc53829463ef791` |
| totem_warp_cuyabeno_hp_LOD1.glb | `12e6253bb36a2e7efdb6ec0ebace78faf540bbb93e177a1d1ef7916364fb8a5b` | `3a6580a03f0e221f5d52136d35d3058ae3223ed46b026171eca552d6b2258b07` |
| totem_warp_cuyabeno_hp_LOD2.glb | `00dc583c9dda9f89a47034e5ce0004beb6966e717ddb81043e61f2b6446d8ab3` | `57639a0f7dea8dc7f30d5fd918ff2d604ba962532ccf9dfe0bd829899c81b09e` |
| trunk_selva_kit_hp.blend | `007ce91e1d7feb6956d199d7e735e2344fda76c46f5ef7907c0dc89ee5f15bb7` | `8503b459d8959b16097513d3987f79ab31140347a2ea31be93c5a99f1f028e32` |
| trunk_selva_kit_hp_LOD0.glb | `7a075c9ddd1887f332d71cd7094534acf0d1b0169be010eec413f5a7ab3f4a09` | `a95c01da5b54e8238bcc5010dff9c86d894870cfeaa9f9cf3b723eff60b1fd73` |
| trunk_selva_kit_hp_LOD1.glb | `991d2b42ffa545798bc48cb1d104c15c6de5ce917d5660469caa6f88b5612541` | `b4ae905b5e962bf3f9b6320608ba6a876e7944138536ed49abb9c735b5c59bb3` |
| trunk_selva_kit_hp_LOD2.glb | `9a9f8e67c94744f128e28d06d6e684ba452a8371386ed5ef31f56a5820a53374` | `cb21854ca1aaa035bdf88ab01c398e796ff4a5c08acff34bdd161758688b0bc2` |
| HP001_trunks_bark_closeup.png | (new in v2) | `9cbf8c89fa9155d5c3d3c29c7dd997459bff6154fc406d54aad95358a1ed7be6` |

- **v1.1 pods (2026-10-06, totem only; labelled 'v2 pods' in the previous README)**: Identidad / Pista 3D feedback said two sharp ends read as gem/crystal and upright pods with the point on top read as flames/torch. The 3 pods now HANG like real cacao (cauliflory): peduncle (stem) end on TOP, attached by a short curved stem coming out of the chamfered crown underside, stem end a broad fully rounded shoulder, bottom a single BLUNT rounded nose (nose radius ~4 cm), fat ellipsoid body. The 10 ribs are now SUNKEN GROOVES cut into the geometry (V furrows, 9% of the local radius, alternating 1.0/0.75 depth) and reinforced in the albedo/normal/AO maps; the warty-but-smooth surface is kept. BeamOrigin re-centred on the new cluster; VFX_WarpBeam_Spawn unchanged at (0, 0, 3.03). Wood, lianas, footprint, pivot and the whole trunk kit are unchanged (trunk files not rebuilt).

## Triangles per LOD (read back from the exported GLBs)

| Piece / node | LOD0 | LOD1 | LOD2 | Budget LOD0/1/2 | OK |
|---|---|---|---|---|---|
| totem_warp_cuyabeno_hp `Totem_LODn` | 5872 | 2904 | 988 | 6000 / 3000 / 1000 | yes |
| trunk_selva_kit_hp `Trunk_Thin_LODn` | 3961 | 1967 | 521 | 4000 / 2000 / 600 | yes |
| trunk_selva_kit_hp `Trunk_Medium_LODn` | 3684 | 1588 | 563 | 4000 / 2000 / 600 | yes |
| trunk_selva_kit_hp `Trunk_Thick_LODn` | 3796 | 1785 | 579 | 4000 / 2000 / 600 | yes |

Totem tris by part (Blender build): LOD0 {'wood': 2088, 'pod': 2880, 'stem': 240, 'liana': 664}; LOD1 {'wood': 1000, 'pod': 1440, 'stem': 144, 'liana': 320}; LOD2 {'wood': 360, 'pod': 480, 'stem': 72, 'liana': 76}.

## Greybox vs HP: dims and pivot (Blender Z-up, metres; the GLBs are Y-up via the exporter)

| Item | Greybox `totem_warp_cuyabeno` | HP `Totem_LOD0` |
|---|---|---|
| Pivot | origin (0,0,0) = base centre, base on z=0 | origin (0,0,0) = base centre, base on z=0 (min z 0.0) |
| Footprint | 0.95 x 0.95 (Base_Step0, z 0..0.20) | 0.950 x 0.950 (rounded-square carved plinth, z 0..0.20; x/y -0.475..0.475) |
| Base | stepped plinth 0.95 / 0.72 | v2: 5 roots/buttresses (z 0..~0.64) fitted exactly to x/y +-0.475; no plinth |
| Shaft | 0.48 / 0.58 ledge / 0.40 wide | v2: irregular tapered trunk, mean dia ~0.52 @ z 0.5, ~0.45 @ z 1.5, ~0.42 @ z 2.3 (+-5-12% lobes) |
| Bands | raised mouldings (v1) | v2: 3 flat incised bands, 8 mm deep, z 0.55 / 1.50 / 2.20 |
| Crown | plate 0.50 wide @ z 2.49..2.61 | v2: chopped/sawn top, rim z 2.505..2.610 (slanted, broken notch) |
| Total height | 3.03 (cyan cone apex: TOTEM_TIP_Z 2.95 + 0.08) | 2.6098 (high point of the chopped top; locked by Pista 3D; pods hang below it, nothing above it). Inside the greybox z 0..3.03 envelope |
| Beam marker | `VFX_WarpBeam_Spawn` (0, 0, 3.03) | `BeamOrigin` (-0.0009, -0.22, 2.2783) (centre of the pod cluster); `VFX_WarpBeam_Spawn` kept at (0, 0, 3.03) only as a legacy empty (not wired; the beam uses BeamOrigin) |
| HP bbox LOD0 / LOD1 / LOD2 | - | {'min': [-0.475, -0.475, 0.0], 'max': [0.475, 0.475, 2.6098]} / {'min': [-0.475, -0.475, 0.0], 'max': [0.475, 0.475, 2.6098]} / {'min': [-0.475, -0.475, 0.0], 'max': [0.475, 0.475, 2.6098]} |

Greybox check: reference constants confirmed (TOTEM_TIP_Z 2.95, base 0.95x0.95x0.20, crown 0.50x0.50x0.12). Source: raw.githubusercontent.com/NadiaCoelloO/cacao-rush-3d/main/assets/scripts/bpy/totem_warp_cuyabeno.py (HTTP 200, byte-identical to /home/box/workspace/world-001/logs/ref_totem_warp_cuyabeno.py; nothing cloned).

Greybox bug (informational): the reference script rotates/scales some parts about the world origin after their transforms were already applied. Running it gives a raw LOD0 bbox of x[-0.475, 1.110] y[-0.475, 0.475] z[-0.561, 4.631]: the gold ovals land at x 0.57/1.10 (partly below ground) and the 5 cacao spheres float at z 4.06..4.63. The HP stays inside the intended envelope (base 0.95 x 0.95, crown 2.49..2.61, VFX 3.03, pivot at origin). The greybox crown spikes and cyan cone are deliberately not reproduced (no spiky shapes).

## Totem
- Pods: exactly 3 whole pods (separate closed islands, counted: LOD0 3, LOD1 3, LOD2 3). v2: each is one closed fat-ellipsoid loft HANGING from the crown underside: rounded stem shoulder on top, single blunt rounded nose at the bottom, 10 sunken longitudinal grooves (5 deeper + 5 shallower), smooth shading + Weighted Normal (face area). Centre (front, azimuth 270 deg): Kakaw yellow #D6AB3D, 0.31 m long, whole. Left (208 deg): orange #CE722E, 0.29 m. Right (332 deg): red #A64B36, 0.285 m. Each hangs 8-11 deg off vertical, away from the post, on a curved olive peduncle sunk into the crown wood and into the pod shoulder (attached, no gap).
- Pod segments (around x along): LOD0 40x13, LOD1 30x9, LOD2 20x5 (rings at equal silhouette arc length; grooves land exactly on vertex columns; LOD2 grooves are texture-only).
- Pod clearances (m, un-grooved envelope, conservative; post_min = gap to the carved post, liana_min = gap to the lianas, pods_max_abs_xy = max |x|,|y| of any pod, limit 0.475): {'Pod_Center_Yellow~Pod_Left_Orange': 0.1395, 'Pod_Center_Yellow~Pod_Right_Red': 0.1404, 'Pod_Left_Orange~Pod_Right_Red': 0.4031, 'post_min': 0.0177, 'liana_min': 0.2234, 'pods_max_abs_xy': 0.4414, 'stem_root_buried_min': 0.0156}.
- Soft emission: emissive map = albedo x 0.3 (sRGB), strength 1.0 (glTF emissiveTexture, emissiveFactor 1). No bloom, so form and colour stay readable.
- No spiky cards, fans, cones, flames or stars anywhere. No leaves.
- v2 post: hand-carved tree trunk (see revision log). Carving is abstract only: incised diamond lattice (z 0.66..1.36), 3 incised zigzag lines (z 1.70..2.10), 3 flat incised bands, adze facets along the grain, cracks. No faces, eyes, masks or facial symmetry.
- Footprint fit and checks: pods frozen (verify-only) {'Pod_Center_Yellow~Pod_Left_Orange': 0.1395, 'Pod_Center_Yellow~Pod_Right_Red': 0.1404, 'Pod_Left_Orange~Pod_Right_Red': 0.4031, 'post_min': 0.0177, 'liana_min': 0.2234, 'pods_max_abs_xy': 0.4414, 'stem_root_buried_min': 0.0156}.
- Lianas: 2 olive lianas (1 in LOD2) authored as Bezier curves (kept hidden in collection `Source_Curves_Lianas` of the .blend) and converted to mesh.
- One material `M_Totem_HP`, 1K atlas (wood | liana | pods in Y/O/R rows): Albedo, Normal (OpenGL +Y), ORM (R=AO, G=roughness, B=metallic), Emission. Opaque.

## Trunk kit
- 3 variants: Thin 8 m / Medium 11 m / Thick 14 m above the water, with 3/4/5 buttress (tablar) fins reaching ~0.6/1.15/2.0 m. Base z=0 = waterline; roots and fins continue to z=-0.5, with an open bottom under water. Fork limbs at the top (all LODs) ending in broken mossy stubs, bare, for the E2 canopy attachment.
- Life (v3): 2 compact bromeliad rosettes per variant hugging the shaft at mid-height (short, broad, cupped, rounded leaves in a tight vase; LOD0 8 leaves, LOD1 6; none in LOD2). Nothing on the fork tops: the broken mossy stubs are bare for the E2 canopy. 2 lianas per variant in LOD0/LOD1 (one loose catenary loop from a fork limb back into the trunk, one drape hanging almost to the water; 3-5 cm thick); none in LOD2. Shaft irregularity (lobes/ridges/burls) is in all LODs.
- Per-variant checks (Blender build):
  - `Thin_LOD0`: 3961 tris {'trunk': 2706, 'cap': 33, 'limb': 130, 'epiphyte': 1092}; rosettes z 3.76 m az -54.4 deg 0.45 m across x 0.24 m tall, z 4.96 m az 157.6 deg 0.46 m across x 0.23 m tall; leaf points > 3 cm inside bark 0 (min gap -0.005 m); liana-to-leaf min 0.674 m; lianas loop z 7.93->2.74 (end 3.04) dia 4.0-3.2 cm clearance 0.087 m, hang z 7.66->1.1 (end 1.1) dia 3.8-3.0 cm clearance 0.598 m
  - `Medium_LOD0`: 3684 tris {'trunk': 2288, 'cap': 44, 'limb': 260, 'epiphyte': 1092}; rosettes z 4.95 m az -65.9 deg 0.51 m across x 0.28 m tall, z 6.6 m az -8.6 deg 0.53 m across x 0.27 m tall; leaf points > 3 cm inside bark 0 (min gap -0.005 m); liana-to-leaf min 0.422 m; lianas loop z 10.78->3.91 (end 4.62) dia 4.6-3.6 cm clearance 0.103 m, hang z 10.55->0.45 (end 0.45) dia 4.4-3.4 cm clearance 0.239 m
  - `Thick_LOD0`: 3796 tris {'trunk': 2392, 'cap': 52, 'limb': 260, 'epiphyte': 1092}; rosettes z 5.18 m az -71.6 deg 0.61 m across x 0.31 m tall, z 7.84 m az 2.9 deg 0.56 m across x 0.32 m tall; leaf points > 3 cm inside bark 0 (min gap -0.011 m); liana-to-leaf min 0.137 m; lianas loop z 13.9->4.67 (end 5.6) dia 5.0-3.8 cm clearance 0.131 m, hang z 13.41->0.6 (end 0.6) dia 5.0-3.8 cm clearance 1.005 m
  - `Thin_LOD1`: 1967 tris {'trunk': 1400, 'cap': 25, 'limb': 54, 'epiphyte': 488}; rosettes z 3.76 m az -54.4 deg 0.45 m across x 0.24 m tall, z 4.96 m az 157.6 deg 0.45 m across x 0.23 m tall; leaf points > 3 cm inside bark 0 (min gap -0.012 m); liana-to-leaf min 0.641 m; lianas loop z 7.93->2.74 (end 3.04) dia 4.0-3.2 cm clearance 0.133 m, hang z 7.66->1.1 (end 1.1) dia 3.8-3.0 cm clearance 0.684 m
  - `Medium_LOD1`: 1588 tris {'trunk': 960, 'cap': 32, 'limb': 108, 'epiphyte': 488}; rosettes z 4.95 m az -65.9 deg 0.49 m across x 0.27 m tall, z 6.6 m az -8.6 deg 0.52 m across x 0.28 m tall; leaf points > 3 cm inside bark 0 (min gap -0.01 m); liana-to-leaf min 0.42 m; lianas loop z 10.78->3.91 (end 4.62) dia 4.6-3.6 cm clearance 0.164 m, hang z 10.55->0.45 (end 0.45) dia 4.4-3.4 cm clearance 0.231 m
  - `Thick_LOD1`: 1785 tris {'trunk': 1148, 'cap': 41, 'limb': 108, 'epiphyte': 488}; rosettes z 5.18 m az -71.6 deg 0.6 m across x 0.32 m tall, z 7.84 m az 2.9 deg 0.56 m across x 0.3 m tall; leaf points > 3 cm inside bark 0 (min gap -0.022 m); liana-to-leaf min 0.183 m; lianas loop z 13.9->4.68 (end 5.6) dia 5.0-3.8 cm clearance 0.217 m, hang z 13.41->0.6 (end 0.6) dia 5.0-3.8 cm clearance 1.0 m
  - `Thin_LOD2`: 521 tris {'trunk': 480, 'cap': 16, 'limb': 25}
  - `Medium_LOD2`: 563 tris {'trunk': 494, 'cap': 19, 'limb': 50}
  - `Thick_LOD2`: 579 tris {'trunk': 506, 'cap': 23, 'limb': 50}
- Bark colour, measured on the albedo atlas (sRGB mean colour -> HSV; target hue 28-35 deg, sat <= 0.2): atlas_B_dry_bark_all: RGB [65, 60, 55] hue 29.2 sat 0.164 (median hue 29.7, median sat 0.164); atlas_B_bark_without_lichen: RGB [65, 60, 55] hue 29.2 sat 0.164 (median hue 29.7, median sat 0.164); atlas_shaft_rows_300_1792_excl_moss_band: RGB [66, 61, 55] hue 29.5 sat 0.163 (median hue 29.7, median sat 0.164); atlas_A_stain_moss_band: RGB [46, 51, 33] hue 76.0 sat 0.356 (median hue 75.3, median sat 0.346); lichen cover in the tiling shaft rows 0.0.
- Bark colour, measured on the rendered stills (mean of 9x9 px patches on the lit bark facing the camera, display sRGB; patches hidden behind leaves/lianas are skipped by a ray test): HP001_trunks_front.png: 24 patches (0 occluded skipped), RGB [90, 86, 82] hue 30.8 sat 0.093 (median hue 30.0, median sat 0.107); HP001_trunks_34.png: 24 patches (0 occluded skipped), RGB [91, 85, 78] hue 29.8 sat 0.144 (median hue 30.0, median sat 0.152); HP001_trunks_bark_closeup.png: 3 patches (6 occluded skipped), RGB [93, 87, 79] hue 34.0 sat 0.154 (median hue 33.8, median sat 0.157).
- Pivot at base centre (0,0,0). Every node has an identity transform in the GLB, so it is MultiMesh-ready (the 3 nodes overlap at the origin by design).
- One shared material `M_Bark_HP` and one 2K bark atlas (Albedo/Normal/ORM). Rows 0..511: lower trunk/buttresses (waterline at row ~102 = z 0, dark water-stain band with patchy moss up to row ~206 and moss tongues/patches to ~290, lichen crusts above it; same bark scale as the shaft; fin walls mapped planar, mirrored about each crest (no crest seam; small U step hidden in the root crease)). Rows 512..1792: dry plated/fissured bark tiling in U and V (repeated per tile: Thin 0.60 m, Medium 1.10 m, Thick 1.90 m, restarted per face corner so verts are not split). Rows 1793..2047: x 0..1479 limb/cap bark with moss (top ~20 % = broken stub ends: moss + splintered dark wood, also used by the break faces), x 1480..2047 epiphyte leaves (top) and lianas (bottom).
- `Trunk_Thin_LOD0` bbox (Z-up) min (-0.5518, -0.4382, -0.5) max (1.0325, 0.9865, 8.1952)
- `Trunk_Medium_LOD0` bbox (Z-up) min (-1.3589, -1.5012, -0.5) max (1.5117, 1.3537, 11.0834)
- `Trunk_Thick_LOD0` bbox (Z-up) min (-2.6276, -2.6514, -0.5) max (2.3752, 2.1528, 14.3917)

## Textures (self-made with procedural numpy in this script; CC0; no external sources)

| File | Size | Format | Bytes | SHA256 |
|---|---|---|---|---|
| textures/totem_warp_cuyabeno_hp_albedo_1k.png | 1024x1024 | PNG RGB 8-bit | 857840 | `aaa4f4ad2a11117e37cb9e64ca1a60af1fa27b1e76fbe3274cd648c3a77dd04e` |
| textures/totem_warp_cuyabeno_hp_emission_1k.png | 1024x1024 | PNG RGB 8-bit | 116183 | `92bc5efc52873720baa8cd5c16d5eb03755d2625882b891ba708e2d2d4544c1e` |
| textures/totem_warp_cuyabeno_hp_normal_1k.png | 1024x1024 | PNG RGB 8-bit | 1359661 | `047117c0aad631c07cd11837103e0a531174c8469a2e31759a52bbd3febb6499` |
| textures/totem_warp_cuyabeno_hp_orm_1k.png | 1024x1024 | PNG RGB 8-bit | 825371 | `42d90b823f167b3e9a790eb20d9d72387e3b21f8e6ef89129de0becf7b6fc9cd` |
| textures/trunk_selva_bark_atlas_albedo_2k.png | 2048x2048 | PNG RGB 8-bit | 3056278 | `14417535f9a9eb2f93321a77342c8b5bf6a1465158cb6fe5e9cd758c5f5583ed` |
| textures/trunk_selva_bark_atlas_normal_2k.png | 2048x2048 | PNG RGB 8-bit | 7001173 | `90722ad6a069e57b636ec982db22b1413df87b9dade72deeda4cdb61c40ba7e5` |
| textures/trunk_selva_bark_atlas_orm_2k.png | 2048x2048 | PNG RGB 8-bit | 3509780 | `2172a5ef24f0807a4774fcf3cd817a9956d5a68fbd96a0a0ad55bc049d5b73e9` |

The .blend files reference the textures with relative paths (`//textures/...`). The GLBs embed their textures, so they are self-contained.

## GLB readback

- `totem_warp_cuyabeno_hp_LOD0.glb`: nodes [BeamOrigin @ [-0.0009, 2.2783, 0.22], Totem_LOD0 (5872 tris), VFX_WarpBeam_Spawn @ [0, 3.03, 0], Totem_Warp_Cuyabeno_HP @ [0, 0, 0]]; images [totem_warp_cuyabeno_hp_emission_1k 1024x1024, totem_warp_cuyabeno_hp_normal_1k 1024x1024, totem_warp_cuyabeno_hp_orm_1k 1024x1024, totem_warp_cuyabeno_hp_albedo_1k 1024x1024]; materials [M_Totem_HP alpha=OPAQUE normal=True occl+MR=True emissiveTex=True]; extensions []; Y-up bounds [-0.475, 0, -0.475]..[0.475, 2.61, 0.475]
- `totem_warp_cuyabeno_hp_LOD1.glb`: nodes [BeamOrigin @ [-0.0009, 2.2783, 0.22], Totem_LOD1 (2904 tris), VFX_WarpBeam_Spawn @ [0, 3.03, 0], Totem_Warp_Cuyabeno_HP @ [0, 0, 0]]; images [totem_warp_cuyabeno_hp_emission_1k 1024x1024, totem_warp_cuyabeno_hp_normal_1k 1024x1024, totem_warp_cuyabeno_hp_orm_1k 1024x1024, totem_warp_cuyabeno_hp_albedo_1k 1024x1024]; materials [M_Totem_HP alpha=OPAQUE normal=True occl+MR=True emissiveTex=True]; extensions []; Y-up bounds [-0.475, 0, -0.475]..[0.475, 2.61, 0.475]
- `totem_warp_cuyabeno_hp_LOD2.glb`: nodes [BeamOrigin @ [-0.0009, 2.2783, 0.22], Totem_LOD2 (988 tris), VFX_WarpBeam_Spawn @ [0, 3.03, 0], Totem_Warp_Cuyabeno_HP @ [0, 0, 0]]; images [totem_warp_cuyabeno_hp_emission_1k 1024x1024, totem_warp_cuyabeno_hp_normal_1k 1024x1024, totem_warp_cuyabeno_hp_orm_1k 1024x1024, totem_warp_cuyabeno_hp_albedo_1k 1024x1024]; materials [M_Totem_HP alpha=OPAQUE normal=True occl+MR=True emissiveTex=True]; extensions []; Y-up bounds [-0.475, 0, -0.475]..[0.475, 2.61, 0.475]
- `trunk_selva_kit_hp_LOD0.glb`: nodes [Trunk_Medium_LOD0 (3684 tris), Trunk_Thick_LOD0 (3796 tris), Trunk_Thin_LOD0 (3961 tris)]; images [trunk_selva_bark_atlas_normal_2k 2048x2048, trunk_selva_bark_atlas_orm_2k 2048x2048, trunk_selva_bark_atlas_albedo_2k 2048x2048]; materials [M_Bark_HP alpha=OPAQUE normal=True occl+MR=True emissiveTex=False]; extensions []; Y-up bounds [-2.628, -0.5, -2.153]..[2.375, 14.392, 2.651]
- `trunk_selva_kit_hp_LOD1.glb`: nodes [Trunk_Medium_LOD1 (1588 tris), Trunk_Thick_LOD1 (1785 tris), Trunk_Thin_LOD1 (1967 tris)]; images [trunk_selva_bark_atlas_normal_2k 2048x2048, trunk_selva_bark_atlas_orm_2k 2048x2048, trunk_selva_bark_atlas_albedo_2k 2048x2048]; materials [M_Bark_HP alpha=OPAQUE normal=True occl+MR=True emissiveTex=False]; extensions []; Y-up bounds [-2.609, -0.5, -2.153]..[2.375, 14.364, 2.651]
- `trunk_selva_kit_hp_LOD2.glb`: nodes [Trunk_Medium_LOD2 (563 tris), Trunk_Thick_LOD2 (579 tris), Trunk_Thin_LOD2 (521 tris)]; images [trunk_selva_bark_atlas_normal_2k 2048x2048, trunk_selva_bark_atlas_orm_2k 2048x2048, trunk_selva_bark_atlas_albedo_2k 2048x2048]; materials [M_Bark_HP alpha=OPAQUE normal=True occl+MR=True emissiveTex=False]; extensions []; Y-up bounds [-2.595, -0.5, -2.153]..[2.375, 14.362, 2.651]

## Stills (Blender EEVEE, 1920x1080 RGB; LOD0 left, LOD2 right; the close-ups show LOD0 only; `HP001_trunks_bark_closeup.png` = Thick LOD0 base: waterline, moss band, lichen)

| File | Size | Magenta px | Bytes | SHA256 |
|---|---|---|---|---|
| HP001_totem_34.png | 1920x1080 RGB | 0 | 1823995 | `0589423c6caca19347944ebadf7a587c9f4f1daed84336f147c759ab0bf6296e` |
| HP001_totem_front.png | 1920x1080 RGB | 0 | 1845575 | `238bc608ccc1a8d8365a5898e6f3b3e8cff2caea94a20a52d02abf9c78b2ea05` |
| HP001_totem_pods_closeup.png | 1920x1080 RGB | 0 | 1971364 | `188884cdc0bd4aabfc71018e182624e20d998c36616749e9a21375f5fa3afffa` |
| HP001_trunks_34.png | 1920x1080 RGB | 0 | 1937837 | `f2f7e577eb7d16f12724c7d5fd9a4bca40f404dcbcebb3acef9556b14339572f` |
| HP001_trunks_bark_closeup.png | 1920x1080 RGB | 0 | 2113621 | `9cbf8c89fa9155d5c3d3c29c7dd997459bff6154fc406d54aad95358a1ed7be6` |
| HP001_trunks_front.png | 1920x1080 RGB | 0 | 1925508 | `11b3a12fbd28220313f66f2013f5a6ab698ef4b35f6e653472437c9626b73531` |

## SHA256 (.glb / .blend)

| File | Bytes | SHA256 |
|---|---|---|
| totem_warp_cuyabeno_hp_LOD0.glb | 3304776 | `53a9660266ef561091cdc0991f09c00279f2d480c14909f91cc53829463ef791` |
| totem_warp_cuyabeno_hp_LOD1.glb | 3235476 | `3a6580a03f0e221f5d52136d35d3058ae3223ed46b026171eca552d6b2258b07` |
| totem_warp_cuyabeno_hp_LOD2.glb | 3189572 | `57639a0f7dea8dc7f30d5fd918ff2d604ba962532ccf9dfe0bd829899c81b09e` |
| trunk_selva_kit_hp_LOD0.glb | 13878304 | `a95c01da5b54e8238bcc5010dff9c86d894870cfeaa9f9cf3b723eff60b1fd73` |
| trunk_selva_kit_hp_LOD1.glb | 13728576 | `b4ae905b5e962bf3f9b6320608ba6a876e7944138536ed49abb9c735b5c59bb3` |
| trunk_selva_kit_hp_LOD2.glb | 13629056 | `cb21854ca1aaa035bdf88ab01c398e796ff4a5c08acff34bdd161758688b0bc2` |
| totem_warp_cuyabeno_hp.blend | 1538346 | `6a883c0b1f64f507cbd9d95cae0a8cdcc249390971dc84f0d52fd1c752ed951c` |
| trunk_selva_kit_hp.blend | 2308853 | `8503b459d8959b16097513d3987f79ab31140347a2ea31be93c5a99f1f028e32` |

## Notes
- Two blend files: `totem_warp_cuyabeno_hp.blend` (collections `Totem_Warp_Cuyabeno_HP`, `Source_Curves_Lianas` hidden, `Stage_Stills`) and `trunk_selva_kit_hp.blend` (`Trunk_Selva_Kit_HP`, `Stage_Stills`). Stage objects (ground, backdrop, lights, cameras, labels, still instances) are never exported.
- Idempotent: the script starts from an empty factory scene and overwrites every output. Textures (custom PNG writer) and GLBs are byte-reproducible. .blend and EEVEE PNG bytes can differ between runs (file headers, sampling); their content is the same.
- Not done, by instruction: no git clone/push, no Godot wiring, no PR or branch changes, no messages to other agents.
