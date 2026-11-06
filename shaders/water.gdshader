shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;
// Rivers and sea: muddy-green shallows fading to deep blue-green, sky reflections via roughness/fresnel,
// layered moving ripples, a soft foam line where it meets the bank.

uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec3 shallow : source_color = vec3(0.30, 0.34, 0.22);
uniform vec3 deep : source_color = vec3(0.03, 0.10, 0.11);
uniform float clarity = 1.6;

// ripples: one seamless normal-map noise sampled three times at different scales, angles and drift, so there's no
// grid to see (the old hash noise fell apart into blocks at the map's big world coordinates)
uniform sampler2D ripple_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float ripple_strength = 0.55;
vec2 rot(vec2 p, float a) { float c = cos(a), s = sin(a); return vec2(c * p.x - s * p.y, s * p.x + c * p.y); }
vec3 ripple(vec2 q, float t) {
	q = mod(q, 4096.0);                      // keep the numbers small: the texture tiles anyway
	vec3 a = texture(ripple_tex, rot(q, 0.4) / 23.0 + vec2(t * 0.011, t * 0.004)).rgb * 2.0 - 1.0;
	vec3 b = texture(ripple_tex, rot(q, 2.1) / 9.0 - vec2(t * 0.007, t * 0.019)).rgb * 2.0 - 1.0;
	vec3 c = texture(ripple_tex, rot(q, 4.0) / 3.1 + vec2(-t * 0.03, t * 0.024)).rgb * 2.0 - 1.0;
	vec2 xy = (a.xy * 0.5 + b.xy * 0.35 + c.xy * 0.2) * ripple_strength;
	return normalize(vec3(xy.x, 1.0, xy.y));
}

varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	float t = TIME;
	vec2 q = wpos.xz;
	vec3 n = ripple(q, t);
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	// how much water lies between this surface and the bed behind it
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	v.xyz /= v.w;
	float thick = max(0.0, VERTEX.z - v.z);
	float k = 1.0 - exp(-thick / clarity);
	vec2 ruv = SCREEN_UV + n.xz * 0.02 * k;
	vec3 under = texture(screen_tex, ruv).rgb;
	vec3 col = mix(under * shallow * 2.2, deep, k);
	float foam = (1.0 - smoothstep(0.0, 0.35, thick)) * (0.5 + 0.5 * texture(foam_tex, mod(q, 4096.0) / 2.5 + t * 0.02).r);
	ALBEDO = mix(col, vec3(0.85, 0.88, 0.85), foam * 0.5);
	ROUGHNESS = 0.04 + foam * 0.4;
	METALLIC = 0.0;
	SPECULAR = 0.55;
	ALPHA = 1.0;
}
