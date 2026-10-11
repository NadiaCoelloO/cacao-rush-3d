shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

uniform float water_top = 4.0;
uniform float sim_time = 0.0;
uniform vec3 deep_col : source_color = vec3(0.227, 0.090, 0.047);
uniform vec3 body_col : source_color = vec3(0.420, 0.227, 0.122);
uniform vec3 amber_col : source_color = vec3(0.808, 0.447, 0.180);

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float depth = clamp((water_top - world.y) / 5.2, 0.0, 1.0);
	vec3 col = mix(body_col, deep_col, depth);
	// Amber lip, about the 5 px strip in render.ts.
	float lip = smoothstep(0.28, 0.0, water_top - world.y);
	col = mix(col, amber_col, lip * 0.82);
	// Current: long streaks plus a shorter amber glint. Kept dark enough
	// that a streak behind Maya cannot become a bright halo.
	float flow = world.x * 1.15 - sim_time * 1.7 + sin(world.y * 2.0) * 0.35;
	float streak = smoothstep(0.82, 0.98, sin(flow));
	float glint = smoothstep(0.93, 1.0, sin(flow * 2.4 + 1.7));
	col = mix(col, amber_col, streak * 0.28 + glint * 0.22);
	float sheen = 0.5 + 0.5 * sin(world.x * 0.35 - sim_time * 0.6);
	col = mix(col, body_col, sheen * 0.08);
	ALBEDO = col;
}
