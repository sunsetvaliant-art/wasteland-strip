shader_type spatial;
render_mode cull_back, depth_draw_opaque;
// 0.2.75: the MakeHuman people's skin and clothes. The body's vertex colours say which garments hide each vertex
// (tools/mh/gen_people.py): whatever's worn (the instance's "worn" bits) drops the skin under it, so nothing pokes
// through. Clothes take a colour multiply (a white tee dyed), and everyone takes dirt, blood and a zombie's cast.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool has_nrm = false;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float rough = 0.8;
uniform bool is_body = false;

instance uniform int worn = 0;
instance uniform vec4 mul = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform vec4 tint = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform float wear = 0.15;
instance uniform float blood = 0.0;
instance uniform float pale = 0.0;          // a zombie's dead skin: grey, a little green, bruised

varying float hidden;
varying float under;     // 1 where the underwear is (bit 23 of the vertex colour: tools/mh/gen_people.py)

void vertex() {
	hidden = 0.0;
	under = 0.0;
	if (is_body) {
		int bits = int(round(COLOR.r * 255.0)) | (int(round(COLOR.g * 255.0)) << 8) | (int(round(COLOR.b * 255.0)) << 16);
		if ((bits & worn) != 0) hidden = 1.0;
		under = float((bits >> 23) & 1);
	}
}

float hash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vnoise(vec3 x) {
	vec3 i = floor(x); vec3 g = fract(x); g = g * g * (3.0 - 2.0 * g);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), g.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), g.x), g.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), g.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), g.x), g.y), g.z);
}

void fragment() {
	if (hidden > 0.01) discard;
	vec3 c = texture(albedo_tex, UV).rgb * albedo.rgb;
	if (is_body && pale > 0.0) {
		float l0 = dot(c, vec3(0.299, 0.587, 0.114));
		vec3 dead = vec3(l0) * vec3(0.8, 0.85, 0.76) * (0.85 + 0.3 * vnoise(vec3(UV * 9.0, 2.0)));
		dead = mix(dead, vec3(0.32, 0.2, 0.26) * l0 * 2.0, smoothstep(0.62, 0.8, vnoise(vec3(UV * 5.0, 7.0))) * 0.6);   // bruising
		c = mix(c, dead, pale);
	}
	if (is_body && under > 0.5) {
		// underwear: dark cotton (always there; it's just under whatever's on top)
		c = vec3(0.05, 0.06, 0.1);
	}
	if (!is_body) {
		// dyed: the multiply on the cloth's own shading (its light parts take the colour, its seams stay dark)
		float l = dot(c, vec3(0.299, 0.587, 0.114));
		c = mix(c, mul.rgb * (0.35 + 0.9 * l), step(0.001, 1.0 - min(mul.r, min(mul.g, mul.b))) * 0.9);
	}
	vec3 lp = vec3(UV * 24.0, 0.5);          // on the cloth, so it doesn't swim as they move
	float n1 = vnoise(lp);
	float n2 = vnoise(lp * 3.4);
	float dirt = wear * smoothstep(0.45, 0.85, n1 * 0.7 + n2 * 0.3);
	c = mix(c, vec3(0.2, 0.15, 0.1), clamp(dirt, 0.0, 0.8));
	float bl = blood * smoothstep(0.55, 0.78, vnoise(lp * 0.45 + 3.1) * 0.7 + n2 * 0.3);
	c = mix(c, vec3(0.2, 0.02, 0.015), clamp(bl, 0.0, 0.95));
	ALBEDO = c * tint.rgb;
	ROUGHNESS = (is_body && under > 0.5) ? 0.85 : rough;
	if (has_nrm) NORMAL_MAP = texture(normal_tex, UV).rgb;
}
