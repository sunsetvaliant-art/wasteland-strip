shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;
// 0.2.74: the sea. Clear water you see the sand through in the shallows, turquoise over the sand bars, going to deep
// blue a few hundred metres out. Gentle swell lines run in to the beach, the waterline laps up and back over the wet
// sand, and there's a broken white edge where it runs out.
// How far out every point is comes from assets/world/sea_dist.png (tools/coast_fix.py): the map's sea bed is flat,
// so the water's depth there is made up from that: a beach shelving at about 1 in 40.

uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D dist_tex : filter_nearest, repeat_disable;
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

// 0.2.77: sea_dist.png holds sqrt(metres out / 4000) in 16 bits (red high byte, green low), filtered here by hand.
// (8 bits stepped the distance 7-15 m at a time a few hundred metres out, and the swell lines jumped at every step)
float _e(ivec2 c, ivec2 sz) {
	vec3 t = texelFetch(dist_tex, clamp(c, ivec2(0), sz - 1), 0).rgb;
	return (floor(t.r * 255.0 + 0.5) * 256.0 + floor(t.g * 255.0 + 0.5)) / 65535.0;
}
// metres out from the land (x), and whether all four texels round here are land (y: the sea sheet showing through
// ground that dips under it, inland: still water there). A long way out when off the map of it.
vec2 out_dist(vec2 p) {
	vec2 uv = (p - dist_rect.xy) / dist_rect.zw;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return vec2(4000.0, 0.0);
	ivec2 sz = textureSize(dist_tex, 0);
	vec2 f = uv * vec2(sz) - 0.5;
	ivec2 c = ivec2(floor(f));
	vec2 w = f - floor(f);
	float a = _e(c, sz), b = _e(c + ivec2(1, 0), sz), cc = _e(c + ivec2(0, 1), sz), dd = _e(c + ivec2(1, 1), sz);
	float e = mix(mix(a, b, w.x), mix(cc, dd, w.x), w.y);
	return vec2(e * e * 4000.0, max(max(a, b), max(cc, dd)) < 0.0005 ? 1.0 : 0.0);
}

float hash2(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
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
	vec2 od = out_dist(q);
	float d = od.x;
	// 0.2.77: the waves. 0.2.74 ran one 14 m swell line along every contour of the distance to the land, the same
	// height everywhere: from up high it was evenly spaced wrinkles. Now three trains:
	//  1. the swell running in to the beach: long out deep (~80 m), shortening as it shoals (the wavelength goes with
	//     the root of the depth), its crests bent by a slow warp, coming in sets, in broken lengths
	//  2. the open-ocean swell from the east-south-east and a shorter one from the east-north-east, crossing each other
	//     and the contours, in patches, dying out as they come in to the beach
	//  3. a short wind chop from the south, and the ripple texture on top
	// Each fades out where it's finer than the pixels (no moire a long way off).
	float e5 = 5.0;
	float dx = out_dist(q + vec2(e5, 0.0)).x, dz = out_dist(q + vec2(0.0, e5)).x;
	vec2 gd = vec2(dx - d, dz - d) / e5;                       // the way out to sea (length ~1)
	float dd = max(d, 2.0);
	float warp = (vnoise(q / 380.0) - 0.5) * 2.4 + (vnoise(q / 1300.0 + 7.0) - 0.5) * 3.0;
	float c1 = 0.5 * sqrt(dd) + t / 9.0 + warp;
	float s1 = sin(c1 * 6.2831);
	float group = 0.55 + 0.45 * sin((c1 / 5.3 + vnoise(q / 900.0)) * 6.2831);
	float broken = smoothstep(0.2, 0.7, vnoise(q / 110.0 + vec2(t * 0.013, 0.0)));
	float a1 = 0.55 * smoothstep(1.0, 10.0, d) * (1.0 - smoothstep(350.0, 800.0, d)) * group * mix(0.35, 1.0, broken);
	a1 *= 1.0 - smoothstep(0.22, 0.6, fwidth(c1));
	float dh1 = a1 * 6.2831 * (0.5 + 0.5 * s1) * cos(c1 * 6.2831) * 0.25 / sqrt(dd);   // dh/dd
	vec2 g1 = gd * dh1;
	vec2 dir2 = normalize(vec2(-1.0, 0.33));
	float c2 = dot(q, dir2) / 85.0 - t / 9.6 + (vnoise(q / 700.0 + 3.0) - 0.5) * 1.6;
	float a2 = 0.4 * smoothstep(120.0, 500.0, d) * (1.0 - smoothstep(0.22, 0.6, fwidth(c2)));
	a2 *= 0.15 + 0.85 * smoothstep(0.2, 0.8, vnoise(q / 420.0 + vec2(11.0, t * 0.006)));     // patchy, never even rows
	vec2 g2 = dir2 * a2 * 6.2831 / 85.0 * cos(c2 * 6.2831);
	vec2 dir2b = normalize(vec2(-1.0, -0.25));               // a second, shorter swell a little off the first: they cross
	float c2b = dot(q, dir2b) / 58.0 - t / 7.7 + (vnoise(q / 520.0 + 9.0) - 0.5) * 2.0;
	float a2b = 0.3 * smoothstep(120.0, 500.0, d) * (1.0 - smoothstep(0.22, 0.6, fwidth(c2b))) * smoothstep(0.25, 0.85, vnoise(q / 300.0 + 21.0));
	g2 += dir2b * a2b * 6.2831 / 58.0 * cos(c2b * 6.2831);
	vec2 dir3 = normalize(vec2(-0.35, -1.0));
	float c3 = dot(q, dir3) / 27.0 - t / 4.2 + (vnoise(q / 160.0 + 5.0) - 0.5) * 1.2;
	float a3 = 0.07 * (1.0 - smoothstep(0.22, 0.6, fwidth(c3)));
	vec2 g3 = dir3 * a3 * 6.2831 / 27.0 * cos(c3 * 6.2831);
	vec2 sw = g1 + g2 + g3;
	float swell = s1;
	vec3 r = ripple(q, t);
	vec3 n = normalize(vec3(r.x - sw.x, 1.0, r.y - sw.y));
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
	water_col *= 0.9 + 0.2 * vnoise(q / 650.0 + vec2(t * 0.004, 0.0));     // darker and lighter wind patches
	vec3 col = mix(under * sand_tint, water_col, k);
	// foam: the white edge where it runs up (thin water, moving with the heave), and the broken tops of the swell
	// lines as they break in the last 40 m
	float fn = texture(foam_tex, mod(q, 4096.0) / 3.0 + vec2(t * 0.03, -t * 0.02)).r;
	float fn2 = texture(foam_tex, mod(q, 4096.0) / 11.0 - vec2(t * 0.01, t * 0.015)).r;
	float edge = (1.0 - smoothstep(0.0, 0.06 + 0.05 * (0.5 + 0.5 * heave), vdep)) * fade * (1.0 - smoothstep(15.0, 40.0, d));   // offshore the flat bed is thin too: only at the beach
	// the swell breaking: white on the crests in the last ~45 m, more on the big ones of a set, and broken white water
	// trailing behind them in towards the sand
	float brk = (1.0 - smoothstep(35.0, 95.0, d)) * smoothstep(1.0, 5.0, d) * mix(0.5, 1.0, group) * mix(0.45, 1.0, broken);
	float crest = smoothstep(0.8, 0.97, 0.5 + 0.5 * swell) * brk;
	float trail = smoothstep(0.45, 0.95, 0.5 + 0.5 * sin((c1 + 0.1) * 6.2831)) * brk * 0.6 * (1.0 - smoothstep(10.0, 55.0, d));
	float lace = smoothstep(0.42, 0.8, fn2) * (0.4 + 0.6 * fn);          // foam's never a flat sheet: lacy, with gaps
	float foam = clamp(edge * (0.55 + 0.6 * fn) + (crest * 0.9 + trail) * lace, 0.0, 1.0);
	float inl = od.y;
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
