shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

uniform float sim_time = 0.0;
uniform vec3 deep_col : source_color = vec3(0.227, 0.078, 0.039);
uniform vec3 body_col : source_color = vec3(0.420, 0.227, 0.122);
uniform vec3 amber_col : source_color = vec3(0.808, 0.447, 0.180);

void fragment() {
	// Quad faces the camera, so UV.y is the 2D vertical: lip on the top ~6 px.
	float up = UV.y;
	vec3 col = mix(deep_col, body_col, smoothstep(0.0, 0.55, up));
	float lip = smoothstep(0.955, 0.995, up);
	col = mix(col, amber_col, lip * 0.9);
	float flow = UV.x * 46.0 - sim_time * 1.5 + sin(up * 18.0) * 0.25;
	float streak = smoothstep(0.86, 0.99, sin(flow));
	float glint = smoothstep(0.94, 1.0, sin(flow * 2.2 + 1.4));
	col = mix(col, amber_col, streak * 0.22 + glint * 0.16);
	ALBEDO = col;
}
