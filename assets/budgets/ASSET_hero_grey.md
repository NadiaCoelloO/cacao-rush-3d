```
ASSET hero_grey
tris: 896 / 25000  PASS
lods: 896, 358, 106
maps: unlit Emission cream/tan (T-020 greybox) — NOT high-poly
  base Body idle cream RGB(224,184,136) / Hair brown(104,72,40) / Pack tan(152,112,72)
  material slots (stable): Maya_Body, Maya_Hair, Maya_Pack
  runtime tint targets (Fable override; not sole baked base): crouch(138,99,65) crawl(148,110,76)
  2D tip sample: sand-vivid 5fd45031 (local crouch/crawl under /workspace/maya-t020/)
script: assets/scripts/bpy/hero_maya_grey.py
helpers: assets/scripts/bpy/_common.py (make_rgb_material + make_grey_material)
glb: assets/greybox/heroes/hero_grey.glb
runtime: runtime/models/hero_grey.glb (same binary)
source: assets/source/hero_grey.blend
license: original
blocked: none
high-poly: HOLD (until explicit post-delivery Identidad PASA)
Identidad: PASA greybox T-020 cream/tan (hue~28°); high-poly still HOLD
pose note: crouch/crawl remain squash-to-hitbox (no new crouch mesh)
display biome: Cuyabeno
```
