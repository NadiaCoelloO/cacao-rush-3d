shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;

// LOOK-001 cream #8f8578. Unshaded and fog_disabled so the amber river
// and the distance haze cannot pull the torso under the 4.4:1 floor.
// The 3/4 side lifts warmer but never darker than the cream.
uniform vec4 cream : source_color = vec4(0.561, 0.522, 0.471, 1.0);
uniform vec4 warm : source_color = vec4(0.780, 0.706, 0.580, 1.0);

void fragment() {
	float nd = clamp(dot(NORMAL, normalize(vec3(0.42, 0.35, 0.84))), 0.0, 1.0);
	ALBEDO = mix(cream.rgb, warm.rgb, nd * 0.42);
}
