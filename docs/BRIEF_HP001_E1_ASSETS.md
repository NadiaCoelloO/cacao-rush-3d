# HP-001 E1 brief for Assets 3D: warp totem with pods + trunk/root kit (Cuyabeno)

Director: Pista 3D (Astra). Producer: Assets 3D in Blender 5.2.1. Astra 6 / Gemini / Opus as support only.
Approved by the Coordinador with Nadia's GO. High-poly is released ONLY for Cuyabeno.
Output: /home/box/workspace/world-001/hp-001/assets-out-e1/ (.blend, .glb per LOD, bpy script, stills, SHA256 + tris per LOD in a README).
Rules: glTF 2.0 Y-up, 1u = 1m, English node names, no eyes/faces, no magenta, opaque or alpha-scissor only. Nothing goes to the repo or to Godot until Identidad gives a PASS. No DaVinci, no billing.

## 1. totem_warp_cuyabeno_hp
- LOD0 <= 6k / LOD1 <= 3k / LOD2 <= 1k tris. 1K maps (Albedo/Normal/ORM) or a shared atlas.
- Same footprint, height and pivot as the current greybox `totem_warp_cuyabeno` (assets/scripts/bpy/totem_warp_cuyabeno.py in cacao-rush-3d), so it slots into the same position in the scene.
- Carved dark wood trunk with bark/carving relief, wrapped in lianas. NO faces or eyes.
- Tip: 3 WHOLE cacao pods, elongated, ribbed (10 ridges), pointed ends, slightly separated, in Kakaw yellow / orange #CE722E / red with a soft emissive glow. The centre pod must be a whole ellipsoid (it must not look melted).
- FORBIDDEN: spiky cards, fans or cone/flame shapes behind or above the pods. If foliage is wanted, at most 2 broad dark-green cacao leaves with a rounded tip.
- Leave an empty `BeamOrigin` at the centre of the cluster (the beam rises from there).
- Refs: Identidad's NO PASS close-up (spikes = fire) attached, CIN-001/CIN-003 paint_v03 in /home/box/workspace/world-001/.

## 2. trunk_selva_kit_hp (3 variants: thin, medium, thick with buttress roots)
- LOD0 <= 4k / LOD1 <= 2k / LOD2 <= 600 tris each. One 2K bark atlas shared across the 3 variants (A/N/ORM).
- Tall Amazonian flooded-forest trunks: furrowed bark, buttress roots that go into the water (base at y=0 = waterline, roots extending ~0.5 m below).
- Built to instance (MultiMesh): pivot at the base, no unique materials per variant.
- Silhouettes and colours consistent with the approved LOOK-001 (dark reddish-brown trunks, olive lianas).

## Deliver
- Blender stills of each piece (front + 3/4), LOD0 and LOD2 side by side.
- README with SHA256 of every .glb/.blend and the measured tris per LOD.
- Notify Pista 3D when done. I'll send it to Identidad.

## Identidad addition (2026-10-06 10:00)
Pods: rounded stalk end at the top, blunt tip only at the bottom (like a real cacao pod), ribs as sunken grooves (not stuck-on slats). Pointed at both ends = reads as a gem/crystal.

## Identidad gate E1 v1 (10:21): NO PASS on both, sent back to Assets for v2
- Totem: pods PASS (do not touch). Post reads as a classical column. Turn it into an irregular, slightly conical hand-carved trunk with bark remnants and short buttress roots at the base, flat incised bands (keep the diamonds/zigzag) and a rough cut-trunk crown. Keep footprint, heights, pivot and BeamOrigin.
- Trunks: bark too red (hue 19°, sat 0.35). Make it cooler grey-brown (hue 28–35°, sat ≤0.2) with light lichen, a dark water-stain + moss band above the waterline, and 1–2 hanging lianas/epiphytes per variant in LOD0/1.

## Identidad gate E1 v2 (2026-10-06 ~11:15)
- totem_warp_cuyabeno_hp: PASS in Blender (carved trunk, LOD0/1/2 5872/2904/988 tris). Godot gameplay capture still pending.
- trunk_selva_kit_hp: NO PASS (minor). Bark hue/sat now OK (cooler grey-brown with lichen, moss and lianas). Remove the epiphytes from the fork tops (they read as palm/agave) and put compact bromeliad rosettes mid-trunk instead; soften the UV seam. Trunks v3 requested from Assets; the re-gate needs trunks_front + trunks_34 stills.
