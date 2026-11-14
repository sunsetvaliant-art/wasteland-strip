shader_type sky;
// The sky: day to dusk to night, a sun and a moon, stars after dark, and two drifting layers of cloud whose cover
// follows the weather (a few fair-weather clouds on a clear day, a solid grey lid in a storm).
uniform vec3 top : source_color = vec3(0.13, 0.36, 0.78);
uniform vec3 horizon : source_color = vec3(0.62, 0.76, 0.9);
uniform vec3 ground : source_color = vec3(0.16, 0.2, 0.15);
uniform vec3 cloud_col : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 sun_col : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 moon_dir = vec3(0.3, 0.8, 0.4);
uniform float night = 0.0;
uniform float cover = 0.2;
uniform float wind = 1.0;
uniform sampler2D noise : repeat_enable, filter_linear_mipmap;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col = mix(horizon, top, pow(clamp(h, 0.0, 1.0), 0.45));
	if (h < 0.0) col = mix(horizon, ground, clamp(-h * 6.0, 0.0, 1.0));
	float clear = 1.0 - cover;
	// stars: brighter ones fewer, twinkling a little, washed out towards the horizon
	if (night > 0.05 && h > 0.0) {
		vec3 cell = floor(d * 260.0);
		float r = hash(cell);
		float star = smoothstep(0.9965, 1.0, r) * (0.65 + 0.35 * sin(TIME * 1.7 + r * 400.0));
		col += vec3(0.9, 0.95, 1.0) * star * night * clear * smoothstep(0.02, 0.3, h) * 2.2;
	}
	// the sun
	if (LIGHT0_ENABLED) {
		float sd = dot(d, LIGHT0_DIRECTION);
		col += sun_col * (smoothstep(0.99955, 0.9998, sd) * 6.0 + pow(max(sd, 0.0), 420.0) * 0.7 + pow(max(sd, 0.0), 12.0) * 0.12) * (1.0 - cover * 0.9) * (1.0 - night);
	}
	// the moon: a pale disc with a soft ring of light
	float md = dot(d, normalize(moon_dir));
	float disc = smoothstep(0.99925, 0.9995, md);
	float mare = 0.82 + 0.18 * texture(noise, d.xz * 9.0 + d.y * 4.0).r;
	col = mix(col, vec3(0.92, 0.94, 1.0) * mare * 1.3, disc * night * (1.0 - cover * 0.75));
	col += vec3(0.5, 0.6, 0.8) * pow(max(md, 0.0), 260.0) * 0.25 * night * clear;
	// clouds on a flat ceiling, two layers sliding at different speeds
	if (h > 0.015) {
		vec2 uv = d.xz / (h + 0.14);
		float t = TIME * 0.0006 * wind;   // a layer crosses the sky in about 90 s at the zenith on a calm day
		float n = texture(noise, uv * 0.055 + vec2(t, t * 0.35)).r * 0.62 + texture(noise, uv * 0.16 + vec2(-t * 1.6, t * 0.9)).r * 0.38;
		float th = mix(0.68, 0.2, cover);
		float c = smoothstep(th, th + 0.22, n) * smoothstep(0.015, 0.16, h);
		float thick = smoothstep(th + 0.05, th + 0.5, n);
		vec3 cc = cloud_col * mix(1.0, 0.52, thick * (0.4 + 0.6 * cover));
		if (LIGHT0_ENABLED) cc += sun_col * pow(max(dot(d, LIGHT0_DIRECTION), 0.0), 8.0) * 0.25 * (1.0 - thick) * (1.0 - night);
		col = mix(col, cc, c * 0.94);
	}
	COLOR = col;
}
