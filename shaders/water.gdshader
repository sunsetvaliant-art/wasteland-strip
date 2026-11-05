shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;
// Rivers and sea: muddy-green shallows fading to deep blue-green, sky reflections via roughness/fresnel,
// layered moving ripples, a soft foam line where it meets the bank.

uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec3 shallow : source_color = vec3(0.30, 0.34, 0.22);
uniform vec3 deep : source_color = vec3(0.03, 0.10, 0.11);
uniform float clarity = 1.6;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y); }
float waves(vec2 q, float t) {
	return vn(q * 0.35 + vec2(t * 0.21, t * 0.07)) * 0.5 + vn(q * 0.9 - vec2(t * 0.11, t * 0.33)) * 0.3
		+ vn(q * 2.3 + vec2(t * 0.5, -t * 0.4)) * 0.15 + vn(q * 6.0 + vec2(-t * 0.9, t * 0.6)) * 0.05;
}

varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	float t = TIME;
	vec2 q = wpos.xz;
	float e = 0.15, h0 = waves(q, t);
	vec3 n = normalize(vec3(h0 - waves(q + vec2(e, 0), t), e * 2.2, h0 - waves(q + vec2(0, e), t)));
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
	float foam = (1.0 - smoothstep(0.0, 0.35, thick)) * (0.5 + 0.5 * vn(q * 3.0 + t * 0.4));
	ALBEDO = mix(col, vec3(0.85, 0.88, 0.85), foam * 0.5);
	ROUGHNESS = 0.04 + foam * 0.4;
	METALLIC = 0.0;
	SPECULAR = 0.55;
	ALPHA = 1.0;
}
