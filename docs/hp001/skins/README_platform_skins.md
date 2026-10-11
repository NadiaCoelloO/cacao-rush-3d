# HP-001 E3 Cuyabeno: platform skins (chunk 2)

These skins are visual only. They sit on the existing selva-1 collision boxes and add no collision. Built with Blender 5.2.1 (`platform_skins_cuyabeno.py`, seed 3101).
To rebuild: `blender -b --python platform_skins_cuyabeno.py -- --out <dir> --maya hero_grey.glb`. The script exits 1 if a piece goes over budget, leaves its box, or a still has magenta pixels.

## Source (read only, raw HTTP and connector, no clone)
The source is NadiaCoelloO/cacao-rush-3d @ 2191c381a7dda6ea18ea8ef265c86bcd5c0deb5e (PR#6, cursor/hp001-e1-cuyabeno).
- `runtime/data/selva1_layout.json`: platforms[] center_m / size_m / top_m, and pickups[] (24 beans, radius 0.5).
- `runtime/scripts/selva1_play.gd`: `_add_box` builds a BoxShape3D of size_m with the body at center_m. `_add_lip` adds a visual lip box on every platform top: h = min(0.16, 0.4*h), top 0.01 above top_m. Beans are spheres r 0.22 scaled (1.18, 2.28, 0.32).
- `assets/greybox/heroes/hero_grey.glb`: git blob 11011ccf, verified. Used only for the scale still.

## Box dimensions used (Godot x, y, z in m, depth z always 2.6667)
- Oneway P01/P07/P10: 4.0 x 0.6667. P16: 6.6667 x 0.75.
  The earlier note "4x0.18x2 at (6,1,0)" is the pilot feel-harness CSGOneway. It is disabled in selva-1 and was not used.
- Solid: 21 platforms. Solid widths are 4.0 / 8.0 / 9.33 / 10.67 / 13.33 / 18.67, and heights run from 2.67 to 28.
- Lip: there is no "lip" platform kind. The lip is the 0.16 m top band that `_add_lip` puts on every box. `Lip_2m` skins that band.

## Pieces, pivots and tiling
For every piece the pivot is the top face of the collision box: x is the segment centre (for modules) or the box end (for caps), z = 0 at the box depth centre, and y = top_m. No vertex is above the pivot, so the grain surface is clear.
- To tile a box of width W: place a CapL at the left end and a CapR at the right end (each 0.3333 m inside the box). Between them place N = round((W-0.6667)/2) `*_2m` modules with X scale s = (W-0.6667)/(2N). The scale stays in the range 0.83–1.17 for every selva-1 box.
- `Solid_Top_*`: covers the top 1.3333 m. It has a litter top (z = 0 exactly), a lighter rounded front edge, a wet-earth face, half-tube roots and moss cards.
- `Solid_Fill_*`: a 2 m face tile placed below the top piece. Scale the last tile in Z to land on the box bottom (or let it go off-screen).
- `Oneway_*`: a hewn log plank with a flat adze-cut top at z = 0, a round bark belly down to -0.667, end-grain caps and moss. For P16 (h 0.75), use Z scale 1.125.
- `Lip_*`: the 0.35 m front strip of the top. It has a moss rim with a crisp r = 0.06 edge. The band is 0.16 deep and its moss strands hang to -0.40, which stays inside every box (minimum h 0.667). Under the lip strip, `Solid_Top` dips 12 mm so the two pieces never z-fight.

## Tris (budget per piece 1500 / 600 / 200)
| piece | LOD0 | LOD1 | LOD2 |
|---|---|---|---|
| Solid_Top_2m | 614 | 120 | 6 |
| Solid_Top_CapL / R | 130 | 23 | 10 |
| Solid_Fill_2m | 226 | 52 | 2 |
| Solid_Fill_CapL / R | 20 | 12 | 4 |
| Oneway_2m | 214 | 50 | 10 |
| Oneway_CapL / R | 37 | 22 | 13 |
| Lip_2m | 122 | 52 | 8 |
| Lip_CapL / R | 20 | 17 | 11 |
GLB totals: LOD0 1590, LOD1 422, LOD2 102.

## Box-fit check (local vertex bounds, all pass; full list in platform_skins_report.json)
- x stays within [-1, 1] for modules, [0, 0.3333] for CapL and [-0.3333, 0] for CapR.
- y (depth) stays within ±1.3333.
- Maximum z is 0.0 for every piece, so nothing protrudes above the top. Minimum z is ≥ -1.3333 (Top), -2.0 (Fill), -0.667 (Oneway) and -0.405 (Lip).
- The GLB position max Y is ≤ 0 for all nodes.

## Material and texture
- One material, `M_PlatformSkins_Cuyabeno`: glTF alphaMode MASK (default cutoff 0.5), double-sided, roughness 0.62. No blend.
- One atlas, `textures/T_PlatformSkins_Cuyabeno_A.png` (1024², RGBA, embedded in the GLBs). It has 0 magenta texels. Regions: earth, litter, bark, hewn wood, light edge, lip moss, end grain and a moss card.
- Palette: earth #3E2C20, cool browns, deep moss #34502F. There is no yellow, orange or red, so nothing competes with the pods.

## Stills (0 magenta pixels each)
- `HP001_platform_skins_front.png`: the collision boxes are ghosted in wire.
- `HP001_platform_skins_34.png`
- `HP001_platform_skins_closeup.png`
- `HP001_platform_skins_scale_maya.png`: selva-1 entrance (P00 + P01) through the game camera (fov 50, offset 0, 1, 24.13), with greybox Maya and the beans at their layout positions plus a grain marker on the top.
- `HP001_platform_skins_scale_maya_close.png`

## Warnings
1. From the low game camera, the oneway belly reads quite dark (front and scale stills). Godot ambient and fill should lift it, or the bark atlas region could be brightened.
2. There is a faint tone seam between Solid_Top and Solid_Fill at -1.333 m.
3. The moss cards read a bit like a barcode in the closeup.
4. Tops are texture-only (litter and moss) because nothing may rise above the top. The roots and moss are on the faces.
5. Maya in the scale still is the 2.04 m greybox. Her height and rig are still open with Pista.


## v2 (Oct 11): Identidad NO PASA fixes
Unchanged and approved: the top leaf litter, the #3E2C20 earth face with moss, pivots, the tiling rule, depth 2.6667 and z <= 0 everywhere. The box-fit check still passes for every piece.
1. **Lip:** the smooth green slab is gone. The edge is now irregular earth: it is broken inward by up to 35 mm, crumbled down by up to 45 mm, and the lip top dips 12 mm in its front 0.12 m. The moss is patchy (texture), with no continuous band and no bright rim line. Tufts have varying tip heights, all at or below -0.006. There are 2 poking roots per module and 3 leaves draped over the edge per module (they lie in the dipped zone, so nothing goes above the top). The solid's rounded edge uses the same patchy texture, so no light band shows through.
2. **Hanging moss:** 3 groups per module with gaps between them. Each group has 3 cards of very different lengths (0.11 to 0.9 m). Strands are tapered and curved, mixed with fine light-brown rootlets.
3. **Roots:** smooth cubic curves going down. Radius tapers from about 5 cm to 4 mm. About half of the roots fork once (LOD0). Each root shows only 55% of its radius above the earth face; the rest is buried. The bark stripes run along the root.
4. **Top/Fill seam:** the lower half of the earth atlas repeats every 256 rows, so both joins (Top to Fill and Fill to Fill) use identical texel rows. The grid row next to each join is flat, so the join normals match exactly. Measured in the front still at the join: v1 had a step from 50.6 to 37.3 (luma); v2 runs 44.0 > 43.5 > 42.5 with no step. No vertex colour or AO is needed.
5. **New stills:** HP001_platform_skins_oneway_front.png and HP001_platform_skins_oneway_34.png. They use a close camera, a key light and a soft bounce light from below (Bounce_Under, look-only), so the log belly is lit, not black.

The front, 3/4, closeup and scale_maya stills were re-rendered (greybox Maya). All stills have 0 magenta pixels.

### v2 tris (budget 1500 / 600 / 200)
| piece | LOD0 | LOD1 | LOD2 |
|---|---|---|---|
| Solid_Top_2m | 820 | 134 | 6 |
| Solid_Top_CapL | 152 | 23 | 10 |
| Solid_Top_CapR | 152 | 23 | 10 |
| Solid_Fill_2m | 290 | 64 | 2 |
| Solid_Fill_CapL | 20 | 12 | 4 |
| Solid_Fill_CapR | 20 | 12 | 4 |
| Oneway_2m | 214 | 50 | 10 |
| Oneway_CapL | 37 | 22 | 13 |
| Oneway_CapR | 37 | 22 | 13 |
| Lip_2m | 326 | 100 | 10 |
| Lip_CapL | 34 | 17 | 14 |
| Lip_CapR | 34 | 17 | 14 |

GLB totals: LOD0 2136, LOD1 496, LOD2 110.

### v1 -> v2 log (old v1 SHA256; all of these files changed)
d86643106b173a8aecd97e06b29ec9700934b97b5ae7f2564fc19a6f14f114a7  platform_skins_cuyabeno.py
11ced7551582ef402530153e4af78850ffa4d11dc4b0698f12790993467a0294  platform_skins_cuyabeno.blend
e05a41b4f9a78ad5a1a3857be3d725b6218190fc8548a35316e42d1782a49997  platform_skins_cuyabeno_LOD0.glb
6c4122c3849ed43b01a6ce596db48054ed40b23471a6e6932f541cfa7a084955  platform_skins_cuyabeno_LOD1.glb
84e890dd7a61f576dd7764c6ab55feae869c456233e85d954292381fbdad4013  platform_skins_cuyabeno_LOD2.glb
d37e21f7abe97147776243ee26551b498857353e636dd11d3a4823f3ebbf67ea  platform_skins_report.json
ed221c9223be53e85687c3c0059f67d3c5af299bb6ff8e006fd86a7aa1b8c535  textures/T_PlatformSkins_Cuyabeno_A.png
ebea4780d37f62802d8138a4f4736555be3f155ae0c1eea07948db4120f492b9  HP001_platform_skins_front.png
fb7cb57e04b8ab405bf3b91c32e257cc1092d89a6d6353c5cd7513e5e1ff22bd  HP001_platform_skins_34.png
eaa74b781de27139801ccb552ea7bd20d5fb2ffb42219e42d9f50cbfb3ac1fd8  HP001_platform_skins_closeup.png
4a212b1dd52c0020e1aa26121b90d08ca53e4539be9e1260b7afb6a71eb6efc4  HP001_platform_skins_scale_maya.png
fa7f679f353156184c57072afc6eb8c3f93e530453cb6bef5c5339400cdf6907  HP001_platform_skins_scale_maya_close.png

### v2 warnings
- The lip still reads as a rim along the edge, but it is broken, earthy and patchy, not a slab. The tufts and leaves are small at gameplay distance.
- The Bounce_Under light leaves a bright patch on the P00 face in the scale_maya still. It is look-only; in Godot, use ambient light instead.
- The oneway bark texture reads as horizontal stripes when seen straight on.


## v2.1 (Oct 11): review fixes
Pivots, the tiling rule (caps + N scaled modules), budgets and z <= 0 are unchanged. The box-fit check passes for every piece. Roots are kept as in v2.
1. **Lip:** the rounded rail is gone. Solid_Top's flat top now stops 0.40 m behind the box front, and its earth face starts 0.30 m below the top. Lip_* is the earth top itself breaking down into the face: a 6-row surface whose brink sits 3-15 cm behind the front (scallops and bites), with a small overhang/undercut and crumble. Every row varies along X, and the noise continues across cap/module joins. Moss is in separate patches with bare earth between them. There are tufts of different heights, 2 roots curling out and 3 drooping leaves per module.
   **New rule: Lip_* is REQUIRED on every solid top**, because Solid_Top no longer has its own front edge.
2. **Hanging moss:** 3 clumps per module (2 at LOD1): a short tuft, a long beard and a mid clump, with gaps between them. Strands splay and curve from a small root mass, taper to fine tips and have very different lengths. They use olive #3C4027 and brown #4C3E2E with light-brown rootlets #7A6650.
3. **One-way:** a round log, r about 0.335 m, sitting at the box depth centre (where the grains are). It has an adzed flat top at z = 0 (about 0.25 m wide), rounded bark sides and belly, a slight bow and swelling, and bark with broken lens fissures along its length (no continuous stripes). There are 2 knots, a broken branch stub and a moss clump per module, moss on the upper bark sides, and rings on the end caps.
   **Footprint note:** the log now fills only about 0.67 m of the 2.67 m box depth. It is still inside the box (box-fit passes), but it no longer covers the full collision depth.

### v2.1 tris (budget 1500 / 600 / 200)
| piece | LOD0 | LOD1 | LOD2 |
|---|---|---|---|
| Solid_Top_2m | 728 | 106 | 4 |
| Solid_Top_CapL | 133 | 15 | 7 |
| Solid_Top_CapR | 133 | 15 | 7 |
| Solid_Fill_2m | 290 | 64 | 2 |
| Solid_Fill_CapL | 20 | 12 | 4 |
| Solid_Fill_CapR | 20 | 12 | 4 |
| Oneway_2m | 397 | 115 | 12 |
| Oneway_CapL | 78 | 28 | 16 |
| Oneway_CapR | 78 | 28 | 16 |
| Lip_2m | 464 | 140 | 12 |
| Lip_CapL | 55 | 25 | 10 |
| Lip_CapR | 55 | 25 | 10 |

GLB totals: LOD0 2451, LOD1 585, LOD2 104.

### v2 -> v2.1 log (old v2 SHA256; all of these files changed)
46e9eef45ad2de905deaa69bc8d2afcb4edb08a7cc58b56d0c71f0200151b3e1  platform_skins_cuyabeno.py
d28188240d44c8e8c15c16d80ab60ba16b11d92a89a51feec40f51f76654ce81  platform_skins_cuyabeno.blend
e8066ed27289edad2cb5ae8ad59261579afb2eab915ecdec23d079671e4d248b  platform_skins_cuyabeno_LOD0.glb
d90657ec1d427a749c9d3f8bd89d3349c2ec021adfda0405cbdfb492ddb243bd  platform_skins_cuyabeno_LOD1.glb
be8a9d3dc235b332c7348264b23e1f1a4ca76d905ed349fe586088e90de135db  platform_skins_cuyabeno_LOD2.glb
6923587fb5aa6eb036c5dc1f0b688fd88c492c344cd496cb6063b282df56807b  platform_skins_report.json
5ee4dd166a63cdac23a68678e1d67e5fa533c74fe9a2786fd5035461ddf83e22  textures/T_PlatformSkins_Cuyabeno_A.png
d805c2ac7dafa456c51e89ef118e22bfd095b157a949b360414292611c8ecf7f  HP001_platform_skins_front.png
549e4a0086cc03e02067949515d923640a2d2c95393397f3648bcc0021a86bb2  HP001_platform_skins_34.png
d03a58156829571f615d584f4b15ac6eb5d5948fb673c709d2e02f7151b587c3  HP001_platform_skins_closeup.png
aa4eed19d547ad89d8014e997d1822ace30883653f6ced40febfc5de59c86d1d  HP001_platform_skins_oneway_front.png
f64d90eea424f7bbf50bab451fd0c42bb357b44ca7a2f8524a3a24f35224aaab  HP001_platform_skins_oneway_34.png
b666d130cc790104694d48fbbbf4eb5fbdc5f28b6855c6330136dc269573a1b3  HP001_platform_skins_scale_maya.png
719ab74c8673f273597e6c919751d301e0a6c8b95b38e34958cffe9fa25d3ecd  HP001_platform_skins_scale_maya_close.png

### v2.1 self-review / warnings
- **Lip:** no tube, and the outline varies along X. It now reads as a wide, sloped, crumbly earth bevel. The tufts and leaves are small and hard to see.
- **Hanging moss:** the clumps splay and curve now, but they are still small and sparse. The long beard does not read as long in the stills. This needs another pass (denser, longer strands).
- **One-way:** clearly a log now, with rings, knots and a stub. Under the stage lights the bark is a bit pale, and a faint texture seam shows at the cap/module joins.
- The Bounce_Under light still leaves a bright patch on the P00 face in the scale_maya still (look-only).


## v2.2 (Oct 11): hanging moss, plus bark tone and cap seam
The lip, one-way, root and solid geometry are unchanged.
- **Hanging moss** moved from Solid_Top into Lip_*. Each module has 3 bundles (2 at LOD1) draping from the lip crumble: about 0.15 m, 0.4 m and a 0.9 m beard, with bare gaps between them.
  - Each bundle is a clustered fan of 6 alpha-scissor strand cards (3 at LOD1). Each card has 2 segments with a sideways sway and slight fan-out.
  - The cards sit 2.5 to 20 mm inside the box front.
  - The strand texture (the clump tile of the card area in the atlas) is 150 tapered, curved strands: dense at the top and splitting into wisps lower down. Colours are olive #3C4027, moss #34502F and brown #4C3E2E, with 14 light-brown rootlets #8A735A.
  - LIP_DROP (the lip's box-fit depth) is now 1.10 m. The lip is only used on solids, and the shortest solid is 2.67 m tall.
- **One-way bark** is warmer and darker (#41332A, was #4A3D33). Roots use the same bark colour.
- **One-way cap seam:** the caps now continue the module's bark u coordinate across the join, so the texture is continuous at cap/module boundaries.

### v2.2 tris
- Lip_2m 536 / 158 / 12 (budget 1500 / 600 / 200).
- Other pieces are as in v2.1, except Solid_Top_2m, which lost the moss cards.
- GLB totals: LOD0 2517, LOD1 599, LOD2 104.

### v2.1 -> v2.2 log (old v2.1 SHA256)
8bbb1651ad4a432f357085037b9de83b9e05ad157f7e1c2f1d40572dba899369  platform_skins_cuyabeno.py
439e41d8b76b0daee518af1fdfcc05fa98ae53534994cf997674ffcbf45d44a7  platform_skins_cuyabeno.blend
049865c2489db33632dee140c44600ccbc065befc00b6534da5ce5165f5df1a7  platform_skins_cuyabeno_LOD0.glb
c95a4497dedb486bdc4a62b1549391f45c268fb94af3fd1bc98b7874bc5d1b4e  platform_skins_cuyabeno_LOD1.glb
c53da997e7f2b121f23b4e03ba2f765b91b8ed72b167af32a55751197d5e0820  platform_skins_cuyabeno_LOD2.glb
b865087016ffed804e21fd1a0622ae488e96f46a84872f3b0c0e6e653e18bad4  platform_skins_report.json
ce692406623163148d28140f1ef4c715502ec628a3cf788b12f3d78721f046ed  textures/T_PlatformSkins_Cuyabeno_A.png
4c692b42adda0263a974410bbbd8f95fc1db6e28c09b5aae168f6ffcd13249e1  HP001_platform_skins_front.png
8425f4c4132ff50dfab373234e98357274cbe068c77f06254ccc0474045c57c4  HP001_platform_skins_34.png
99c0247b21dc7fd0ea1b963f4ae94103abadd3323580b607fc2ccb7e29a5414c  HP001_platform_skins_closeup.png
3a85467eb375c3c998ca27bcab755dc6201da0ef14bc781cf5eaba9a2c39a938  HP001_platform_skins_oneway_front.png
1b0797da96a17c7b106de93dc9d9e51a6d7557f3f475353ea19fd97db63c9bc0  HP001_platform_skins_oneway_34.png
aa1cf679ca4ec7f51b9af29b5c907f5f28ebde48f2a4207b5b6e476f33c86ec3  HP001_platform_skins_scale_maya.png
b8733821cd64a7ed7ef0a7f192545cc4e21da7b1f752d228a49b4eedb2ad512c  HP001_platform_skins_scale_maya_close.png

### v2.2 verdict
The moss now reads as dense draping bundles rather than sparse grass tufts. However, the top of each card still shows a straight, hard edge, so the clumps read a bit like brush or fringe blocks. The long beard is mostly hidden behind roots in the closeup. A follow-up should feather the top edge of the alpha and stagger the card tops.


## v2.3 (Oct 11): moss tops, beard placement, lip/face crease
1. **Moss tops:** the strand texture's top is now a ragged moss cushion (overlapping blobs, a different outline per column, plus short tufts poking up). The top 3 rows and the side columns are transparent, so there is no straight alpha edge. Card tops are staggered by +3 to -3 cm. The top row of each card is bent 2.5 cm back toward the earth, under the lip crumble, so each clump grows out of the earth.
2. **Beard placement:** the beard's X position is chosen as the spot farthest from every Solid_Top and Lip root, and the other clumps fill the remaining gaps.
3. **Lip/face crease:** the lip's bottom row now varies along X (-0.30 to -0.43 m) and overlaps onto the face. The bottom 40% of the lip texture bleeds into dark wet earth with moss blotches. Solid_Top's face top edge is tucked 3 cm in behind the lip crumble, so it no longer cuts through as a line.

### Tris
- Lip_2m 536 / 152 / 12; Lip caps 55 / 25 / 10.
- Solid_Top_2m 722 / 102 / 4.
- GLB totals: LOD0 2517, LOD1 593, LOD2 104.

### v2.2 -> v2.3 log (old v2.2 SHA256)
41f57904ed895c31ca5e762a7d43372543030e15cc8b3c6ae37cec9c4d8614e6  platform_skins_cuyabeno.py
d89cb857664f3584ab080ede82cf960c00ea565e2aaa2d9873450b7445074cb8  platform_skins_cuyabeno.blend
ecc9239fb59d0d1012c332e483c25f1c2cce88ff0524004c69dbb188ae8eb4c5  platform_skins_cuyabeno_LOD0.glb
f8fa8a9f3f546572d88630a0b459b305e8680204c2ecb718c2469ec489085427  platform_skins_cuyabeno_LOD1.glb
83b7c30aaa4f284f01f7cf3cba19ac1a189e361b3ee7c7a3fea92d3c149cbcc3  platform_skins_cuyabeno_LOD2.glb
884f77a5fb5a6573dde1ebaca8b834dec9d23f8536108ff9673fa8f0d437c3ab  platform_skins_report.json
ec4c0347205665b8e44fc83d352555cd5ffb4a2c0e873b17c717c74aaedeb65a  textures/T_PlatformSkins_Cuyabeno_A.png
2097fb32a914689fe726fd537b8e0ab7f4104aecc29071cfd62f472a9659d9d9  HP001_platform_skins_front.png
18e744078d4991c50e12324df0e4664b47e592ac6b2dd349064d4f93b5498533  HP001_platform_skins_34.png
2163f41f0f3c10c919a1fe1c3cd1b8c6e964f85791202c01cf40ecb7c9cbad46  HP001_platform_skins_closeup.png
a3f1fc0d0e5d22471c427fe5848299cedc09fb4f7100b58d2ec1020be585646a  HP001_platform_skins_oneway_front.png
c04d287ba9151b42e5abaec410fc16d81c30c5e502c83c9fde905e50f5cc7a2e  HP001_platform_skins_oneway_34.png
877d86eba88e8b70cb2142059d18e27fb8beba6a2d01ed9a2d6f177d1877d5a8  HP001_platform_skins_scale_maya.png
3ac958673d6f7a59f39c9f5791be68f3671a68b4d56f0ef751683cbf6ae2c76a  HP001_platform_skins_scale_maya_close.png

### v2.3 verdict
- **Moss:** no straight tops are visible, and the clumps read as moss growing from under the crumble.
- **Crease:** the continuous crease is gone.
- **Lip bottom:** it now shows as a faceted sawtooth edge (polygonal bites) rather than a soft broken line. It reads as crumbled earth up close, but it is a bit geometric.
- **Beard:** it is visible, though a root still runs along one side of it in the closeup.
