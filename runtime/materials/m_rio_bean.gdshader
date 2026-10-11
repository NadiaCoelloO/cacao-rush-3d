shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;

uniform vec4 dark_col : source_color = vec4(0.420, 0.227, 0.122, 1.0);
uniform vec4 mid_col : source_color = vec4(0.545, 0.290, 0.169, 1.0);
uniform vec4 rim_col : source_color = vec4(0.808, 0.447, 0.180, 1.0);

void fragment() {
	// 3/4 face sits toward +X (camera looks along -Z, Maya's right is +X).
	float face = clamp(NORMAL.x * 0.75 + NORMAL.y * 0.2 + 0.25, 0.0, 1.0);
	vec3 body = mix(dark_col.rgb, mid_col.rgb, face);
	float rim = pow(1.0 - clamp(abs(NORMAL.z), 0.0, 1.0), 2.4);
	body = mix(body, rim_col.rgb, smoothstep(0.35, 0.78, rim));
	ALBEDO = body;
}
