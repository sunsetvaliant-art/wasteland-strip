shader_type spatial;
render_mode cull_back, depth_draw_opaque;
// 0.2.75: what a character wears, drawn on their own body. Outfit.gd remakes each body's mesh with the head and hands
// kept as they were, and the rest a "shell" that carries, per vertex, where it is on the body (how far down the arm,
// how far down the leg, how high up the torso, its rest position and normal in metres). This works out per pixel
// which garment is over that spot (sleeve and leg lengths, where the shirt hangs to, how high the boots come) from
// per-instance values, so any mix of clothes on any body is one mesh and one draw, and swapping a shirt is free.
// The original painted texture is kept as shading detail (folds, seams, wear), not colour.

uniform sampler2D base_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D nrm_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool has_nrm = false;
uniform vec4 base_col : source_color = vec4(1.0);
uniform float base_lum = 0.4;        // the original texture's average brightness (to read its shading off it)
uniform float m_per_unit = 0.01;     // metres in one skeleton unit (cloth thickness is pushed out in metres)

// what they are wearing: kinds are numbers (Outfit.TOPS / BOTTOMS / FEET); colours sRGB (Godot makes Color instance values linear)
instance uniform float top_kind = 0.0;      // 0 none 1 tee 2 singlet 3 flanno 4 work shirt 5 hi-vis 6 hoodie 7 jacket
instance uniform vec4 top_col = vec4(0.6, 0.6, 0.6, 1.0);
instance uniform vec4 top_col2 = vec4(0.1, 0.1, 0.1, 1.0);
instance uniform float sleeve = 0.45;       // 0 none .. 1 to the wrist
instance uniform float top_bottom = 0.1;    // where the shirt hangs to (torso height, 0 = hip joint, 1 = neck)
instance uniform float bot_kind = 1.0;      // 0 none (briefs) 1 jeans 2 shorts 3 cargo 4 trackies
instance uniform vec4 bot_col = vec4(0.15, 0.2, 0.35, 1.0);
instance uniform float leg_len = 1.0;       // 0 .. 1 to the ankle
instance uniform float feet_kind = 1.0;     // 0 bare 1 work boots 2 gumboots 3 runners 4 thongs
instance uniform vec4 feet_col = vec4(0.35, 0.22, 0.12, 1.0);
instance uniform vec4 skin_col = vec4(0.62, 0.45, 0.36, 1.0);
instance uniform float wear = 0.2;          // dirt
instance uniform float blood = 0.0;
instance uniform vec4 tint = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform float keep_tone = 1.0;     // the character screen's skin tone, on the painted face and hands too   // a zombie's grey-green cast over the lot

varying vec4 f;        // arm_t, leg_t, h, female
varying vec3 rp;       // rest position (m: y up from the ground, x and z from the hips)
varying vec3 rn;       // rest normal
varying float keep;    // 1 on the head and hands: drawn as painted

// 0 skin, 1 top, 2 bottoms, 3 feet, 4 briefs, 5 crop top
int layer(vec4 q, float y) {
	float arm_t = q.x, leg_t = q.y, h = q.z;
	bool top = top_kind > 0.5;
	bool bot = bot_kind > 0.5;
	if (leg_t > 0.0) {
		float boot_top = feet_kind < 0.5 ? 9.0 : (feet_kind < 1.5 ? 0.80 : (feet_kind < 2.5 ? 0.64 : (feet_kind < 3.5 ? 0.95 : 9.0)));
		bool boot = leg_t > boot_top;
		bool pants = bot && leg_t < leg_len;
		if (feet_kind > 3.5 && leg_t > 0.965 && y < 0.03) return 3;          // a thong's sole
		if (boot && (feet_kind > 1.5 && feet_kind < 2.5 || leg_t >= 0.9)) return 3;
		if (pants) return 2;
		if (boot) return 3;
		if (!bot && leg_t < 0.07) return 4;
		return 0;
	}
	if (arm_t > 0.0) {
		return (top && arm_t < sleeve) ? 1 : 0;
	}
	if (h >= 1.0) {
		float collar = (top_kind > 3.5) ? (top_kind > 5.5 ? 0.16 : 0.09) : 0.03;
		return (top && h < 1.0 + collar) ? 1 : 0;
	}
	if (top && h > top_bottom) return 1;
	if (h < 0.24) return bot ? 2 : 4;
	if (!top && q.w > 0.5 && h > 0.55 && h < 0.83) return 5;
	return 0;
}

float thickness(int l) {
	if (l == 1) return top_kind > 6.5 ? 0.012 : (top_kind > 5.5 ? 0.009 : (top_kind > 2.5 ? 0.004 : 0.0025));
	if (l == 2) return bot_kind > 2.5 && bot_kind < 3.5 ? 0.004 : 0.003;
	if (l == 3) return feet_kind > 1.5 && feet_kind < 2.5 ? 0.008 : (feet_kind > 3.5 ? 0.0 : 0.006);
	return 0.0;
}

void vertex() {
	f = CUSTOM0;
	rp = CUSTOM1.xyz;
	rn = CUSTOM2.xyz;
	keep = CUSTOM2.w;
	int l = layer(f, rp.y);
	if (CUSTOM2.w < 0.5) VERTEX += NORMAL * thickness(l) / max(m_per_unit, 1e-6);
}

float hash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vnoise(vec3 x) {
	vec3 i = floor(x); vec3 g = fract(x); g = g * g * (3.0 - 2.0 * g);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), g.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), g.x), g.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), g.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), g.x), g.y), g.z);
}
// the two surface coordinates a woven pattern runs along, picked by which way the cloth faces at rest
vec2 cloth_uv(vec3 p, vec3 n) {
	vec3 a = abs(n);
	if (a.y > a.x && a.y > a.z) return p.xz;
	return a.x > a.z ? p.zy : p.xy;
}
vec3 plaid(vec2 uv, vec3 c1, vec3 c2) {
	float P = 0.085;
	vec2 g = fract(uv / P);
	float a = step(g.x, 0.42), b = step(g.y, 0.42);
	float thin = max(step(abs(g.x - 0.71), 0.025), step(abs(g.y - 0.71), 0.025));
	vec3 c = mix(c1, c2, a * b);                       // the dark squares where both bands cross
	c = mix(c, mix(c1, c2, 0.5), (a + b) * 0.5 * (1.0 - a * b));
	c = mix(c, vec3(0.85, 0.8, 0.65), thin * 0.35);
	return c;
}

void fragment() {
	int l = layer(f, rp.y);
	vec3 orig = texture(base_tex, UV).rgb;
	if (keep > 0.5) {
		ALBEDO = orig * base_col.rgb * tint.rgb * keep_tone;
		ROUGHNESS = 0.6;
		if (has_nrm) { NORMAL_MAP = texture(nrm_tex, UV).rgb; NORMAL_MAP_DEPTH = 1.0; }
	} else {
	float lum = dot(orig, vec3(0.299, 0.587, 0.114));
	float detail = clamp(mix(1.0, lum / max(base_lum, 0.05), 0.5), 0.7, 1.22);
	vec2 cu = cloth_uv(rp, rn);
	float n1 = vnoise(rp * 38.0);
	vec3 col = skin_col.rgb;
	float rough = 0.6;
	float metal = 0.0;
	vec3 emit = vec3(0.0);
	if (l == 0) {
		col = skin_col.rgb * (0.94 + 0.12 * vnoise(rp * 60.0));
		rough = 0.55;
	} else if (l == 1) {
		rough = 0.9;
		col = top_col.rgb;
		if (top_kind > 2.5 && top_kind < 3.5) {
			col = plaid(cu, top_col.rgb, top_col2.rgb);
		} else if (top_kind > 4.5 && top_kind < 5.5) {
			// two-tone hi-vis: fluoro over the shoulders and down the sleeves, the body below; reflective tape
			bool upper = f.x > 0.0 || f.z > 0.58;
			col = upper ? top_col.rgb : top_col2.rgb;
			if (upper) emit = top_col.rgb * 0.08;
			float tape = step(abs(f.z - 0.5), 0.022) + step(abs(f.z - 0.32), 0.022) * (f.x > 0.0 ? 0.0 : 1.0) + step(abs(f.x - 0.72), 0.03) * (f.x > 0.0 ? 1.0 : 0.0);
			if (tape > 0.5) { col = vec3(0.72); rough = 0.3; metal = 0.5; }
		} else if (top_kind > 5.5 && top_kind < 6.5) {
			col = top_col.rgb * (0.9 + 0.2 * vnoise(rp * 140.0));          // marle
		} else if (top_kind > 6.5) {
			col = top_col.rgb * (0.85 + 0.25 * vnoise(rp * 9.0));          // a field jacket's faded olive
		}
		// a little cuff and hem shading
		col *= 1.0 - 0.12 * step(f.x > 0.0 ? sleeve - f.x : 1.0, 0.03);
	} else if (l == 2) {
		rough = 0.92;
		col = bot_col.rgb;
		if (bot_kind < 1.5) {
			float tw = 0.92 + 0.08 * sin((cu.x + cu.y) * 900.0);           // denim twill
			float fade = 1.0 + 0.25 * smoothstep(0.35, 0.0, abs(f.y - 0.5)) + 0.15 * vnoise(rp * 6.0);   // knees and thighs worn pale
			col = bot_col.rgb * tw * fade;
		} else if (bot_kind > 3.5) {
			col = bot_col.rgb * (0.88 + 0.22 * vnoise(rp * 140.0));
		}
	} else if (l == 3) {
		col = feet_col.rgb;
		rough = 0.75;
		if (feet_kind > 1.5 && feet_kind < 2.5) { rough = 0.3; }
		if (rp.y < 0.028) { col = feet_kind > 2.5 && feet_kind < 3.5 ? vec3(0.85) : vec3(0.05); rough = 0.8; }   // the sole
	} else if (l == 4) {
		col = vec3(0.08, 0.09, 0.12);
		rough = 0.85;
	} else {
		col = vec3(0.1, 0.1, 0.11);
		rough = 0.85;
	}
	if (l != 0) col *= detail;
	else col *= clamp(mix(1.0, detail, 0.3), 0.88, 1.12);
	// dirt, worse down low; blood
	float dn = vnoise(rp * 7.0) * 0.6 + n1 * 0.4;
	float dirt = wear * (0.35 + 0.65 * smoothstep(0.4, 1.0, f.y)) * smoothstep(0.35, 0.8, dn);
	col = mix(col, vec3(0.2, 0.15, 0.1), clamp(dirt, 0.0, 0.85));
	float bl = blood * smoothstep(0.55, 0.75, vnoise(rp * 5.0 + 3.1) * 0.7 + n1 * 0.3);
	col = mix(col, vec3(0.18, 0.02, 0.015), clamp(bl, 0.0, 0.95));
	ALBEDO = col * tint.rgb;
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = emit;
	if (has_nrm) {
		NORMAL_MAP = texture(nrm_tex, UV).rgb;
		NORMAL_MAP_DEPTH = 0.8;
	}
	}
}
