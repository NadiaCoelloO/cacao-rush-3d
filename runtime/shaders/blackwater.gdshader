shader_type spatial;
// LOOK-001 M_BLACKWATER (Godot adaptation, manifest godot_rebuild_notes.water).
// Opaque black lagoon: #10191A, metallic 0, roughness 0.15, specular 0.5. Broad, slow
// ripples come from two drifting normal noises (~4 m and ~1 m) — no foam, no fine noise,
// no transparency / refraction (brief §4). The exported plane has no UVs or tangents, so
// the ripple perturbs the world-space normal of the horizontal plane directly.
// Reflections: Environment SSR (on-screen) + ReflectionProbe over the lagoon (off-screen).
render_mode cull_disabled, depth_draw_opaque, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(0.0627, 0.0980, 0.1020, 1.0); // #10191A (sRGB)
uniform float roughness : hint_range(0.0, 1.0) = 0.15;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform sampler2D ripple_broad : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D ripple_fine : hint_normal, repeat_enable, filter_linear_mipmap;
uniform float broad_scale_m = 4.0;
uniform float fine_scale_m = 1.0;
uniform vec2 broad_drift_m_s = vec2(0.035, 0.02);
uniform vec2 fine_drift_m_s = vec2(-0.02, 0.045);
uniform float ripple_strength : hint_range(0.0, 1.0) = 0.1;

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 uv_a = (world_xz + TIME * broad_drift_m_s) / broad_scale_m;
	vec2 uv_b = (world_xz + TIME * fine_drift_m_s) / fine_scale_m;
	vec2 da = texture(ripple_broad, uv_a).rg * 2.0 - 1.0;
	vec2 db = texture(ripple_fine, uv_b).rg * 2.0 - 1.0;
	vec2 d = (da * 0.7 + db * 0.3) * ripple_strength;
	vec3 n_world = normalize(vec3(d.x, 1.0, d.y));
	if (!FRONT_FACING) {
		n_world = -n_world;
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	ALBEDO = albedo.rgb;
	METALLIC = 0.0;
	ROUGHNESS = roughness;
	SPECULAR = specular;
}
