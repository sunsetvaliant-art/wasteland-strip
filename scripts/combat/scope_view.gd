class_name ScopeView
extends Control
## The magnified window you look through when aiming down a scoped rifle: a second camera at the eye with the fov
## cut by the scope's power, drawn in a round window in the middle of the screen with a reticle (post and
## crosshair, the old No.32 / SUIT style), a dark eye-relief ring and a bit of edge blur. It only renders while used.

var sub: SubViewport
var cam: Camera3D
var rect: TextureRect
var mat: ShaderMaterial
var on := false
var fade := 0.0
var main_cam_fov := 70.0

const SHADER := """
shader_type canvas_item;
uniform float fade = 1.0;
uniform float reticle_style = 0.0;   // 0 = post + crosshair, 1 = chevron (SUIT)
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;                         // canvas y runs down; the reticle's drawn with up = +y
	float r = length(p);
	vec4 c = texture(TEXTURE, UV);
	// slight darkening and colour fringe towards the edge of the glass
	c.rgb *= 1.0 - smoothstep(0.75, 1.0, r) * 0.7;
	// reticle
	float px = fwidth(p.x) * 1.5;
	float line = 0.0;
	line = max(line, (1.0 - smoothstep(0.0, px, abs(p.y))) * step(0.08, abs(p.x)));            // horizontal hairs
	if (reticle_style < 0.5) {
		line = max(line, (1.0 - smoothstep(0.0, px * 3.0, abs(p.x))) * step(p.y, -0.0) * step(-1.0, p.y)); // the post from below
		line = max(line, (1.0 - smoothstep(0.0, px, abs(p.x))) * step(0.0, p.y) * step(0.6, p.y));
	} else {
		vec2 q = p - vec2(0.0, -0.01);
		float chev = abs(abs(q.x) * 1.6 + q.y) ;
		line = max(line, (1.0 - smoothstep(0.0, px * 2.0, chev)) * step(q.y, 0.0) * step(-0.12, q.y));
		line = max(line, (1.0 - smoothstep(0.0, px, abs(p.x))) * step(0.15, abs(p.y)));
	}
	c.rgb = mix(c.rgb, vec3(0.02), line);
	// the round window, a black ring, then nothing
	float inside = 1.0 - smoothstep(0.97, 1.0, r);
	float ring = smoothstep(0.93, 0.98, r) * (1.0 - smoothstep(1.0, 1.04, r));
	c.rgb = mix(c.rgb, vec3(0.0), ring);
	c.a = max(inside, ring * 0.9) * fade;
	COLOR = c;
}
"""

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub = SubViewport.new()
	sub.size = Vector2i(720, 720)
	sub.render_target_update_mode = SubViewport.UPDATE_DISABLED
	sub.msaa_3d = Viewport.MSAA_2X
	add_child(sub)
	cam = Camera3D.new()
	cam.near = 0.1
	cam.far = 6000.0
	cam.cull_mask = 0xFFFFF & ~(2 | 4)       # not your own gun (layer 2) or body (layer 3)
	sub.add_child(cam)
	rect = TextureRect.new()
	rect.texture = sub.get_texture()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	mat.shader = sh
	rect.material = mat
	add_child(rect)
	visible = false

## Called every frame by whoever's aiming
func set_active(want: bool, g: Gun, look: Basis, eye: Vector3) -> void:
	on = want
	if not want and fade <= 0.0:
		return
	var mag: float = max(float(g.def.get("scope", 1.0)), 1.0) if g else 1.0
	var vp_cam := get_viewport().get_camera_3d()
	main_cam_fov = vp_cam.fov if vp_cam else 70.0
	# true magnification: tan of the half-angle divided by the power
	var half := deg_to_rad(main_cam_fov * 0.5)
	cam.fov = rad_to_deg(atan(tan(half) / mag)) * 2.0 * 1.0
	cam.global_transform = Transform3D(look, eye + (-look.z) * 0.3)
	mat.set_shader_parameter("reticle_style", 1.0 if g and g.key == "slr" else 0.0)

func _process(dt: float) -> void:
	fade = move_toward(fade, 1.0 if on else 0.0, dt * 8.0)
	visible = fade > 0.0
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	if not visible:
		return
	var vs := get_viewport_rect().size
	var d: float = vs.y * 0.62
	rect.size = Vector2(d, d)
	rect.position = (vs - rect.size) * 0.5
	mat.set_shader_parameter("fade", fade)
	# the eye has to be right behind the glass: the field narrows in as you settle
	rect.scale = Vector2.ONE * lerpf(0.85, 1.0, fade)
	rect.pivot_offset = rect.size * 0.5
	queue_redraw()

func _draw() -> void:
	if fade <= 0.0:
		return
	# everything outside the glass goes dark, like having your eye to a real scope
	var vs := get_viewport_rect().size
	var c := vs * 0.5
	var r := vs.y * 0.31 * lerpf(0.85, 1.0, fade)
	var a := 0.82 * fade
	var col := Color(0, 0, 0, a)
	draw_rect(Rect2(0, 0, c.x - r, vs.y), col)
	draw_rect(Rect2(c.x + r, 0, vs.x - c.x - r, vs.y), col)
	draw_rect(Rect2(c.x - r, 0, r * 2.0, c.y - r), col)
	draw_rect(Rect2(c.x - r, c.y + r, r * 2.0, vs.y - c.y - r), col)
	# corners of the square round the circle
	var pts := 48
	for q in 4:
		var poly := PackedVector2Array()
		var ang0 := q * PI * 0.5
		var corner := c + Vector2(cos(ang0 + PI * 0.25), sin(ang0 + PI * 0.25)).sign() * r
		poly.append(corner)
		for i in pts + 1:
			var aa := ang0 + PI * 0.5 * float(i) / pts
			poly.append(c + Vector2(cos(aa), sin(aa)) * r)
		draw_colored_polygon(poly, col)
