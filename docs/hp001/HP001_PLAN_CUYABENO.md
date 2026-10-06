# HP-001 Cuyabeno — high-poly plan (Pista 3D / Astra)

Scope: only Cuyabeno (pilot, world id `selva`). Every other world, Ruinas included, stays greybox.
Base: layout and look already approved (PR#5 b421353 + light2). Playable lighting, feel and collisions stay untouched.
Production: Assets 3D in Blender 5.2.1, with Astra 6 / Gemini / Opus as support for the briefs. glTF 2.0 Y-up, 1u = 1m.
Rules: no eyes, no magenta. Maya is cream #8F8578. Kakaw pods Y/O #CE722E/R. Each piece goes through Identidad before ASSET OK.
Branch: its own PR off PR#5 (`hp001-cuyabeno`), no merge until Nadia's OK. No billing, DaVinci or sand-vivid.

## Target: Nadia's Intel UHD (integrated) at 60 fps, 1080p with render scale 0.75–1.0
Frame budget (worst camera, everything visible after LOD):
- Visible tris: <= 350k (target 250k)
- Draw calls: <= 250 (MultiMesh for trunks, roots, leaf cards and ground cover)
- Textures: <= 192 MB VRAM. 2K only for Maya and the trunk/bark atlas; everything else 1K or atlas.
- Materials: opaque or alpha-scissor only (no alpha blend on foliage). One shader per class.
- Shadows: only the directional key, 2 cascades. Omni/spot route lights without shadows (same as now).
- Volumetric fog: keep the current look. Add a "low" preset (lower vol-fog resolution) that doesn't change the playable light.

## Budget per piece (LOD0 / LOD1 / LOD2 tris)
| # | Piece | LOD0 | LOD1 | LOD2 | Maps | Notes |
|---|---|---|---|---|---|---|
| 1 | Warp totem + 3 cacao pods | 6k | 3k | 1k | 1K | carved wood + lianas, ribbed whole pods, beam rises from the cluster, no flames |
| 2 | Trunk kit with bark + buttress roots (3 variants) | 4k each | 2k | 600 | 2K shared atlas | MultiMesh, roots go into the flooded water |
| 3 | Canopy (clumps + leaf cards) | 2.5k per clump | 1.2k | impostor | 1K atlas | <= 60k visible total, closed canopy as in light2 |
| 4 | Maya final (shape + clothing, cream #8F8578) | 20k | 10k | 4k | 2K A-N-R | same proportions, pivot and capsule; animations/feel untouched |
| 5 | Wooden dock (modular 4 m) | 3k per segment | 1.5k | 500 | 1K atlas | wood plank texture, no new collision |
| 6 | Solid / oneway platform skins | 2k | 1k | 400 | atlas | visual only, fitted to the existing boxes (oneway 4x0.18x2 @ 6,1,0) |
| 7 | Ground cover (lilies, ferns, cacao leaves) | 300–500 | 150 | — | atlas | MultiMesh |
| — | Black water | shader unchanged | | | | |

## Delivery order
1. Delivery 1: totem with pods (#1) + trunk/root kit (#2). Blender stills, then Godot wire on the HP branch, then laguna/dosel captures with the same cameras, then Identidad.
2. Delivery 2: canopy (#3) + dock (#5) + ground cover (#7).
3. Delivery 3: Maya final (#4) + platform skins (#6).
Each delivery comes with: .blend/.glb SHA256, tris per LOD, maya_feel_check 54/54, and a perf report from Godot (visible tris, draw calls, VRAM from the Performance monitors on the worst camera).
Limitation: I can't measure real fps on Nadia's UHD from here. The Godot counters are the proxy, and a real fps check needs her playtest.

## Coordinador OK (2026-10-06 09:48)
- Approved. Visible tris target 250k (350k is the hard ceiling). The volumetric fog "low" preset is ON by default in the demo.
- Every delivery also includes a capture from the gameplay camera, not only Laguna and Dosel.
- The HP totem is born with no orange spikes and a whole centre pod. Nothing goes into Godot until the totem_pods fix has a PASS.
