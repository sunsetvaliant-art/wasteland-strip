shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// Grass beyond the real clumps: crossed cards showing photographs of four grass_medium_01 clumps (taken at load
// time in flat light, so this lights them). Same wind, dry patches and hand-over ring as the real clumps.
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float wind = 0.1;
uniform vec3 dry : source_color = vec3(0.86, 0.78, 0.5);
uniform float alpha_cut = 0.45;
uniform float near_hide = 0.0;
uniform float far_hide = 10000.0;
varying float var_k;
varying float frame;
varying float bend;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	var_k = fract(sin(dot(mod(w.xz, 1000.0), vec2(12.9898, 78.233))) * 43758.5453);
	frame = floor(fract(var_k * 7.31) * 4.0);
	float k = clamp(VERTEX.y / 0.6, 0.0, 1.0);
	bend = k;
	float t = TIME;
	vec2 wq = mod(w.xz, 1000.0);
	float gust = sin(wq.x * 0.05 + wq.y * 0.03 + t * 0.7) * 0.5 + 0.5;
	float s = (sin(wq.x * 0.8 + t * 2.1) + 0.6 * sin(wq.y * 1.1 + t * 1.6)) * wind * (0.35 + gust);
	VERTEX.x += s * k * k * 0.6;
	VERTEX.z += s * 0.6 * k * k * 0.6;
	float dc = distance(w.xz, CAMERA_POSITION_WORLD.xz);
	// clump by clump, not ring by ring: a share of them takes over from the real clumps across a wide band, and
	// out towards the edge they thin away gradually
	float h2 = fract(var_k * 13.37);
	float inner = smoothstep(near_hide - 4.0, near_hide + 3.0, dc);
	float outer = 1.0 - smoothstep(far_hide * 0.45, far_hide - 1.0, dc);
	VERTEX *= step(h2, inner) * step(h2, outer);
	// light it like ground cover: mostly up-facing, so it sits in with the terrain instead of flashing per card
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.75));
}
void fragment() {
	vec4 a = texture(atlas, vec2((frame + clamp(UV.x, 0.01, 0.99)) * 0.25, UV.y));
	if (a.a < alpha_cut) discard;
	vec3 col = mix(a.rgb, a.rgb * dry * 1.25, smoothstep(0.55, 0.95, var_k) * 0.7);
	ALBEDO = col;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	BACKLIGHT = col * 0.4;
	AO = mix(0.55, 1.0, bend);
	AO_LIGHT_AFFECT = 0.5;
}
