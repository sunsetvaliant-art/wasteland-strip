shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;
// 0.2.74: the sea. Clear water you see the sand through in the shallows, turquoise over the sand bars, going to deep
// blue a few hundred metres out. Gentle swell lines run in to the beach, the waterline laps up and back over the wet
// sand, and there's a broken white edge where it runs out.
// How far out every point is comes from assets/world/sea_dist.png (tools/coast_fix.py): the map's sea bed is flat,
// so the water's depth there is made up from that: a beach shelving at about 1 in 40.

uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D dist_tex : filter_linear, repeat_disable;
uniform vec4 dist_rect = vec4(12000.0, -20480.0, 13600.0, 35840.0);    // x0, z0, width, depth (m)
uniform sampler2D ripple_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_tex : hint_default_white, filter_linear_mipmap, repeat_enable;

uniform vec3 sand_tint : source_color = vec3(0.86, 0.98, 0.95);   // what the sand under a little water looks like
uniform vec3 shallow : source_color = vec3(0.22, 0.72, 0.70);     // turquoise over the sand
uniform vec3 mid : source_color = vec3(0.05, 0.42, 0.55);
uniform vec3 deep : source_color = vec3(0.015, 0.11, 0.24);
uniform float clarity = 3.0;          // metres of water before the bottom's gone
uniform float slope = 0.025;          // sea bed fall per metre out
uniform float lap = 0.05;             // how far the sea sheet rises and falls (m): the waterline creeping up the beach
uniform float ripple_strength = 0.4;
uniform vec3 sky_tint : source_color = vec3(0.52, 0.66, 0.8);      // what it reflects (the engine's own reflection is kept weak)

vec2 rot(vec2 p, float a) { float c = cos(a), s = sin(a); return vec2(c * p.x - s * p.y, s * p.x + c * p.y); }
vec3 ripple(vec2 q, float t) {
	q = mod(q, 4096.0);
	vec3 a = texture(ripple_tex, rot(q, 0.4) / 23.0 + vec2(t * 0.011, t * 0.004)).rgb * 2.0 - 1.0;
	vec3 b = texture(ripple_tex, rot(q, 2.1) / 9.0 - vec2(t * 0.007, t * 0.019)).rgb * 2.0 - 1.0;
	vec3 c = texture(ripple_tex, rot(q, 4.0) / 3.1 + vec2(-t * 0.03, t * 0.024)).rgb * 2.0 - 1.0;
	return vec3((a.xy * 0.5 + b.xy * 0.35 + c.xy * 0.2) * ripple_strength, 0.0);
}

// metres from the land; a long way when off the map of it
float out_dist(vec2 p) {
	vec2 uv = (p - dist_rect.xy) / dist_rect.zw;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return 4000.0;
	float e = texture(dist_tex, uv).r;
	return e * e * 4000.0;
}

// inland: the sea sheet showing through ground that dips under it (swales behind the dunes): no foam or swell
// there, still water. True when every texel round here is land (none of the sea within ~10 m).
float inland(vec2 p) {
	vec2 uv = (p - dist_rect.xy) / dist_rect.zw;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return 0.0;
	ivec2 sz = textureSize(dist_tex, 0);
	ivec2 c = ivec2(uv * vec2(sz));
	float m = 0.0;
	for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++)
		m = max(m, texelFetch(dist_tex, clamp(c + ivec2(i, j), ivec2(0), sz - 1), 0).r);
	return m < 0.002 ? 1.0 : 0.0;
}

varying vec3 wpos;
varying float heave;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// the whole sheet breathes: up and back down the beach every 8 s or so, a little out of step along the coast
	heave = sin(TIME * 0.78 + wpos.z * 0.0021) * 0.7 + sin(TIME * 0.41 + wpos.z * 0.0013 + 1.7) * 0.3;
	VERTEX.y += lap * heave;
}

void fragment() {
	float t = TIME;
	vec2 q = wpos.xz;
	float d = out_dist(q);
	// the swell: lines parallel to the shore (the distance field's contours) rolling in, steeper as it shoals
	float lam = 14.0;
	float ph = d / lam + t * 0.11;
	float swell = sin(ph * 6.2831);
	float near = 1.0 - smoothstep(20.0, 220.0, d);
	// the slope of the swell across the water, along the way to the shore
	float e = 1.5;
	vec2 grad = vec2(out_dist(q + vec2(e, 0.0)) - out_dist(q - vec2(e, 0.0)), out_dist(q + vec2(0.0, e)) - out_dist(q - vec2(0.0, e))) / (2.0 * e);
	vec2 gdir = length(grad) > 0.01 ? normalize(grad) : vec2(1.0, 0.0);
	vec2 sw = gdir * cos(ph * 6.2831) * 0.22 * near;
	vec3 r = ripple(q, t);
	vec3 n = normalize(vec3(r.x + sw.x, 1.0, r.y + sw.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	// how much water is over the bottom: what the depth buffer says near the beach (the reshaped beach goes down to
	// -3 m), or the made-up shelf further out, whichever's more
	float zb = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, zb, 1.0);
	v.xyz /= v.w;
	float thick = max(0.0, VERTEX.z - v.z);
	// straight down from the surface to the bed (the view-line thickness is many times that at a low angle)
	vec3 bed_w = (INV_VIEW_MATRIX * vec4(v.xyz, 1.0)).xyz;
	vec3 surf_w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float vdep = max(0.0, surf_w.y - bed_w.y);
	float depth = max(vdep, d * slope);
	float fade = clamp(1.0 + VERTEX.z / 900.0, 0.0, 1.0);      // the depth buffer's no good a long way off
	depth = mix(d * slope, depth, fade);
	// colour: the bottom through clear water, turquoise, then deep blue
	vec2 ruv = SCREEN_UV + n.xz * 0.015 * clamp(depth, 0.0, 1.0);
	vec3 under = texture(screen_tex, ruv).rgb;
	float k = 1.0 - exp(-depth / clarity);
	vec3 water_col = mix(shallow, mid, smoothstep(2.0, 9.0, depth));
	water_col = mix(water_col, deep, smoothstep(8.0, 30.0, depth));
	vec3 col = mix(under * sand_tint, water_col, k);
	// foam: the white edge where it runs up (thin water, moving with the heave), and the broken tops of the swell
	// lines as they break in the last 40 m
	float fn = texture(foam_tex, mod(q, 4096.0) / 3.0 + vec2(t * 0.03, -t * 0.02)).r;
	float fn2 = texture(foam_tex, mod(q, 4096.0) / 11.0 - vec2(t * 0.01, t * 0.015)).r;
	float edge = (1.0 - smoothstep(0.0, 0.035 + 0.03 * (0.5 + 0.5 * heave), vdep)) * fade * (1.0 - smoothstep(15.0, 40.0, d));   // offshore the flat bed is thin too: only at the beach
	float crest = smoothstep(0.82, 0.98, 0.5 + 0.5 * swell) * (1.0 - smoothstep(6.0, 45.0, d)) * smoothstep(0.0, 3.0, d);
	float foam = clamp(edge * (0.55 + 0.6 * fn) + crest * smoothstep(0.35, 0.75, fn2) * 0.9, 0.0, 1.0);
	float inl = inland(q);
	foam *= 1.0 - inl;
	if (inl > 0.5) {
		// a still, brackish pool: brown-green over the mud
		col = mix(under * vec3(0.55, 0.55, 0.42), vec3(0.08, 0.1, 0.07), 1.0 - exp(-thick / 0.8));
		n = normalize(vec3(r.x * 0.3, 1.0, r.y * 0.3));
		NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	}
	// the sky in it, a Fresnel amount of it: strong only at a low angle, so straight down and out to the middle
	// distance the water's own colour shows (the engine's sky reflection washed it all pale)
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
	col = mix(col, sky_tint, fres * 0.55);
	ALBEDO = mix(col, vec3(0.92, 0.95, 0.95), foam * 0.85);
	ROUGHNESS = 0.1 + foam * 0.5;
	METALLIC = 0.0;
	SPECULAR = 0.12;          // sun glints, not the whole pale sky
	ALPHA = 1.0;
}
