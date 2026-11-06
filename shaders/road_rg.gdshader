shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Roads built by the Road Generator addon (the pilot): the game's scanned asphalt in world space, with the addon's
// lane markings taken from its texture atlas and painted Australian white (its centre lines are American yellow).
uniform sampler2D marks : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D asph_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asph_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asph_rgh : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tyre_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 grass_tint : source_color = vec3(0.92, 0.98, 0.85);
uniform float wild = 0.5;              // how far nature's got back in (same scale as the old roads: busy road ~0.4)
uniform float asph_scale = 0.28;
uniform vec3 paint_white : source_color = vec3(0.86, 0.85, 0.80);
uniform float wear = 1.0;
varying vec3 wp;

float h21(vec2 p) { p = fract(p * vec2(0.1031, 0.1030)); p += dot(p, p.yx + 33.33); return fract((p.x + p.y) * p.x); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) { return vn(p) * 0.5 + vn(p * 2.03 + 7.1) * 0.3 + vn(p * 4.1 + 3.3) * 0.2; }

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// textures run in world space (x, z), so the normal maps need world-aligned tangents, not the road's own
	TANGENT = normalize(vec3(1.0, 0.0, 0.0) - NORMAL * NORMAL.x);
	BINORMAL = normalize(vec3(0.0, 0.0, -1.0) - NORMAL * -NORMAL.z);
}

// The asphalt scan repeats every 3.6 m and has a long crack down one side: tiled straight it draws a grid from the
// air. Two samples, one turned and shifted, blended by a slow noise, hide the repeat.
vec4 untiled(sampler2D t, vec2 q, float k) {
	const mat2 R = mat2(vec2(0.788, 0.616), vec2(-0.616, 0.788));
	vec4 a = texture(t, q);
	vec4 b = texture(t, R * q * 0.83 + vec2(0.37, 0.61));
	return mix(a, b, k);
}

void fragment() {
	vec2 q = mod(wp.xz, 2048.0) * asph_scale;
	vec2 wuv = mod(wp.xz, 2048.0) * 0.16;
	float k = smoothstep(0.3, 0.7, fbm(q * 0.31 + 3.0));
	vec3 a = untiled(asph_alb, q, k).rgb;
	a = mix(a, texture(tyre_alb, q * 0.7).rgb * 0.9, 0.25);
	a *= 0.8 + 0.16 * fbm(wuv * 0.25);                  // patches of different-age seal
	vec3 nrm = untiled(asph_nrm, q, k).rgb;
	float rgh = 0.8 + 0.2 * untiled(asph_rgh, q, k).r;      // old, sun-baked bitumen is matte
	vec4 m = texture(marks, UV);
	// markings are the bright white or yellow parts of the atlas; its grey base and dark shoulders aren't
	float paint = smoothstep(0.5, 0.75, max(m.r, m.g));
	float fade = 0.35 + 0.55 * fbm(wuv * 0.6 + 5.0);
	paint *= fade;
	vec3 col = mix(a, paint_white, paint * 0.92);
	rgh = mix(rgh, 0.7, paint);
	// nature taking it back, as on the old roads: up the cracks, moss, grass in patches, leaf litter
	vec3 gr_col = texture(grass_alb, wuv * 2.5).rgb * grass_tint;
	vec3 g_col = texture(dirt_alb, wuv * 2.1).rgb;
	float n1 = fbm(wuv * 0.9);
	float n2 = fbm(wuv * 3.5 + 11.0);
	float grow = clamp((n1 - 0.62 + 0.12 * n2) * 1.6 * wild + (wild - 0.55) * 0.5, 0.0, 1.0);
	float moss = clamp((n2 - 0.5) * 2.0 * wild, 0.0, 1.0) * (1.0 - grow);
	col = mix(col, col * vec3(0.55, 0.62, 0.38), moss * 0.5);
	col = mix(col, gr_col, grow);
	nrm = mix(nrm, texture(grass_nrm, wuv * 2.5).rgb, grow);
	rgh = mix(rgh, 0.92, grow);
	float litter = clamp((fbm(wuv * 0.4 + 31.0) - 0.6) * 3.0, 0.0, 1.0) * wild;
	col = mix(col, g_col * vec3(0.8, 0.72, 0.6), litter * 0.6);
	ALBEDO = col;
	ROUGHNESS = rgh;
	SPECULAR = 0.3;
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = 1.0;
}
