shader_type spatial;

uniform vec4 albedo : source_color = vec4(0.173, 0.094, 0.063, 1.0);
uniform float roughness_value = 0.94;
uniform vec3 maya_pos = vec3(0.0);

// Drops the face that sits between the camera (+Z) and Maya.
// Collision stays where the layout put it.
void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float in_front = smoothstep(0.15, 0.55, world_pos.z - maya_pos.z);
	vec4 maya_clip = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(maya_pos, 1.0));
	vec2 maya_ndc = maya_clip.xy / maya_clip.w;
	vec4 frag_clip = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
	vec2 frag_ndc = frag_clip.xy / frag_clip.w;
	float close = 1.0 - smoothstep(0.035, 0.14, length(frag_ndc - maya_ndc));
	float kill = in_front * close;
	float dither = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
	if (kill > 0.82 || (kill > 0.35 && dither < kill)) {
		discard;
	}
}
