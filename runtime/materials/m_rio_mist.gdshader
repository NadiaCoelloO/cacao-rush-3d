shader_type spatial;
// Warm river mist. Depth is not written, so it cannot hide the lane.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;

uniform vec4 albedo : source_color = vec4(0.77, 0.52, 0.32, 1.0);
uniform float alpha = 0.35;

void fragment() {
	ALBEDO = albedo.rgb;
	ALPHA = alpha;
}
