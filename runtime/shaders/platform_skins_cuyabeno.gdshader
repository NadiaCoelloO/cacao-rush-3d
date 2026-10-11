shader_type spatial;
// HP-001 E3a Identity remaps on the Cuyabeno platform atlas.
// Geometry and UVs stay as authored. Soft fixes only:
//   (a) straw-beige hanging moss → olive / wet brown, keep a few rootlets
//   (b) cream root tips darkened toward bark
//   (c) oneway log warmer-brown + lichen/moss on the belly; belly lifted
//       by ambient (shaded, not unshaded) plus a small albedo lift.
// Litter tops are left alone so grains stay readable. Alpha MASK, double-sided.
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float roughness : hint_range(0.0, 1.0) = 0.62;
uniform float is_oneway : hint_range(0.0, 1.0) = 0.0;
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.5;

varying vec3 world_n;

void vertex() {
	world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	if (t.a < alpha_scissor) {
		discard;
	}
	vec3 c = t.rgb;
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	float rg = c.g / max(c.r, 0.001);
	float h = hash21(UV * 97.0 + vec2(is_oneway, 3.1));

	bool moss_card = UV.x >= 0.74 && UV.y < 0.26;
	bool lip_moss = UV.x < 0.52 && UV.y >= 0.12 && UV.y < 0.26;
	bool bark_uv = UV.x < 0.52 && UV.y >= 0.24 && UV.y < 0.52;
	bool litter = UV.x >= 0.50 && UV.y >= 0.50;

	// (a) straw-beige strands → olive #3C4027 / wet brown #4C3E2E.
	// Keep sparse light-brown rootlets #8A735A.
	bool beige = c.r > 0.34 && c.r < 0.88 && c.r > c.g && c.g > c.b + 0.015
			&& rg > 0.55 && rg < 0.96 && (c.r - c.b) > 0.07 && luma > 0.28;
	bool keep_rootlet = beige && luma > 0.40 && rg < 0.78 && h > 0.90;
	if (beige && !keep_rootlet && !litter && (moss_card || lip_moss || luma > 0.38)) {
		vec3 olive = vec3(0.235, 0.251, 0.153);
		vec3 wet = vec3(0.298, 0.243, 0.180);
		c = mix(c, mix(olive, wet, step(0.45, h)), 0.84);
	}

	// (b) cream / pale root tips → bark #41332A.
	bool cream = !litter && c.r > 0.42 && c.g > 0.30 && c.b < 0.40
			&& c.r > c.b + 0.10 && abs(c.r - c.g) < 0.24 && luma > 0.36;
	if (cream && (bark_uv || moss_card || lip_moss)) {
		c = mix(c, vec3(0.255, 0.200, 0.165), 0.62);
	}

	// (c) oneway: warmer/darker bark, lichen on the underside, belly lift.
	if (is_oneway > 0.5) {
		c *= vec3(0.78, 0.64, 0.50);
		if (world_n.y < -0.22) {
			float blot = hash21(UV * 31.0 + vec2(7.2, 1.7));
			if (blot > 0.70) {
				c = mix(c, vec3(0.204, 0.263, 0.145), 0.48);
			} else if (blot > 0.48) {
				c = mix(c, vec3(0.33, 0.31, 0.18), 0.28);
			}
			c = mix(c, c * vec3(1.22, 1.16, 1.08) + vec3(0.035, 0.028, 0.012), 0.40);
		}
	}

	ALBEDO = clamp(c, vec3(0.0), vec3(1.0));
	ROUGHNESS = roughness;
	METALLIC = 0.0;
	SPECULAR = 0.3;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
}
