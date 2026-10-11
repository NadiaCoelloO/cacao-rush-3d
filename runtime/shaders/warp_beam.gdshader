shader_type spatial;
// LOOK-001 warp beam VFX (manifest warp_beam_preview / CIN-001 gold + cyan core).
// Additive, unshaded cone spawned at VFX_WarpBeam_Spawn. Mirrors the Blender
// LOOKONLY_VFX_Beam* preview: fades with height ((1 - h)^1.6) and at grazing angles
// (facing term), gain 0.85. Gold dominant, cyan restricted to the core.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 beam_color : source_color = vec4(1.0, 0.82, 0.416, 1.0);
uniform float strength = 3.2;
uniform float height_m = 6.2;
uniform float height_fade_pow = 1.6;
uniform float facing_gain = 0.85;

varying float h01;

void vertex() {
	// CylinderMesh is centred on its origin: bottom at -height/2, top at +height/2.
	h01 = clamp(VERTEX.y / height_m + 0.5, 0.0, 1.0);
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float a = clamp(facing_gain * pow(1.0 - h01, height_fade_pow) * facing, 0.0, 1.0);
	ALBEDO = beam_color.rgb * strength;
	ALPHA = a;
}
