# runtime/models

Godot 4 imports glTF from here for the Fase 2 pilot.

| File | Notes |
|------|-------|
| `totem_warp_cuyabeno.glb` | CIN-001 greybox warp post (858/2000 tris). Prefer binary `.glb`. |
| `totem_warp_cuyabeno.glb.b64` | Base64 staging when MCP cannot push binary — decode: `base64 -d totem_warp_cuyabeno.glb.b64 > totem_warp_cuyabeno.glb` |

Copy from `assets/greybox/` when Assets 3D lands binaries there. Script: `assets/scripts/bpy/totem_warp_cuyabeno.py`.
