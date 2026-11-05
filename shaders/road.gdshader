shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Roads decades after anyone last fixed them. Surfaces by vertex colour R: 0 seal, .5 gravel, .75 grassed batter,
// 1 concrete (kerbs, footpaths, bridge decks). Markings by G (road class), solid centre lines in curves (B),
// how far nature has got back in (A). UV = (metres across, metres along); UV2 = (half-width, end fade).

uniform sampler2D asph_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asph_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asph_rgh : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tyre_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D conc_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D conc_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float asph_scale = 0.28;       // asphalt tile ~3.5 m
uniform float wear = 1.3;              // master overgrowth amount (Forge / weather can push it)
uniform vec3 paint_white : source_color = vec3(0.86, 0.85, 0.80);
uniform vec3 grass_tint : source_color = vec3(0.78, 0.92, 0.62);

varying vec3 wpos;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y); }
float fbm(vec2 p) { return vn(p) * 0.5 + vn(p * 2.03 + 17.1) * 0.27 + vn(p * 4.1 + 3.7) * 0.15 + vn(p * 8.3 - 9.2) * 0.08; }

float band(float x, float c, float w, float aa) { return 1.0 - smoothstep(w * 0.5 - aa, w * 0.5 + aa, abs(x - c)); }

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	float off = UV.x, along = UV.y, hs = UV2.x, endf = UV2.y;
	float surf = COLOR.r, style = COLOR.g, curve = COLOR.b, wild = COLOR.a * wear;
	vec2 suv = vec2(off, along) * asph_scale;            // follows the road, so the cracks run with it
	vec2 wuv = wpos.xz * 0.16;                           // world space for the natural stuff
	float aa = fwidth(off) * 1.2 + 0.01;

	// --- base surfaces
	vec3 a_col = texture(asph_alb, suv).rgb;
	float a_rgh = texture(asph_rgh, suv).r;
	vec3 a_nrm = texture(asph_nrm, suv).rgb;
	// tyre-polished wheel tracks and oil staining on the sealed lanes
	float lane = abs(abs(off) - hs * 0.5);
	float tracks = (1.0 - smoothstep(0.25, 0.9, abs(lane - 0.45))) * step(0.01, hs - abs(off)) * (1.0 - wild);
	a_col = mix(a_col, texture(tyre_alb, suv * 0.7).rgb * 0.9, 0.35 * tracks);
	a_col *= 0.92 + 0.16 * fbm(wuv * 0.25);              // big patches of different-age seal
	vec3 g_col = texture(dirt_alb, wuv * 1.6).rgb;
	vec3 g_nrm = texture(dirt_nrm, wuv * 1.6).rgb;
	vec3 c_col = texture(conc_alb, suv * 0.9).rgb * 0.95;
	vec3 c_nrm = texture(conc_nrm, suv * 0.9).rgb;
	vec3 gr_col = texture(grass_alb, wuv * 1.3).rgb * grass_tint;
	vec3 gr_nrm = texture(grass_nrm, wuv * 1.3).rgb;

	float is_gravel = smoothstep(0.3, 0.55, surf) * (1.0 - smoothstep(0.6, 0.8, surf));
	float is_grass = smoothstep(0.6, 0.75, surf) * (1.0 - smoothstep(0.85, 0.95, surf));
	float is_conc = smoothstep(0.85, 0.98, surf);
	vec3 col = a_col; vec3 nrm = a_nrm; float rgh = mix(0.75, 0.95, a_rgh);
	col = mix(col, g_col, is_gravel); nrm = mix(nrm, g_nrm, is_gravel); rgh = mix(rgh, 0.95, is_gravel);
	col = mix(col, c_col, is_conc); nrm = mix(nrm, c_nrm, is_conc); rgh = mix(rgh, 0.85, is_conc);

	// --- line markings (Australian: white, dashed 3 m line / 9 m gap, solid through curves)
	float paint = 0.0;
	float sealed = (1.0 - is_gravel) * (1.0 - is_grass) * (1.0 - is_conc);
	if (style > 0.1) {
		float edge = (style > 0.4 && style < 0.6) ? hs - 1.1 : hs - 0.35;
		paint = max(paint, band(abs(off), edge, 0.1, aa));
		float dash = step(fract(along / 12.0), 0.25);
		if (style < 0.4) {                               // two-lane road: centre line
			float c = mix(dash, 1.0, step(0.5, curve));
			paint = max(paint, band(off, 0.0, 0.1, aa) * c);
		} else if (style < 0.6) {                        // motorway carriageway: lane line
			paint = max(paint, band(off, 0.0, 0.1, aa) * dash);
		}
	}
	float fade = 0.35 + 0.55 * fbm(vec2(along * 0.08, off * 0.5) + 5.0);   // sun-faded, worn through in patches
	paint *= sealed * fade * smoothstep(0.0, 1.0, endf);
	col = mix(col, paint_white, paint);
	rgh = mix(rgh, 0.6, paint);

	// --- nature taking it back: in from the edges, up the cracks, everywhere on the quiet roads
	float edge_d = smoothstep(hs - 1.6, hs + 0.3, abs(off));
	float crack = 1.0 - smoothstep(0.08, 0.22, a_col.r + a_col.g * 0.2);   // the dark crack lines in the scan
	float n1 = fbm(wuv * 0.9);
	float n2 = fbm(wuv * 3.5 + 11.0);
	float grow = (n1 - 0.62 + edge_d * 0.55 + crack * 0.35 * n2) * 1.6 * wild + (wild - 0.55) * 0.5;
	grow = clamp(grow, 0.0, 1.0) * (1.0 - is_grass);
	float moss = clamp((n2 - 0.5) * 2.0 * wild, 0.0, 1.0) * sealed * (1.0 - grow);
	col = mix(col, col * vec3(0.55, 0.62, 0.38), moss * 0.5);
	col = mix(col, gr_col, max(grow, is_grass));
	nrm = mix(nrm, gr_nrm, max(grow, is_grass));
	rgh = mix(rgh, 0.92, max(grow, is_grass));
	// leaf litter and dirt washed across low spots
	float litter = clamp((fbm(wuv * 0.4 + 31.0) - 0.6) * 3.0, 0.0, 1.0) * wild * sealed;
	col = mix(col, g_col * vec3(0.8, 0.72, 0.6), litter * 0.6);

	ALBEDO = col;
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = 1.0;
	ROUGHNESS = rgh;
	SPECULAR = 0.35;
}
