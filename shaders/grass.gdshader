shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;
// grass blades: colour from the vertex, sway with a gusting wind, a touch of light through the blades
uniform vec3 tint : source_color = vec3(1.0);
uniform float wind = 0.12;
varying vec3 wp;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME;
	float gust = sin(w.x * 0.05 + t * 0.8) * 0.5 + 0.5;
	float sway = (sin(w.x * 0.9 + t * 2.3) + sin(w.z * 1.3 + t * 1.7) * 0.6) * wind * (0.4 + gust);
	VERTEX.x += sway * UV.y * UV.y;
	VERTEX.z += sway * 0.6 * UV.y * UV.y;
	wp = w;
}
void fragment() {
	float v = fract(sin(dot(floor(wp.xz * 0.7), vec2(12.9898, 78.233))) * 43758.5453);
	ALBEDO = COLOR.rgb * tint * (0.85 + 0.3 * v);
	ROUGHNESS = 0.85;
	BACKLIGHT = vec3(0.25, 0.32, 0.1) * UV.y;
	NORMAL = mix(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz, 0.6);
}
