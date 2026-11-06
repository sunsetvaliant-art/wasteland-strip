shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, depth_prepass_alpha;
// Scanned grass clumps (Poly Haven, CC0): the photo texture with alpha cut-out, normal map, wind that bends the tips
// more than the roots, light coming through the blades, and a per-clump dry / green variation.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap;
uniform float height = 0.2;              // model-space height of the clump (for the bend)
uniform float wind = 0.1;
uniform vec3 dry : source_color = vec3(0.86, 0.78, 0.5);
uniform float alpha_cut = 0.4;
varying float bend;
varying float var_k;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	var_k = fract(sin(dot(w.xz, vec2(12.9898, 78.233))) * 43758.5453);
	float k = clamp(VERTEX.y / height, 0.0, 1.0);
	bend = k;
	float t = TIME;
	float gust = sin(w.x * 0.05 + w.z * 0.03 + t * 0.7) * 0.5 + 0.5;
	float s = (sin(w.x * 0.8 + t * 2.1) + 0.6 * sin(w.z * 1.1 + t * 1.6)) * wind * (0.35 + gust);
	VERTEX.x += s * k * k * height * 4.0;
	VERTEX.z += s * 0.6 * k * k * height * 4.0;
}
void fragment() {
	vec4 a = texture(albedo_tex, UV);
	if (a.a < alpha_cut) discard;
	// some clumps have gone off in the heat
	vec3 col = mix(a.rgb, a.rgb * dry * 1.25, smoothstep(0.55, 0.95, var_k) * 0.7);
	ALBEDO = col * (0.75 + 0.35 * bend);
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	ROUGHNESS = texture(rough_tex, UV).g * 0.9;
	SPECULAR = 0.3;
	BACKLIGHT = col * 0.45;
	AO = mix(0.45, 1.0, bend);
	AO_LIGHT_AFFECT = 0.6;
}
