shader_type spatial;
render_mode blend_mix, unshaded, fog_disabled, cull_disabled, depth_draw_opaque;

uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float alpha = 1.0;

void fragment() {
	ALBEDO = albedo.rgb;
	ALPHA = alpha;
}
