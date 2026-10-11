shader_type spatial;
// Far riverside canopy. Fog stays on so the distance reads as warm mist.
// Maya and the bean use their own fog_disabled shaders.
render_mode unshaded, cull_disabled;

uniform vec4 albedo : source_color = vec4(0.10, 0.14, 0.12, 1.0);

void fragment() {
	ALBEDO = albedo.rgb;
}
