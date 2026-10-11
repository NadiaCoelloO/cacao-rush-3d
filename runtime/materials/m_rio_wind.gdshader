shader_type spatial;
render_mode blend_mix, unshaded, fog_disabled, cull_disabled, depth_draw_opaque;

uniform float sim_time = 0.0;
uniform float dir = 1.0;
uniform vec4 tint : source_color = vec4(0.953, 0.902, 0.816, 1.0);

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float drift = sim_time * 2.6 * dir;
	float x = world.x * 2.4 - drift;
	float along = abs(fract(x) - 0.5);
	float row = abs(fract(world.y * 1.6) - 0.5);
	float line = smoothstep(0.07, 0.0, along) * smoothstep(0.42, 0.18, row);
	ALBEDO = tint.rgb;
	ALPHA = line * 0.42;
}
